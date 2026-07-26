import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'theme_switcher_page.dart';
import 'panduan_page.dart';
import 'export_excel_sheet.dart';
import 'backup_page.dart';
import 'langganan_page.dart';

class SettingPage extends StatefulWidget {
  final String userDisplayName;
  final bool isLoggedInGoogle;
  final String? userPhotoUrl;
  final String? currentUserId;
  final bool isPremiumUser;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGoogleSignOut;
  final VoidCallback onResetTransaksi;
  final VoidCallback onResetKasAktif;
  final String selectedBukuKas;
  final Future<void> Function(String message, String appVersion) onKirimFeedback;
  final Future<void> Function(String namaBukuKas) onSetelahRestoreBackup;
  final List<Map<String, dynamic>> transactions;
  final List<String> daftarBukuKas;

  const SettingPage({
    super.key,
    required this.userDisplayName,
    required this.isLoggedInGoogle,
    required this.userPhotoUrl,
    required this.currentUserId,
    required this.isPremiumUser,
    required this.onGoogleSignIn,
    required this.onGoogleSignOut,
    required this.onResetTransaksi,
    required this.onResetKasAktif,
    required this.selectedBukuKas,
    required this.onKirimFeedback,
    required this.onSetelahRestoreBackup,
    required this.transactions,
    required this.daftarBukuKas,
  });

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _muatPackageInfo();
  }

  Future<void> _muatPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  String _formatVersi() {
    final info = _packageInfo;
    if (info == null) return 'Memuat versi...';
    return 'Versi ${info.version} (build ${info.buildNumber})';
  }

  String _appVersionUntukData() {
    final info = _packageInfo;
    if (info == null) return 'unknown';
    return '${info.version}+${info.buildNumber}';
  }

  void _tampilkanModalFeedback(BuildContext pageContext) {
    final TextEditingController feedbackController = TextEditingController();
    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool bisaKirim = feedbackController.text.trim().isNotEmpty;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 20, right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Berikan Saran & Masukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Ceritakan saran atau masalah yang kamu temui...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: bisaKirim
                          ? () async {
                              final pesan = feedbackController.text.trim();
                              Navigator.pop(context);
                              await widget.onKirimFeedback(pesan, _appVersionUntukData());
                              if (pageContext.mounted) {
                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  const SnackBar(content: Text('Terima kasih atas masukannya!')),
                                );
                              }
                            }
                          : null,
                      child: const Text('Kirim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
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

  void _konfirmasiReset({
    required BuildContext context,
    required String namaTarget,
    required int jumlahTransaksi,
    required VoidCallback onKonfirmasi,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Reset'),
          content: Text(
            'Yakin mau reset $namaTarget? $jumlahTransaksi transaksi akan dihapus dari tampilan, '
            'tapi otomatis di-backup selama 30 hari. Kamu bisa restore lewat menu Backup kalau berubah pikiran.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
              onPressed: () {
                Navigator.pop(context);
                onKonfirmasi();
              },
              child: const Text('Ya, Reset', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _bukaBackupPage(BuildContext context) {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum terhubung ke server, coba beberapa saat lagi.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupPage(
          userId: widget.currentUserId!,
          onSetelahRestore: widget.onSetelahRestoreBackup,
          isPremiumUser: widget.isPremiumUser,
        ),
      ),
    );
  }

  void _bukaLanggananPage(BuildContext context) {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum terhubung ke server, coba beberapa saat lagi.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LanggananPage(userId: widget.currentUserId!)),
    );
  }

  void _tampilkanDialogInformasiAplikasi(BuildContext pageContext) {
    showDialog(
      context: pageContext,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cash Teisou', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatVersi(), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),
              const Text(
                'Pencatat keuangan pribadi yang ngerti bahasa kamu - tinggal ketik, dia yang urus sisanya.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text('Dibuat oleh: Teisou Sensei', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _tampilkanModalFeedback(pageContext);
              },
              child: const Text('Ada masukan?'),
            ),
            TextButton(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Cash Teisou',
                  applicationVersion: _packageInfo == null ? null : '${_packageInfo!.version} (build ${_packageInfo!.buildNumber})',
                );
              },
              child: const Text('Lihat Lisensi Open Source'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: sebelumnya ditebak dari string userDisplayName (rapuh kalau nama
    // Google user kebetulan sama dengan default anonim). Sekarang dikirim
    // langsung dari MainScreen berdasarkan status auth yang sebenarnya.
    bool isLoggedWithGoogle = widget.isLoggedInGoogle;
    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuSectionTitle('Akun'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: isLoggedWithGoogle && widget.userPhotoUrl != null
                  ? CircleAvatar(backgroundImage: NetworkImage(widget.userPhotoUrl!))
                  : Icon(Icons.account_circle_outlined, color: isLoggedWithGoogle ? Colors.blue : Colors.grey),
              title: const Text('Informasi Akun', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(isLoggedWithGoogle ? 'Terhubung: ${widget.userDisplayName}' : 'Belum terhubung ke Google'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLoggedWithGoogle ? Colors.red[800] : primaryColor,
                ),
                onPressed: isLoggedWithGoogle ? widget.onGoogleSignOut : widget.onGoogleSignIn,
                child: Text(isLoggedWithGoogle ? 'Keluar' : 'Login Google', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuSectionTitle('Aplikasi & Fitur'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingTile(Icons.star_outline, 'Langganan', 'Aktifkan fitur premium Teisou App', context, () => _bukaLanggananPage(context)),
                const Divider(height: 1),

                _buildSettingTile(Icons.palette_outlined, 'Ganti Tema', 'Kustomisasi warna dasar aplikasi', context, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ThemeSwitcherPage(
                      isPremiumUser: widget.isPremiumUser,
                      userId: widget.currentUserId,
                    )),
                  );
                }),
                const Divider(height: 1),
                _buildSettingTile(Icons.file_download_outlined, 'Download Transaksi (Excel)', 'Ekspor data kas ke format .xlsx', context, () {
                  tampilkanModalExportExcel(
                    pageContext: context,
                    transactions: widget.transactions,
                    daftarBukuKas: widget.daftarBukuKas,
                    isPremiumUser: widget.isPremiumUser,
                  );
                }),
                const Divider(height: 1),
                _buildSettingTile(Icons.inventory_2_outlined, 'Riwayat Backup', 'Lihat & restore data yang pernah di-reset', context, () => _bukaBackupPage(context)),
                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.layers_clear_outlined, color: Colors.orange),
                  title: Text('Reset Kas [${widget.selectedBukuKas}]', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.orange)),
                  subtitle: Text('Hapus riwayat khusus di buku kas ${widget.selectedBukuKas}'),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  onTap: () => _konfirmasiReset(
                    context: context,
                    namaTarget: 'buku kas "${widget.selectedBukuKas}"',
                    jumlahTransaksi: widget.transactions.where((tx) => tx['bukuKas'] == widget.selectedBukuKas).length,
                    onKonfirmasi: widget.onResetKasAktif,
                  ),
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Reset Semua Transaksi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red)),
                  subtitle: const Text('Menghapus seluruh riwayat rekaman kas secara permanen'),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                  onTap: () => _konfirmasiReset(
                    context: context,
                    namaTarget: 'semua data',
                    jumlahTransaksi: widget.transactions.length,
                    onKonfirmasi: widget.onResetTransaksi,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuSectionTitle('Dukungan'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingTile(Icons.menu_book_outlined, 'Panduan Penggunaan Aplikasi', 'Cara pakai Smart Cash Input', context, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PanduanPage()));
                }),
                const Divider(height: 1),
                _buildSettingTile(Icons.info_outline, 'Informasi Aplikasi', _formatVersi(), context, () => _tampilkanDialogInformasiAplikasi(context)),
                const Divider(height: 1),
                _buildSettingTile(Icons.rate_review_outlined, 'Berikan Saran & Masukan', 'Kirim feedback langsung ke tim', context, () => _tampilkanModalFeedback(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle, BuildContext context, VoidCallback? customAction) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: customAction ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menu "$title" berhasil dipicu! Fitur ini akan aktif pada update selanjutnya.')),
        );
      },
    );
  }
}
