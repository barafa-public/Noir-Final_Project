import { corsHeaders } from "./cors.ts";

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function noContent(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}

/** Kontrak error ke aplikasi: { "error": "pesan" } */
export function errorResponse(message: string, status: number): Response {
  return json({ error: message }, status);
}

/** Error yang aman ditampilkan ke pengguna (pesan + status HTTP). */
export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}