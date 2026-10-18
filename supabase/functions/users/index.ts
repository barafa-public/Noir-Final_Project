import { requireAuth } from "../_shared/auth_guard.ts";
import { signAvatarUrl } from "../_shared/avatars.ts";
import { getDb } from "../_shared/db.ts";
import { createRouter } from "../_shared/router.ts";
import { createUsersRoutes, type ProfileRow, type UsersStore } from "./logic.ts";

const store: UsersStore = {
  async getProfile(userId) {
    const { data, error } = await getDb()
      .from("users")
      .select("id, username, role, nama, foto_url, alamat, telepon, biometric_enabled")
      .eq("id", userId)
      .maybeSingle();
    if (error) throw error;
    return data as ProfileRow | null;
  },
  async updateNama(userId, nama) {
    const { error } = await getDb().from("users").update({ nama }).eq("id", userId);
    if (error) throw error;
  },
  signAvatar: signAvatarUrl,
};

Deno.serve(createRouter(createUsersRoutes(store), (req, roles) => requireAuth(req, { roles })));
