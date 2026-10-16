import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class ProductDao {
  /// Ganti seluruh katalog dengan data dari server dalam SATU transaksi,
  /// supaya produk yang sudah nonaktif di server ikut hilang dari cache.
  /// [rows] = daftar produk dari endpoint katalog (kunci = nama kolom products_cache).
  Future<void> replaceAll(List<Map<String, Object?>> rows) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete('products_cache');
      final batch = txn.batch();
      for (final r in rows) {
        batch.insert('products_cache', {...r, 'synced_at': now});
      }
      await batch.commit(noResult: true);
      await txn.insert(
        'meta',
        {'key': 'products_synced_at', 'value': now, 'updated_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Pencarian nama/SKU + filter opsional (kategori, zona, status stok).
  /// Nilai selalu lewat parameter (?), tidak disambung ke string SQL.
  Future<List<Map<String, Object?>>> search({
    String query = '',
    String? kategori,
    String? zona,
    String? statusStok, // 'Habis' | 'Menipis' | 'Aman'
  }) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (query.trim().isNotEmpty) {
      where.add('(nama LIKE ? OR sku LIKE ?)');
      args..add('%${query.trim()}%')..add('%${query.trim()}%');
    }
    if (kategori != null) {
      where.add('kategori = ?');
      args.add(kategori);
    }
    if (zona != null) {
      where.add('zona = ?');
      args.add(zona);
    }
    if (statusStok != null) {
      where.add('status_stok = ?');
      args.add(statusStok);
    }

    return db.query(
      'v_products_status',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'nama',
    );
  }
}
