class UserModel {
  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.nama,
    this.fotoUrl,
    this.biometricEnabled = false,
  });

  final int id;
  final String username;
  final String role; // 'customer' | 'manager' | 'staff'
  final String? nama;
  final String? fotoUrl;
  final bool biometricEnabled;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      role: json['role'] as String,
      nama: json['nama'] as String?,
      fotoUrl: json['foto_url'] as String?,
      biometricEnabled: (json['biometric_enabled'] as bool?) ?? false,
    );
  }
}
