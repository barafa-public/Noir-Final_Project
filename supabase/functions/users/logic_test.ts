// Jalankan:  deno test -A supabase/functions/users/logic_test.ts
import assert from "node:assert/strict";
import { HttpError } from "../_shared/http.ts";
import type { Role } from "../_shared/auth_guard.ts";
import { createRouter } from "../_shared/router.ts";
import {
  createUsersRoutes,
  type ProfileRow,
  type StaffPatch,
  type StaffRow,
  type UsersStore,
} from "./logic.ts";

interface Row extends ProfileRow {
  is_active: boolean;
  created_at: string;
  password_hash?: string;
  failed_login_count: number;
  locked_until: string | null;
}
const base = { alamat: null, telepon: null, biometric_enabled: false, foto_url: null, created_at: "2026-10-18T00:00:00Z", failed_login_count: 0, locked_until: null };

function setup() {
  const rows: Record<number, Row> = {
    1: { ...base, id: 1, username: "bara", role: "customer", nama: "Bara", foto_url: "1/avatar-1.jpg", alamat: "Yogya", telepon: "0812", is_active: true, password_hash: "RAHASIA" },
    2: { ...base, id: 2, username: "gudang1", role: "staff", nama: "Gudang Satu", is_active: true, password_hash: "HASH-LAMA" },
    3: { ...base, id: 3, username: "mgr", role: "manager", nama: "Manager", is_active: true, password_hash: "HASH-MGR" },
    4: { ...base, id: 4, username: "mgr2", role: "manager", nama: "Manager Dua", is_active: true },
  };
  let nextId = 10;
  const revoked: number[] = [];
  const toStaff = (r: Row): StaffRow => ({ id: r.id, username: r.username, role: r.role, nama: r.nama, is_active: r.is_active, created_at: r.created_at });

  const store: UsersStore = {
    getProfile: (id) => Promise.resolve(rows[id] ?? null),
    updateNama: (id, nama) => { rows[id].nama = nama; return Promise.resolve(); },
    signAvatar: (path) => Promise.resolve(`https://signed.example/${path}?t=abc`),
    listStaff: () => Promise.resolve(Object.values(rows).filter((r) => r.role === "staff").map(toStaff)),
    findUserById: (id) => Promise.resolve(rows[id] ? toStaff(rows[id]) : null),
    createStaff: (i) => {
      if (Object.values(rows).some((r) => r.username === i.username)) return Promise.resolve("duplicate" as const);
      const id = nextId++;
      rows[id] = { ...base, id, username: i.username, role: "staff", nama: i.nama, is_active: true, password_hash: i.password_hash };
      return Promise.resolve(toStaff(rows[id]));
    },
    updateStaff: (id, patch: StaffPatch) => {
      const r = rows[id];
      if (patch.nama !== undefined) r.nama = patch.nama;
      if (patch.is_active !== undefined) r.is_active = patch.is_active;
      if (patch.password_hash !== undefined) r.password_hash = patch.password_hash;
      if (patch.unlock) { r.failed_login_count = 0; r.locked_until = null; }
      return Promise.resolve(toStaff(r));
    },
    revokeSessions: (id) => { revoked.push(id); return Promise.resolve(); },
  };

  // meniru requireAuth: 401 tanpa login, 403 jika role tidak termasuk
  const authenticate = (req: Request, roles?: Role[]) => {
    const id = Number(req.headers.get("x-test-user") ?? "0");
    const user = rows[id];
    if (!user || !user.is_active) return Promise.reject(new HttpError(401, "Sesi berakhir. Silakan masuk lagi."));
    if (roles && !roles.includes(user.role as Role)) return Promise.reject(new HttpError(403, "Anda tidak berhak mengakses fitur ini"));
    return Promise.resolve({ userId: id, role: user.role as Role, username: user.username });
  };

  const handler = createRouter(createUsersRoutes(store, { hash: (p) => Promise.resolve(`HASH(${p})`) }), authenticate);
  async function call(action: string, body: unknown, user?: number) {
    const res = await handler(new Request(`https://x/functions/v1/users/${action}`, {
      method: "POST", headers: user ? { "x-test-user": String(user) } : {}, body: JSON.stringify(body),
    }));
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null };
  }
  return { rows, revoked, call, handler };
}

// ---------------------------------------------------------------- profil (Batch C)

Deno.test("me: butuh login; foto_url bertanda tangan; tidak membocorkan hash", async () => {
  const { call } = setup();
  assert.equal((await call("me", {})).status, 401);
  const r = await call("me", {}, 1);
  assert.equal(r.status, 200);
  assert.equal(r.body.foto_url, "https://signed.example/1/avatar-1.jpg?t=abc");
  assert.equal(JSON.stringify(r.body).includes("RAHASIA"), false);
  assert.equal((await call("me", {}, 2)).body.foto_url, null);
});

Deno.test("update-profile: hanya milik sendiri, validasi, spasi dirapikan", async () => {
  const { call, rows } = setup();
  const ok = await call("update-profile", { nama: "  Bara   Baradyan " }, 1);
  assert.equal(ok.body.nama, "Bara Baradyan");
  await call("update-profile", { nama: "Pura Pura", id: 2, user_id: 2 }, 1);
  assert.equal(rows[2].nama, "Gudang Satu"); // id dari body diabaikan
  for (const nama of ["A", "x".repeat(51), "ab\u0007cd", undefined]) {
    assert.equal((await call("update-profile", { nama }, 1)).status, 400);
  }
  assert.equal((await call("update-profile", { nama: "Bara" })).status, 401);
});

// ---------------------------------------------------------------- kelola staff (Batch D)

