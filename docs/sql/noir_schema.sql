-- =====================================================================
-- NOIR - Skema Database Supabase (PostgreSQL)
-- Jalankan di Supabase SQL Editor, satu kali, berurutan dari atas.
-- Arsitektur: Flutter -> Edge Functions (service_role) -> tabel/RPC.
-- Klien (anon/authenticated) TIDAK boleh menyentuh tabel maupun fungsi.
-- Supabase Auth tidak dipakai; autentikasi memakai tabel users sendiri.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Ekstensi & kunci akses
-- ---------------------------------------------------------------------
create extension if not exists pgcrypto with schema extensions;

-- Objek yang dibuat setelah baris ini otomatis tertutup untuk klien
alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. Tabel master & autentikasi
-- ---------------------------------------------------------------------
create table users (
  id               bigint generated always as identity primary key,
  username         text not null,
  password_hash    text not null check (length(password_hash) >= 60),  -- bcrypt/argon2, BUKAN plaintext
  role             text not null check (role in ('customer','manager','staff')),
  nama             text,
  alamat           text,
  telepon          text check (telepon is null or telepon ~ '^0[0-9]{9,19}$'),
  lat              double precision check (lat between -90 and 90),
  lng              double precision check (lng between -180 and 180),
  foto_url         text,
  biometric_enabled boolean not null default false,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now()
);
create unique index users_username_uq on users (lower(username));

create table refresh_tokens (
  id          bigint generated always as identity primary key,
  user_id     bigint not null references users(id) on delete cascade,
  token_hash  text not null unique,           -- simpan hash token, bukan token asli
  device      text,
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);
create index refresh_tokens_user_idx on refresh_tokens (user_id);

create table suppliers (
  id             bigint generated always as identity primary key,
  nama           text not null,
  mata_uang      text not null default 'IDR' check (mata_uang in ('IDR','USD','CNY','JPY','EUR')),
  lead_time_hari int  not null default 7 check (lead_time_hari > 0),
  alamat         text,
  lat            double precision check (lat between -90 and 90),
  lng            double precision check (lng between -180 and 180),
  created_at     timestamptz not null default now()
);

create table warehouses (
  id         bigint generated always as identity primary key,
  nama       text not null,
  alamat     text,
  lat        double precision not null check (lat between -90 and 90),
  lng        double precision not null check (lng between -180 and 180),
  created_at timestamptz not null default now()
);

