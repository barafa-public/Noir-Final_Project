import { requireAuth } from "../_shared/auth_guard.ts";
import { signAvatarUrl } from "../_shared/avatars.ts";
import { getDb } from "../_shared/db.ts";
import { createRouter } from "../_shared/router.ts";
import {
  createUsersRoutes,
  type ProfileRow,
  type StaffRow,
  type UsersStore,
} from "./logic.ts";

// Kolom akun TANPA password_hash.
const STAFF_COLUMNS = "id, username, role, nama, is_active, created_at";

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

  async listStaff() {
    const { data, error } = await getDb()
      .from("users")
      .select(STAFF_COLUMNS)
      .eq("role", "staff")
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []) as StaffRow[];
  },
  async findUserById(id) {
    const { data, error } = await getDb()
      .from("users")
      .select(STAFF_COLUMNS)
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    return data as StaffRow | null;
  },
  async createStaff(input) {
    const { data, error } = await getDb()
      .from("users")
      .insert({ ...input, role: "staff" })
      .select(STAFF_COLUMNS)
      .single();
    if (error) {
      if (error.code === "23505") return "duplicate"; // username sudah ada
      throw error;
    }
    return data as StaffRow;
  },
  async updateStaff(id, patch) {
    const update: Record<string, unknown> = {};
    if (patch.nama !== undefined) update.nama = patch.nama;
    if (patch.is_active !== undefined) update.is_active = patch.is_active;
    if (patch.password_hash !== undefined) update.password_hash = patch.password_hash;
    if (patch.unlock) {
      update.failed_login_count = 0;
      update.locked_until = null;
    }
    const { data, error } = await getDb()
      .from("users")
      .update(update)
      .eq("id", id)
      .eq("role", "staff") // lapisan kedua: tidak pernah menyentuh akun non-staff
      .select(STAFF_COLUMNS)
      .single();
    if (error) throw error;
    return data as StaffRow;
  },
  async revokeSessions(userId) {
    const { error } = await getDb()
      .from("refresh_tokens")
      .update({ revoked_at: new Date().toISOString() })
      .eq("user_id", userId)
      .is("revoked_at", null);
    if (error) throw error;
  },
};

Deno.serve(createRouter(createUsersRoutes(store), (req, roles) => requireAuth(req, { roles })));