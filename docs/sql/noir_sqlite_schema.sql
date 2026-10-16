-- =====================================================================
-- NOIR - Skema SQLite (cache lokal di perangkat, paket sqflite)
-- Sumber kebenaran = PostgreSQL Supabase. SQLite HANYA cache + draft.
-- Cakupan FR-27: katalog produk, draft keranjang, kurs terakhir, status baca notifikasi.
--
-- JANGAN simpan di SQLite: access/refresh token, password, hash apa pun.
-- SQLite tidak terenkripsi. Token tetap di flutter_secure_storage (kriteria 2 & 3).
--
-- Konvensi: waktu = teks ISO-8601 UTC ('2026-10-16T08:30:00Z'); uang = INTEGER (IDR);
-- boolean = INTEGER 0/1. Kolom turunan (kode_lokasi) disimpan biasa, bukan
-- generated column, karena SQLite bawaan Android lama (< 3.31) tidak mendukungnya.
-- =====================================================================

-- Wajib dijalankan setiap koneksi dibuka (di onConfigure sqflite), bukan hanya sekali:
PRAGMA foreign_keys = ON;
-- Disarankan karena workmanager membuka DB dari isolate lain: PRAGMA journal_mode = WAL;
-- Versi skema (naikkan saat migrasi, dan tangani di onUpgrade):
PRAGMA user_version = 1;

