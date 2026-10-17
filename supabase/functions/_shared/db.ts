import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

let client: SupabaseClient | null = null;

/**
 * Klien database dengan kunci service_role (melewati RLS). Hanya ada di server.
 * SERVICE_KEY (opsional) menggantikan kunci bawaan jika kunci bawaan tidak berlaku.
 */
export function getDb(): SupabaseClient {
  if (client) return client;
  const url = Deno.env.get("SUPABASE_URL");
  const key =
    Deno.env.get("SERVICE_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key)
    throw new Error("SUPABASE_URL / kunci service role tidak tersedia");
  client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}
