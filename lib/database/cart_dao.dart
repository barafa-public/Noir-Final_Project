import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

String _nowUtc() => DateTime.now().toUtc().toIso8601String();

class CartDao {
  /// Tambah ke keranjang. Tidak memakai "ON CONFLICT DO UPDATE" (upsert) karena
  /// butuh SQLite >= 3.24, sedangkan Android 9 ke bawah membawa versi lebih lama.
  Future<void> addItem({
    required int userId,
    required int productId,
    required int qty,
    required String nama,
    required int harga,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      final updated = await txn.rawUpdate(
        'UPDATE cart_items SET qty = qty + ?, nama_snapshot = ?, '
        'harga_snapshot = ?, updated_at = ? WHERE user_id = ? AND product_id = ?',
        [qty, nama, harga, _nowUtc(), userId, productId],
      );
      if (updated == 0) {
        await txn.insert('cart_items', {
          'user_id': userId,
          'product_id': productId,
          'qty': qty,
          'nama_snapshot': nama,
          'harga_snapshot': harga,
          'updated_at': _nowUtc(),
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> items(int userId) async {
    final db = await AppDatabase.instance.database;
    return db.query('cart_items',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'nama_snapshot');
  }

  /// Hanya perkiraan tampilan; total resmi dihitung server saat create_order.
  Future<int> estimatedTotal(int userId) async {
    final db = await AppDatabase.instance.database;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(qty * harga_snapshot), 0) AS total '
      'FROM cart_items WHERE user_id = ?',
      [userId],
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
