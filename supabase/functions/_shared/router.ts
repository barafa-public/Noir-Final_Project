import type { AuthContext, Role } from "./auth_guard.ts";
import { corsHeaders } from "./cors.ts";
import { errorResponse, HttpError } from "./http.ts";

export interface Route {
  /** Role yang boleh. Kosong = semua pengguna yang sudah login. */
  roles?: Role[];
  handle: (ctx: AuthContext, body: Record<string, unknown>) => Promise<Response>;
}

export type Authenticator = (req: Request, roles?: Role[]) => Promise<AuthContext>;

/**
 * Router untuk fungsi yang HARUS login. Setiap rute otomatis lewat `authenticate`
 * SEBELUM body dibaca, jadi tidak ada endpoint yang bisa lupa dipasangi pengaman.
 * Aksi diambil dari segmen terakhir path: /functions/v1/users/me -> "me".
 */
export function createRouter(
  routes: Record<string, Route>,
  authenticate: Authenticator,
  opts: { maxBodyBytes?: number } = {},
) {
  const maxBody = opts.maxBodyBytes ?? 20_000;

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return errorResponse("Metode tidak diizinkan", 405);

    const action = new URL(req.url).pathname.split("/").filter(Boolean).pop() ?? "";
    const route = Object.hasOwn(routes, action) ? routes[action] : undefined;
    if (!route) return errorResponse("Endpoint tidak ditemukan", 404);

    try {
      const ctx = await authenticate(req, route.roles); // 401/403 sebelum membaca body

      if (Number(req.headers.get("content-length") ?? "0") > maxBody) {
        throw new HttpError(413, "Permintaan terlalu besar");
      }
      const text = await req.text();
      if (text.length > maxBody) throw new HttpError(413, "Permintaan terlalu besar");

      let parsed: unknown;
      try {
        parsed = text ? JSON.parse(text) : {};
      } catch {
        throw new HttpError(400, "Body harus berupa JSON yang valid");
      }
      if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
        throw new HttpError(400, "Body harus berupa objek JSON");
      }
      return await route.handle(ctx, parsed as Record<string, unknown>);
    } catch (e) {
      if (e instanceof HttpError) return errorResponse(e.message, e.status);
      console.error("router error:", e);
      return errorResponse("Terjadi kesalahan pada server.", 500);
    }
  };
}