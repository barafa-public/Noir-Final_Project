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
