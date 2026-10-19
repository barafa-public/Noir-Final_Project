export const MIN_PASSWORD = 6; // sama dengan validasi di aplikasi
export const MAX_PASSWORD_BYTES = 72; // batas bcrypt; lebih dari ini dipotong diam-diam

const USERNAME_RE = /^[A-Za-z0-9_.]{3,30}$/;
const PHONE_RE = /^0[0-9]{9,19}$/;

export interface RegisterInput {
  username: string;
  alamat: string;
  telepon: string;
  password: string;
}

export type Parsed<T> = { ok: true; value: T } | { ok: false; error: string };

export function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

/** Mengembalikan pesan error, atau null jika valid. */
export function checkUsername(username: string): string | null {
  return USERNAME_RE.test(username)
    ? null
    : "Username 3-30 karakter: huruf, angka, titik, atau garis bawah";
}

export function checkPassword(password: string): string | null {
  if (password.length < MIN_PASSWORD) return "Password terlalu pendek";
  if (new TextEncoder().encode(password).length > MAX_PASSWORD_BYTES) {
    return "Password terlalu panjang (maksimal 72 byte)";
  }
  return null;
}

export function normalizeNama(nama: string): string {
  return nama.trim().replace(/\s+/g, " ");
}

export function checkNama(nama: string): string | null {
  if (nama.length < 2 || nama.length > 50) return "Nama harus 2-50 karakter";
  if (/[\u0000-\u001f\u007f]/.test(nama)) return "Nama mengandung karakter yang tidak diizinkan";
  return null;
}

export function parseRegister(body: Record<string, unknown>): Parsed<RegisterInput> {
  const username = str(body.username).trim();
  const alamat = str(body.alamat).trim();
  const telepon = str(body.telepon).trim();
  const password = str(body.password); // tidak di-trim

  const usernameError = checkUsername(username);
  if (usernameError) return { ok: false, error: usernameError };
  if (alamat.length === 0 || alamat.length > 500) {
    return { ok: false, error: "Alamat wajib diisi (maksimal 500 karakter)" };
  }
  if (!PHONE_RE.test(telepon)) {
    return { ok: false, error: "Nomor telepon tidak valid" };
  }
  const passwordError = checkPassword(password);
  if (passwordError) return { ok: false, error: passwordError };

  return { ok: true, value: { username, alamat, telepon, password } };
}