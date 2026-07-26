import 'package:flutter/material.dart';
import 'package:cash_teisou/core/utils/category_utils.dart'; // FIX: untuk icon sesuai kategori
import 'package:cash_teisou/core/utils/tanggal_utils.dart';
import 'package:cash_teisou/core/utils/timeframe_utils.dart';

class TransactionPage extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final Function(int, String, int, bool) onEditTransaction;
  final Function(int) onDeleteTransaction;
  final List<String> masterKategori;

  const TransactionPage({
    super.key,
    required this.transactions,
    required this.onEditTransaction,
    required this.onDeleteTransaction,
    required this.masterKategori,
  });

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String _selectedFilter = 'Semua';
  TimeframeFilter _selectedTimeframe = TimeframeFilter.semuaWaktu;
  String _selectedCategoryFilter = 'Semua';

  final Map<String, bool> _keywordMemory = {
    'bayar spp': false,
  };

  String _formatRupiah(int angka) {
    return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _tampilkanModalEdit(int index, Map<String, dynamic> tx) {
    final TextEditingController judulController = TextEditingController(text: tx['title']);
    final TextEditingController nominalController = TextEditingController(text: tx['amount'].toString());
    
    String judulNormal = tx['title'].toString().toLowerCase().trim();
    bool apakahPemasukan = _keywordMemory[judulNormal] ?? tx['isIncome'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 20, right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ubah Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: judulController, 
                    decoration: const InputDecoration(labelText: 'Judul Transaksi', border: OutlineInputBorder()),
                    onChanged: (value) {
                      String key = value.toLowerCase().trim();
                      if (_keywordMemory.containsKey(key)) {
                        setModalState(() {
                          apakahPemasukan = _keywordMemory[key]!;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: nominalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pemasukan')),
                          selected: apakahPemasukan == true,
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          side: BorderSide(
                            color: apakahPemasukan == true ? const Color(0xFF4CAF50) : Colors.transparent,
                            width: 1,
                          ),
                          showCheckmark: false, 
                          labelStyle: TextStyle(
                            color: apakahPemasukan == true ? const Color(0xFF4CAF50) : Colors.black54, 
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => apakahPemasukan = true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Pengeluaran')),
                          selected: apakahPemasukan == false,
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                          side: BorderSide(
                            color: apakahPemasukan == false ? const Color(0xFFD32F2F) : Colors.transparent,
                            width: 1,
                          ),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: apakahPemasukan == false ? const Color(0xFFD32F2F) : Colors.black54, 
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => apakahPemasukan = false);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        String judulBaru = judulController.text.trim();
                        int nominalBaru = int.tryParse(nominalController.text) ?? 0;

                        if (judulBaru.isNotEmpty && nominalBaru > 0) {
                          setState(() {
                            _keywordMemory[judulBaru.toLowerCase()] = apakahPemasukan;
                          });

                          widget.onEditTransaction(index, judulBaru, nominalBaru, apakahPemasukan);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _tampilkanModalFilter() {
    TimeframeFilter draftTimeframe = _selectedTimeframe;
    String draftKategori = _selectedCategoryFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24, left: 20, right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 20),
                  const Text('Rentang Waktu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TimeframeFilter.values.map((tf) {
                      bool isSelected = draftTimeframe == tf;
                      return ChoiceChip(
                        label: Text(tf.label),
                        selected: isSelected,
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setModalState(() => draftTimeframe = tf);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Semua', ...widget.masterKategori].map((kat) {
                      bool isSelected = draftKategori == kat;
                      return ChoiceChip(
                        label: Text(kat),
                        selected: isSelected,
                        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setModalState(() => draftKategori = kat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            setState(() {
                              _selectedTimeframe = TimeframeFilter.semuaWaktu;
                              _selectedCategoryFilter = 'Semua';
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Reset Filter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            setState(() {
                              _selectedTimeframe = draftTimeframe;
                              _selectedCategoryFilter = draftKategori;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Terapkan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
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
    final now = DateTime.now();
    bool adaFilterLanjutanAktif = _selectedTimeframe != TimeframeFilter.semuaWaktu || _selectedCategoryFilter != 'Semua';

    List<Map<String, dynamic>> filteredTransactions = widget.transactions.where((tx) {
      if (_selectedFilter == 'Pemasukan' && tx['isIncome'] != true) return false;
      if (_selectedFilter == 'Pengeluaran' && tx['isIncome'] != false) return false;
      if (_selectedCategoryFilter != 'Semua' && tx['category'] != _selectedCategoryFilter) return false;
      if (!cocokTimeframe(tx['date'], _selectedTimeframe, now)) return false;
      return true;
    }).toList();

    return Scaffold(
      // Ditambahkan AppBar agar layout terdorong ke bawah area aman sistem otomatis
      appBar: AppBar(
        title: const Text('Riwayat Transaksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          Badge(
            isLabelVisible: adaFilterLanjutanAktif,
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _tampilkanModalFilter,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: ['Semua', 'Pemasukan', 'Pengeluaran'].map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100], 
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          filter, 
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700], 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            adaFilterLanjutanAktif || _selectedFilter != 'Semua'
                                ? 'Tidak ada transaksi yang cocok dengan filter saat ini.'
                                : 'Belum ada transaksi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        int originalIndex = widget.transactions.indexOf(tx);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              // FIX: sebelumnya cek `tx['icon'] is IconData` yang selalu false
                              // karena Firestore tidak pernah menyimpan field 'icon'.
                              // Sekarang konsisten dengan HomePage: ambil icon dari kategori.
                              child: Icon(
                                CategoryUtils.getIcon(tx['category'] ?? 'Lainnya'),
                                color: tx['isIncome'] == true ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(tx['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4), 
                              child: Text(
                                '${TanggalUtils.formatTanggal(tx['date'])} • [${tx['bukuKas'] ?? 'Pribadi'}]',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (tx['isIncome'] as bool ? '+ ' : '- ') + _formatRupiah(tx['amount'] as int),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: tx['isIncome'] as bool ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F)),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    widget.onDeleteTransaction(originalIndex);
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _tampilkanModalEdit(originalIndex, tx),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
