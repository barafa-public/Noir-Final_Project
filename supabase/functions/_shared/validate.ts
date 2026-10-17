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

export function parseRegister(body: Record<string, unknown>): Parsed<RegisterInput> {
  const username = str(body.username).trim();
  const alamat = str(body.alamat).trim();
  const telepon = str(body.telepon).trim();
  const password = str(body.password); // tidak di-trim

  if (!USERNAME_RE.test(username)) {
    return { ok: false, error: "Username 3-30 karakter: huruf, angka, titik, atau garis bawah" };
  }
  if (alamat.length === 0 || alamat.length > 500) {
    return { ok: false, error: "Alamat wajib diisi (maksimal 500 karakter)" };
  }
  if (!PHONE_RE.test(telepon)) {
    return { ok: false, error: "Nomor telepon tidak valid" };
  }
  if (password.length < MIN_PASSWORD) {
    return { ok: false, error: "Password terlalu pendek" };
  }
  if (new TextEncoder().encode(password).length > MAX_PASSWORD_BYTES) {
    return { ok: false, error: "Password terlalu panjang (maksimal 72 byte)" };
  }
  return { ok: true, value: { username, alamat, telepon, password } };
}