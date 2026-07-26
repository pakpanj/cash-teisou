import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cash_teisou/core/services/database_service.dart';
import 'package:cash_teisou/core/services/ad_service.dart';

class BackupPage extends StatefulWidget {
  final String userId;
  final Future<void> Function(String namaBukuKas) onSetelahRestore;
  final bool isPremiumUser;

  const BackupPage({
    super.key,
    required this.userId,
    required this.onSetelahRestore,
    required this.isPremiumUser,
  });

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _sedangProses = false;

  @override
  void initState() {
    super.initState();
    // Auto-expire: bersihkan backup yang sudah lewat 30 hari sebelum ditampilkan.
    _dbService.hapusBackupKedaluwarsa(widget.userId);
  }

  String _formatTanggal(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _sisaHari(Timestamp? kedaluwarsaPada) {
    if (kedaluwarsaPada == null) return '-';
    final sisa = kedaluwarsaPada.toDate().difference(DateTime.now());
    if (sisa.isNegative) return 'Kedaluwarsa';
    return '${sisa.inDays} hari lagi';
  }

  Future<void> _konfirmasiHapusPermanen(String backupId, String namaBukuKas) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Permanen'),
        content: Text('Backup "$namaBukuKas" akan dihapus permanen sekarang, tidak bisa di-restore lagi. Yakin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    setState(() => _sedangProses = true);
    await _dbService.hapusBackupPermanen(widget.userId, backupId);
    if (mounted) {
      setState(() => _sedangProses = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup dihapus permanen.')),
      );
    }
  }

  Future<void> _restore(String backupId, Map<String, dynamic> backupData) async {
    setState(() => _sedangProses = true);
    try {
      await _dbService.restoreBackup(widget.userId, backupId, backupData);
      await widget.onSetelahRestore(backupData['namaBukuKas'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil restore "${backupData['namaBukuKas']}".')),
        );
        AdService().showInterstitialSegera(isPremiumUser: widget.isPremiumUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal restore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangProses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.streamBackups(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Belum ada backup.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return AbsorbPointer(
            absorbing: _sedangProses,
            child: Opacity(
              opacity: _sedangProses ? 0.5 : 1,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final namaBukuKas = (data['namaBukuKas'] as String?) ?? '-';
                  final jumlahTransaksi = (data['jumlahTransaksi'] as int?) ?? 0;
                  final dihapusPada = data['dihapusPada'] as Timestamp?;
                  final kedaluwarsaPada = data['kedaluwarsaPada'] as Timestamp?;
                  final tipeReset = data['tipeReset'] as String? ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(namaBukuKas, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                  tipeReset == 'semuaTransaksi' ? 'Reset Semua' : 'Reset Kas',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Dihapus: ${_formatTanggal(dihapusPada)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('$jumlahTransaksi transaksi • ${_sisaHari(kedaluwarsaPada)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _konfirmasiHapusPermanen(doc.id, namaBukuKas),
                                  child: const Text('Hapus Permanen Sekarang', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                                  onPressed: () => _restore(doc.id, data),
                                  child: const Text('Restore', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
