import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/staff_model.dart';
import '../../services/api_exception.dart';
import '../../services/staff_service.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_view.dart';
import 'user_form_page.dart';

/// Daftar akun Staff Gudang (khusus Manager): tambah, ubah, aktifkan/nonaktifkan.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<StaffModel> _staff = const [];
  bool _loading = true;
  String? _error;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await StaffService.instance.list();
      if (!mounted) return;
      setState(() {
        _staff = list;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _openForm([StaffModel? staff]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => UserFormPage(staff: staff)),
    );
    if (changed == true && mounted) await _load();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(StaffModel staff, bool value) async {
    if (_busyIds.contains(staff.id)) return;

    if (!value) {
      final ok = await showConfirmDialog(
        context,
        title: 'Nonaktifkan akun?',
        message:
            '${staff.displayName} akan keluar dari semua perangkat dan tidak '
            'bisa masuk sampai diaktifkan lagi.',
        confirmLabel: 'Nonaktifkan',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busyIds.add(staff.id));
    try {
      final updated = await StaffService.instance.update(
        staff.id,
        isActive: value,
      );
      if (!mounted) return;
      setState(() {
        _staff = [for (final s in _staff) s.id == updated.id ? updated : s];
      });
      _snack(value ? 'Akun diaktifkan.' : 'Akun dinonaktifkan.');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Terjadi kesalahan tak terduga.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(staff.id));
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
      );
    }

    final Widget content;
    if (_error != null && _staff.isEmpty) {
      content = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AuthErrorBox(message: _error!),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _retry,
              child: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    } else if (_staff.isEmpty) {
      content = ListView(
        children: const [
          SizedBox(
            height: 420,
            child: EmptyView(
              icon: Icons.badge_outlined,
              title: 'Belum ada akun staff',
              message: 'Tekan "Tambah Staff" untuk membuat akun pertama.',
            ),
          ),
        ],
      );
    } else {
      content = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _staff.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final staff = _staff[index];
          return _StaffTile(
            staff: staff,
            busy: _busyIds.contains(staff.id),
            onTap: () => _openForm(staff),
            onToggle: (value) => _toggle(staff, value),
          );
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.black,
      backgroundColor: AppColors.yellow,
      onRefresh: _load,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun Staff'),
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.black,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Staff'),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.staff,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  final StaffModel staff;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final initial = String.fromCharCode(staff.displayName.runes.first)
        .toUpperCase();
    final statusColor = staff.isActive ? AppColors.success : AppColors.error;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: staff.isActive
                    ? AppColors.yellow
                    : AppColors.border,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: staff.isActive
                        ? AppColors.black
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '@${staff.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.isActive ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.yellow,
                  ),
                )
              else
                Switch(value: staff.isActive, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
