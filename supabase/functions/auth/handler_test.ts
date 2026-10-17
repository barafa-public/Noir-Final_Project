// Jalankan:  deno test -A supabase/functions/auth/handler_test.ts
import assert from "node:assert/strict";
import { createHandler } from "./handler.ts";
import type { AuthStore, RefreshRow, UserRow } from "./store.ts";
import { hashPassword } from "../_shared/password.ts";
import { verifyAccessToken } from "../_shared/jwt.ts";

const SECRET = "x".repeat(40);
const COST = 4; // murah agar tes cepat

function memoryStore() {
  const users: UserRow[] = [];
  const tokens: (RefreshRow & { token_hash: string })[] = [];
  let uid = 0, tid = 0;
  const store: AuthStore = {
    findUserByUsername: (u) => Promise.resolve(users.find((x) => x.username === u) ?? null),
    findUserById: (id) => Promise.resolve(users.find((x) => x.id === id) ?? null),
    createCustomer: (i) => {
      if (users.some((x) => x.username === i.username)) return Promise.resolve("duplicate" as const);
      users.push({
        id: ++uid, username: i.username, password_hash: i.password_hash, role: "customer",
        nama: i.nama, foto_url: null, biometric_enabled: false, is_active: true,
        failed_login_count: 0, locked_until: null,
      });
      return Promise.resolve("ok" as const);
    },
    setLoginState: (id, count, until) => {
      const u = users.find((x) => x.id === id)!;
      u.failed_login_count = count;
      u.locked_until = until ? until.toISOString() : null;
      return Promise.resolve();
    },
    insertRefreshToken: (i) => {
      tokens.push({
        id: ++tid, user_id: i.user_id, device: i.device, token_hash: i.token_hash,
        expires_at: i.expires_at.toISOString(), revoked_at: null,
      });
      return Promise.resolve();
    },
    findRefreshToken: (h) => Promise.resolve(tokens.find((t) => t.token_hash === h) ?? null),
    revokeRefreshToken: (id) => {
      const t = tokens.find((x) => x.id === id)!;
      t.revoked_at ||= new Date().toISOString();
      return Promise.resolve();
    },
  };
  return { store, users, tokens };
}

function setup(nowFn?: () => Date) {
  const mem = memoryStore();
  const handler = createHandler({
    store: mem.store,
    now: nowFn,
    config: {
      jwtSecret: SECRET, accessTtlSeconds: 1800, refreshTtlDays: 30,
      maxFailedLogins: 5, lockMinutes: 10, bcryptCost: COST,
    },
  });
  const call = async (action: string, body: unknown, method = "POST") => {
    const res = await handler(new Request(`https://x.supabase.co/functions/v1/auth/${action}`, {
      method,
      headers: { "content-type": "application/json" },
      body: method === "POST" ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined,
    }));
    const text = await res.text();
    const isJson = (res.headers.get("content-type") ?? "").includes("json");
    return { status: res.status, body: text && isJson ? JSON.parse(text) : null, res };
  };
  return { ...mem, call };
}

const REG = { username: "AgusWijaya", alamat: "Jl. Kridosono 7", telepon: "081234567890", password: "rahasia123" };

Deno.test("register: sukses, duplikat (tak peka huruf), validasi", async () => {
  const { call, users } = setup();
  assert.equal((await call("register", REG)).status, 201);
  assert.equal(users[0].username, "aguswijaya");
  assert.equal(users[0].nama, "AgusWijaya");
  assert.equal(users[0].role, "customer");
  assert.notEqual(users[0].password_hash, REG.password);
  assert.match(users[0].password_hash, /^\$2[aby]\$/);

  assert.equal((await call("register", { ...REG, username: "AGUSWIJAYA" })).status, 409);
  const badPhone = await call("register", { ...REG, username: "budi", telepon: "81234" });
  assert.equal(badPhone.status, 400);
  assert.equal(badPhone.body.error, "Nomor telepon tidak valid");
  assert.equal((await call("register", { ...REG, username: "budi", password: "123" })).body.error, "Password terlalu pendek");
  assert.equal((await call("register", { ...REG, username: "a b" })).status, 400);
  // role dari klien harus diabaikan
  await call("register", { ...REG, username: "sneaky", role: "manager" });
  assert.equal(users.find((u) => u.username === "sneaky")!.role, "customer");
});

Deno.test("login: sukses mengembalikan token & user tanpa hash", async () => {
  const { call, tokens } = setup();
  await call("register", REG);
  const r = await call("login", { username: " aguswijaya ", password: REG.password });
  assert.equal(r.status, 200);
  assert.equal(r.body.user.role, "customer");
  assert.equal(r.body.user.nama, "AgusWijaya");
  assert.equal("password_hash" in r.body.user, false);
  assert.equal(JSON.stringify(r.body).includes("password_hash"), false);
  const claims = await verifyAccessToken(SECRET, r.body.access_token);
  assert.equal(claims.role, "customer");
  assert.equal(claims.sub, String(r.body.user.id));
  // yang tersimpan di DB hanya hash, bukan token aslinya
  assert.equal(tokens.length, 1);
  assert.notEqual(tokens[0].token_hash, r.body.refresh_token);
  assert.equal(tokens[0].token_hash.length, 64);
});

Deno.test("login: password salah dan username tak ada -> respons identik", async () => {
  const { call } = setup();
  await call("register", REG);
  const a = await call("login", { username: "aguswijaya", password: "salah-banget" });
  const b = await call("login", { username: "tidakada", password: "salah-banget" });
  assert.equal(a.status, 401);
  assert.equal(b.status, 401);
  assert.deepEqual(a.body, b.body);
  assert.equal(a.body.error, "Username atau password salah");
});

