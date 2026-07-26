import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:cash_teisou/core/utils/timeframe_utils.dart';

String _pad2(int v) => v.toString().padLeft(2, '0');

CellStyle _headerStyle() => CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('FF1E8E4F'),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

CellStyle _dataStyle() => CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

CellStyle _nominalStyle() => CellStyle(
      numberFormat: NumFormat.standard_3, // "#,##0"
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

void _tulisHeaderBaris(Sheet sheet, int rowIndex, List<String> judul) {
  for (int col = 0; col < judul.length; col++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      TextCellValue(judul[col]),
      cellStyle: _headerStyle(),
    );
  }
}

// Sheet.setColumnAutoFit menandai kolom untuk auto-fit saat file dibuka di
// Excel/software sejenis (bukan hitung lebar piksel manual).
void _autoFitKolom(Sheet sheet, int jumlahKolom) {
  for (int col = 0; col < jumlahKolom; col++) {
    sheet.setColumnAutoFit(col);
  }
}

// Tentukan tanggal efektif transaksi: 'date' ISO 8601, fallback ke
// 'timestamp' (int, selalu ada) kalau 'date' tidak valid/kosong (data lama
// pre-fix) - supaya transaksi lama tetap ikut ter-export, tidak disembunyikan.
DateTime _tanggalEfektif(Map<String, dynamic> tx) {
  final rawDate = tx['date']?.toString() ?? '';
  if (rawDate.isNotEmpty) {
    try {
      return DateTime.parse(rawDate);
    } catch (_) {}
  }
  return DateTime.fromMillisecondsSinceEpoch(tx['timestamp'] as int);
}

String _namaSheetUnik(String namaDiinginkan, Set<String> sudahDipakai) {
  String bersih = namaDiinginkan.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-');
  if (bersih.length > 31) bersih = bersih.substring(0, 31);

  String kandidat = bersih;
  int suffix = 2;
  while (sudahDipakai.contains(kandidat)) {
    final tambahan = ' ($suffix)';
    final batasDasar = 31 - tambahan.length;
    final dasar = bersih.length > batasDasar ? bersih.substring(0, batasDasar) : bersih;
    kandidat = '$dasar$tambahan';
    suffix++;
  }
  sudahDipakai.add(kandidat);
  return kandidat;
}