-- ---------------------------------------------------------------------
-- 1. meta: penanda sinkronisasi
--    key contoh: 'products_synced_at', 'kurs_synced_at', 'notif_last_id:<user_id>'
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- ---------------------------------------------------------------------
-- 2. products_cache: cermin katalog (data bersama, tidak terikat user)
--    Sinkronisasi = ganti seluruh isi dalam satu transaksi (hapus yang sudah
--    tidak ada di server), jangan hanya upsert, supaya produk nonaktif hilang.
--    Harga/stok di sini bisa basi. Server selalu menghitung ulang saat pesan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products_cache (
  id            INTEGER PRIMARY KEY,                    -- = products.id di Supabase
  sku           TEXT NOT NULL,
  nama          TEXT NOT NULL COLLATE NOCASE,
  kategori      TEXT NOT NULL CHECK (kategori IN ('Kertas','Alat Tulis','Map','Lainnya')),
  harga         INTEGER NOT NULL CHECK (harga >= 0),
  stok          INTEGER NOT NULL CHECK (stok >= 0),
  supplier_id   INTEGER,
  zona          TEXT,
  rak           TEXT,
  level         TEXT,
  bin           TEXT,
  kode_lokasi   TEXT,                                   -- 'A-03-02-B', dari server
  gambar        TEXT,
  reorder_point INTEGER NOT NULL DEFAULT 0,
  synced_at     TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_products_sku     ON products_cache (sku COLLATE NOCASE);
CREATE INDEX        IF NOT EXISTS ix_products_nama    ON products_cache (nama);
CREATE INDEX        IF NOT EXISTS ix_products_kategori ON products_cache (kategori);
CREATE INDEX        IF NOT EXISTS ix_products_zona    ON products_cache (zona);

-- Filter "status stok" (Habis / Menipis / Aman) tanpa kolom tambahan
CREATE VIEW IF NOT EXISTS v_products_status AS
SELECT p.*,
       CASE WHEN p.stok = 0                    THEN 'Habis'
            WHEN p.stok <= p.reorder_point     THEN 'Menipis'
            ELSE 'Aman' END AS status_stok
FROM products_cache p;

-- ---------------------------------------------------------------------
-- 3. cart_items: draft keranjang, per user (satu HP bisa dipakai banyak akun)
--    Sengaja TANPA foreign key ke products_cache: sinkronisasi katalog
--    (hapus lalu isi ulang) akan menghapus isi keranjang secara diam-diam.
--    Snapshot nama/harga dipakai agar keranjang tetap bisa ditampilkan;
--    validitas produk dicek server saat create_order.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cart_items (
  user_id        INTEGER NOT NULL,
  product_id     INTEGER NOT NULL,
  qty            INTEGER NOT NULL CHECK (qty > 0),
  nama_snapshot  TEXT NOT NULL,
  harga_snapshot INTEGER NOT NULL CHECK (harga_snapshot >= 0),
  updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  PRIMARY KEY (user_id, product_id)
) WITHOUT ROWID;

-- Draft isian halaman Pesan (alamat & metode) agar tidak hilang saat app ditutup
CREATE TABLE IF NOT EXISTS checkout_draft (
  user_id      INTEGER PRIMARY KEY,
  alamat       TEXT,
  lat          REAL CHECK (lat IS NULL OR lat BETWEEN -90 AND 90),
  lng          REAL CHECK (lng IS NULL OR lng BETWEEN -180 AND 180),
  metode_bayar TEXT CHECK (metode_bayar IS NULL OR metode_bayar IN ('Transfer Bank','QRIS','E-Wallet')),
  updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- ---------------------------------------------------------------------
-- 4. kurs_cache: kurs terakhir untuk pratinjau harga impor saat offline
--    Hanya tampilan. Kurs yang berlaku adalah yang dibekukan server pada pengadaan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kurs_cache (
  mata_uang    TEXT PRIMARY KEY CHECK (mata_uang IN ('USD','CNY','JPY','EUR')),
  kurs_idr     REAL NOT NULL CHECK (kurs_idr > 0),      -- 1 unit mata uang = n IDR
  diambil_pada TEXT NOT NULL,                           -- waktu server mengambil kurs
  synced_at    TEXT NOT NULL
) WITHOUT ROWID;

-- ---------------------------------------------------------------------
-- 5. notifications_local: salinan notifikasi + status lokal
--    - sudah_ditampilkan: mencegah workmanager menampilkan notifikasi yang sama dua kali
--    - read_pending_sync: ditandai baca saat offline, dikirim ke server saat online
--    Dedup memakai server_id; cursor polling di meta 'notif_last_id:<user_id>'.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications_local (
  server_id         INTEGER PRIMARY KEY,                -- = notifications.id di Supabase
  user_id           INTEGER NOT NULL,
  jenis             TEXT NOT NULL CHECK (jenis IN ('stok_rop','pesanan_baru','pembayaran',
                                                   'siap_kemas','status_pesanan','batas_bayar')),
  judul             TEXT NOT NULL,
  isi               TEXT NOT NULL,
  ref_type          TEXT,
  ref_id            INTEGER,
  dibaca            INTEGER NOT NULL DEFAULT 0 CHECK (dibaca IN (0,1)),
  read_pending_sync INTEGER NOT NULL DEFAULT 0 CHECK (read_pending_sync IN (0,1)),
  sudah_ditampilkan INTEGER NOT NULL DEFAULT 0 CHECK (sudah_ditampilkan IN (0,1)),
  created_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_notif_user ON notifications_local (user_id, dibaca, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_notif_pending_sync ON notifications_local (user_id)
  WHERE read_pending_sync = 1;

-- ---------------------------------------------------------------------
-- 6. payment_reminders: pengingat batas bayar yang dijadwalkan lokal
--    notif_id = id integer untuk flutter_local_notifications, disimpan agar
--    pengingat bisa DIBATALKAN saat pesanan sudah dibayar/dibatalkan.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_reminders (
  order_id    INTEGER PRIMARY KEY,
  user_id     INTEGER NOT NULL,
  notif_id    INTEGER NOT NULL UNIQUE,
  batas_bayar TEXT NOT NULL,
  fire_at     TEXT NOT NULL,                            -- mis. 1 jam sebelum batas_bayar
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS ix_reminders_user ON payment_reminders (user_id);

-- =====================================================================
-- QUERY UMUM (referensi; jalankan lewat sqflite dengan parameter ?, jangan
-- menyambung string)
-- =====================================================================

-- Pencarian katalog (nama/SKU) + filter opsional:
--   SELECT * FROM v_products_status
--   WHERE (nama LIKE '%' || ? || '%' OR sku LIKE '%' || ? || '%')
--     AND (? IS NULL OR kategori = ?)
--     AND (? IS NULL OR zona = ?)
--     AND (? IS NULL OR status_stok = ?)
--   ORDER BY nama;

-- Total & jumlah item keranjang (hanya tampilan):
--   SELECT COUNT(*) AS jenis, COALESCE(SUM(qty),0) AS total_qty,
--          COALESCE(SUM(qty * harga_snapshot),0) AS total_perkiraan
--   FROM cart_items WHERE user_id = ?;

-- Tambah ke keranjang (upsert):
--   INSERT INTO cart_items (user_id, product_id, qty, nama_snapshot, harga_snapshot)
--   VALUES (?,?,?,?,?)
--   ON CONFLICT (user_id, product_id) DO UPDATE SET
--     qty = qty + excluded.qty, nama_snapshot = excluded.nama_snapshot,
--     harga_snapshot = excluded.harga_snapshot,
--     updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now');

-- Notifikasi baru dari server (idempoten):
--   INSERT OR IGNORE INTO notifications_local
--     (server_id, user_id, jenis, judul, isi, ref_type, ref_id, dibaca, created_at)
--   VALUES (?,?,?,?,?,?,?,?,?);

-- Yang perlu ditampilkan sebagai notifikasi lokal:
--   SELECT * FROM notifications_local
--   WHERE user_id = ? AND sudah_ditampilkan = 0 AND dibaca = 0;

-- Tandai baca (offline-safe), lalu sinkronkan ke server dan reset flag:
--   UPDATE notifications_local SET dibaca = 1, read_pending_sync = 1 WHERE server_id = ?;
--   SELECT server_id FROM notifications_local WHERE user_id = ? AND read_pending_sync = 1;
--   UPDATE notifications_local SET read_pending_sync = 0 WHERE server_id IN (...);

-- Jumlah belum dibaca (badge):
--   SELECT COUNT(*) FROM notifications_local WHERE user_id = ? AND dibaca = 0;

-- Sinkronisasi katalog (dalam SATU transaksi):
--   DELETE FROM products_cache;
--   INSERT INTO products_cache (...) VALUES (...);   -- batch
--   INSERT INTO meta (key, value) VALUES ('products_synced_at', ?)
--     ON CONFLICT (key) DO UPDATE SET value = excluded.value,
--       updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now');

-- =====================================================================
-- LOGOUT / GANTI AKUN: bersihkan data per-user (HP bisa dipakai bersama).
-- Katalog, kurs, dan meta bersama boleh tetap. Jalankan dalam satu transaksi.
-- Batalkan juga pengingat terjadwal di flutter_local_notifications
-- (ambil notif_id dari payment_reminders SEBELUM dihapus).
-- =====================================================================
--   DELETE FROM cart_items          WHERE user_id = ?;
--   DELETE FROM checkout_draft      WHERE user_id = ?;
--   DELETE FROM notifications_local WHERE user_id = ?;
--   DELETE FROM payment_reminders   WHERE user_id = ?;
--   DELETE FROM meta                WHERE key = 'notif_last_id:' || ?;
