import { errorResponse } from "../_shared/http.ts";
import { createHandler } from "./handler.ts";
import { createSupabaseStore } from "./store.ts";

type Handler = (req: Request) => Promise<Response>;
let handler: Handler | null = null;

function getHandler(): Handler {
  if (handler) return handler;

  const url = Deno.env.get("SUPABASE_URL");
  // SERVICE_KEY (opsional) dipakai jika kunci bawaan Supabase tidak berlaku, mis. setelah
  // legacy API keys dinonaktifkan dan kamu membuat secret key baru di dashboard.
  const serviceKey = Deno.env.get("SERVICE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const jwtSecret = Deno.env.get("JWT_SECRET");
  if (!url || !serviceKey) {
    throw new Error("SUPABASE_URL / kunci service role tidak tersedia");
  }
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error("JWT_SECRET belum diset atau kurang dari 32 karakter");
  }

  handler = createHandler({
    store: createSupabaseStore(url, serviceKey),
    config: {
      jwtSecret,
      accessTtlSeconds: 30 * 60, // 30 menit
      refreshTtlDays: 30,
      maxFailedLogins: 5,
      lockMinutes: 10,
      bcryptCost: 10,
    },
  });
  return handler;
}

Deno.serve(async (req) => {
  try {
    return await getHandler()(req);
  } catch (e) {
    console.error("auth: konfigurasi server bermasalah:", e);
    return errorResponse("Server belum dikonfigurasi dengan benar.", 500);
  }
});