import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../utils/role_menu.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/noir_logo.dart';
import '../../widgets/stat_card.dart';

/// Beranda: header, kartu sapaan, ringkasan (Manager/Staff), dan menu sesuai role.
/// Isi tiap menu belum dibuat: menu tanpa `builder` menampilkan "belum tersedia".
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user});

  final UserModel user;

  bool get _isCustomer => user.role == 'customer';

  void _comingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name belum tersedia')));
  }

  void _open(BuildContext context, MenuEntry item) {
    final builder = item.builder;
    if (builder == null) {
      _comingSoon(context, item.title);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final groups = RoleMenu.forRole(user.role);
    final stats = RoleMenu.statsFor(user.role);
    final name = (user.nama != null && user.nama!.trim().isNotEmpty)
        ? user.nama!.trim()
        : user.username;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const NoirLogo(width: 96),
              const Spacer(),
              IconButton(
                tooltip: 'Notifikasi',
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.white,
                ),
                onPressed: () => _comingSoon(context, 'Notifikasi'),
              ),
              if (_isCustomer)
                IconButton(
                  tooltip: 'Keranjang',
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.white,
                  ),
                  onPressed: () => _comingSoon(context, 'Keranjang'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _GreetingCard(
            name: name,
            subtitle: RoleMenu.greetingSubtitle(user.role),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('Ringkasan'),
            const SizedBox(height: 12),
            _StatsGrid(stats: stats),
          ],
          for (final group in groups) ...[
            const SizedBox(height: 24),
            if (group.title != null) ...[
              _SectionTitle(group.title!),
              const SizedBox(height: 12),
            ],
            for (final item in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MenuCard(
                  title: item.title,
                  icon: item.icon,
                  onTap: () => _open(context, item),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.yellow)),
          const Positioned(top: -50, right: -40, child: _Dot(size: 150)),
          const Positioned(bottom: -60, left: -30, child: _Dot(size: 120)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: AppColors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Halo, $name!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.8),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.black.withValues(alpha: 0.07),
      ),
    );
  }
}

/// Statistik dalam baris berisi dua kartu. Nilai '-' sementara: belum ada data
/// dari server (akan diisi lewat report_service).
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<StatEntry> stats;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      final left = stats[i];
      final right = i + 1 < stats.length ? stats[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < stats.length ? 12 : 0),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: left.icon,
                  label: left.label,
                  value: '-',
                  color: left.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : StatCard(
                        icon: right.icon,
                        label: right.label,
                        value: '-',
                        color: right.color,
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
