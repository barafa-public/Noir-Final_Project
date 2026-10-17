import { corsHeaders } from "../_shared/cors.ts";
import { errorResponse, HttpError, json, noContent } from "../_shared/http.ts";
import { randomToken, sha256Hex, signAccessToken } from "../_shared/jwt.ts";
import { DUMMY_HASH, hashPassword, verifyPassword } from "../_shared/password.ts";
import { parseRegister, str } from "../_shared/validate.ts";
import type { AuthStore, UserRow } from "./store.ts";

export interface AuthConfig {
  jwtSecret: string;
  accessTtlSeconds: number;
  refreshTtlDays: number;
  maxFailedLogins: number;
  lockMinutes: number;
  bcryptCost: number;
}

export interface Deps {
  store: AuthStore;
  config: AuthConfig;
  now?: () => Date;
}

// Satu pesan untuk username salah DAN password salah (cegah penebakan username).
const INVALID_CREDENTIALS = "Username atau password salah";
const SESSION_ENDED = "Sesi berakhir. Silakan masuk lagi.";
const TOO_MANY = "Terlalu banyak percobaan. Coba lagi beberapa menit lagi.";
const MAX_BODY_BYTES = 10_000;

export function createHandler(deps: Deps) {
  const { store, config } = deps;
  const now = deps.now ?? (() => new Date());

  function publicUser(u: UserRow) {
    // Tidak pernah menyertakan password_hash atau data penguncian.
    return {
      id: u.id,
      username: u.username,
      role: u.role,
      nama: u.nama,
      foto_url: u.foto_url,
      biometric_enabled: u.biometric_enabled,
    };
  }

  async function issueSession(user: UserRow, device: string | null) {
    const accessToken = await signAccessToken(config.jwtSecret, user, config.accessTtlSeconds);
    const refreshToken = randomToken();
    await store.insertRefreshToken({
      user_id: user.id,
      token_hash: await sha256Hex(refreshToken),
      device,
      expires_at: new Date(now().getTime() + config.refreshTtlDays * 86_400_000),
    });
    return {
      access_token: accessToken,
      refresh_token: refreshToken,
      expires_in: config.accessTtlSeconds,
      user: publicUser(user),
    };
  }

  async function register(body: Record<string, unknown>): Promise<Response> {
    const parsed = parseRegister(body);
    if (!parsed.ok) throw new HttpError(400, parsed.error);
    const { username, alamat, telepon, password } = parsed.value;

    const result = await store.createCustomer({
      username: username.toLowerCase(), // kunci login tidak peka huruf besar/kecil
      nama: username, // nama tampilan = ejaan yang diketik pengguna
      alamat,
      telepon,
      password_hash: await hashPassword(password, config.bcryptCost),
    });
    if (result === "duplicate") throw new HttpError(409, "Username sudah dipakai");
    return json({}, 201); // role selalu 'customer', ditetapkan server
  }

  async function login(body: Record<string, unknown>): Promise<Response> {
    const username = str(body.username).trim().toLowerCase();
    const password = str(body.password);
    if (!username || !password || password.length > 200) {
      throw new HttpError(400, "Username dan password wajib diisi");
    }
    const device = str(body.device).trim().slice(0, 100) || null;

    const user = await store.findUserByUsername(username);
    if (!user) {
      await verifyPassword(password, DUMMY_HASH); // samakan waktu respons
      throw new HttpError(401, INVALID_CREDENTIALS);
    }

    if (user.locked_until && new Date(user.locked_until) > now()) {
      throw new HttpError(429, TOO_MANY);
    }

    if (!(await verifyPassword(password, user.password_hash))) {
      const count = user.failed_login_count + 1;
      if (count >= config.maxFailedLogins) {
        const until = new Date(now().getTime() + config.lockMinutes * 60_000);
        await store.setLoginState(user.id, 0, until);
      } else {
        await store.setLoginState(user.id, count, null);
      }
      throw new HttpError(401, INVALID_CREDENTIALS);
    }

    // Password benar tapi akun nonaktif: aman memberi tahu, penebak tidak sampai sini.
    if (!user.is_active) throw new HttpError(403, "Akun dinonaktifkan. Hubungi Manager.");

    if (user.failed_login_count > 0 || user.locked_until) {
      await store.setLoginState(user.id, 0, null);
    }
    return json(await issueSession(user, device), 200);
  }

  async function refresh(body: Record<string, unknown>): Promise<Response> {
    const token = str(body.refresh_token);
    if (!token) throw new HttpError(401, SESSION_ENDED);

    const record = await store.findRefreshToken(await sha256Hex(token));
    if (!record || record.revoked_at || new Date(record.expires_at) <= now()) {
      throw new HttpError(401, SESSION_ENDED);
    }
    const user = await store.findUserById(record.user_id);
    if (!user || !user.is_active) throw new HttpError(401, SESSION_ENDED);

    await store.revokeRefreshToken(record.id); // rotasi: token lama langsung mati
    return json(await issueSession(user, record.device), 200);
  }

  async function logout(body: Record<string, unknown>): Promise<Response> {
    const token = str(body.refresh_token);
    if (token) {
      const record = await store.findRefreshToken(await sha256Hex(token));
      if (record && !record.revoked_at) await store.revokeRefreshToken(record.id);
    }
    return noContent(); // selalu 204: tidak membocorkan apakah token valid
  }

  async function readJson(req: Request): Promise<Record<string, unknown>> {
    const length = Number(req.headers.get("content-length") ?? "0");
    if (length > MAX_BODY_BYTES) throw new HttpError(413, "Permintaan terlalu besar");
    let parsed: unknown;
    try {
      parsed = await req.json();
    } catch {
      throw new HttpError(400, "Body harus berupa JSON yang valid");
    }
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      throw new HttpError(400, "Body harus berupa objek JSON");
    }
    return parsed as Record<string, unknown>;
  }

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return errorResponse("Metode tidak diizinkan", 405);

    // Path di Supabase: /auth/<aksi>. Ambil segmen terakhir agar tahan perbedaan awalan.
    const action = new URL(req.url).pathname.split("/").filter(Boolean).pop() ?? "";

    try {
      switch (action) {
        case "register":
          return await register(await readJson(req));
        case "login":
          return await login(await readJson(req));
        case "refresh":
          return await refresh(await readJson(req));
        case "logout":
          return await logout(await readJson(req));
        default:
          return errorResponse("Endpoint tidak ditemukan", 404);
      }
    } catch (e) {
      if (e instanceof HttpError) return errorResponse(e.message, e.status);
      console.error("auth error:", e); // detail hanya di log server
      return errorResponse("Terjadi kesalahan pada server.", 500);
    }
  };
}