Deno.test("staff-*: hanya Manager (customer/staff -> 403, tanpa login -> 401)", async () => {
  const { call } = setup();
  const bodies: Record<string, unknown> = {
    "staff-list": {}, "staff-create": { username: "baru1", nama: "Baru", password: "rahasia1" },
    "staff-update": { id: 2, nama: "Ubah" },
  };
  for (const [action, body] of Object.entries(bodies)) {
    assert.equal((await call(action, body)).status, 401, action);
    assert.equal((await call(action, body, 1)).status, 403, `${action} customer`);
    assert.equal((await call(action, body, 2)).status, 403, `${action} staff`);
  }
});

Deno.test("staff-list: hanya akun staff, tanpa hash", async () => {
  const { call } = setup();
  const r = await call("staff-list", {}, 3);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.staff.map((s: { username: string }) => s.username), ["gudang1"]);
  assert.equal(JSON.stringify(r.body).includes("HASH"), false);
  assert.equal(JSON.stringify(r.body).includes("password"), false);
});

Deno.test("staff-create: role dipaksa staff, username huruf kecil, password di-hash", async () => {
  const { call, rows } = setup();
  const r = await call("staff-create", { username: "Gudang.Dua", nama: "  Gudang   Dua ", password: "rahasia1", role: "manager" }, 3);
  assert.equal(r.status, 201);
  assert.equal(r.body.staff.username, "gudang.dua");
  assert.equal(r.body.staff.nama, "Gudang Dua");
  const created = rows[r.body.staff.id];
  assert.equal(created.role, "staff"); // 'role: manager' dari klien diabaikan
  assert.equal(created.password_hash, "HASH(rahasia1)");
  assert.equal(JSON.stringify(r.body).includes("HASH"), false);
  assert.equal((await call("staff-create", { username: "GUDANG.DUA", nama: "X Y", password: "rahasia1" }, 3)).status, 409);
});

Deno.test("staff-create: validasi", async () => {
  const { call, rows } = setup();
  const ok = { username: "baru1", nama: "Baru", password: "rahasia1" };
  for (const bad of [
    { ...ok, username: "a b" }, { ...ok, username: "ab" }, { ...ok, nama: "A" },
    { ...ok, password: "123" }, { ...ok, password: "x".repeat(80) }, { username: "baru1" }, {},
  ]) {
    assert.equal((await call("staff-create", bad, 3)).status, 400, JSON.stringify(bad));
  }
  assert.equal(Object.keys(rows).length, 4);
});

Deno.test("staff-update: nonaktifkan mencabut sesi; aktifkan ulang membuka kunci", async () => {
  const { call, rows, revoked } = setup();
  rows[2].failed_login_count = 5;
  rows[2].locked_until = "2099-01-01T00:00:00Z";

  const off = await call("staff-update", { id: 2, is_active: false }, 3);
  assert.equal(off.status, 200);
  assert.equal(off.body.staff.is_active, false);
  assert.deepEqual(revoked, [2]);
  assert.equal(rows[2].locked_until, "2099-01-01T00:00:00Z"); // menonaktifkan tidak membuka kunci

  const on = await call("staff-update", { id: 2, is_active: true }, 3);
  assert.equal(on.body.staff.is_active, true);
  assert.equal(rows[2].failed_login_count, 0);
  assert.equal(rows[2].locked_until, null);
  assert.deepEqual(revoked, [2]); // mengaktifkan tidak mencabut sesi lagi
});

Deno.test("staff-update: reset password mencabut sesi dan membuka kunci; ganti nama saja tidak", async () => {
  const { call, rows, revoked } = setup();
  rows[2].failed_login_count = 3;
  const rename = await call("staff-update", { id: 2, nama: "  Nama   Baru " }, 3);
  assert.equal(rename.body.staff.nama, "Nama Baru");
  assert.deepEqual(revoked, []);
  assert.equal(rows[2].password_hash, "HASH-LAMA");

  const reset = await call("staff-update", { id: 2, password: "sandi-baru-1" }, 3);
  assert.equal(reset.status, 200);
  assert.equal(rows[2].password_hash, "HASH(sandi-baru-1)");
  assert.equal(rows[2].failed_login_count, 0);
  assert.deepEqual(revoked, [2]);
  assert.equal(JSON.stringify(reset.body).includes("HASH"), false);
});

Deno.test("staff-update: hanya akun staff; manager lain, customer, diri sendiri, id tak ada -> 404", async () => {
  const { call, rows } = setup();
  for (const id of [1, 3, 4, 999]) {
    assert.equal((await call("staff-update", { id, is_active: false }, 3)).status, 404, `id ${id}`);
  }
  assert.equal(rows[4].is_active, true);
  assert.equal(rows[3].is_active, true);
  assert.equal(rows[1].is_active, true);
});

Deno.test("staff-update: validasi masukan", async () => {
  const { call } = setup();
  for (const bad of [
    {}, { id: "2", nama: "Ok Nama" }, { id: 2.5, nama: "Ok Nama" }, { id: -1, nama: "Ok Nama" },
    { id: 2 }, { id: 2, nama: "A" }, { id: 2, is_active: "false" }, { id: 2, password: "123" },
    { id: 2, password: "" },
  ]) {
    assert.equal((await call("staff-update", bad, 3)).status, 400, JSON.stringify(bad));
  }
});

Deno.test("staff yang dinonaktifkan tidak bisa memakai endpoint lagi", async () => {
  const { call } = setup();
  assert.equal((await call("me", {}, 2)).status, 200);
  await call("staff-update", { id: 2, is_active: false }, 3);
  assert.equal((await call("me", {}, 2)).status, 401); // pengaman membaca ulang is_active
});