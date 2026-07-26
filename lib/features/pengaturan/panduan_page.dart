import 'package:flutter/material.dart';

class PanduanPage extends StatelessWidget {
  const PanduanPage({super.key});

  static const List<Map<String, String>> _daftarFaq = [
    {
      'q': 'Gimana sih cara pakai Smart Cash Input?',
      'a': 'Gampang, tinggal ketik kayak lagi ngobrol aja. Contoh: gaji 5jt, '
          'makan siang 25k, bayar spp 500rb. App-nya bakal otomatis nebak nominal, '
          'jenis (masuk/keluar), sama kategorinya.',
    },
    {
      'q': 'Kok nominalnya beda dari yang aku ketik?',
      'a': 'Nih aturannya:\n'
          '- Pake k/rb/ribu di belakang angka -> dikali 1.000\n'
          '- Pake jt/juta -> dikali 1.000.000\n'
          '- Pake m/milyar -> dikali 1.000.000.000\n'
          '- Gak pake apa-apa & angkanya di bawah 1000 -> otomatis dianggap '
          'ribuan (misal ketik \'makan 15\' = Rp15.000, bukan lima belas rupiah)',
    },
    {
      'q': 'Gimana app tau ini pemasukan atau pengeluaran?',
      'a': 'Kalo ada kata kayak \'gaji\', \'bonus\', \'jual\', \'cashback\', dll -> '
          'otomatis Pemasukan. Kalo gak ada kata-kata itu -> default-nya '
          'Pengeluaran.',
    },
    {
      'q': 'Kategori kok kadang kedeteksi kadang enggak?',
      'a': 'Kalo ada kata kayak \'rokok\', \'makan\', \'sawit\', \'saham\' -> '
          'langsung kedeteksi kategorinya. Kalo enggak, app bakal nanya kamu mau '
          'masuk kategori apa - dan dia bakal inget buat next time kamu ketik yang '
          'mirip. Makin sering dipake, makin pinter dia nebak.',
    },
    {
      'q': 'Gimana cara kelola Buku Kas?',
      'a': 'Buku Kas itu kayak \'dompet terpisah\' - misal Pribadi vs Bisnis. '
          'Kamu bisa tambah buku kas baru, pindah-pindah buku kas aktif, atau '
          'hapus buku kas yang udah gak dipake, semua lewat halaman Home.',
    },
    {
      'q': 'Gimana cara filter transaksi?',
      'a': 'Di halaman Transaksi, tekan ikon filter buat milih rentang waktu '
          '(Hari Ini/Minggu Ini/Bulan Ini/Tahun Ini) dan kategori. Bisa '
          'dikombinasikan sekaligus buat nyari transaksi spesifik.',
    },
    {
      'q': 'Reset Data itu ngeri gak?',
      'a': 'Lumayan - ini permanen, gak bisa di-undo. \'Reset Kas Aktif\' cuma '
          'hapus buku kas yang lagi aktif, \'Reset Semua Transaksi\' hapus SEMUANYA. '
          'Hati-hati pas mau pencet ini ya.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Penggunaan Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _daftarFaq.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final faq = _daftarFaq[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            color: Colors.white,
            child: ExpansionTile(
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              title: Text(faq['q']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faq['a']!, style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
              ],
            ),
          );
        },
      ),
    );
  }
}
