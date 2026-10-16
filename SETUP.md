# Noir: Langkah Setelah Ekstrak

1. Salin ISI folder ini ke root proyek Flutter (`lib/main.dart` bawaan akan tertimpa, memang disengaja).
2. Tambahkan ke `.gitignore` proyek (SEBELUM `git add`):
   ```
   .env
   supabase/.env.local
   ```
3. Salin `.env.example` menjadi `.env`, isi `BACKEND_URL` dan `BACKEND_PUBLISHABLE_KEY`.
4. Pasang paket (versi terbaru yang kompatibel akan dipilih otomatis):
   ```
   flutter pub add flutter_dotenv dio flutter_secure_storage sqflite path provider local_auth geolocator sensors_plus flutter_local_notifications workmanager image_picker url_launcher timezone intl fl_chart
   ```
5. Daftarkan asset di `pubspec.yaml`:
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - .env
       - assets/images/
   ```
6. Edit file platform: `MainActivity.kt` -> `FlutterFragmentActivity`,
   `AndroidManifest.xml` (izin), `build.gradle.kts` (`minSdk` >= 23), `Info.plist` (deskripsi izin).
7. Supabase: jalankan `supabase/migrations/..._noir_schema.sql` di SQL Editor, lalu (opsional, demo) `supabase/seed.sql`.
   Buat dua bucket Storage PRIVAT: `payment-proofs` dan `avatars`.
8. Taruh gambar di `assets/images/` (logo_noir.png, placeholder_product.png, avatar_default.png).

File bertanda `// TODO` masih kosong. File yang sudah berisi: main.dart, app.dart, config/app_config.dart,
services/api_client.dart, database/{app_database,schema_v1,cart_dao,product_dao}.dart, kedua file SQL,
supabase/config.toml, dan .env.example.
