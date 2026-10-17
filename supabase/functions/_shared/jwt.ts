import { jwtVerify, SignJWT } from "npm:jose@5.9.6";

const ISSUER = "noir";

export interface AccessClaims {
  sub: string; // id pengguna (teks)
  role: string;
  username: string;
}

function key(secret: string): Uint8Array {
  return new TextEncoder().encode(secret);
}

export function signAccessToken(
  secret: string,
  user: { id: number; role: string; username: string },
  ttlSeconds: number,
): Promise<string> {
  return new SignJWT({ role: user.role, username: user.username })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(String(user.id))
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(`${ttlSeconds}s`)
    .sign(key(secret));
}

/** Untuk fungsi lain (RBAC). Melempar error jika token salah/kedaluwarsa. */
export async function verifyAccessToken(secret: string, token: string): Promise<AccessClaims> {
  const { payload } = await jwtVerify(token, key(secret), {
    issuer: ISSUER,
    algorithms: ["HS256"], // tolak alg lain (mis. "none")
  });
  return {
    sub: String(payload.sub),
    role: String(payload.role),
    username: String(payload.username),
  };
}

/** Refresh token opaque: 32 byte acak, base64url. Yang disimpan di DB hanya hash-nya. */
export function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}