class SmartInputService {
  final Map<String, String> _smartBrainMap = {
    'rokok': 'Rokok',
    'sampoerna': 'Rokok',
    'sawit': 'Kebun Sawit',
    'panen': 'Kebun Sawit',
    'gotrade': 'Investasi',
    'saham': 'Investasi',
    'crypto': 'Investasi',
    'makan': 'Makanan',
    'warteg': 'Makanan',
    'bakso': 'Makanan',
  };

  final Map<String, bool> _dynamicKeywordMemory = {
    'bayar spp': false,
  };

  Map<String, String> get smartBrainMap => _smartBrainMap;

  void pelajariKataKunciBaru(String kataKunci, String kategori) {
    _smartBrainMap[kataKunci] = kategori;
  }

  void catatMemoriDinamis(String judul, bool apakahPemasukan) {
    _dynamicKeywordMemory[judul.toLowerCase()] = apakahPemasukan;
  }

  Map<String, dynamic> prosesTeksKeData(String rawText) {
    String teks = rawText.toLowerCase();
    bool apakahPemasukan = false;
    int nominalAkhir = 0;
    String judulTransaksi = rawText;

    // 1. Cek Memori Dinamis
    bool memoriDitemukan = false;
    for (var key in _dynamicKeywordMemory.keys) {
      if (teks.contains(key)) {
        apakahPemasukan = _dynamicKeywordMemory[key]!;
        memoriDitemukan = true;
        break;
      }
    }

    // 2. Cek Rumus Kata Kunci Pemasukan
    if (!memoriDitemukan) {
      List<String> keywordPemasukan = [
        'gaji', 'gajian', 'freelance', 'bonus', 'pemasukan', 'untung', 'profit', 'cuan', 'dapat', 'jual', 'dividend', 'uang', 'transfer dari', 'refund', 'reimburse', 'bunga', 'interest', 'royalti', 'komisi', 'insentif', 'reward', 'hadiah', 'cashback', 'investasi', 'invest', 'penjualan', 'jualan', 'bisnis', 'jasa', 'layanan', 'service', 'fee', 'honor', 'bayaran', 'sewa', 'crypto', 'saham', 'gotrade', 'pluang', 'trading', 'wd', 'withdraw', 'forex', 'sawit', 'panen', 'kebun', 'jeruk', 'mengajar', 'lpk', 'konten', 'youtube', 'tiktok', 'adsense', 'facebook', 'fb'
      ];
      for (var key in keywordPemasukan) {
        if (teks.contains(key)) {
          apakahPemasukan = true;
          break;
        }
      }
    }

    // 3. RegEx Parsing Angka (K, Jt, M)
    RegExp regExp = RegExp(r'(\d+)\s*([a-zA-Z]+)?');
    Iterable<RegExpMatch> matches = regExp.allMatches(teks);

    if (matches.isNotEmpty) {
      var match = matches.last;
      String? angkaStr = match.group(1);
      if (angkaStr != null) {
        int angkaMurni = int.tryParse(angkaStr) ?? 0;
        String satuan = (match.group(2) ?? '').toLowerCase();

        if (satuan.isNotEmpty) {
          if (RegExp(r'^(k|rb|rbu|ribu|rp)$').hasMatch(satuan)) {
            nominalAkhir = angkaMurni * 1000;
          } else if (RegExp(r'^(jt|jp|rj|jta|juta)$').hasMatch(satuan)) {
            nominalAkhir = angkaMurni * 1000000;
          } else if (RegExp(r'^(m|milyar|miliar)$').hasMatch(satuan)) {
            nominalAkhir = angkaMurni * 1000000000;
          } else {
            nominalAkhir = angkaMurni;
          }
        } else {
          nominalAkhir = angkaMurni < 1000 ? angkaMurni * 1000 : angkaMurni;
        }
        String matchedText = match.group(0) ?? '';
        judulTransaksi = rawText.replaceAll(matchedText, '').trim();
      }
    }

    if (judulTransaksi.isEmpty) {
      judulTransaksi = apakahPemasukan ? 'Pemasukan Otomatis' : 'Pengeluaran Otomatis';
    }

    // 4. Deteksi Kategori Berdasarkan Otak Cerdas
    String? kategoriTerdeteksi;
    String kataKunciTerpilih = judulTransaksi.toLowerCase().trim();
    List<String> kataList = kataKunciTerpilih.split(' ');

    for (var kata in kataList) {
      if (_smartBrainMap.containsKey(kata)) {
        kategoriTerdeteksi = _smartBrainMap[kata];
        break;
      }
    }

    if (kategoriTerdeteksi == null) {
      for (var entry in _smartBrainMap.entries) {
        if (kataKunciTerpilih.contains(entry.key)) {
          kategoriTerdeteksi = entry.value;
          break;
        }
      }
    }

    // Ekstrak kata cadangan untuk dipelajari jika tidak terdeteksi
    String kataDisarankan = kataList.length > 1 ? kataList[1] : kataList[0];
    if (kataList.length > 2 && (kataDisarankan == 'bayar' || kataDisarankan == 'beli')) {
      kataDisarankan = kataList[2];
    }

    return {
      'title': judulTransaksi,
      'amount': nominalAkhir,
      'isIncome': apakahPemasukan,
      'category': kategoriTerdeteksi,
      'suggestedKeyword': kataDisarankan,
    };
  }
}