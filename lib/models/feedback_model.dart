class FeedbackModel {
  const FeedbackModel({
    required this.kesan,
    required this.saran,
    required this.rating,
    this.createdAt,
  });

  final String kesan;
  final String saran;
  final int rating; // 1..5
  final DateTime? createdAt;

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      kesan: json['kesan'] as String,
      saran: json['saran'] as String,
      rating: (json['rating'] as num).toInt(),
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}
