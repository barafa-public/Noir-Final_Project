import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Satu menu di Beranda. Isi [builder] dengan halaman tujuan saat halamannya sudah
/// dibuat; selama null, menu menampilkan "belum tersedia".
class MenuEntry {
  const MenuEntry({required this.title, required this.icon, this.builder});

  final String title;
  final IconData icon;
  final WidgetBuilder? builder;
}

class MenuGroup {
  const MenuGroup({this.title, required this.items});

  final String? title;
  final List<MenuEntry> items;
}

class StatEntry {
  const StatEntry({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

/// Daftar menu per role. Ini HANYA mengatur tampilan; hak akses sebenarnya
/// harus dicek di server (Edge Function) pada setiap endpoint.
class RoleMenu {
  RoleMenu._();

  /// Role tak dikenal diperlakukan sebagai customer (menu paling terbatas).
  static List<MenuGroup> forRole(String role) {
    switch (role) {
      case 'manager':
        return _manager;
      case 'staff':
        return _staff;
      default:
        return _customer;
    }
  }

  static List<StatEntry> statsFor(String role) {
    switch (role) {
      case 'manager':
        return _managerStats;
      case 'staff':
        return _staffStats;
      default:
        return const [];
    }
  }

  static String greetingSubtitle(String role) {
    switch (role) {
      case 'manager':
        return 'Monitor dan kelola sistem dengan mudah';
      case 'staff':
        return 'Siap menyiapkan pesanan hari ini?';
      default:
        return 'Apa yang ingin Anda pesan hari ini?';
    }
  }

  // ---- Customer ----
  static const _customer = <MenuGroup>[
    MenuGroup(
      title: 'Menu Utama',
      items: [
        MenuEntry(title: 'Katalog Produk', icon: Icons.storefront_outlined),
        MenuEntry(title: 'Status Pesanan', icon: Icons.local_shipping_outlined),
        MenuEntry(title: 'Jarak ke Gudang', icon: Icons.place_outlined),
        MenuEntry(title: 'Konversi Waktu', icon: Icons.schedule_outlined),
        MenuEntry(title: 'Mini Game', icon: Icons.sports_esports_outlined),
      ],
    ),
  ];

  // ---- Staff Gudang ----
  static const _staff = <MenuGroup>[
    MenuGroup(
      title: 'Menu Utama',
      items: [
        MenuEntry(title: 'Daftar Kemas', icon: Icons.inventory_2_outlined),
        MenuEntry(
          title: 'Penerimaan Barang',
          icon: Icons.move_to_inbox_outlined,
        ),
        MenuEntry(title: 'Stok', icon: Icons.warehouse_outlined),
        MenuEntry(title: 'Konversi Waktu', icon: Icons.schedule_outlined),
        MenuEntry(title: 'Mini Game', icon: Icons.sports_esports_outlined),
      ],
    ),
  ];

  static const _staffStats = <StatEntry>[
    StatEntry(
      label: 'Perlu Dikemas',
      icon: Icons.inventory_2_outlined,
      color: AppColors.yellow,
    ),
    StatEntry(
      label: 'Sudah Dikemas',
      icon: Icons.check_circle_outline,
      color: AppColors.success,
    ),
  ];

  // ---- Manager ----
  static const _manager = <MenuGroup>[
    MenuGroup(
      title: 'Operasional',
      items: [
        MenuEntry(title: 'Monitoring Pesanan', icon: Icons.fact_check_outlined),
        MenuEntry(
          title: 'Pengadaan Barang',
          icon: Icons.shopping_basket_outlined,
        ),
        MenuEntry(title: 'Stok', icon: Icons.warehouse_outlined),
        MenuEntry(title: 'Monitoring Stok', icon: Icons.bar_chart_rounded),
      ],
    ),
    MenuGroup(
      title: 'Analisis',
      items: [
        MenuEntry(title: 'Rekomendasi AI', icon: Icons.auto_awesome_outlined),
        MenuEntry(title: 'Blockchain', icon: Icons.link_rounded),
      ],
    ),
    MenuGroup(
      title: 'Master Data',
      items: [
        MenuEntry(title: 'Produk', icon: Icons.category_outlined),
        MenuEntry(title: 'Supplier & Gudang', icon: Icons.business_outlined),
        MenuEntry(title: 'Akun Staff', icon: Icons.manage_accounts_outlined),
      ],
    ),
    MenuGroup(
      title: 'Alat',
      items: [
        MenuEntry(title: 'Konversi Mata Uang', icon: Icons.currency_exchange),
        MenuEntry(title: 'Konversi Waktu', icon: Icons.schedule_outlined),
        MenuEntry(title: 'Supplier Terdekat', icon: Icons.near_me_outlined),
        MenuEntry(title: 'Mini Game', icon: Icons.sports_esports_outlined),
      ],
    ),
  ];

  static const _managerStats = <StatEntry>[
    StatEntry(
      label: 'Total Stok',
      icon: Icons.inventory_2_outlined,
      color: AppColors.yellow,
    ),
    StatEntry(
      label: 'Pesanan Masuk',
      icon: Icons.assignment_outlined,
      color: AppColors.white,
    ),
    StatEntry(
      label: 'Disetujui',
      icon: Icons.check_circle_outline,
      color: AppColors.success,
    ),
    StatEntry(
      label: 'Ditolak',
      icon: Icons.cancel_outlined,
      color: AppColors.error,
    ),
  ];
}
