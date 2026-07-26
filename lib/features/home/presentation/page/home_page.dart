import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cash_teisou/core/utils/category_utils.dart'; // Import utility baru
import 'package:cash_teisou/core/utils/tanggal_utils.dart';
import 'package:cash_teisou/core/services/ad_service.dart';

enum ChartTimeframe { hari, minggu, bulan, tahun }

extension ChartTimeframeX on ChartTimeframe {
  String get chipLabel {
    switch (this) {
      case ChartTimeframe.hari:
        return '1H';
      case ChartTimeframe.minggu:
        return '1M';
      case ChartTimeframe.bulan:
        return '1B';
      case ChartTimeframe.tahun:
        return '1T';
    }
  }
}

const _namaHariPendek = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _namaBulanPendek = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

// Satu titik siap-plot di chart tren saldo: nilai saldo kumulatif + label
// sumbu-X (kosong kalau titik ini bukan awal grup kasar, jadi tidak digambar)
// + label detail untuk tooltip (selalu diisi).
class _ChartPoint {
  final int saldo;
  String labelSumbu;
  final String labelTooltip;

  _ChartPoint({required this.saldo, required this.labelSumbu, required this.labelTooltip});
}

void _terapkanThinningLabel(List<_ChartPoint> points, int setiapKe) {
  if (setiapKe <= 1) return;
  for (int i = 0; i < points.length; i++) {
    if (i % setiapKe != 0) points[i].labelSumbu = '';
  }
}