class ExportExcelService {
  // NOTE: package `excel` (v4.0.6) tidak punya API freeze-pane, jadi header
  // row TIDAK di-freeze - ini keterbatasan library, bukan terlewat.
  Uint8List buatFileExcel({
    required List<Map<String, dynamic>> semuaTransaksi,
    required TimeframeFilter rentang,
    required List<String> bukuKasTerpilih,
    required bool gabungSheet,
  }) {
    final now = DateTime.now();

    final filtered = semuaTransaksi
        .where((tx) => bukuKasTerpilih.contains(tx['bukuKas']) && cocokTimeframe(tx['date'], rentang, now))
        .toList()
      ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

    final excel = Excel.createExcel();
    final namaSheetDefault = excel.getDefaultSheet()!;
    excel.rename(namaSheetDefault, 'Ringkasan');
    _tulisRingkasan(excel['Ringkasan'], filtered, rentang, bukuKasTerpilih, now);

    final gabung = gabungSheet || bukuKasTerpilih.length <= 1;
    if (gabung) {
      _tulisDetail(excel['Detail Transaksi'], filtered);
    } else {
      final namaSheetTerpakai = <String>{};
      for (final namaKas in bukuKasTerpilih) {
        final txKasIni = filtered.where((tx) => tx['bukuKas'] == namaKas).toList();
        if (txKasIni.isEmpty) continue;
        final namaSheet = _namaSheetUnik('Detail - $namaKas', namaSheetTerpakai);
        _tulisDetail(excel[namaSheet], txKasIni);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Gagal encode file Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  String buatNamaFile(TimeframeFilter rentang) {
    final now = DateTime.now();
    final tanggal = '${now.year}${_pad2(now.month)}${_pad2(now.day)}_${_pad2(now.hour)}${_pad2(now.minute)}';
    final rentangLabel = rentang.label.replaceAll(' ', '');
    return 'CashTeisou_Export_${rentangLabel}_$tanggal.xlsx';
  }

  void _tulisRingkasan(
    Sheet sheet,
    List<Map<String, dynamic>> filtered,
    TimeframeFilter rentang,
    List<String> bukuKasTerpilih,
    DateTime now,
  ) {
    int totalPemasukan = 0;
    int totalPengeluaran = 0;
    for (final tx in filtered) {
      final amount = tx['amount'] as int;
      if (tx['isIncome'] == true) {
        totalPemasukan += amount;
      } else {
        totalPengeluaran += amount;
      }
    }

    int row = 0;

    void tulisJudul(String label) {
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), TextCellValue(label),
          cellStyle: CellStyle(bold: true));
      row++;
    }

    void tulisPasangan(String label, String nilai) {
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), TextCellValue(label));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), TextCellValue(nilai));
      row++;
    }

    void tulisPasanganNominal(String label, int nilai) {
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), TextCellValue(label));
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), IntCellValue(nilai),
          cellStyle: _nominalStyle());
      row++;
    }

    tulisJudul('Cash Teisou - Laporan Ekspor Transaksi');
    row++;
    tulisPasangan('Tanggal Export', '${_pad2(now.day)}/${_pad2(now.month)}/${now.year} ${_pad2(now.hour)}:${_pad2(now.minute)}');
    tulisPasangan('Rentang Waktu', rentang.label);
    row++;
    tulisPasanganNominal('Total Pemasukan', totalPemasukan);
    tulisPasanganNominal('Total Pengeluaran', totalPengeluaran);
    tulisPasanganNominal('Saldo Akhir', totalPemasukan - totalPengeluaran);
    row++;

    tulisJudul('Breakdown per Buku Kas');
    _tulisHeaderBaris(sheet, row, ['Buku Kas', 'Pemasukan', 'Pengeluaran', 'Saldo']);
    row++;
    for (final namaKas in bukuKasTerpilih) {
      int pemasukanKas = 0;
      int pengeluaranKas = 0;
      for (final tx in filtered.where((t) => t['bukuKas'] == namaKas)) {
        final amount = tx['amount'] as int;
        if (tx['isIncome'] == true) {
          pemasukanKas += amount;
        } else {
          pengeluaranKas += amount;
        }
      }
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), TextCellValue(namaKas), cellStyle: _dataStyle());
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), IntCellValue(pemasukanKas), cellStyle: _nominalStyle());
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row), IntCellValue(pengeluaranKas), cellStyle: _nominalStyle());
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row), IntCellValue(pemasukanKas - pengeluaranKas), cellStyle: _nominalStyle());
      row++;
    }
    row++;

    tulisJudul('Breakdown per Kategori Pengeluaran');
    _tulisHeaderBaris(sheet, row, ['Kategori', 'Total Pengeluaran']);
    row++;
    final Map<String, int> perKategori = {};
    for (final tx in filtered.where((t) => t['isIncome'] == false)) {
      final kategori = (tx['category'] as String?) ?? 'Lainnya';
      perKategori[kategori] = (perKategori[kategori] ?? 0) + (tx['amount'] as int);
    }
    for (final entry in perKategori.entries) {
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row), TextCellValue(entry.key), cellStyle: _dataStyle());
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row), IntCellValue(entry.value), cellStyle: _nominalStyle());
      row++;
    }

    _autoFitKolom(sheet, 4);
  }

  void _tulisDetail(Sheet sheet, List<Map<String, dynamic>> transaksi) {
    const judulKolom = [
      'No', 'Tanggal', 'Jam', 'Buku Kas', 'Kategori', 'Judul', 'Jenis', 'Pemasukan', 'Pengeluaran', 'Saldo Berjalan',
    ];
    _tulisHeaderBaris(sheet, 0, judulKolom);

    int saldoBerjalan = 0;
    for (int i = 0; i < transaksi.length; i++) {
      final tx = transaksi[i];
      final rowIndex = i + 1;
      final amount = tx['amount'] as int;
      final isIncome = tx['isIncome'] == true;
      saldoBerjalan += isIncome ? amount : -amount;

      final tanggal = _tanggalEfektif(tx);
      final tanggalStr = '${_pad2(tanggal.day)}/${_pad2(tanggal.month)}/${tanggal.year}';
      final jamStr = '${_pad2(tanggal.hour)}:${_pad2(tanggal.minute)}';

      final nilai = <CellValue?>[
        IntCellValue(rowIndex),
        TextCellValue(tanggalStr),
        TextCellValue(jamStr),
        TextCellValue((tx['bukuKas'] as String?) ?? '-'),
        TextCellValue((tx['category'] as String?) ?? 'Lainnya'),
        TextCellValue((tx['title'] as String?) ?? '-'),
        TextCellValue(isIncome ? 'Masuk' : 'Keluar'),
        isIncome ? IntCellValue(amount) : null,
        isIncome ? null : IntCellValue(amount),
        IntCellValue(saldoBerjalan),
      ];

      for (int col = 0; col < nilai.length; col++) {
        final isNominalCol = col == 7 || col == 8 || col == 9;
        sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          nilai[col],
          cellStyle: isNominalCol ? _nominalStyle() : _dataStyle(),
        );
      }
    }

    _autoFitKolom(sheet, judulKolom.length);
  }
}
