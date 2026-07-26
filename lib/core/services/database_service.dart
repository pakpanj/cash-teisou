import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mendapatkan stream data transaksi user
  Stream<QuerySnapshot> streamTransaksi(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mendapatkan stream metadata dokumen user (untuk daftar buku kas)
  Stream<DocumentSnapshot> streamUserMetadata(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Tambah Transaksi Baru
  Future<void> tambahTransaksi({
    required String userId,
    required String judul,
    required int nominal,
    required bool apakahPemasukan,
    required String kategori,
    required String bukuKas,
  }) async {
    final now = DateTime.now();
    final data = {
      'title': judul,
      // FIX: sebelumnya hardcode 'Hari Ini'. Sekarang simpan tanggal asli
      // dalam format ISO 8601 agar bisa diparse & diformat ulang di UI,
      // dan agar chart tren saldo di HomePage bisa membaca tanggal per titik.
      'date': now.toIso8601String(),
      'bukuKas': bukuKas,
      'category': kategori,
      'amount': nominal,
      'isIncome': apakahPemasukan,
      'timestamp': now.millisecondsSinceEpoch,
    };
    await _firestore.collection('users').doc(userId).collection('transactions').add(data);
  }

  // Edit Transaksi
  Future<void> editTransaksi({
    required String userId,
    required String docId,
    required String judulBaru,
    required int nominalBaru,
    required bool apakahPemasukan,
  }) async {
    await _firestore.collection('users').doc(userId).collection('transactions').doc(docId).update({
      'title': judulBaru,
      'amount': nominalBaru,
      'isIncome': apakahPemasukan,
    });
  }

  // Hapus Satu Transaksi
  Future<void> hapusSatuTransaksi(String userId, String docId) async {
    await _firestore.collection('users').doc(userId).collection('transactions').doc(docId).delete();
  }

  // Sync / Simpan Daftar Buku Kas ke Cloud
  Future<void> perbaruiDaftarBukuKas(String userId, List<String> daftarBukuKas) async {
    await _firestore.collection('users').doc(userId).set({
      'daftarBukuKas': daftarBukuKas,
    }, SetOptions(merge: true));
  }

  // Sync / Simpan Daftar Kategori Custom ke Cloud
  Future<void> perbaruiDaftarKategori(String userId, List<String> daftarKategori) async {
    await _firestore.collection('users').doc(userId).set({
      'daftarKategori': daftarKategori,
    }, SetOptions(merge: true));
  }

  // Perbarui status langganan Premium user.
  // TODO(keamanan): saat ini isPremium ditulis langsung dari client setelah
  // status purchaseStream == purchased/restored (lihat premium_service.dart).
  // Rule Firestore users/{userId} saat ini mengizinkan user menulis field
  // apapun di dokumennya sendiri, jadi secara teknis client bisa langsung
  // set isPremium=true tanpa pembelian nyata. Untuk produksi sungguhan,
  // idealnya field ini di-set oleh Cloud Function yang memverifikasi
  // receipt pembelian di server, bukan langsung dari app.
  Future<void> perbaruiStatusPremium(String userId, {required bool isPremium, DateTime? premiumExpiresAt}) async {
    await _firestore.collection('users').doc(userId).set({
      'isPremium': isPremium,
      'premiumExpiresAt': premiumExpiresAt != null ? Timestamp.fromDate(premiumExpiresAt) : null,
    }, SetOptions(merge: true));
  }

  // Cari nama backup anti-tabrakan berdasarkan namaAsli: backup pertama
  // dengan namaAsli tsb tetap pakai nama asli tanpa suffix, backup
  // berikutnya jadi "namaAsli (1)", "namaAsli (2)", dst.
  Future<String> _namaBackupUnik(String userId, String namaAsli) async {
    final existing = await _firestore
        .collection('users').doc(userId).collection('backups')
        .where('namaAsli', isEqualTo: namaAsli)
        .get();
    final jumlah = existing.docs.length;
    return jumlah == 0 ? namaAsli : '$namaAsli ($jumlah)';
  }

  Future<void> _buatBackup({
    required String userId,
    required String namaAsli,
    required String tipeReset,
    required List<QueryDocumentSnapshot> dokumenTransaksi,
    required bool isPremiumUser,
  }) async {
    if (dokumenTransaksi.isEmpty) return;
    final namaBackup = await _namaBackupUnik(userId, namaAsli);
    final sekarang = DateTime.now();
    // Masa retensi dikunci di waktu backup dibuat berdasarkan status premium
    // SAAT INI - tidak berubah otomatis kalau status premium user berubah
    // belakangan.
    final masaRetensi = Duration(days: isPremiumUser ? 90 : 30);
    await _firestore.collection('users').doc(userId).collection('backups').add({
      'namaBukuKas': namaBackup,
      'namaAsli': namaAsli,
      'tipeReset': tipeReset,
      'dihapusPada': FieldValue.serverTimestamp(),
      // FieldValue.serverTimestamp() adalah sentinel, tidak bisa diaritmetika
      // di client - jadi kedaluwarsaPada dihitung dari waktu lokal saat ini.
      'kedaluwarsaPada': Timestamp.fromDate(sekarang.add(masaRetensi)),
      'jumlahTransaksi': dokumenTransaksi.length,
      'transaksi': dokumenTransaksi.map((doc) => doc.data() as Map<String, dynamic>).toList(),
    });
  }

  // Backup dokumen transaksi yang akan dihapus, DIKELOMPOKKAN per nilai
  // 'bukuKas' masing-masing (bukan satu backup campur semua kas), supaya
  // restore-nya (yang men-set bukuKas semua transaksi dalam satu backup ke
  // satu nama) tidak menghilangkan identitas kas asli tiap transaksi.
  Future<void> _backupTerkelompokLaluHapus({
    required String userId,
    required String tipeReset,
    required List<QueryDocumentSnapshot> dokumenTransaksi,
    required bool isPremiumUser,
  }) async {
    if (dokumenTransaksi.isEmpty) return;

    final Map<String, List<QueryDocumentSnapshot>> kelompok = {};
    for (var doc in dokumenTransaksi) {
      final data = doc.data() as Map<String, dynamic>;
      final namaKas = (data['bukuKas'] as String?) ?? 'Tanpa Nama';
      kelompok.putIfAbsent(namaKas, () => []).add(doc);
    }

    for (final entry in kelompok.entries) {
      await _buatBackup(userId: userId, namaAsli: entry.key, tipeReset: tipeReset, dokumenTransaksi: entry.value, isPremiumUser: isPremiumUser);
    }

    final batch = _firestore.batch();
    for (var doc in dokumenTransaksi) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Reset Transaksi pada Buku Kas tertentu, dengan backup otomatis dulu
  Future<void> resetTransaksiBukuKasDenganBackup(String userId, String namaBukuKas, {required bool isPremiumUser}) async {
    final snapshots = await _firestore.collection('users').doc(userId).collection('transactions').where('bukuKas', isEqualTo: namaBukuKas).get();
    await _backupTerkelompokLaluHapus(userId: userId, tipeReset: 'kasAktif', dokumenTransaksi: snapshots.docs, isPremiumUser: isPremiumUser);
  }

  // Reset Semua Transaksi milik User, dengan backup otomatis dulu
  Future<void> resetSemuaTransaksiDenganBackup(String userId, {required bool isPremiumUser}) async {
    final snapshots = await _firestore.collection('users').doc(userId).collection('transactions').get();
    await _backupTerkelompokLaluHapus(userId: userId, tipeReset: 'semuaTransaksi', dokumenTransaksi: snapshots.docs, isPremiumUser: isPremiumUser);
  }

  // Mendapatkan stream daftar backup milik user, urut terbaru
  Stream<QuerySnapshot> streamBackups(String userId) {
    return _firestore
        .collection('users').doc(userId).collection('backups')
        .orderBy('dihapusPada', descending: true)
        .snapshots();
  }

  // Tulis ulang semua transaksi dari backup ke transactions, lalu hapus
  // dokumen backup-nya (sudah tidak perlu lagi).
  Future<void> restoreBackup(String userId, String backupId, Map<String, dynamic> backupData) async {
    final namaBukuKas = backupData['namaBukuKas'] as String;
    final List<dynamic> transaksiList = backupData['transaksi'] as List<dynamic>;

    final transaksiRef = _firestore.collection('users').doc(userId).collection('transactions');
    final batch = _firestore.batch();
    for (var item in transaksiList) {
      final data = Map<String, dynamic>.from(item as Map);
      // Selalu pakai nama hasil anti-tabrakan dari backup, BUKAN nama buku
      // kas aktif sekarang, supaya data yang di-restore tidak tercampur.
      data['bukuKas'] = namaBukuKas;
      batch.set(transaksiRef.doc(), data);
    }
    batch.delete(_firestore.collection('users').doc(userId).collection('backups').doc(backupId));
    await batch.commit();
  }

  Future<void> hapusBackupPermanen(String userId, String backupId) async {
    await _firestore.collection('users').doc(userId).collection('backups').doc(backupId).delete();
  }

  // Hapus permanen semua backup milik user yang sudah lewat kedaluwarsaPada
  Future<void> hapusBackupKedaluwarsa(String userId) async {
    final expired = await _firestore
        .collection('users').doc(userId).collection('backups')
        .where('kedaluwarsaPada', isLessThan: Timestamp.now())
        .get();
    if (expired.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (var doc in expired.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Kirim Saran & Masukan ke collection top-level 'feedback' (bukan di
  // bawah users/{userId}) - perlu rule Firestore baru, lihat firestore.rules.
  Future<void> kirimFeedback({required String? userId, required String message, required String appVersion}) async {
    await _firestore.collection('feedback').add({
      'userId': userId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'appVersion': appVersion,
    });
  }
}
