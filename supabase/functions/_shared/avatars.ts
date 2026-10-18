import { getDb } from "./db.ts";

export const AVATAR_BUCKET = "avatars";
const SIGNED_URL_SECONDS = 3600; // tautan foto berlaku 1 jam

/** Tautan sementara untuk menampilkan foto dari bucket privat. null jika gagal. */
export async function signAvatarUrl(path: string): Promise<string | null> {
  const { data, error } = await getDb().storage
    .from(AVATAR_BUCKET)
    .createSignedUrl(path, SIGNED_URL_SECONDS);
  if (error || !data) {
    console.error("signAvatarUrl:", error);
    return null;
  }
  return data.signedUrl;
}