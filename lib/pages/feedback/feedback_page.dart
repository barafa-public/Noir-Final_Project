import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_exception.dart';
import '../../services/feedback_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';

/// Saran & Kesan mata kuliah Pemrograman Aplikasi Mobile.
/// Satu jawaban per pengguna: jawaban sebelumnya dimuat dan mengirim lagi memperbarui.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const _maxText = 1000;

  final _formKey = GlobalKey<FormState>();
  final _kesan = TextEditingController();
  final _saran = TextEditingController();

  int _rating = 0;
  bool _ratingMissing = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  DateTime? _sentAt;

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  @override
  void dispose() {
    _kesan.dispose();
    _saran.dispose();
    super.dispose();
  }

  Future<void> _loadPrevious() async {
    try {
      final previous = await FeedbackService.instance.mine();
      if (!mounted) return;
      if (previous != null) {
        _kesan.text = previous.kesan;
        _saran.text = previous.saran;
        _rating = previous.rating;
        _sentAt = previous.createdAt;
      }
    } on ApiException {
      // Gagal memuat jawaban lama tidak menghalangi pengisian form baru.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateText(String? value, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field wajib diisi';
    if (text.length > _maxText) return '$field maksimal $_maxText karakter';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState!.validate();
    setState(() => _ratingMissing = _rating == 0);
    if (!formOk || _rating == 0) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final saved = await FeedbackService.instance.submit(
        kesan: _kesan.text.trim(),
        saran: _saran.text.trim(),
        rating: _rating,
      );
      if (!mounted) return;
      setState(() => _sentAt = saved.createdAt ?? DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih! Saran & kesan Anda tersimpan.'),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _formatDate(DateTime date) {
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Saran & Kesan',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mata kuliah Pemrograman Aplikasi Mobile',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Rating',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                _RatingBar(
                  value: _rating,
                  onChanged: _sending
                      ? null
                      : (v) => setState(() {
                          _rating = v;
                          _ratingMissing = false;
                        }),
                ),
                if (_ratingMissing)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Pilih rating terlebih dahulu',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _kesan,
                  label: 'Kesan',
                  hint: 'Bagaimana kesan Anda tentang mata kuliah ini?',
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  enabled: !_sending,
                  validator: (v) => _validateText(v, 'Kesan'),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _saran,
                  label: 'Saran',
                  hint: 'Apa yang bisa ditingkatkan?',
                  icon: Icons.lightbulb_outline_rounded,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  enabled: !_sending,
                  validator: (v) => _validateText(v, 'Saran'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(message: _error!),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: _sentAt == null ? 'Kirim' : 'Perbarui',
                  loading: _sending,
                  onPressed: _submit,
                ),
                if (_sentAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Terakhir dikirim ${_formatDate(_sentAt!)}. '
                    'Mengirim lagi akan memperbarui jawaban Anda.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i bintang',
            iconSize: 40,
            onPressed: onChanged == null ? null : () => onChanged!(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value ? AppColors.yellow : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
