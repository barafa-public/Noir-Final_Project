import bcrypt from "npm:bcryptjs@2.4.3";

// Hash valid dengan cost 10, dipakai agar login username TIDAK terdaftar memakan
// waktu yang sama dengan username terdaftar (mencegah penebakan username lewat waktu).
export const DUMMY_HASH = "$2a$10$snOxSzcMeGxgAxG1ncJKXOgXwl6LjnswJRQy8a4Rrs1pSGRIz3HP6";

export function hashPassword(plain: string, cost = 10): Promise<string> {
  return bcrypt.hash(plain, cost);
}

/** Selalu mengembalikan boolean; hash rusak dianggap tidak cocok. */
export async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  try {
    return await bcrypt.compare(plain, hash);
  } catch {
    return false;
  }
}