class HomePage extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final bool isSaldoHidden;
  final String userDisplayName;
  final String? userPhotoUrl;
  final List<String> daftarBukuKas;
  final String selectedBukuKas;
  final List<String> masterKategori;
  final VoidCallback onToggleSaldo;
  final Function(String) onTambahBukuKas;
  final Function(int) onHapusBukuKas;
  final Function(String) onPilihBukuKas;
  final bool isPremiumUser;

  const HomePage({
    super.key,
    required this.transactions,
    required this.isSaldoHidden,
    required this.userDisplayName,
    required this.userPhotoUrl,
    required this.daftarBukuKas,
    required this.selectedBukuKas,
    required this.masterKategori,
    required this.onToggleSaldo,
    required this.onTambahBukuKas,
    required this.onHapusBukuKas,
    required this.onPilihBukuKas,
    required this.isPremiumUser,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _activeCategoryFilter = 'Semua';
  ChartTimeframe _chartTimeframe = ChartTimeframe.minggu;

  final AdService _adService = AdService();
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _muatBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Status premium bisa berubah saat halaman ini masih terbuka (mis.
    // baru saja beres berlangganan). User premium tidak boleh sempat lihat
    // banner lama yang sudah kadung dimuat sebelum status ter-update.
    if (!oldWidget.isPremiumUser && widget.isPremiumUser) {
      _bannerAd?.dispose();
      _bannerAd = null;
      setState(() => _isBannerAdLoaded = false);
    } else if (oldWidget.isPremiumUser && !widget.isPremiumUser && _bannerAd == null) {
      _muatBannerAd();
    }
  }

  void _muatBannerAd() {
    _bannerAd = _adService.muatBannerAd(
      isPremiumUser: widget.isPremiumUser,
      onAdLoaded: (ad) {
        if (mounted) setState(() => _isBannerAdLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() => _isBannerAdLoaded = false);
      },
    );
  }

  List<Map<String, dynamic>> get _currentKasTransactions => widget.transactions
      .where((tx) => tx['bukuKas'] == widget.selectedBukuKas)
      .toList();

  int get _totalPemasukan => _currentKasTransactions.where((tx) => tx['isIncome'] == true).fold(0, (sum, tx) => sum + (tx['amount'] as int));
  int get _totalPengeluaran => _currentKasTransactions.where((tx) => tx['isIncome'] == false).fold(0, (sum, tx) => sum + (tx['amount'] as int));
  int get _totalSaldo => _totalPemasukan - _totalPengeluaran;

  String _formatRupiah(int angka) {
    return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Agregasi transaksi buku kas aktif jadi titik-titik siap-plot sesuai
  // timeframe terpilih. Saldo dihitung kumulatif sepanjang SELURUH riwayat
  // (bukan reset ke nol per-window) supaya perilakunya seperti chart
  // trading yang di-zoom, bukan grafik pertumbuhan dari nol.
  List<_ChartPoint> _buildChartPoints(ChartTimeframe timeframe, DateTime now) {
    final semuaTx = List<Map<String, dynamic>>.from(_currentKasTransactions)
      ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

    final tanggalEfektif = <DateTime>[];
    final saldoSetelahTx = <int>[];
    int runningSaldo = 0;
    for (var tx in semuaTx) {
      final amount = tx['amount'] as int;
      runningSaldo += (tx['isIncome'] == true) ? amount : -amount;
      saldoSetelahTx.add(runningSaldo);

      DateTime? tanggal;
      final rawDate = tx['date']?.toString() ?? '';
      if (rawDate.isNotEmpty) {
        try {
          tanggal = DateTime.parse(rawDate);
        } catch (_) {}
      }
      // Fallback ke timestamp (int, selalu ada) kalau 'date' tidak ISO valid
      // (data lama pre-fix) - transaksi lama tetap ikut diplot, tidak disembunyikan.
      tanggalEfektif.add(tanggal ?? DateTime.fromMillisecondsSinceEpoch(tx['timestamp'] as int));
    }

    if (timeframe == ChartTimeframe.hari) {
      final batasAwal = DateTime(now.year, now.month, now.day);
      final hasil = <_ChartPoint>[];
      for (int i = 0; i < semuaTx.length; i++) {
        final t = tanggalEfektif[i];
        if (t.isBefore(batasAwal) || t.isAfter(now)) continue;
        final jam = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        final judul = semuaTx[i]['title']?.toString() ?? 'Transaksi';
        hasil.add(_ChartPoint(saldo: saldoSetelahTx[i], labelSumbu: jam, labelTooltip: '$judul\n$jam'));
      }
      if (hasil.length > 6) _terapkanThinningLabel(hasil, (hasil.length / 6).ceil());
      return hasil;
    }

    final (Duration lebarBucket, int jumlahBucket) = switch (timeframe) {
      ChartTimeframe.minggu => (const Duration(hours: 2), 84), // 7 hari x 12 blok 2 jam
      ChartTimeframe.bulan => (const Duration(days: 1), 30),
      ChartTimeframe.tahun => (const Duration(days: 7), 53), // ~371 hari x 1 minggu
      ChartTimeframe.hari => throw StateError('unreachable'),
    };

    final batasAwal = now.subtract(lebarBucket * jumlahBucket);

    // Cari saldo tepat sebelum window mulai, jadi bucket pertama bisa
    // carry-forward dari saldo riwayat sebelumnya (bukan mulai dari 0).
    int saldoSebelumWindow = 0;
    for (int i = 0; i < semuaTx.length; i++) {
      if (tanggalEfektif[i].isBefore(batasAwal)) {
        saldoSebelumWindow = saldoSetelahTx[i];
      } else {
        break;
      }
    }

    final saldoBucket = List<int?>.filled(jumlahBucket, null);
    for (int i = 0; i < semuaTx.length; i++) {
      final t = tanggalEfektif[i];
      if (t.isBefore(batasAwal) || t.isAfter(now)) continue;
      int idx = t.difference(batasAwal).inMilliseconds ~/ lebarBucket.inMilliseconds;
      if (idx < 0) idx = 0;
      if (idx >= jumlahBucket) idx = jumlahBucket - 1;
      // Transaksi diproses ascending, jadi overwrite = saldo TERAKHIR di bucket ini.
      saldoBucket[idx] = saldoSetelahTx[i];
    }

    int saldoBerjalan = saldoSebelumWindow;
    DateTime? hariLabelTerakhir;
    int? bulanLabelTerakhir;
    final hasil = <_ChartPoint>[];

    for (int idx = 0; idx < jumlahBucket; idx++) {
      if (saldoBucket[idx] != null) saldoBerjalan = saldoBucket[idx]!;
      final waktu = batasAwal.add(lebarBucket * idx);

      String labelSumbu = '';
      String labelTooltip;
      switch (timeframe) {
        case ChartTimeframe.minggu:
          final hariBaru = hariLabelTerakhir == null ||
              waktu.year != hariLabelTerakhir.year ||
              waktu.month != hariLabelTerakhir.month ||
              waktu.day != hariLabelTerakhir.day;
          if (hariBaru) {
            labelSumbu = _namaHariPendek[waktu.weekday - 1];
            hariLabelTerakhir = waktu;
          }
          final jamAkhir = waktu.add(lebarBucket);
          labelTooltip = '${_namaHariPendek[waktu.weekday - 1]}, '
              '${waktu.hour.toString().padLeft(2, '0')}:00-'
              '${jamAkhir.hour.toString().padLeft(2, '0')}:00';
          break;
        case ChartTimeframe.bulan:
          final day = waktu.day.toString().padLeft(2, '0');
          final month = waktu.month.toString().padLeft(2, '0');
          labelSumbu = '$day/$month';
          labelTooltip = '$day/$month/${waktu.year} (Minggu ke-${(idx ~/ 7) + 1})';
          break;
        case ChartTimeframe.tahun:
          final bulanBaru = bulanLabelTerakhir == null || waktu.month != bulanLabelTerakhir;
          if (bulanBaru) {
            labelSumbu = _namaBulanPendek[waktu.month - 1];
            bulanLabelTerakhir = waktu.month;
          }
          labelTooltip = 'Minggu ke-${((waktu.day - 1) ~/ 7) + 1} - ${_namaBulanPendek[waktu.month - 1]}';
          break;
        case ChartTimeframe.hari:
          throw StateError('unreachable');
      }

      hasil.add(_ChartPoint(saldo: saldoBerjalan, labelSumbu: labelSumbu, labelTooltip: labelTooltip));
    }

    // Bucket harian (30 titik) kalau semua diberi label akan sesak,
    // jadi cuma tampilkan tiap ~4 hari.
    if (timeframe == ChartTimeframe.bulan) _terapkanThinningLabel(hasil, 4);

    return hasil;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _showFlexTime(BuildContext context) {
    final now = DateTime.now();
    final formatWaktu = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final formatTanggal = "${now.day}/${now.month}/${now.year}";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 40),
                ),
                const SizedBox(height: 12),
                const Text('TOTAL SALDO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20), letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Buku Kas: ${widget.selectedBukuKas}', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.grey, thickness: 0.5)),
                _buildRowStruk('Nominal Saldo', _formatRupiah(_totalSaldo), isBoldValue: true),
                _buildRowStruk('Tanggal', formatTanggal),
                _buildRowStruk('Waktu', '$formatWaktu WIB'),
                _buildRowStruk('Tipe Aplikasi', 'Cash Teisou Pro'),
                _buildRowStruk('Status ID', 'TX-${now.millisecondsSinceEpoch.toString().substring(7)}'),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.grey, thickness: 0.5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1B5E20)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.share, size: 18, color: Color(0xFF1B5E20)),
                        label: const Text('Share', style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowStruk(String label, String value, {bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal, color: isBoldValue ? const Color(0xFF1B5E20) : Colors.black87)),
        ],
      ),
    );
  }

  void _tampilkanModalFilterKategori() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Gabungkan kata 'Semua' dengan daftar master kategori yang ada
            List<String> semuaKategori = ['Semua', ...widget.masterKategori];
            
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Kategori Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: semuaKategori.map((kategori) {
                      bool isTerpilih = _activeCategoryFilter == kategori;
                      return ChoiceChip(
                        label: Text(kategori),
                        selected: isTerpilih,
                        selectedColor: const Color(0xFF1B5E20).withOpacity(0.2),
                        labelStyle: TextStyle(color: isTerpilih ? const Color(0xFF1B5E20) : Colors.black87, fontWeight: isTerpilih ? FontWeight.bold : FontWeight.normal),
                        onSelected: (selected) {
                          setState(() {
                            _activeCategoryFilter = kategori;
                          });
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _tampilkanModalBukuKas() {
    final TextEditingController bukuKasController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih & Atur Buku Kas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Ketuk nama buku kas untuk berpindah kas', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.daftarBukuKas.length,
                      itemBuilder: (context, index) {
                        String namaKas = widget.daftarBukuKas[index];
                        bool isAktif = widget.selectedBukuKas == namaKas;

                        return ListTile(
                          onTap: () {
                            widget.onPilihBukuKas(namaKas);
                            Navigator.pop(context);
                          },
                          leading: Icon(Icons.menu_book, color: isAktif ? Theme.of(context).primaryColor : Colors.grey),
                          title: Text(namaKas, style: TextStyle(fontWeight: isAktif ? FontWeight.bold : FontWeight.normal, color: isAktif ? Theme.of(context).primaryColor : Colors.black87)),
                          trailing: isAktif 
                              ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                              : (widget.daftarBukuKas.length > 1 
                                  ? IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        widget.onHapusBukuKas(index);
                                        setModalState(() {});
                                      },
                                    )
                                  : null),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Tambah Buku Kas Baru:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: bukuKasController, decoration: const InputDecoration(hintText: 'Misal: Uang Kas Kelas, DLL', border: OutlineInputBorder())),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                        onPressed: () {
                          if (bukuKasController.text.trim().isNotEmpty) {
                            widget.onTambahBukuKas(bukuKasController.text.trim());
                            bukuKasController.clear();
                            setModalState(() {});
                          }
                        },
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> finalFilteredTransactions = _currentKasTransactions.where((tx) {
      if (_activeCategoryFilter == 'Semua') return true;
      return tx['category'] == _activeCategoryFilter;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text('Buku Kas Aktif: ', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text(widget.selectedBukuKas, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSaldoCard(),
            const SizedBox(height: 16),
            _buildFlowSummaryRow(),
            const SizedBox(height: 24),
            _buildChartSection(),
            const SizedBox(height: 24),
            _buildRecentTransactionsSection(finalFilteredTransactions),
            if (_isBannerAdLoaded && _bannerAd != null) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFD54F),
              backgroundImage: widget.userPhotoUrl != null ? NetworkImage(widget.userPhotoUrl!) : null,
              child: widget.userPhotoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_getGreeting()},', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                Text(widget.userDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ],
        ),
        IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
      ],
    );
  }

  Widget _buildSaldoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL SALDO KAS', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => _showFlexTime(context),
                child: Text('Lihat Struk Saldo', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(widget.isSaldoHidden ? 'Rp ***' : _formatRupiah(_totalSaldo), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onToggleSaldo,
                child: Icon(widget.isSaldoHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white.withOpacity(0.7), size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.daftarBukuKas.length} Buku Kas Tersedia', style: const TextStyle(color: Colors.white, fontSize: 14)),
              GestureDetector(onTap: _tampilkanModalBukuKas, child: Text('Lihat dan Edit Buku Kas >', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSummaryRow() {
    return Row(
      children: [
        Expanded(child: _buildFlowCard(title: 'Pemasukan', amountStr: widget.isSaldoHidden ? 'Rp ***' : _formatRupiah(_totalPemasukan), icon: Icons.arrow_upward_rounded, iconColor: const Color(0xFF4CAF50))),
        const SizedBox(width: 12),
        Expanded(child: _buildFlowCard(title: 'Pengeluaran', amountStr: widget.isSaldoHidden ? 'Rp ***' : _formatRupiah(_totalPengeluaran), icon: Icons.arrow_downward_rounded, iconColor: const Color(0xFFD32F2F))),
      ],
    );
  }

  Widget _buildFlowCard({required String title, required String amountStr, required IconData icon, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 4),
              Text(amountStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeChip(ChartTimeframe tf) {
    bool isSelected = _chartTimeframe == tf;
    return GestureDetector(
      onTap: () => setState(() => _chartTimeframe = tf),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tf.chipLabel,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    if (_currentKasTransactions.isEmpty) {
      return const SizedBox.shrink();
    }
    final chartPoints = _buildChartPoints(_chartTimeframe, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tren Saldo ${widget.selectedBukuKas}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Row(children: ChartTimeframe.values.map(_buildTimeframeChip).toList()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          padding: const EdgeInsets.only(right: 16, top: 24, bottom: 4, left: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: chartPoints.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada transaksi pada rentang ini.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                )
              : LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.black.withOpacity(0.85),
                  tooltipRoundedRadius: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final idx = barSpot.x.toInt();
                      if (idx < 0 || idx >= chartPoints.length) {
                        return const LineTooltipItem('', TextStyle());
                      }
                      final titik = chartPoints[idx];
                      return LineTooltipItem(
                        '${titik.labelTooltip}\n',
                        const TextStyle(color: Colors.white70, fontSize: 11),
                        children: [
                          TextSpan(text: _formatRupiah(titik.saldo), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),

              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    getTitlesWidget: (value, meta) {
                      double nilaiAsli = value * 1000;
                      String teksNominal = '';

                      if (nilaiAsli >= 1000000) {
                        teksNominal = '${(nilaiAsli / 1000000).toStringAsFixed(1)}M';
                      } else if (nilaiAsli >= 1000) {
                        teksNominal = '${(nilaiAsli / 1000).toStringAsFixed(0)}k';
                      } else {
                        teksNominal = nilaiAsli.toStringAsFixed(0);
                      }

                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          teksNominal,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),

                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= chartPoints.length || chartPoints[index].labelSumbu.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        child: Text(
                          chartPoints[index].labelSumbu,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ),

              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (int i = 0; i < chartPoints.length; i++)
                      FlSpot(i.toDouble(), chartPoints[i].saldo / 1000),
                  ],
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    // Titik individual cuma masuk akal saat 1 titik = 1 transaksi asli (timeframe Hari).
                    // Di timeframe lain titiknya adalah bucket agregat, jadi garis polos lebih rapi.
                    show: _chartTimeframe == ChartTimeframe.hari,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 3.5,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.3),
                        Theme.of(context).primaryColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(List<Map<String, dynamic>> filteredList) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_activeCategoryFilter != 'Semua')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(_activeCategoryFilter, style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            TextButton(onPressed: _tampilkanModalFilterKategori, child: Text('Filter Kategori >', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
          ],
        ),
        filteredList.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Tidak ada transaksi untuk kategori "$_activeCategoryFilter".', style: const TextStyle(color: Colors.grey, fontSize: 13))),
              )
            : Column(
                children: filteredList.take(5).map((tx) {
                  return _buildTransactionItem(
                    title: tx['title'] as String,
                    category: (tx['category'] as String?) ?? 'Lainnya',
                    amount: widget.isSaldoHidden ? 'Rp ***' : (tx['isIncome'] as bool ? '+ ' : '- ') + _formatRupiah(tx['amount'] as int),
                    isIncome: tx['isIncome'] as bool,
                    icon: CategoryUtils.getIcon(tx['category'] ?? 'Lainnya'),
                    tanggalJam: TanggalUtils.formatTanggalJam(tx['date']),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildTransactionItem({required String title, required String category, required String amount, required bool isIncome, required IconData icon, required String tanggalJam}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Kategori: $category', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(tanggalJam, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F), fontSize: 14)),
        ],
      ),
    );
  }
}