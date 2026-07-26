import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cash_teisou/core/utils/timeframe_utils.dart';
import 'package:cash_teisou/core/services/export_excel_service.dart';
import 'package:cash_teisou/core/services/ad_service.dart';

void tampilkanModalExportExcel({
  required BuildContext pageContext,
  required List<Map<String, dynamic>> transactions,
  required List<String> daftarBukuKas,
  required bool isPremiumUser,
}) {
  int tahap = 1;
  TimeframeFilter rentang = TimeframeFilter.semuaWaktu;
  Set<String> bukuKasTerpilih = {};
  bool gabungSheet = true;
  bool sedangExport = false;

  showModalBottomSheet(
    context: pageContext,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (modalContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Widget isiTahap;
          if (tahap == 1) {
            isiTahap = _buildTahapRentang(
              context: context,
              rentang: rentang,
              onPilih: (tf) => setModalState(() => rentang = tf),
              onLanjut: () => setModalState(() => tahap = 2),
            );
          } else {
            isiTahap = _buildTahapBukuKas(
              context: context,
              daftarBukuKas: daftarBukuKas,
              bukuKasTerpilih: bukuKasTerpilih,
              gabungSheet: gabungSheet,
              sedangExport: sedangExport,
              onToggleSemua: (pilihSemua) => setModalState(() {
                bukuKasTerpilih = pilihSemua ? daftarBukuKas.toSet() : {};
              }),
              onToggleSatu: (nama, dipilih) => setModalState(() {
                if (dipilih) {
                  bukuKasTerpilih.add(nama);
                } else {
                  bukuKasTerpilih.remove(nama);
                }
              }),
              onGabungChanged: (val) => setModalState(() => gabungSheet = val),
              onKembali: () => setModalState(() => tahap = 1),
              onExport: () async {
                setModalState(() => sedangExport = true);
                try {
                  final service = ExportExcelService();
                  final bytes = service.buatFileExcel(
                    semuaTransaksi: transactions,
                    rentang: rentang,
                    bukuKasTerpilih: bukuKasTerpilih.toList(),
                    gabungSheet: gabungSheet,
                  );
                  final namaFile = service.buatNamaFile(rentang);
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/$namaFile');
                  await file.writeAsBytes(bytes);

                  if (modalContext.mounted) Navigator.pop(modalContext);
                  AdService().showInterstitialSegera(isPremiumUser: isPremiumUser);
                  await Share.shareXFiles([XFile(file.path)], text: 'Export transaksi Cash Teisou');
                } catch (e) {
                  setModalState(() => sedangExport = false);
                  if (pageContext.mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(content: Text('Gagal membuat file Excel: $e')),
                    );
                  }
                }
              },
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24, left: 20, right: 20,
            ),
            child: isiTahap,
          );
        },
      );
    },
  );
}

Widget _buildTahapRentang({
  required BuildContext context,
  required TimeframeFilter rentang,
  required void Function(TimeframeFilter) onPilih,
  required VoidCallback onLanjut,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Export Transaksi (Excel)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
      const SizedBox(height: 4),
      Text('Langkah 1/2 - Pilih rentang waktu', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: TimeframeFilter.values.map((tf) {
          bool isSelected = rentang == tf;
          return ChoiceChip(
            label: Text(tf.label),
            selected: isSelected,
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => onPilih(tf),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: onLanjut,
          child: const Text('Lanjut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}

Widget _buildTahapBukuKas({
  required BuildContext context,
  required List<String> daftarBukuKas,
  required Set<String> bukuKasTerpilih,
  required bool gabungSheet,
  required bool sedangExport,
  required void Function(bool) onToggleSemua,
  required void Function(String, bool) onToggleSatu,
  required void Function(bool) onGabungChanged,
  required VoidCallback onKembali,
  required VoidCallback onExport,
}) {
  bool semuaTerpilih = daftarBukuKas.isNotEmpty && bukuKasTerpilih.length == daftarBukuKas.length;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: sedangExport ? null : onKembali,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Langkah 2/2 - Pilih buku kas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Semua Buku Kas', style: TextStyle(fontWeight: FontWeight.bold)),
        value: semuaTerpilih,
        onChanged: sedangExport ? null : (val) => onToggleSemua(val ?? false),
      ),
      const Divider(height: 1),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView(
          shrinkWrap: true,
          children: daftarBukuKas.map((nama) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(nama),
              value: bukuKasTerpilih.contains(nama),
              onChanged: sedangExport ? null : (val) => onToggleSatu(nama, val ?? false),
            );
          }).toList(),
        ),
      ),
      if (bukuKasTerpilih.length > 1) ...[
        const SizedBox(height: 8),
        const Text('Format Sheet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Gabung jadi satu sheet'),
          value: true,
          groupValue: gabungSheet,
          onChanged: sedangExport ? null : (val) => onGabungChanged(val ?? true),
        ),
        RadioListTile<bool>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pisah per Buku Kas'),
          value: false,
          groupValue: gabungSheet,
          onChanged: sedangExport ? null : (val) => onGabungChanged(val ?? true),
        ),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: (bukuKasTerpilih.isEmpty || sedangExport) ? null : onExport,
          child: sedangExport
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
