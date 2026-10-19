import { HttpError, json } from "../_shared/http.ts";
import { hashPassword } from "../_shared/password.ts";
import type { Route } from "../_shared/router.ts";
import {
  checkNama,
  checkPassword,
  checkUsername,
  normalizeNama,
  str,
} from "../_shared/validate.ts";

export interface ProfileRow {
  id: number;
  username: string;
  role: string;
  nama: string | null;
  foto_url: string | null; // PATH objek di bucket, bukan URL
  alamat: string | null;
  telepon: string | null;
  biometric_enabled: boolean;
}

/** Baris akun untuk kelola staff. TANPA password_hash. */
export interface StaffRow {
  id: number;
  username: string;
  role: string;
  nama: string | null;
  is_active: boolean;
  created_at: string;
}

export interface StaffPatch {
  nama?: string;
  is_active?: boolean;
  password_hash?: string;
  /** Hapus penguncian akibat salah password (failed_login_count, locked_until). */
  unlock?: boolean;
}

export interface UsersStore {
  getProfile(userId: number): Promise<ProfileRow | null>;
  updateNama(userId: number, nama: string): Promise<void>;
  signAvatar(path: string): Promise<string | null>;
  // --- kelola staff (khusus Manager) ---
  listStaff(): Promise<StaffRow[]>;
  findUserById(id: number): Promise<StaffRow | null>; // role apa pun, untuk memeriksa target
  createStaff(input: { username: string; nama: string; password_hash: string }): Promise<StaffRow | "duplicate">;
  updateStaff(id: number, patch: StaffPatch): Promise<StaffRow>;
  revokeSessions(userId: number): Promise<void>;
}

export interface UsersOptions {
  hash?: (plain: string) => Promise<string>; // diganti saat pengujian agar cepat
}

function publicStaff(s: StaffRow) {
  return {
    id: s.id,
    username: s.username,
    nama: s.nama,
    is_active: s.is_active,
    created_at: s.created_at,
  };
}

export function createUsersRoutes(
  store: UsersStore,
  opts: UsersOptions = {},
): Record<string, Route> {
  const hash = opts.hash ?? ((plain: string) => hashPassword(plain));

  async function profile(userId: number): Promise<Response> {
    const p = await store.getProfile(userId);
    if (!p) throw new HttpError(401, "Sesi berakhir. Silakan masuk lagi.");
    // Field dipilih satu per satu: apa pun tambahan dari store tidak ikut terkirim.
    return json({
      id: p.id,
      username: p.username,
      role: p.role,
      nama: p.nama,
      alamat: p.alamat,
      telepon: p.telepon,
      foto_url: p.foto_url ? await store.signAvatar(p.foto_url) : null,
      biometric_enabled: p.biometric_enabled,
    });
  }

  return {
    me: { handle: (ctx) => profile(ctx.userId) },

    "update-profile": {
      handle: async (ctx, body) => {
        const nama = normalizeNama(str(body.nama));
        const error = checkNama(nama);
        if (error) throw new HttpError(400, error);
        await store.updateNama(ctx.userId, nama); // selalu untuk pemilik token, bukan dari body
        return profile(ctx.userId);
      },
    },

    // ---------------------------------------------------------- kelola staff (Manager)

    "staff-list": {
      roles: ["manager"],
      handle: async () => json({ staff: (await store.listStaff()).map(publicStaff) }),
    },

    "staff-create": {
      roles: ["manager"],
      handle: async (_ctx, body) => {
        const username = str(body.username).trim();
        const nama = normalizeNama(str(body.nama));
        const password = str(body.password);
        const error = checkUsername(username) ?? checkNama(nama) ?? checkPassword(password);
        if (error) throw new HttpError(400, error);

        // Role SELALU 'staff'; field role dari klien tidak pernah dibaca.
        const created = await store.createStaff({
          username: username.toLowerCase(),
          nama,
          password_hash: await hash(password),
        });
        if (created === "duplicate") throw new HttpError(409, "Username sudah dipakai");
        return json({ staff: publicStaff(created) }, 201);
      },
    },

    "staff-update": {
      roles: ["manager"],
      handle: async (_ctx, body) => {
        const id = body.id;
        if (typeof id !== "number" || !Number.isSafeInteger(id) || id <= 0) {
          throw new HttpError(400, "Id staff tidak valid");
        }

        // Hanya akun ber-role 'staff' yang boleh diubah lewat jalur ini. Manager lain,
        // customer, dan diri sendiri dijawab "tidak ditemukan".
        const target = await store.findUserById(id);
        if (!target || target.role !== "staff") {
          throw new HttpError(404, "Akun staff tidak ditemukan");
        }

        const patch: StaffPatch = {};
        if ("nama" in body) {
          const nama = normalizeNama(str(body.nama));
          const error = checkNama(nama);
          if (error) throw new HttpError(400, error);
          patch.nama = nama;
        }
        if ("is_active" in body) {
          if (typeof body.is_active !== "boolean") {
            throw new HttpError(400, "is_active harus true atau false");
          }
          patch.is_active = body.is_active;
        }
        if ("password" in body) {
          const password = str(body.password);
          const error = checkPassword(password);
          if (error) throw new HttpError(400, error);
          patch.password_hash = await hash(password);
        }
        if (Object.keys(patch).length === 0) throw new HttpError(400, "Tidak ada perubahan");

        // Reset password atau pengaktifan ulang juga membuka kunci login.
        const reactivating = patch.is_active === true && !target.is_active;
        if (patch.password_hash || reactivating) patch.unlock = true;

        const updated = await store.updateStaff(id, patch);

        // Dinonaktifkan atau password diganti: semua sesi staff itu dicabut.
        if (patch.is_active === false || patch.password_hash) await store.revokeSessions(id);

        return json({ staff: publicStaff(updated) });
      },
    },
  };
}