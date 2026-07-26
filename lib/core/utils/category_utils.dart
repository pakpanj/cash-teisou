import 'package:flutter/material.dart';

class CategoryUtils {
  // 1. Master kategori default aplikasi
  // FIX: 'Semua' dihapus dari sini. 'Semua' bukan kategori transaksi asli,
  // melainkan opsi filter UI. Sebelumnya home_page.dart menambahkan 'Semua'
  // lagi di depan list ini -> menyebabkan chip "Semua" tampil dobel.
  static final List<String> defaultKategori = [
    'Rokok',
    'Makanan',
    'Investasi',
    'Kebun Sawit',
    'Lainnya'
  ];

  // 2. Mapping ikon berdasarkan nama kategori
  static IconData getIcon(String category) {
    switch (category) {
      case 'Rokok':
        return Icons.smoking_rooms;
      case 'Makanan':
        return Icons.fastfood;
      case 'Investasi':
        return Icons.trending_up;
      case 'Kebun Sawit':
        return Icons.nature;
      case 'Lainnya':
      default:
        return Icons.receipt_long;
    }
  }
}
