import { HttpError, json } from "../_shared/http.ts";
import type { Route } from "../_shared/router.ts";
import { str } from "../_shared/validate.ts";

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

export interface UsersStore {
  getProfile(userId: number): Promise<ProfileRow | null>;
  updateNama(userId: number, nama: string): Promise<void>;
  signAvatar(path: string): Promise<string | null>;
}

export function createUsersRoutes(store: UsersStore): Record<string, Route> {
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
        const nama = str(body.nama).trim().replace(/\s+/g, " ");
        if (nama.length < 2 || nama.length > 50) {
          throw new HttpError(400, "Nama harus 2-50 karakter");
        }
        if (/[\u0000-\u001f\u007f]/.test(nama)) {
          throw new HttpError(400, "Nama mengandung karakter yang tidak diizinkan");
        }
        await store.updateNama(ctx.userId, nama); // selalu untuk pemilik token, bukan dari body
        return profile(ctx.userId);
      },
    },
  };
}
