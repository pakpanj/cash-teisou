class TanggalUtils {
  // Parse field 'date' (ISO 8601). Null kalau kosong/bukan format ISO
  // (data lama pre-fix, lihat database_service.dart).
  static DateTime? _parseAtauNull(dynamic rawDate) {
    final dateStr = rawDate?.toString() ?? '';
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  // Format "dd/MM/yyyy". Fallback ke string mentah kalau tidak bisa
  // di-parse (data lama non-ISO seperti "Hari Ini").
  static String formatTanggal(dynamic rawDate) {
    final parsed = _parseAtauNull(rawDate);
    if (parsed == null) {
      final dateStr = rawDate?.toString() ?? '';
      return dateStr.isEmpty ? '-' : dateStr;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  // Format "dd/MM/yyyy • HH:mm".
  static String formatTanggalJam(dynamic rawDate) {
    final parsed = _parseAtauNull(rawDate);
    if (parsed == null) {
      final dateStr = rawDate?.toString() ?? '';
      return dateStr.isEmpty ? '-' : dateStr;
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year} • $hour:$minute';
  }
}
