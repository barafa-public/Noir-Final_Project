import { getDb } from "./db.ts";
import { HttpError } from "./http.ts";
import { type AccessClaims, verifyAccessToken } from "./jwt.ts";

export type Role = "customer" | "manager" | "staff";

export interface AuthContext {
  userId: number;
  role: Role; // diambil dari DATABASE, bukan dari isi token
  username: string;
}

export interface UserLookup {
  role: Role;
  is_active: boolean;
  username: string;
}

export type LookupUser = (id: number) => Promise<UserLookup | null>;

export interface GuardOptions {
  /** Role yang boleh. Kosong = semua pengguna yang sudah login. */
  roles?: Role[];
  secret?: string; // default: JWT_SECRET
  lookupUser?: LookupUser; // default: baca tabel users
}

const SESSION_ENDED = "Sesi berakhir. Silakan masuk lagi.";
const FORBIDDEN = "Anda tidak berhak mengakses fitur ini";

async function dbLookupUser(id: number): Promise<UserLookup | null> {
  const { data, error } = await getDb()
    .from("users")
    .select("role, is_active, username")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  return data as UserLookup | null;
}

/**
 * Pengaman setiap endpoint (RBAC di server). Dipakai di awal handler:
 *
 *   const me = await requireAuth(req, { roles: ["manager"] });
 *
 * Melempar HttpError 401 (token salah/kedaluwarsa/akun nonaktif/dihapus) atau
 * 403 (role tidak berhak). Aplikasi mencoba refresh token pada 401.
 *
 * Role dan status aktif DIBACA ULANG dari database pada setiap permintaan, sehingga
 * akun yang dinonaktifkan atau diturunkan rolenya langsung berlaku, tanpa menunggu
 * access token (30 menit) habis.
 */
export async function requireAuth(req: Request, opts: GuardOptions = {}): Promise<AuthContext> {
  const secret = opts.secret ?? Deno.env.get("JWT_SECRET");
  if (!secret || secret.length < 32) {
    throw new Error("JWT_SECRET belum diset atau kurang dari 32 karakter");
  }

  const match = /^Bearer\s+(.+)$/i.exec(req.headers.get("authorization") ?? "");
  if (!match) throw new HttpError(401, SESSION_ENDED);

  let claims: AccessClaims;
  try {
    claims = await verifyAccessToken(secret, match[1].trim());
  } catch {
    throw new HttpError(401, SESSION_ENDED);
  }

  const userId = Number(claims.sub);
  if (!Number.isSafeInteger(userId) || userId <= 0) throw new HttpError(401, SESSION_ENDED);

  const user = await (opts.lookupUser ?? dbLookupUser)(userId);
  if (!user || !user.is_active) throw new HttpError(401, SESSION_ENDED);

  if (opts.roles && !opts.roles.includes(user.role)) throw new HttpError(403, FORBIDDEN);

  return { userId, role: user.role, username: user.username };
}