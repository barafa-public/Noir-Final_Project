// Aplikasi Flutter (Android/iOS) tidak butuh CORS, tetapi pratinjau web dan alat uji butuh.
// Tanpa cookie, jadi "*" aman untuk asal permintaan.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};