import 'package:flutter/material.dart';

class DialogUtils {
  // Modal Input Transaksi Cerdas
  static void tampilkanModalInput({
    required BuildContext context,
    required String selectedBukuKas,
    required Function(String) onSubmitted,
  }) {
    final TextEditingController smartController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: smartController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Input di [$selectedBukuKas]...',
                  border: const UnderlineInputBorder(),
                ),
                onSubmitted: (value) {
                  Navigator.pop(context);
                  onSubmitted(value);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Dialog Belajar Kategori Baru
  static void tampilkanDialogBelajarKategori({
    required BuildContext context,
    required String judul,
    required List<String> masterKategori,
    required Function(String) onKategoriTerpilih,
    required Function(String) onKategoriBaruDibuat,
  }) {
    final TextEditingController kategoriBaruController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.psychology_alt, color: Colors.orange),
              SizedBox(width: 8),
              Text('Kategori Baru 🤔', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaksi "$judul" masuk kategori mana?', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: masterKategori.where((kat) => kat != 'Semua').map((kategori) {
                  return InkWell(
                    onTap: () {
                      onKategoriTerpilih(kategori);
                      Navigator.pop(context);
                    },
                    child: Chip(label: Text(kategori, style: const TextStyle(fontSize: 11))),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kategoriBaruController,
                      decoration: const InputDecoration(
                        hintText: 'Kategori baru...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () {
                      String katBaru = kategoriBaruController.text.trim();
                      if (katBaru.isNotEmpty) {
                        onKategoriBaruDibuat(katBaru);
                        Navigator.pop(context);
                      }
                    },
                    child: const Icon(Icons.check),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}