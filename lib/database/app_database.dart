import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema_v1.dart';

/// Pintu tunggal ke SQLite lokal (file noir.db di penyimpanan privat aplikasi).
/// Dipakai sebagai singleton: jangan membuka database yang sama dari banyak tempat.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _fileName = 'noir.db';
  static const _version = 1; // naikkan saat skema berubah, lalu isi onUpgrade

  Future<Database>? _opening;

  /// Database dibuka sekali (lazy). Panggilan berikutnya memakai Future yang sama.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Jalan setiap kali koneksi dibuka (sebelum onCreate/onUpgrade).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // WAL mengurangi "database is locked" saat workmanager (isolate lain) ikut menulis.
    // PRAGMA ini mengembalikan baris, jadi pakai rawQuery (execute bisa error di Android).
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  // Jalan SEKALI, saat file database belum ada (instalasi pertama / setelah dihapus).
  // sqflite membungkusnya dalam transaksi: jika satu statement gagal, semuanya batal.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in kSchemaV1) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  // Jalan saat versi di HP (mis. 1) lebih kecil dari _version (mis. 2).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Contoh nanti:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE ... ADD COLUMN ...'); }
  }

  /// Bersihkan data per-user saat logout / ganti akun (katalog & kurs tetap).
  /// Batalkan dulu pengingat terjadwal di flutter_local_notifications
  /// (baca notif_id dari payment_reminders SEBELUM memanggil ini).
  Future<void> clearUserData(int userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('checkout_draft', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('notifications_local', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('payment_reminders', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('meta', where: 'key = ?', whereArgs: ['notif_last_id:$userId']);
    });
  }

  /// Hanya untuk development: hapus file database agar onCreate jalan lagi.
  Future<void> deleteForDev() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    _opening = null;
    await deleteDatabase(path);
  }
}
