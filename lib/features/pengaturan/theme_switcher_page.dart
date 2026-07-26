import 'package:flutter/material.dart';
import 'package:cash_teisou/core/constants/colors.dart';
import 'package:cash_teisou/features/pengaturan/langganan_page.dart';

class ThemeSwitcherPage extends StatefulWidget {
  final bool isPremiumUser;
  final String? userId;

  const ThemeSwitcherPage({super.key, required this.isPremiumUser, required this.userId});

  @override
  State<ThemeSwitcherPage> createState() => _ThemeSwitcherPageState();
}

class _ThemeSwitcherPageState extends State<ThemeSwitcherPage> {
  late AppThemeMode _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = globalThemeNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganti Tema', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16, left: 4),
                  child: Text(
                    'Aktif',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 0.6,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildThemeCard(
                      mode: AppThemeMode.teisouHijau,
                      title: 'Green Jelly',
                      subtitle: 'Hijau Jelly',
                      previewBg: const Color.fromARGB(255, 2, 184, 14),
                      cardBg: const Color(0xFFF1F8E9),
                    ),
                    _buildThemeCard(
                      mode: AppThemeMode.darkMode,
                      title: 'Dark Mode',
                      subtitle: 'Mode Gelap',
                      previewBg: const Color(0xFF1E222B),
                      cardBg: const Color(0xFF252A34),
                    ),
                    _buildThemeCard(
                      mode: AppThemeMode.oceanBlue,
                      title: 'Ocean Blue',
                      subtitle: 'Biru Samudra',
                      previewBg: const Color(0xFF1976D2),
                      cardBg: const Color(0xFFE3F2FD),
                    ),
                    _buildThemeCard(
                      mode: AppThemeMode.sunsetOrange,
                      title: 'Sunset Orange',
                      subtitle: 'Oranye Matahari',
                      previewBg: const Color(0xFFF57C00),
                      cardBg: const Color(0xFFFFF3E0),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  globalThemeNotifier.value = _selectedTheme;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tema Berhasil Diperbarui! 🎨'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  'Simpan Tema',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _tampilkanDialogUpsellTema() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tema Premium'),
          content: const Text('Tema ini cuma tersedia untuk pengguna Premium. Upgrade dulu buat pakai semua tema.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (widget.userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LanggananPage(userId: widget.userId!)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Belum terhubung ke server, coba beberapa saat lagi.')),
                  );
                }
              },
              child: const Text('Upgrade ke Premium'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeCard({
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required Color previewBg,
    required Color cardBg,
  }) {
    bool isSelected = _selectedTheme == mode;
    // Tema pertama/default tetap gratis, sisanya dikunci untuk non-premium.
    bool terkunci = !widget.isPremiumUser && mode != AppThemeMode.teisouHijau;

    return GestureDetector(
      onTap: () {
        if (terkunci) {
          _tampilkanDialogUpsellTema();
          return;
        }
        setState(() {
          _selectedTheme = mode;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: previewBg,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                  if (terkunci)
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.lock, size: 12, color: Colors.black54),
                    )
                  else if (isSelected)
                    const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.check, size: 12, color: Colors.green),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12), top: Radius.circular(12)),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 6, width: 40, decoration: BoxDecoration(color: previewBg.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Container(height: 25, decoration: BoxDecoration(color: previewBg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)))),
                        const SizedBox(width: 4),
                        Expanded(child: Container(height: 25, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Container(height: 30, width: double.infinity, decoration: BoxDecoration(color: previewBg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}