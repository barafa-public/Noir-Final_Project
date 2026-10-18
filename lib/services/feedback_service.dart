import '../models/feedback_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

/// Saran & Kesan. Kontrak Edge Function:
///
/// POST feedback/mine    {}                         -> 200 {feedback: {...} | null}
/// POST feedback/submit  {kesan, saran, rating 1-5} -> 201/200 {feedback: {...}}
///   (satu jawaban per pengguna: mengirim lagi memperbarui jawaban sebelumnya)
class FeedbackService {
  FeedbackService._();

  static final FeedbackService instance = FeedbackService._();

  ApiClient get _api => AuthService.instance.api;

  Future<FeedbackModel?> mine() async {
    final res = await _api.send('feedback/mine');
    return _parse(res.data);
  }

  Future<FeedbackModel> submit({
    required String kesan,
    required String saran,
    required int rating,
  }) async {
    final res = await _api.send('feedback/submit', {
      'kesan': kesan,
      'saran': saran,
      'rating': rating,
    });
    final parsed = _parse(res.data);
    if (parsed == null) throw ApiException('Respons server tidak valid.');
    return parsed;
  }

  FeedbackModel? _parse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    final raw = data['feedback'];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    try {
      return FeedbackModel.fromJson(raw);
    } catch (_) {
      throw ApiException('Respons server tidak valid.');
    }
  }
}