create table products (
  id            bigint generated always as identity primary key,
  sku           text not null unique,
  nama          text not null,
  kategori      text not null check (kategori in ('Kertas','Alat Tulis','Map','Lainnya')),
  harga         bigint not null check (harga >= 0),           -- IDR per satuan
  stok          int    not null default 0 check (stok >= 0),  -- stok tidak boleh negatif
  supplier_id   bigint references suppliers(id) on delete set null,
  zona          text,
  rak           text,
  level         text,
  bin           text,
  kode_lokasi   text generated always as (zona || '-' || rak || '-' || level || '-' || bin) stored,
  reorder_point int not null default 0,    -- diisi hasil analisis AI (untuk notifikasi stok)
  safety_stock  int not null default 0,
  gambar        text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create index products_kategori_idx on products (kategori);
create index products_zona_idx on products (zona);
create index products_nama_idx on products (lower(nama));

-- ---------------------------------------------------------------------
-- 2. Pesanan, pembayaran, pengiriman
-- Status: Menunggu Pembayaran -> Menunggu Konfirmasi -> Diproses
--         -> Dikemas -> Dikirim -> Selesai | Dibatalkan
-- ---------------------------------------------------------------------
create table orders (
  id            bigint generated always as identity primary key,
  no_pesanan    text generated always as ('ORD-' || lpad(id::text, 6, '0')) stored,
  customer_id   bigint not null references users(id),
  alamat        text not null,
  lat           double precision,
  lng           double precision,
  metode_bayar  text not null check (metode_bayar in ('Transfer Bank','QRIS','E-Wallet')),
  total         bigint not null default 0 check (total >= 0),
  status        text not null default 'Menunggu Pembayaran'
                check (status in ('Menunggu Pembayaran','Menunggu Konfirmasi','Diproses',
                                  'Dikemas','Dikirim','Selesai','Dibatalkan')),
  batas_bayar   timestamptz,
  alasan_tolak  text,
  approved_at   timestamptz,    -- dipakai analisis penjualan AI
  approved_by   bigint references users(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index orders_customer_idx on orders (customer_id);
create index orders_status_idx   on orders (status);
create index orders_approved_idx on orders (approved_at);

create table order_items (
  id           bigint generated always as identity primary key,
  order_id     bigint not null references orders(id) on delete cascade,
  product_id   bigint not null references products(id),
  qty          int    not null check (qty > 0),
  harga_satuan bigint not null check (harga_satuan >= 0),   -- harga dibekukan saat order
  subtotal     bigint generated always as (qty::bigint * harga_satuan) stored,
  unique (order_id, product_id)
);
create index order_items_product_idx on order_items (product_id);

create table payments (
  id                bigint generated always as identity primary key,
  order_id          bigint not null unique references orders(id) on delete cascade,
  metode            text not null,
  detail            jsonb not null default '{}'::jsonb,
  -- Transfer: {"nama_bank","no_rekening","atas_nama"}
  -- E-Wallet: {"platform","no_pengirim","kode_transaksi"}
  -- QRIS    : {"kode_transaksi"}
  bukti_file        text not null,           -- wajib: tidak ada konfirmasi tanpa bukti
  nominal           bigint not null check (nominal > 0),
  status_verifikasi text not null default 'Menunggu' check (status_verifikasi in ('Menunggu','Valid','Ditolak')),
  verified_by       bigint references users(id),
  verified_at       timestamptz,
  created_at        timestamptz not null default now()
);

create table shipments (
  id            bigint generated always as identity primary key,
  order_id      bigint not null unique references orders(id) on delete cascade,
  ekspedisi     text not null,
  no_resi       text not null,
  estimasi_tiba timestamptz,
  created_by    bigint references users(id),
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. Pengadaan, kurs
-- ---------------------------------------------------------------------
create table kurs_cache (
  mata_uang    text primary key check (mata_uang in ('USD','CNY','JPY','EUR')),
  kurs_idr     numeric(18,4) not null check (kurs_idr > 0),   -- 1 unit mata uang = n IDR
  diambil_pada timestamptz not null default now()
);

create table procurements (
  id                bigint generated always as identity primary key,
  kode_barang       text not null,
  supplier_id       bigint not null references suppliers(id),
  product_id        bigint not null references products(id),
  qty               int not null check (qty > 0),
  tanggal           date not null default current_date,
  mata_uang         text not null default 'IDR' check (mata_uang in ('IDR','USD','CNY','JPY','EUR')),
  harga_asing       numeric(18,2) not null check (harga_asing >= 0),
  kurs              numeric(18,4) not null default 1 check (kurs > 0),   -- kurs saat transaksi
  harga_satuan_idr  bigint not null check (harga_satuan_idr >= 0),
  harga_total_idr   bigint not null check (harga_total_idr >= 0),
  estimasi_tiba     timestamptz,
  status            text not null default 'Dipesan' check (status in ('Dipesan','Diterima','Dibatalkan')),
  lokasi_terima     text,
  created_by        bigint references users(id),
  received_by       bigint references users(id),
  received_at       timestamptz,
  created_at        timestamptz not null default now()
);
create index procurements_product_idx on procurements (product_id);
create index procurements_status_idx  on procurements (status);

-- ---------------------------------------------------------------------
-- 4. Notifikasi, blockchain, game, saran & kesan
-- ---------------------------------------------------------------------
create table notifications (
  id         bigint generated always as identity primary key,
  user_id    bigint not null references users(id) on delete cascade,  -- per user, agar status baca tidak bentrok
  jenis      text not null check (jenis in ('stok_rop','pesanan_baru','pembayaran','siap_kemas','status_pesanan','batas_bayar')),
  judul      text not null,
  isi        text not null,
  ref_type   text,
  ref_id     bigint,
  dibaca     boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on notifications (user_id, dibaca, created_at desc);

create table chain_blocks (
  idx          bigint primary key,
  ts           timestamptz not null,
  tipe         text not null check (tipe in ('PENERIMAAN','PENGIRIMAN')),
  ref_id       bigint not null,
  payload      jsonb  not null,
  payload_hash text   not null,
  prev_hash    text   not null,
  nonce        bigint not null,
  hash         text   not null unique
);

create table game_scores (
  id         bigint generated always as identity primary key,
  user_id    bigint not null references users(id) on delete cascade,
  skor       int not null check (skor >= 0),
  created_at timestamptz not null default now()
);
create index game_scores_rank_idx on game_scores (skor desc);

create table feedback (
  id         bigint generated always as identity primary key,
  user_id    bigint not null references users(id) on delete cascade,
  kesan      text not null,
  saran      text not null,
  rating     int  not null check (rating between 1 and 5),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. Fungsi bantu
-- ---------------------------------------------------------------------
create or replace function assert_role(p_user bigint, p_roles text[])
returns void language plpgsql stable set search_path = public, extensions as $$
begin
  if not exists (select 1 from users where id = p_user and is_active and role = any(p_roles)) then
    raise exception 'Akses ditolak: role tidak sesuai';
  end if;
end $$;

create or replace function notify_user(p_user bigint, p_jenis text, p_judul text, p_isi text,
                                       p_ref_type text default null, p_ref_id bigint default null)
returns void language sql set search_path = public, extensions as $$
  insert into notifications (user_id, jenis, judul, isi, ref_type, ref_id)
  values (p_user, p_jenis, p_judul, p_isi, p_ref_type, p_ref_id);
$$;

create or replace function notify_role(p_role text, p_jenis text, p_judul text, p_isi text,
                                       p_ref_type text default null, p_ref_id bigint default null)
returns void language sql set search_path = public, extensions as $$
  insert into notifications (user_id, jenis, judul, isi, ref_type, ref_id)
  select id, p_jenis, p_judul, p_isi, p_ref_type, p_ref_id from users where role = p_role and is_active;
$$;

-- Jarak Haversine (km)
create or replace function haversine_km(lat1 double precision, lng1 double precision,
                                        lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)));
$$;

create or replace function nearby_suppliers(p_lat double precision, p_lng double precision)
returns table (id bigint, nama text, mata_uang text, lead_time_hari int, alamat text,
               lat double precision, lng double precision, jarak_km double precision)
language sql stable set search_path = public, extensions as $$
  select s.id, s.nama, s.mata_uang, s.lead_time_hari, s.alamat, s.lat, s.lng,
         round(haversine_km(p_lat, p_lng, s.lat, s.lng)::numeric, 2)::double precision
  from suppliers s where s.lat is not null and s.lng is not null
  order by 8;
$$;

create or replace function nearby_warehouses(p_lat double precision, p_lng double precision)
returns table (id bigint, nama text, alamat text, lat double precision, lng double precision, jarak_km double precision)
language sql stable set search_path = public, extensions as $$
  select w.id, w.nama, w.alamat, w.lat, w.lng,
         round(haversine_km(p_lat, p_lng, w.lat, w.lng)::numeric, 2)::double precision
  from warehouses w order by 6;
$$;

-- ---------------------------------------------------------------------
-- 6. Blockchain (hash chain SHA-256)
-- ---------------------------------------------------------------------
create or replace function chain_hash(p_idx bigint, p_ts timestamptz, p_tipe text,
                                      p_payload_hash text, p_prev text, p_nonce bigint)
returns text language sql stable set search_path = public, extensions as $$
  select encode(digest(
    p_idx::text || '|' || to_char(p_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || '|' ||
    p_tipe || '|' || p_payload_hash || '|' || p_prev || '|' || p_nonce::text, 'sha256'), 'hex');
$$;

-- Proof-of-work ringan: hash harus diawali '00' (rata-rata ~256 percobaan)
create or replace function append_chain_block(p_tipe text, p_ref_id bigint, p_payload jsonb)
returns chain_blocks language plpgsql set search_path = public, extensions as $$
declare
  v_idx bigint; v_prev text; v_ts timestamptz := now(); v_ph text;
  v_nonce bigint := 0; v_hash text; v_row chain_blocks;
begin
  perform pg_advisory_xact_lock(7001);              -- serialkan pembuatan blok
  select b.idx + 1, b.hash into v_idx, v_prev from chain_blocks b order by b.idx desc limit 1;
  if not found then v_idx := 0; v_prev := repeat('0', 64); end if;

  v_ph := encode(digest(p_payload::text, 'sha256'), 'hex');
  loop
    v_hash := chain_hash(v_idx, v_ts, p_tipe, v_ph, v_prev, v_nonce);
    exit when left(v_hash, 2) = '00';
    v_nonce := v_nonce + 1;
  end loop;

  insert into chain_blocks (idx, ts, tipe, ref_id, payload, payload_hash, prev_hash, nonce, hash)
  values (v_idx, v_ts, p_tipe, p_ref_id, p_payload, v_ph, v_prev, v_nonce, v_hash)
  returning * into v_row;
  return v_row;
end $$;

-- Tombol "Verifikasi Integritas": hitung ulang seluruh rantai
create or replace function verify_chain()
returns table (idx bigint, valid boolean, reason text)
language plpgsql stable set search_path = public, extensions as $$
declare
  b chain_blocks; v_prev text := repeat('0', 64); v_expected bigint := 0; v_reason text;
begin
  for b in select * from chain_blocks order by chain_blocks.idx loop
    v_reason := null;
    if b.idx <> v_expected then
      v_reason := 'Index tidak berurutan (blok hilang)';
    elsif b.prev_hash <> v_prev then
      v_reason := 'prev_hash tidak cocok dengan blok sebelumnya';
    elsif b.payload_hash <> encode(digest(b.payload::text, 'sha256'), 'hex') then
      v_reason := 'Isi dokumen (payload) telah diubah';
    elsif b.hash <> chain_hash(b.idx, b.ts, b.tipe, b.payload_hash, b.prev_hash, b.nonce) then
      v_reason := 'Hash blok tidak valid';
    end if;
    idx := b.idx; valid := (v_reason is null); reason := coalesce(v_reason, 'OK');
    return next;
    v_prev := b.hash; v_expected := b.idx + 1;
  end loop;
end $$;

-- Blok tidak boleh diubah/dihapus lewat jalur normal.
-- Untuk DEMO tamper:  alter table chain_blocks disable trigger trg_chain_immutable;
--   (ubah satu payload, panggil verify_chain(), lalu enable trigger kembali)
create or replace function chain_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'chain_blocks bersifat append-only';
end $$;
create trigger trg_chain_immutable before update or delete on chain_blocks
  for each row execute function chain_immutable();

-- ---------------------------------------------------------------------
-- 7. Alur pesanan (atomik; dipanggil Edge Function via rpc)
-- ---------------------------------------------------------------------
-- Harga SELALU diambil dari tabel products, bukan dari klien.
-- p_items contoh: [{"product_id":1,"qty":2},{"product_id":5,"qty":1}]
create or replace function create_order(p_customer_id bigint, p_alamat text,
    p_lat double precision, p_lng double precision, p_metode text, p_items jsonb,
    p_batas_jam int default 24)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders; v_total bigint; v_req int; v_ok int;
begin
  perform assert_role(p_customer_id, array['customer']);
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Item pesanan kosong';
  end if;

  insert into orders (customer_id, alamat, lat, lng, metode_bayar, total, status, batas_bayar)
  values (p_customer_id, p_alamat, p_lat, p_lng, p_metode, 0, 'Menunggu Pembayaran',
          now() + make_interval(hours => p_batas_jam))
  returning * into v_order;

  with req as (
    select product_id, sum(qty)::int as qty
    from jsonb_to_recordset(p_items) as x(product_id bigint, qty int)
    group by product_id
  )
  insert into order_items (order_id, product_id, qty, harga_satuan)
  select v_order.id, pr.id, r.qty, pr.harga
  from req r join products pr on pr.id = r.product_id and pr.is_active;

  select count(distinct (x.product_id)) into v_req
    from jsonb_to_recordset(p_items) as x(product_id bigint, qty int);
  select count(*) into v_ok from order_items where order_id = v_order.id;
  if v_req <> v_ok then raise exception 'Ada produk yang tidak valid/nonaktif'; end if;

  if exists (select 1 from order_items oi join products pr on pr.id = oi.product_id
             where oi.order_id = v_order.id and oi.qty > pr.stok) then
    raise exception 'Stok tidak mencukupi';
  end if;

  select sum(subtotal) into v_total from order_items where order_id = v_order.id;
  update orders set total = v_total where id = v_order.id returning * into v_order;
  return v_order;
end $$;

create or replace function submit_payment(p_order_id bigint, p_customer_id bigint,
    p_detail jsonb, p_bukti text, p_nominal bigint)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.customer_id <> p_customer_id then raise exception 'Bukan pesanan Anda'; end if;
  if v_order.status <> 'Menunggu Pembayaran' then raise exception 'Pesanan berstatus %, tidak dapat dibayar', v_order.status; end if;
  if v_order.batas_bayar < now() then raise exception 'Batas waktu pembayaran sudah lewat'; end if;
  if p_nominal <> v_order.total then raise exception 'Nominal harus sama dengan total (Rp %)', v_order.total; end if;

  insert into payments (order_id, metode, detail, bukti_file, nominal)
  values (v_order.id, v_order.metode_bayar, coalesce(p_detail, '{}'::jsonb), p_bukti, p_nominal);

  update orders set status = 'Menunggu Konfirmasi', updated_at = now()
   where id = v_order.id returning * into v_order;

  perform notify_role('manager', 'pembayaran', 'Pembayaran menunggu verifikasi',
                      v_order.no_pesanan || ' menunggu verifikasi pembayaran', 'order', v_order.id);
  return v_order;
end $$;

-- Setuju: stok dikurangi atomik. Jika salah satu produk kurang, semuanya batal.
create or replace function approve_order(p_order_id bigint, p_manager_id bigint)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders; r record;
begin
  perform assert_role(p_manager_id, array['manager']);
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.status <> 'Menunggu Konfirmasi' then raise exception 'Pesanan berstatus %, tidak dapat disetujui', v_order.status; end if;

  for r in select product_id, qty from order_items where order_id = p_order_id order by product_id loop
    update products set stok = stok - r.qty where id = r.product_id and stok >= r.qty;
    if not found then raise exception 'Stok tidak cukup untuk produk id %', r.product_id; end if;
  end loop;

  update payments set status_verifikasi = 'Valid', verified_by = p_manager_id, verified_at = now()
   where order_id = p_order_id;
  update orders set status = 'Diproses', approved_at = now(), approved_by = p_manager_id, updated_at = now()
   where id = p_order_id returning * into v_order;

  perform notify_user(v_order.customer_id, 'status_pesanan', 'Pesanan disetujui',
                      v_order.no_pesanan || ' sedang diproses', 'order', v_order.id);
  perform notify_role('staff', 'siap_kemas', 'Pesanan siap dikemas',
                      v_order.no_pesanan || ' menunggu dikemas', 'order', v_order.id);
  return v_order;
end $$;

-- Tolak (atau batalkan pesanan Diproses -> stok dikembalikan)
create or replace function reject_order(p_order_id bigint, p_manager_id bigint, p_alasan text)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders;
begin
  perform assert_role(p_manager_id, array['manager']);
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.status not in ('Menunggu Konfirmasi', 'Diproses') then
    raise exception 'Pesanan berstatus %, tidak dapat ditolak', v_order.status;
  end if;

  if v_order.status = 'Diproses' then
    update products pr set stok = pr.stok + oi.qty
      from order_items oi where oi.order_id = v_order.id and oi.product_id = pr.id;
  end if;

  update payments set status_verifikasi = 'Ditolak', verified_by = p_manager_id, verified_at = now()
   where order_id = p_order_id;
  update orders set status = 'Dibatalkan', alasan_tolak = p_alasan, updated_at = now()
   where id = p_order_id returning * into v_order;

  perform notify_user(v_order.customer_id, 'status_pesanan', 'Pesanan dibatalkan',
                      v_order.no_pesanan || ' dibatalkan: ' || coalesce(p_alasan, '-'), 'order', v_order.id);
  return v_order;
end $$;

create or replace function pack_order(p_order_id bigint, p_staff_id bigint)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders;
begin
  perform assert_role(p_staff_id, array['staff','manager']);
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.status <> 'Diproses' then raise exception 'Pesanan berstatus %, tidak dapat dikemas', v_order.status; end if;

  update orders set status = 'Dikemas', updated_at = now() where id = p_order_id returning * into v_order;
  perform notify_user(v_order.customer_id, 'status_pesanan', 'Pesanan dikemas',
                      v_order.no_pesanan || ' sedang dikemas', 'order', v_order.id);
  return v_order;
end $$;

-- Serah ke ekspedisi + catat blok blockchain tipe PENGIRIMAN
create or replace function ship_order(p_order_id bigint, p_staff_id bigint,
    p_ekspedisi text, p_resi text, p_estimasi timestamptz)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders; v_items jsonb;
begin
  perform assert_role(p_staff_id, array['staff','manager']);
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.status <> 'Dikemas' then raise exception 'Pesanan berstatus %, tidak dapat dikirim', v_order.status; end if;

  insert into shipments (order_id, ekspedisi, no_resi, estimasi_tiba, created_by)
  values (p_order_id, p_ekspedisi, p_resi, p_estimasi, p_staff_id);

  select jsonb_agg(jsonb_build_object('product_id', product_id, 'qty', qty) order by product_id)
    into v_items from order_items where order_id = p_order_id;

  perform append_chain_block('PENGIRIMAN', p_order_id, jsonb_build_object(
    'order_id', p_order_id, 'no_pesanan', v_order.no_pesanan, 'items', v_items,
    'ekspedisi', p_ekspedisi, 'no_resi', p_resi, 'dikirim_oleh', p_staff_id));

  update orders set status = 'Dikirim', updated_at = now() where id = p_order_id returning * into v_order;
  perform notify_user(v_order.customer_id, 'status_pesanan', 'Pesanan dikirim',
                      v_order.no_pesanan || ' dikirim via ' || p_ekspedisi || ', resi ' || p_resi, 'order', v_order.id);
  return v_order;
end $$;

create or replace function confirm_received(p_order_id bigint, p_customer_id bigint)
returns orders language plpgsql set search_path = public, extensions as $$
declare v_order orders;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'Pesanan tidak ditemukan'; end if;
  if v_order.customer_id <> p_customer_id then raise exception 'Bukan pesanan Anda'; end if;
  if v_order.status <> 'Dikirim' then raise exception 'Pesanan berstatus %, belum dapat dikonfirmasi', v_order.status; end if;

  update orders set status = 'Selesai', updated_at = now() where id = p_order_id returning * into v_order;
  perform notify_role('manager', 'status_pesanan', 'Pesanan selesai',
                      v_order.no_pesanan || ' dikonfirmasi diterima customer', 'order', v_order.id);
  return v_order;
end $$;

-- Dipanggil berkala (workmanager/endpoint) atau saat data dibaca. Tanpa cron.
create or replace function expire_unpaid_orders()
returns int language plpgsql set search_path = public, extensions as $$
declare v_count int;
begin
  with x as (
    update orders set status = 'Dibatalkan', alasan_tolak = 'Batas waktu pembayaran habis', updated_at = now()
     where status = 'Menunggu Pembayaran' and batas_bayar < now()
     returning id, customer_id, no_pesanan
  ), n as (
    insert into notifications (user_id, jenis, judul, isi, ref_type, ref_id)
    select customer_id, 'status_pesanan', 'Pesanan kedaluwarsa',
           no_pesanan || ' dibatalkan karena melewati batas pembayaran', 'order', id from x
    returning 1
  )
  select count(*) into v_count from x;
  return v_count;
end $$;

-- ---------------------------------------------------------------------
-- 8. Alur pengadaan
-- ---------------------------------------------------------------------
-- Kurs diambil dari kurs_cache lalu DIBEKUKAN pada baris pengadaan.
create or replace function create_procurement(p_user_id bigint, p_supplier_id bigint, p_product_id bigint,
    p_qty int, p_tanggal date, p_mata_uang text, p_harga_asing numeric,
    p_estimasi_tiba timestamptz, p_kode_barang text)
returns procurements language plpgsql set search_path = public, extensions as $$
declare v_kurs numeric(18,4); v_satuan bigint; v_row procurements;
begin
  perform assert_role(p_user_id, array['manager']);
  if p_mata_uang = 'IDR' then
    v_kurs := 1;
  else
    select kurs_idr into v_kurs from kurs_cache where mata_uang = p_mata_uang;
    if v_kurs is null then raise exception 'Kurs % belum tersedia', p_mata_uang; end if;
  end if;
  v_satuan := round(p_harga_asing * v_kurs);

  insert into procurements (kode_barang, supplier_id, product_id, qty, tanggal, mata_uang, harga_asing,
                            kurs, harga_satuan_idr, harga_total_idr, estimasi_tiba, created_by)
  values (p_kode_barang, p_supplier_id, p_product_id, p_qty, coalesce(p_tanggal, current_date), p_mata_uang,
          p_harga_asing, v_kurs, v_satuan, v_satuan * p_qty, p_estimasi_tiba, p_user_id)
  returning * into v_row;
  return v_row;
end $$;

-- Terima barang: stok bertambah, lokasi rak diset, blok PENERIMAAN dibuat
create or replace function receive_procurement(p_id bigint, p_user_id bigint,
    p_zona text, p_rak text, p_level text, p_bin text)
returns procurements language plpgsql set search_path = public, extensions as $$
declare v_row procurements;
begin
  perform assert_role(p_user_id, array['manager','staff']);
  select * into v_row from procurements where id = p_id for update;
  if not found then raise exception 'Pengadaan tidak ditemukan'; end if;
  if v_row.status <> 'Dipesan' then raise exception 'Pengadaan berstatus %, tidak dapat diterima', v_row.status; end if;

  update products
     set stok = stok + v_row.qty,
         zona = coalesce(p_zona, zona), rak = coalesce(p_rak, rak),
         level = coalesce(p_level, level), bin = coalesce(p_bin, bin)
   where id = v_row.product_id;

  update procurements
     set status = 'Diterima', received_by = p_user_id, received_at = now(),
         lokasi_terima = concat_ws('-', p_zona, p_rak, p_level, p_bin)
   where id = p_id returning * into v_row;

  perform append_chain_block('PENERIMAAN', p_id, jsonb_build_object(
    'procurement_id', p_id, 'kode_barang', v_row.kode_barang, 'product_id', v_row.product_id,
    'supplier_id', v_row.supplier_id, 'qty', v_row.qty, 'harga_total_idr', v_row.harga_total_idr,
    'diterima_oleh', p_user_id));
  return v_row;
end $$;

-- ---------------------------------------------------------------------
-- 9. Data untuk AI (reorder point & produk terlaris)
-- Menghitung hari tanpa penjualan sebagai 0, supaya simpangan baku benar.
-- Penjualan = order yang disetujui (Diproses s.d. Selesai) per approved_at (WIB).
-- Rumus ROP/SS/ABC dihitung di Edge Function memakai hasil fungsi ini.
-- ---------------------------------------------------------------------
create or replace function ai_sales_stats(p_days int default 30)
returns table (product_id bigint, sku text, nama text, kategori text, stok int,
               lead_time_hari int, total_qty bigint, total_nilai bigint,
               rata_harian numeric, stddev_harian numeric)
language sql stable set search_path = public, extensions as $$
  with today as (select (now() at time zone 'Asia/Jakarta')::date as d),
  days as (
    select generate_series(t.d - (p_days - 1), t.d, interval '1 day')::date as d from today t
  ),
  daily as (
    select oi.product_id as pid, (o.approved_at at time zone 'Asia/Jakarta')::date as d,
           sum(oi.qty) as q, sum(oi.subtotal) as v
    from order_items oi join orders o on o.id = oi.order_id
    where o.status in ('Diproses','Dikemas','Dikirim','Selesai') and o.approved_at is not null
    group by 1, 2
  ),
  filled as (
    select p.id as pid, d.d, coalesce(dl.q, 0) as q, coalesce(dl.v, 0) as v
    from products p cross join days d
    left join daily dl on dl.pid = p.id and dl.d = d.d
    where p.is_active
  ),
  agg as (
    select pid, sum(q)::bigint as tq, sum(v)::bigint as tv,
           round(sum(q)::numeric / p_days, 4) as avg_d,
           round(coalesce(stddev_samp(q), 0)::numeric, 4) as sd_d
    from filled group by pid
  )
  select p.id, p.sku, p.nama, p.kategori, p.stok, coalesce(s.lead_time_hari, 7),
         a.tq, a.tv, a.avg_d, a.sd_d
  from agg a join products p on p.id = a.pid left join suppliers s on s.id = p.supplier_id
  order by a.tv desc;
$$;

-- ---------------------------------------------------------------------
-- 10. Keamanan: RLS aktif tanpa policy = klien ditolak; hanya service_role
-- ---------------------------------------------------------------------
alter table users            enable row level security;
alter table refresh_tokens   enable row level security;
alter table suppliers        enable row level security;
alter table warehouses       enable row level security;
alter table products         enable row level security;
alter table orders           enable row level security;
alter table order_items      enable row level security;
alter table payments         enable row level security;
alter table shipments        enable row level security;
alter table kurs_cache       enable row level security;
alter table procurements     enable row level security;
alter table notifications    enable row level security;
alter table chain_blocks     enable row level security;
alter table game_scores      enable row level security;
alter table feedback         enable row level security;

revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant all on all tables     in schema public to service_role;
grant all on all sequences  in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- =====================================================================
-- SEED (opsional, untuk development/demo). GANTI semua password sebelum demo.
-- Hash dibuat bcrypt ($2a$) oleh pgcrypto; kompatibel dengan bcrypt.compare di Edge Function.
-- =====================================================================
insert into warehouses (nama, alamat, lat, lng)
values ('Gudang Pusat Noir', 'Magelang, Jawa Tengah', -7.4797, 110.2177);

insert into suppliers (nama, mata_uang, lead_time_hari, alamat, lat, lng) values
 ('CV Kertas Nusantara',   'IDR', 3,  'Semarang',          -6.9667, 110.4167),
 ('PT Alat Tulis Prima',   'IDR', 4,  'Yogyakarta',        -7.7956, 110.3695),
 ('Shenzhen Stationery Co','CNY', 14, 'Shenzhen, China',    22.5431, 114.0579),
 ('Tokyo Office Supply',   'JPY', 12, 'Tokyo, Japan',       35.6762, 139.6503),
 ('Hamburg Paper GmbH',    'EUR', 18, 'Hamburg, Germany',   53.5511,  9.9937);

insert into products (sku, nama, kategori, harga, stok, supplier_id, zona, rak, level, bin) values
 ('KRT-A4-80',  'Kertas A4 80gsm (rim)',   'Kertas',     52000, 120, (select id from suppliers where nama='CV Kertas Nusantara'), 'A','01','01','A'),
 ('KRT-F4-70',  'Kertas F4 70gsm (rim)',   'Kertas',     48000,  90, (select id from suppliers where nama='CV Kertas Nusantara'), 'A','01','02','B'),
 ('KRT-HVS-A3', 'Kertas A3 80gsm (rim)',   'Kertas',    105000,  25, (select id from suppliers where nama='Hamburg Paper GmbH'), 'A','02','01','A'),
 ('ATL-PEN-01', 'Pulpen Gel 0.5 (lusin)',  'Alat Tulis', 36000,  60, (select id from suppliers where nama='PT Alat Tulis Prima'), 'B','01','01','A'),
 ('ATL-PCL-02', 'Pensil 2B (lusin)',       'Alat Tulis', 24000,  70, (select id from suppliers where nama='PT Alat Tulis Prima'), 'B','01','02','B'),
 ('ATL-MRK-03', 'Spidol Whiteboard (box)', 'Alat Tulis', 85000,  18, (select id from suppliers where nama='Tokyo Office Supply'), 'B','02','01','C'),
 ('MAP-SNP-01', 'Map Snelhecter (lusin)',  'Map',        62000,  40, (select id from suppliers where nama='Shenzhen Stationery Co'), 'C','01','01','A'),
 ('MAP-PLS-02', 'Map Plastik L (lusin)',   'Map',        30000,  55, (select id from suppliers where nama='Shenzhen Stationery Co'), 'C','01','02','B'),
 ('LNY-STP-01', 'Stapler + Isi (set)',     'Lainnya',    45000,   8, (select id from suppliers where nama='Tokyo Office Supply'), 'D','01','01','A');

insert into users (username, password_hash, role, nama, alamat, telepon, lat, lng) values
 ('manager1',  extensions.crypt('GantiPassword#1', extensions.gen_salt('bf', 10)), 'manager',  'Manager Noir',  null, null, null, null),
 ('staff1',    extensions.crypt('GantiPassword#2', extensions.gen_salt('bf', 10)), 'staff',    'Staff Gudang',  null, null, null, null),
 ('customer1', extensions.crypt('GantiPassword#3', extensions.gen_salt('bf', 10)), 'customer', 'Customer Demo', 'Jl. Pemuda No. 10, Magelang', '081234567890', -7.4706, 110.2178);

insert into kurs_cache (mata_uang, kurs_idr) values
 ('USD', 16200), ('CNY', 2230), ('JPY', 108), ('EUR', 17600);

-- Riwayat penjualan 30 hari agar analisis ROP/terlaris punya data
do $$
declare p record; d int; q int; oid bigint; cust bigint;
begin
  select id into cust from users where username = 'customer1';
  for p in select id, harga from products loop
    for d in 0..29 loop
      q := floor(random() * 6)::int;           -- 0..5 per hari
      if q > 0 then
        insert into orders (customer_id, alamat, metode_bayar, total, status, batas_bayar, approved_at, created_at)
        values (cust, 'Seed', 'Transfer Bank', p.harga * q, 'Selesai',
                now(), now() - make_interval(days => d), now() - make_interval(days => d))
        returning id into oid;
        insert into order_items (order_id, product_id, qty, harga_satuan) values (oid, p.id, q, p.harga);
      end if;
    end loop;
  end loop;
end $$;
