// Jalankan:  deno test -A supabase/functions/_shared/auth_guard_test.ts
import assert from "node:assert/strict";
import { SignJWT } from "npm:jose@5.9.6";
import { requireAuth, type LookupUser } from "./auth_guard.ts";
import { HttpError } from "./http.ts";
import { signAccessToken } from "./jwt.ts";

const SECRET = "s".repeat(40);
const enc = (v: string) => new TextEncoder().encode(v);

const req = (token?: string) =>
  new Request("https://x/functions/v1/products", {
    method: "POST",
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });

const users: Record<number, { role: "customer" | "manager" | "staff"; is_active: boolean; username: string }> = {
  1: { role: "manager", is_active: true, username: "mgr" },
  2: { role: "customer", is_active: true, username: "cust" },
  3: { role: "staff", is_active: false, username: "off" },
};
const lookupUser: LookupUser = (id) => Promise.resolve(users[id] ?? null);
const token = (id: number, role: string) => signAccessToken(SECRET, { id, role, username: "x" }, 1800);

async function status(p: Promise<unknown>): Promise<number> {
  try {
    await p;
    return 200;
  } catch (e) {
    if (e instanceof HttpError) return e.status;
    throw e;
  }
}

Deno.test("tanpa/format header salah -> 401", async () => {
  assert.equal(await status(requireAuth(req(), { secret: SECRET, lookupUser })), 401);
  const bad = new Request("https://x", { headers: { authorization: "Basic abc" } });
  assert.equal(await status(requireAuth(bad, { secret: SECRET, lookupUser })), 401);
});

Deno.test("token valid dan role cocok -> lolos, role dari DB", async () => {
  const me = await requireAuth(req(await token(1, "manager")), { secret: SECRET, lookupUser, roles: ["manager"] });
  assert.deepEqual(me, { userId: 1, role: "manager", username: "mgr" });
  // tanpa batas role: semua yang login boleh
  assert.equal((await requireAuth(req(await token(2, "customer")), { secret: SECRET, lookupUser })).role, "customer");
});

Deno.test("role tidak berhak -> 403", async () => {
  assert.equal(await status(requireAuth(req(await token(2, "customer")), { secret: SECRET, lookupUser, roles: ["manager"] })), 403);
});

Deno.test("klaim role di token dipalsukan -> tetap 403 (DB yang menentukan)", async () => {
  // Token bilang 'manager' padahal di DB user 2 adalah customer.
  const t = await token(2, "manager");
  assert.equal(await status(requireAuth(req(t), { secret: SECRET, lookupUser, roles: ["manager"] })), 403);
});

Deno.test("akun nonaktif atau sudah dihapus -> 401 walau token masih berlaku", async () => {
  assert.equal(await status(requireAuth(req(await token(3, "staff")), { secret: SECRET, lookupUser })), 401);
  assert.equal(await status(requireAuth(req(await token(99, "manager")), { secret: SECRET, lookupUser })), 401);
});

Deno.test("token palsu: secret lain, kedaluwarsa, alg none, sampah -> 401", async () => {
  const forged = await new SignJWT({ role: "manager", username: "x" })
    .setProtectedHeader({ alg: "HS256" }).setSubject("1").setIssuer("noir")
    .setIssuedAt().setExpirationTime("30m").sign(enc("y".repeat(40)));
  const expired = await new SignJWT({ role: "manager", username: "x" })
    .setProtectedHeader({ alg: "HS256" }).setSubject("1").setIssuer("noir")
    .setIssuedAt(Math.floor(Date.now() / 1000) - 7200)
    .setExpirationTime(Math.floor(Date.now() / 1000) - 3600).sign(enc(SECRET));
  const noneHeader = btoa(JSON.stringify({ alg: "none", typ: "JWT" })).replace(/=+$/, "");
  const nonePayload = btoa(JSON.stringify({ sub: "1", role: "manager", iss: "noir" })).replace(/=+$/, "");
  for (const t of [forged, expired, `${noneHeader}.${nonePayload}.`, "abc.def.ghi", "sampah"]) {
    assert.equal(await status(requireAuth(req(t), { secret: SECRET, lookupUser })), 401);
  }
});

Deno.test("sub bukan angka -> 401; JWT_SECRET lemah -> error server (bukan lolos)", async () => {
  const weird = await signAccessToken(SECRET, { id: Number.NaN, role: "manager", username: "x" }, 1800);
  assert.equal(await status(requireAuth(req(weird), { secret: SECRET, lookupUser })), 401);
  const valid = await token(1, "manager");
  await assert.rejects(() => requireAuth(req(valid), { secret: "pendek", lookupUser }));
});