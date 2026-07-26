enum TimeframeFilter { semuaWaktu, hariIni, mingguIni, bulanIni, tahunIni }

extension TimeframeFilterLabel on TimeframeFilter {
  String get label {
    switch (this) {
      case TimeframeFilter.semuaWaktu:
        return 'Semua Waktu';
      case TimeframeFilter.hariIni:
        return 'Hari Ini';
      case TimeframeFilter.mingguIni:
        return 'Minggu Ini';
      case TimeframeFilter.bulanIni:
        return 'Bulan Ini';
      case TimeframeFilter.tahunIni:
        return 'Tahun Ini';
    }
  }
}

// Cek apakah tanggal transaksi cocok dengan timeframe, relatif terhadap
// `now` (waktu saat filter dievaluasi).
bool cocokTimeframe(dynamic rawDate, TimeframeFilter timeframe, DateTime now) {
  if (timeframe == TimeframeFilter.semuaWaktu) return true;

  final dateStr = rawDate?.toString() ?? '';
  if (dateStr.isEmpty) return false;

  DateTime tanggal;
  try {
    tanggal = DateTime.parse(dateStr);
  } catch (e) {
    // Data lama (pre-fix) yang bukan format ISO tidak bisa dipastikan
    // waktunya, jadi disembunyikan dari filter timeframe spesifik
    // (tetap muncul kalau timeframe-nya 'Semua Waktu').
    return false;
  }

  switch (timeframe) {
    case TimeframeFilter.hariIni:
      return tanggal.year == now.year && tanggal.month == now.month && tanggal.day == now.day;
    case TimeframeFilter.mingguIni:
      // Rolling 7 hari ke belakang dari `now`, bukan Senin-Minggu kalender.
      final batasAwal = now.subtract(const Duration(days: 7));
      return !tanggal.isBefore(batasAwal) && !tanggal.isAfter(now);
    case TimeframeFilter.bulanIni:
      return tanggal.year == now.year && tanggal.month == now.month;
    case TimeframeFilter.tahunIni:
      return tanggal.year == now.year;
    case TimeframeFilter.semuaWaktu:
      return true;
  }
}
