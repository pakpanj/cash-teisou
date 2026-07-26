import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticPage extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const StatisticPage({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    int totalPemasukan = transactions
        .where((tx) => tx['isIncome'] == true)
        .fold(0, (sum, tx) => sum + (tx['amount'] as int));

    int totalPengeluaran = transactions
        .where((tx) => tx['isIncome'] == false)
        .fold(0, (sum, tx) => sum + (tx['amount'] as int));

    int totalArusDana = totalPemasukan + totalPengeluaran;

    double persenMasuk = totalArusDana > 0 ? (totalPemasukan / totalArusDana) * 100 : 0;
    double persenKeluar = totalArusDana > 0 ? (totalPengeluaran / totalArusDana) * 100 : 0;

    String formatRupiah(int angka) {
      return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Keuangan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Belum ada data untuk kalkulasi statistik.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Rasio Arus Kas Global',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: [
                              if (totalPemasukan > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF4CAF50),
                                  value: persenMasuk,
                                  title: '${persenMasuk.toStringAsFixed(1)}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (totalPengeluaran > 0)
                                PieChartSectionData(
                                  color: const Color(0xFFD32F2F),
                                  value: persenKeluar,
                                  title: '${persenKeluar.toStringAsFixed(1)}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendIndicator(const Color(0xFF4CAF50), 'Pemasukan'),
                          const SizedBox(height: 8),
                          _buildLegendIndicator(const Color(0xFFD32F2F), 'Pengeluaran'),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Rincian Nominal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow('Total Pemasukan', formatRupiah(totalPemasukan), const Color(0xFF4CAF50)),
                        const Divider(height: 24),
                        _buildStatRow('Total Pengeluaran', formatRupiah(totalPengeluaran), const Color(0xFFD32F2F)),
                        const Divider(height: 24),
                        _buildStatRow(
                          'Net Sinkronisasi Kas', 
                          formatRupiah(totalPemasukan - totalPengeluaran), 
                          (totalPemasukan - totalPengeluaran) >= 0 ? const Color(0xFF1B5E20) : const Color(0xFFD32F2F),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendIndicator(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}