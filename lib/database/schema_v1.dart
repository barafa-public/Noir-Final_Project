// DIHASILKAN dari noir_sqlite_schema.sql (komentar & PRAGMA dibuang).
// sqflite hanya menjalankan SATU statement per execute(), jadi skema dipecah per statement.
// Jika skema diubah: buat versi baru (schema_v2) + migrasi di onUpgrade, jangan edit v1.
const List<String> kSchemaV1 = [
  r'''
CREATE TABLE IF NOT EXISTS meta (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
''',
  r'''
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
''',
  r'''
CREATE UNIQUE INDEX IF NOT EXISTS ux_products_sku     ON products_cache (sku COLLATE NOCASE);
''',
  r'''
CREATE INDEX        IF NOT EXISTS ix_products_nama    ON products_cache (nama);
''',
  r'''
CREATE INDEX        IF NOT EXISTS ix_products_kategori ON products_cache (kategori);
''',
  r'''
CREATE INDEX        IF NOT EXISTS ix_products_zona    ON products_cache (zona);
''',
  r'''
CREATE VIEW IF NOT EXISTS v_products_status AS
SELECT p.*,
       CASE WHEN p.stok = 0                    THEN 'Habis'
            WHEN p.stok <= p.reorder_point     THEN 'Menipis'
            ELSE 'Aman' END AS status_stok
FROM products_cache p;
''',
  r'''
CREATE TABLE IF NOT EXISTS cart_items (
  user_id        INTEGER NOT NULL,
  product_id     INTEGER NOT NULL,
  qty            INTEGER NOT NULL CHECK (qty > 0),
  nama_snapshot  TEXT NOT NULL,
  harga_snapshot INTEGER NOT NULL CHECK (harga_snapshot >= 0),
  updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  PRIMARY KEY (user_id, product_id)
) WITHOUT ROWID;
''',
  r'''
CREATE TABLE IF NOT EXISTS checkout_draft (
  user_id      INTEGER PRIMARY KEY,
  alamat       TEXT,
  lat          REAL CHECK (lat IS NULL OR lat BETWEEN -90 AND 90),
  lng          REAL CHECK (lng IS NULL OR lng BETWEEN -180 AND 180),
  metode_bayar TEXT CHECK (metode_bayar IS NULL OR metode_bayar IN ('Transfer Bank','QRIS','E-Wallet')),
  updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
''',
  r'''
CREATE TABLE IF NOT EXISTS kurs_cache (
  mata_uang    TEXT PRIMARY KEY CHECK (mata_uang IN ('USD','CNY','JPY','EUR')),
  kurs_idr     REAL NOT NULL CHECK (kurs_idr > 0),      -- 1 unit mata uang = n IDR
  diambil_pada TEXT NOT NULL,                           -- waktu server mengambil kurs
  synced_at    TEXT NOT NULL
) WITHOUT ROWID;
''',
  r'''
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
''',
  r'''
CREATE INDEX IF NOT EXISTS ix_notif_user ON notifications_local (user_id, dibaca, created_at DESC);
''',
  r'''
CREATE INDEX IF NOT EXISTS ix_notif_pending_sync ON notifications_local (user_id)
  WHERE read_pending_sync = 1;
''',
  r'''
CREATE TABLE IF NOT EXISTS payment_reminders (
  order_id    INTEGER PRIMARY KEY,
  user_id     INTEGER NOT NULL,
  notif_id    INTEGER NOT NULL UNIQUE,
  batas_bayar TEXT NOT NULL,
  fire_at     TEXT NOT NULL,                            -- mis. 1 jam sebelum batas_bayar
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
''',
  r'''
CREATE INDEX IF NOT EXISTS ix_reminders_user ON payment_reminders (user_id);
''',
];
