import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cash_teisou/core/services/database_service.dart';
import 'package:cash_teisou/core/services/premium_service.dart';

class LanggananPage extends StatefulWidget {
  final String userId;

  const LanggananPage({super.key, required this.userId});

  @override
  State<LanggananPage> createState() => _LanggananPageState();
}

class _LanggananPageState extends State<LanggananPage> {
  final DatabaseService _dbService = DatabaseService();
  final PremiumService _premiumService = PremiumService();
  bool _sedangProses = false;

  @override
  void initState() {
    super.initState();
    _premiumService.mulaiDengarPembelian(
      userId: widget.userId,
      onError: (pesan) {
        if (!mounted) return;
        setState(() => _sedangProses = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      },
    );
  }

  @override
  void dispose() {
    _premiumService.berhentiDengar();
    super.dispose();
  }

  Future<void> _mulaiBerlangganan() async {
    setState(() => _sedangProses = true);
    await _premiumService.initiateePurchase(
      onGagal: (pesan) {
        if (!mounted) return;
        setState(() => _sedangProses = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
      },
    );
    // Kalau initiateePurchase berhasil trigger flow store (bukan gagal di
    // atas), status "sedang proses" dilepas lagi di sini - keberhasilan
    // pembelian sebenarnya ditangkap async lewat purchaseStream & bikin
    // StreamBuilder di bawah rebuild sendiri begitu isPremium berubah.
    if (mounted) setState(() => _sedangProses = false);
  }

  String _formatTanggal(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Langganan Premium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _dbService.streamUserMetadata(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final isPremium = data['isPremium'] as bool? ?? false;
          final premiumExpiresAt = data['premiumExpiresAt'] as Timestamp?;

          if (isPremium) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, size: 64, color: Theme.of(context).primaryColor),
                    const SizedBox(height: 16),
                    const Text('Kamu sudah Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      premiumExpiresAt != null ? 'Berlaku sampai ${_formatTanggal(premiumExpiresAt)}' : 'Masa berlaku tidak diketahui',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Cash Teisou Premium', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
              const SizedBox(height: 16),
              _buildBenefit(Icons.block, 'Tanpa iklan sama sekali'),
              _buildBenefit(Icons.menu_book, 'Buku Kas unlimited'),
              _buildBenefit(Icons.inventory_2, 'Backup transaksi tersimpan 90 hari'),
              _buildBenefit(Icons.palette, 'Semua tema aplikasi terbuka'),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Rp XX.XXX/bulan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Harga placeholder, akan diperbarui', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _sedangProses ? null : _mulaiBerlangganan,
                  child: _sedangProses
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Berlangganan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
