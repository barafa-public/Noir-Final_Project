import { createClient } from "npm:@supabase/supabase-js@2";

export interface UserRow {
  id: number;
  username: string;
  password_hash: string;
  role: "customer" | "manager" | "staff";
  nama: string | null;
  foto_url: string | null;
  biometric_enabled: boolean;
  is_active: boolean;
  failed_login_count: number;
  locked_until: string | null;
}

export interface RefreshRow {
  id: number;
  user_id: number;
  device: string | null;
  expires_at: string;
  revoked_at: string | null;
}

/** Semua akses data auth lewat antarmuka ini (mudah diganti saat pengujian). */
export interface AuthStore {
  findUserByUsername(username: string): Promise<UserRow | null>;
  findUserById(id: number): Promise<UserRow | null>;
  createCustomer(input: {
    username: string;
    nama: string;
    alamat: string;
    telepon: string;
    password_hash: string;
  }): Promise<"ok" | "duplicate">;
  setLoginState(userId: number, failedCount: number, lockedUntil: Date | null): Promise<void>;
  insertRefreshToken(input: {
    user_id: number;
    token_hash: string;
    device: string | null;
    expires_at: Date;
  }): Promise<void>;
  findRefreshToken(tokenHash: string): Promise<RefreshRow | null>;
  revokeRefreshToken(id: number): Promise<void>;
}

const USER_COLUMNS =
  "id, username, password_hash, role, nama, foto_url, biometric_enabled, is_active, failed_login_count, locked_until";

export function createSupabaseStore(url: string, serviceKey: string): AuthStore {
  // service_role melewati RLS. Kunci ini hanya hidup di server, tidak pernah di aplikasi.
  const db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    async findUserByUsername(username) {
      const { data, error } = await db.from("users").select(USER_COLUMNS)
        .eq("username", username).maybeSingle();
      if (error) throw error;
      return data as UserRow | null;
    },

    async findUserById(id) {
      const { data, error } = await db.from("users").select(USER_COLUMNS)
        .eq("id", id).maybeSingle();
      if (error) throw error;
      return data as UserRow | null;
    },

    async createCustomer(input) {
      const { error } = await db.from("users").insert({ ...input, role: "customer" });
      if (error) {
        if (error.code === "23505") return "duplicate"; // unique violation
        throw error;
      }
      return "ok";
    },

    async setLoginState(userId, failedCount, lockedUntil) {
      const { error } = await db.from("users")
        .update({
          failed_login_count: failedCount,
          locked_until: lockedUntil ? lockedUntil.toISOString() : null,
        })
        .eq("id", userId);
      if (error) throw error;
    },

    async insertRefreshToken(input) {
      const { error } = await db.from("refresh_tokens").insert({
        user_id: input.user_id,
        token_hash: input.token_hash,
        device: input.device,
        expires_at: input.expires_at.toISOString(),
      });
      if (error) throw error;
    },

    async findRefreshToken(tokenHash) {
      const { data, error } = await db.from("refresh_tokens")
        .select("id, user_id, device, expires_at, revoked_at")
        .eq("token_hash", tokenHash).maybeSingle();
      if (error) throw error;
      return data as RefreshRow | null;
    },

    async revokeRefreshToken(id) {
      const { error } = await db.from("refresh_tokens")
        .update({ revoked_at: new Date().toISOString() })
        .eq("id", id).is("revoked_at", null);
      if (error) throw error;
    },
  };
}