class StaffModel {
  const StaffModel({
    required this.id,
    required this.username,
    required this.isActive,
    this.nama,
    this.createdAt,
  });

  final int id;
  final String username;
  final String? nama;
  final bool isActive;
  final DateTime? createdAt;

  String get displayName {
    final value = nama?.trim();
    return (value != null && value.isNotEmpty) ? value : username;
  }

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      nama: json['nama'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}
