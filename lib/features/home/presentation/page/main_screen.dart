import 'package:flutter/material.dart';
import 'package:cash_teisou/features/home/presentation/page/home_page.dart';
import 'package:cash_teisou/features/transaksi/transaction_page.dart';
import 'package:cash_teisou/features/pengaturan/setting_page.dart';
import 'package:cash_teisou/features/statistik/statistic_page.dart';
import 'package:cash_teisou/core/services/smart_input_service.dart';
import 'package:cash_teisou/core/services/database_service.dart';
import 'package:cash_teisou/core/services/auth_service.dart'; // FIX: service auth baru
import 'package:cash_teisou/core/services/ad_service.dart';
import 'package:cash_teisou/core/utils/dialog_utils.dart';
import 'package:cash_teisou/core/utils/category_utils.dart'; // Import utility baru
import 'package:cash_teisou/features/pengaturan/langganan_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSaldoHidden = false;
  String _userDisplayName =
      'Teisou Sensei'; // Default set ke identitas utama Anda
  String? _userPhotoUrl;
  // FIX: status login Google sekarang dilacak eksplisit dari hasil auth,
  // bukan lagi ditebak dengan membandingkan _userDisplayName ke string
  // default 'Teisou Sensei' (rapuh kalau nama Google user kebetulan sama).
  bool _isGoogleUser = false;
  bool _isPremiumUser = false;

  // FIX: sebelumnya String statis 'demo_user' yang dibagi SEMUA pengguna
  // yang belum login. Sekarang null dulu sampai sesi Firebase Auth siap
  // (anonymous atau Google), lalu diisi dari UID asli yang terverifikasi.
  String? _currentUserId;

  String _selectedBukuKas = 'Pribadi';
  final List<String> _daftarBukuKas = ['Pribadi'];

  final DatabaseService _dbService = DatabaseService();
  final SmartInputService _smartInputService = SmartInputService();
  final AuthService _authService =
      AuthService(); // FIX: ganti GoogleSignIn manual
  final AdService _adService = AdService();

  StreamSubscription<QuerySnapshot>? _transactionSubscription;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  final List<String> _masterKategori = List.from(CategoryUtils.defaultKategori);
  List<Map<String, dynamic>> _globalTransactions = [];

  @override
  void initState() {
    super.initState();
    _inisialisasiSesi();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }

  // FIX: sebelumnya langsung _aktifkanLiveStreamCloud() dengan userId statis.
  // Sekarang pastikan sesi Firebase Auth (anonymous minimal) siap dulu,
  // baru buka stream Firestore dengan UID asli hasil autentikasi.
  Future<void> _inisialisasiSesi() async {
    try {
      final user = await _authService.ensureSignedIn();
      setState(() {
        _currentUserId = user.uid;
        _isGoogleUser = !user.isAnonymous;
        // Kalau sesi ini ternyata bukan anonymous (mis. sesi Google
        // tersimpan dari sebelumnya), tampilkan nama & foto akun tsb.
        if (!user.isAnonymous) {
          _userDisplayName = user.displayName ?? _userDisplayName;
          _userPhotoUrl = user.photoURL;
        }
      });
      _aktifkanLiveStreamCloud();
      // Auto-expire: bersihkan backup user yang sudah lewat 30 hari.
      // Fire-and-forget, tidak menghalangi alur utama inisialisasi.
      _dbService.hapusBackupKedaluwarsa(user.uid);
    } catch (e) {
      // FIX: sebelumnya gagal senyap -> user bisa input tapi data tidak
      // pernah tersimpan tanpa penjelasan apapun. Sekarang error ini
      // ditampilkan jelas ke user, plus tombol coba lagi.
      debugPrint("Gagal inisialisasi sesi auth: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 8),
              content: const Text(
                'Gagal terhubung ke server (autentikasi bermasalah). '
                'Input tidak akan tersimpan sampai ini berhasil.',
              ),
              action: SnackBarAction(
                label: 'Coba Lagi',
                onPressed: _inisialisasiSesi,
              ),
            ),
          );
        });
      }
    }
  }

  void _aktifkanLiveStreamCloud() {
    if (_currentUserId == null) return;
    final userId = _currentUserId!;

    _transactionSubscription?.cancel();
    _userDocSubscription?.cancel();

    _userDocSubscription =
        _dbService.streamUserMetadata(userId).listen((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> userData =
            docSnapshot.data() as Map<String, dynamic>;
        if (userData['daftarBukuKas'] != null) {
          List<dynamic> kasDariCloud = userData['daftarBukuKas'];
          setState(() {
            _daftarBukuKas.clear();
            _daftarBukuKas
                .addAll(kasDariCloud.map((e) => e.toString()).toList());
            if (!_daftarBukuKas.contains(_selectedBukuKas)) {
              _selectedBukuKas =
                  _daftarBukuKas.isNotEmpty ? _daftarBukuKas.first : 'Pribadi';
            }
          });
        }
        // FIX: kategori custom yang dibuat user dulunya cuma tersimpan di
        // _masterKategori lokal (hilang tiap restart). Sekarang dimuat dari
        // Firestore juga - kalau field belum ada (user baru/lama), biarkan
        // _masterKategori tetap di nilai default awalnya.
        if (userData['daftarKategori'] != null) {
          List<dynamic> kategoriDariCloud = userData['daftarKategori'];
          setState(() {
            _masterKategori.clear();
            _masterKategori
                .addAll(kategoriDariCloud.map((e) => e.toString()).toList());
          });
        }
        if (userData['isPremium'] != null) {
          setState(() {
            _isPremiumUser = userData['isPremium'] as bool;
          });
        }
      } else {
        setState(() {
          _daftarBukuKas.clear();
          _daftarBukuKas.add('Pribadi');
        });
      }
    });

    _transactionSubscription =
        _dbService.streamTransaksi(userId).listen((querySnapshot) {
      setState(() {
        _globalTransactions = querySnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint("Gagal sinkronisasi data online: $e");
      setState(() => _isLoading = false);
    });
  }

  Future<void> _tambahTransaksiBaru(
      String judul, int nominal, bool apakahPemasukan, String kategori) async {
    if (_currentUserId == null) return;
    await _dbService.tambahTransaksi(
      userId: _currentUserId!,
      judul: judul,
      nominal: nominal,
      apakahPemasukan: apakahPemasukan,
      kategori: kategori,
      bukuKas: _selectedBukuKas,
    );
    // Titik akhir bersama smart input langsung & dialog belajar kategori,
    // jadi cukup satu panggilan di sini utk cover kedua alur (poin 5).
    _adService.muatDanTampilkanInterstitial(isPremiumUser: _isPremiumUser);
  }

  Future<void> _editTransaksi(int index, String judulBaru, int nominalBaru,
      bool apakahPemasukan) async {
    if (_currentUserId == null) return;
    String docId = _globalTransactions[index]['id'] ?? '';
    if (docId.isEmpty) return;

    await _dbService.editTransaksi(
      userId: _currentUserId!,
      docId: docId,
      judulBaru: judulBaru,
      nominalBaru: nominalBaru,
      apakahPemasukan: apakahPemasukan,
    );
    _smartInputService.catatMemoriDinamis(judulBaru, apakahPemasukan);
  }

  static const int _batasBukuKasGratis = 2;

  Future<void> _tambahBukuKasBaru(String namaBuku) async {
    if (namaBuku.trim().isEmpty || _currentUserId == null) return;

    bool sudahAda = _daftarBukuKas.contains(namaBuku);
    if (!_isPremiumUser && !sudahAda && _daftarBukuKas.length >= _batasBukuKasGratis) {
      _tampilkanDialogBatasBukuKas();
      return;
    }

    setState(() {
      if (!sudahAda) _daftarBukuKas.add(namaBuku);
    });
    await _dbService.perbaruiDaftarBukuKas(_currentUserId!, _daftarBukuKas);
  }

  void _tampilkanDialogBatasBukuKas() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Batas Buku Kas Gratis'),
          content: const Text(
            'Batas Buku Kas gratis tercapai (maks. $_batasBukuKasGratis). '
            'Upgrade ke Premium untuk Buku Kas unlimited.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LanggananPage(userId: _currentUserId!)),
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

  Future<void> _hapusBukuKas(int index) async {
    if (_currentUserId == null) return;
    if (_daftarBukuKas.length > 1) {
      setState(() {
        String kasYangDihapus = _daftarBukuKas[index];
        if (_selectedBukuKas == kasYangDihapus) {
          _selectedBukuKas = _daftarBukuKas[index == 0 ? 1 : 0];
        }
        _daftarBukuKas.removeAt(index);
      });
      await _dbService.perbaruiDaftarBukuKas(_currentUserId!, _daftarBukuKas);
    }
  }

  void _prosesSmartInput(String rawText) {
    if (rawText.trim().isEmpty) return;

    // FIX: sebelumnya kalau _currentUserId belum siap, input tetap "berhasil"
    // di mata user (modal tertutup normal) tapi tidak pernah tersimpan ke
    // Firestore tanpa pesan apapun. Sekarang user diberi tahu secara jelas.
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Belum terhubung ke server, coba beberapa saat lagi.')),
      );
      return;
    }

    final analisis = _smartInputService.prosesTeksKeData(rawText);
    String judul = analisis['title'];
    int nominal = analisis['amount'];
    bool isIncome = analisis['isIncome'];
    String? kategori = analisis['category'];
    String kataKunciUtama = analisis['suggestedKeyword'];

    if (kategori != null) {
      _tambahTransaksiBaru(judul, nominal, isIncome, kategori);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Otomatis masuk kategori: $kategori 🧠🤖')),
      );
    } else {
      DialogUtils.tampilkanDialogBelajarKategori(
        context: context,
        judul: judul,
        masterKategori: _masterKategori,
        onKategoriTerpilih: (kat) {
          _smartInputService.pelajariKataKunciBaru(kataKunciUtama, kat);
          _tambahTransaksiBaru(judul, nominal, isIncome, kat);
        },
        onKategoriBaruDibuat: (katBaru) {
          setState(() {
            if (!_masterKategori.contains(katBaru))
              _masterKategori.add(katBaru);
          });
          _smartInputService.pelajariKataKunciBaru(kataKunciUtama, katBaru);
          _tambahTransaksiBaru(judul, nominal, isIncome, katBaru);
          if (_currentUserId != null) {
            _dbService.perbaruiDaftarKategori(_currentUserId!, _masterKategori);
          }
        },
      );
    }
  }

  void _hapusSatuTransaksi(int index) {
    if (_currentUserId == null) return;
    String docId = _globalTransactions[index]['id'] ?? '';
    if (docId.isEmpty) return;
    _dbService.hapusSatuTransaksi(_currentUserId!, docId);
  }

  Future<void> _kirimFeedback(String message, String appVersion) async {
    await _dbService.kirimFeedback(userId: _currentUserId, message: message, appVersion: appVersion);
  }

  // Setelah restore backup berhasil, pastikan nama buku kas hasil restore
  // (yang sudah unik lewat anti-tabrakan) masuk ke daftarBukuKas kalau
  // belum ada, supaya langsung terlihat/terpilihkan di HomePage.
  Future<void> _setelahRestoreBackup(String namaBukuKas) async {
    if (_currentUserId == null) return;
    if (!_daftarBukuKas.contains(namaBukuKas)) {
      setState(() => _daftarBukuKas.add(namaBukuKas));
      await _dbService.perbaruiDaftarBukuKas(_currentUserId!, _daftarBukuKas);
    }
  }

  void _toggleVisibilitySaldo() =>
      setState(() => _isSaldoHidden = !_isSaldoHidden);
  void _pilihBukuKas(String namaBuku) =>
      setState(() => _selectedBukuKas = namaBuku);

  // FIX: sebelumnya pakai GoogleSignIn manual lalu userId = email mentah
  // tanpa verifikasi Firebase Auth. Sekarang lewat AuthService yang
  // melakukan signInWithCredential/linkWithCredential yang sebenarnya,
  // dan userId diambil dari UID terverifikasi (auth.currentUser.uid).
  Future<void> _handleGoogleSignIn() async {
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        setState(() {
          _userDisplayName = user.displayName ?? "User Google";
          _userPhotoUrl = user.photoURL;
          _currentUserId = user.uid;
          _isGoogleUser = true;
          _isLoading = true;
          _selectedBukuKas = 'Pribadi';
          // FIX: sebelumnya list lama tidak dikosongkan, sehingga tab
          // Transaksi & Statistik sempat menampilkan data akun sebelumnya
          // (dengan docId lama) sampai stream akun baru selesai memuat.
          _globalTransactions = [];
        });
        _aktifkanLiveStreamCloud();
      }
    } catch (e) {
      debugPrint("Gagal login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal login dengan Google. Coba lagi.')),
        );
      }
    }
  }

  Future<void> _handleGoogleSignOut() async {
    try {
      final anonUser = await _authService.signOutAndResetToAnonymous();
      setState(() {
        _userDisplayName = 'Teisou Sensei';
        _userPhotoUrl = null;
        _currentUserId = anonUser.uid;
        _isGoogleUser = false;
        _isLoading = true;
        _selectedBukuKas = 'Pribadi';
        // FIX: sama seperti saat sign-in, kosongkan data akun sebelumnya
        // supaya tab Transaksi/Statistik tidak sempat tampil salah akun.
        _globalTransactions = [];
      });
      _aktifkanLiveStreamCloud();
    } catch (e) {
      debugPrint("Gagal logout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : HomePage(
              transactions: _globalTransactions,
              isSaldoHidden: _isSaldoHidden,
              userDisplayName: _userDisplayName,
              userPhotoUrl: _userPhotoUrl,
              daftarBukuKas: _daftarBukuKas,
              selectedBukuKas: _selectedBukuKas,
              masterKategori: _masterKategori,
              onToggleSaldo: _toggleVisibilitySaldo,
              onTambahBukuKas: _tambahBukuKasBaru,
              onHapusBukuKas: _hapusBukuKas,
              onPilihBukuKas: _pilihBukuKas,
              isPremiumUser: _isPremiumUser,
            ),
      TransactionPage(
        transactions: _globalTransactions,
        onEditTransaction: _editTransaksi,
        onDeleteTransaction: (idx) => _hapusSatuTransaksi(idx),
        masterKategori: _masterKategori,
      ),
      StatisticPage(transactions: _globalTransactions),
      SettingPage(
        userDisplayName: _userDisplayName,
        isLoggedInGoogle: _isGoogleUser,
        userPhotoUrl: _userPhotoUrl,
        currentUserId: _currentUserId,
        isPremiumUser: _isPremiumUser,
        onGoogleSignIn: _handleGoogleSignIn,
        onGoogleSignOut: _handleGoogleSignOut,
        onResetTransaksi: () => _currentUserId == null
            ? null
            : _dbService.resetSemuaTransaksiDenganBackup(_currentUserId!, isPremiumUser: _isPremiumUser),
        onResetKasAktif: () => _currentUserId == null
            ? null
            : _dbService.resetTransaksiBukuKasDenganBackup(
                _currentUserId!, _selectedBukuKas, isPremiumUser: _isPremiumUser),
        selectedBukuKas: _selectedBukuKas,
        onKirimFeedback: _kirimFeedback,
        onSetelahRestoreBackup: _setelahRestoreBackup,
        transactions: _globalTransactions,
        daftarBukuKas: _daftarBukuKas,
      ),
    ];

    Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => DialogUtils.tampilkanModalInput(
          context: context,
          selectedBukuKas: _selectedBukuKas,
          onSubmitted: _prosesSmartInput,
        ),
        backgroundColor: primaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
                icon: Icon(Icons.home_outlined,
                    color: _currentIndex == 0 ? primaryColor : Colors.grey),
                onPressed: () => setState(() => _currentIndex = 0)),
            IconButton(
                icon: Icon(Icons.receipt_long_outlined,
                    color: _currentIndex == 1 ? primaryColor : Colors.grey),
                onPressed: () => setState(() => _currentIndex = 1)),
            const SizedBox(width: 40),
            IconButton(
                icon: Icon(Icons.bar_chart_outlined,
                    color: _currentIndex == 2 ? primaryColor : Colors.grey),
                onPressed: () => setState(() => _currentIndex = 2)),
            IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: _currentIndex == 3 ? primaryColor : Colors.grey),
                onPressed: () => setState(() => _currentIndex = 3)),
          ],
        ),
      ),
    );
  }
}
