/// Validator form. Mengembalikan pesan error, atau null jika valid.
/// Aturan ini hanya kenyamanan UI; server tetap harus memvalidasi ulang.
class Validators {
  Validators._();

  static String? notEmpty(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  static String? username(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'Username wajib diisi';
    if (s.length < 3) return 'Username minimal 3 karakter';
    if (s.length > 30) return 'Username maksimal 30 karakter';
    if (!RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(s)) {
      return 'Hanya huruf, angka, titik, dan garis bawah';
    }
    return null;
  }

  /// Diawali 0, minimal 10 digit total. Sama dengan CHECK di tabel users.
  static String? telepon(String? value) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return 'No. telepon wajib diisi';
    if (!RegExp(r'^0[0-9]{9,19}$').hasMatch(s))
      return 'Nomor telepon tidak valid';
    return null;
  }

  /// Password tidak di-trim (spasi bisa jadi bagian password).
  static String? password(String? value) {
    final s = value ?? '';
    if (s.isEmpty) return 'Password wajib diisi';
    if (s.length < 6) return 'Password terlalu pendek';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty)
      return 'Konfirmasi password wajib diisi';
    if (value != password) return 'Password tidak cocok';
    return null;
  }
}