Deno.test("login: terkunci setelah 5 gagal, terbuka lagi setelah 10 menit", async () => {
  let t = new Date("2026-10-17T00:00:00Z");
  const { call } = setup(() => t);
  await call("register", REG);
  for (let i = 0; i < 5; i++) {
    assert.equal((await call("login", { username: "aguswijaya", password: "salah" + i })).status, 401);
  }
  // password BENAR pun ditolak saat terkunci
  assert.equal((await call("login", { username: "aguswijaya", password: REG.password })).status, 429);
  t = new Date(t.getTime() + 11 * 60_000);
  assert.equal((await call("login", { username: "aguswijaya", password: REG.password })).status, 200);
});

Deno.test("login: akun nonaktif", async () => {
  const { call, users } = setup();
  await call("register", REG);
  users[0].is_active = false;
  assert.equal((await call("login", { username: "aguswijaya", password: "salah" })).status, 401);
  assert.equal((await call("login", { username: "aguswijaya", password: REG.password })).status, 403);
});

Deno.test("refresh: rotasi, token lama ditolak, kedaluwarsa ditolak", async () => {
  let t = new Date("2026-10-17T00:00:00Z");
  const { call } = setup(() => t);
  await call("register", REG);
  const login = (await call("login", { username: "aguswijaya", password: REG.password })).body;

  const r1 = await call("refresh", { refresh_token: login.refresh_token });
  assert.equal(r1.status, 200);
  assert.notEqual(r1.body.refresh_token, login.refresh_token);
  assert.equal((await call("refresh", { refresh_token: login.refresh_token })).status, 401); // lama mati
  assert.equal((await call("refresh", { refresh_token: "ngawur" })).status, 401);
  assert.equal((await call("refresh", {})).status, 401);

  t = new Date(t.getTime() + 31 * 86_400_000);
  assert.equal((await call("refresh", { refresh_token: r1.body.refresh_token })).status, 401);
});

Deno.test("logout: mencabut token, idempoten", async () => {
  const { call } = setup();
  await call("register", REG);
  const login = (await call("login", { username: "aguswijaya", password: REG.password })).body;
  assert.equal((await call("logout", { refresh_token: login.refresh_token })).status, 204);
  assert.equal((await call("logout", { refresh_token: login.refresh_token })).status, 204);
  assert.equal((await call("logout", { refresh_token: "ngawur" })).status, 204);
  assert.equal((await call("refresh", { refresh_token: login.refresh_token })).status, 401);
});

Deno.test("hash bcrypt $2a$10$ (format yang sama dengan seed) bisa diverifikasi", async () => {
  // Seed memakai crypt(..., gen_salt('bf',10)) di Postgres yang berbentuk $2a$10$...
  // Di sini hash dibuat bcryptjs (bukan output Postgres asli), jadi ini menguji format, bukan pgcrypto.
  const { store, users } = memoryStore();
  users.push({
    id: 1, username: "manager1", password_hash: await hashPassword("GantiPassword#1", 10),
    role: "manager", nama: "Manager Noir", foto_url: null, biometric_enabled: false,
    is_active: true, failed_login_count: 0, locked_until: null,
  });
  const h = createHandler({ store, config: {
    jwtSecret: SECRET, accessTtlSeconds: 1800, refreshTtlDays: 30, maxFailedLogins: 5, lockMinutes: 10, bcryptCost: COST } });
  const res = await h(new Request("https://x/auth/login", { method: "POST", body: JSON.stringify({ username: "Manager1", password: "GantiPassword#1" }) }));
  assert.equal(res.status, 200);
  assert.equal((await res.json()).user.role, "manager");
});

Deno.test("protokol: OPTIONS (CORS), GET, JSON rusak, aksi tak dikenal, token palsu", async () => {
  const { call } = setup();
  const opt = await call("login", null, "OPTIONS");
  assert.equal(opt.status, 200);
  assert.equal(opt.res.headers.get("access-control-allow-origin"), "*");
  assert.equal((await call("login", null, "GET")).status, 405);
  assert.equal((await call("login", "{bukan json")).status, 400);
  assert.equal((await call("login", "[1,2]")).status, 400);
  assert.equal((await call("hapus-semua", {})).status, 404);
  assert.equal((await call("login", {})).status, 400);

  // Token palsu: salah secret, alg 'none', dan kedaluwarsa harus ditolak
  const { SignJWT } = await import("npm:jose@5.9.6");
  const enc = (v: string) => new TextEncoder().encode(v);
  const forged = await new SignJWT({ role: "manager", username: "x" })
    .setProtectedHeader({ alg: "HS256" }).setSubject("1").setIssuer("noir")
    .setIssuedAt().setExpirationTime("30m").sign(enc("y".repeat(40)));
  await assert.rejects(() => verifyAccessToken(SECRET, forged));
  const expired = await new SignJWT({ role: "manager", username: "x" })
    .setProtectedHeader({ alg: "HS256" }).setSubject("1").setIssuer("noir")
    .setIssuedAt(Math.floor(Date.now() / 1000) - 7200).setExpirationTime(Math.floor(Date.now() / 1000) - 3600)
    .sign(enc(SECRET));
  await assert.rejects(() => verifyAccessToken(SECRET, expired));
  const header = btoa(JSON.stringify({ alg: "none", typ: "JWT" })).replace(/=+$/, "");
  const payload = btoa(JSON.stringify({ sub: "1", role: "manager", username: "x", iss: "noir" })).replace(/=+$/, "");
  await assert.rejects(() => verifyAccessToken(SECRET, `${header}.${payload}.`));
  await assert.rejects(() => verifyAccessToken(SECRET, "abc.def.ghi"));
});