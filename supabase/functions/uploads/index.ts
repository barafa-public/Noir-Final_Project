import { requireAuth } from "../_shared/auth_guard.ts";
import { AVATAR_BUCKET, signAvatarUrl } from "../_shared/avatars.ts";
import { getDb } from "../_shared/db.ts";
import { createRouter } from "../_shared/router.ts";
import { createUploadsRoutes, MAX_AVATAR_BASE64_CHARS, type UploadsStore } from "./logic.ts";

const store: UploadsStore = {
  async getAvatarPath(userId) {
    const { data, error } = await getDb().from("users").select("foto_url").eq("id", userId).maybeSingle();
    if (error) throw error;
    return (data?.foto_url as string | null | undefined) ?? null;
  },
  async setAvatarPath(userId, path) {
    const { error } = await getDb().from("users").update({ foto_url: path }).eq("id", userId);
    if (error) throw error;
  },
  async putAvatar(path, bytes, contentType) {
    const { error } = await getDb().storage.from(AVATAR_BUCKET).upload(path, bytes, {
      contentType,
      upsert: false,
    });
    if (error) throw error;
  },
  async removeAvatar(path) {
    const { error } = await getDb().storage.from(AVATAR_BUCKET).remove([path]);
    if (error) throw error;
  },
  signAvatar: signAvatarUrl,
};

Deno.serve(
  createRouter(
    createUploadsRoutes(store),
    (req, roles) => requireAuth(req, { roles }),
    { maxBodyBytes: MAX_AVATAR_BASE64_CHARS + 1_000 },
  ),
);
