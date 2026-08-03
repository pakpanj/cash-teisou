import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Mengelola sesi autentikasi Firebase.
///
/// Prinsip: SETIAP request ke Firestore harus punya `request.auth` yang valid
/// (bukan lagi UID/email mentah tanpa verifikasi), supaya Firestore Security
/// Rules bisa memvalidasi siapa pemilik data yang sebenarnya.
///
/// Alur:
/// - Belum login -> anonymous sign-in otomatis. Tiap instalasi app dapat
///   UID anonymous sendiri (BUKAN lagi 'demo_user' yang dibagi semua orang).
/// - Login Google -> credential Google di-LINK ke akun anonymous yang aktif,
///   supaya data yang sudah dibuat sebagai anonymous ikut terbawa ke akun
///   Google. Kalau akun Google itu ternyata sudah pernah dipakai di device
///   lain, otomatis fallback pakai akun Google yang sudah ada (data lama di
///   device lain itu yang dipakai).
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '533604829622-2nefof9b1tfcj68btbcjsl9sau4oi77s.apps.googleusercontent.com',
    serverClientId: '533604829622-1tmjr60cmuvegvp2uk6r7if00pls9ktc.apps.googleusercontent.com',
    scopes: ['email'],
  );

  User? get currentUser => _firebaseAuth.currentUser;

  /// Panggil sekali saat app start. Kalau belum ada sesi sama sekali,
  /// buat sesi anonymous baru. Mengembalikan user yang aktif (anonymous
  /// atau yang sudah login Google sebelumnya & sesi masih tersimpan).
  Future<User> ensureSignedIn() async {
    final existing = _firebaseAuth.currentUser;
    if (existing != null) return existing;

    final credential = await _firebaseAuth.signInAnonymously();
    if (credential.user == null) {
      throw StateError('Gagal membuat sesi anonymous.');
    }
    return credential.user!;
  }

  /// Login/hubungkan dengan akun Google. Mengembalikan User baru,
  /// atau null kalau user membatalkan proses login.
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // dibatalkan user

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _firebaseAuth.currentUser;

    try {
      if (current != null && current.isAnonymous) {
        // Upgrade akun anonymous -> Google, data lama (dibuat sebagai
        // anonymous) tetap nempel di UID yang sama.
        final result = await current.linkWithCredential(credential);
        return _pastikanProfilTerisi(result.user, googleUser);
      } else {
        final result = await _firebaseAuth.signInWithCredential(credential);
        return _pastikanProfilTerisi(result.user, googleUser);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        // Akun Google ini sudah pernah dipakai di device/sesi lain.
        // Pindah ke akun Google yang sudah ada tersebut (data lama di sana
        // yang dipakai, bukan data anonymous di device ini).
        final result = await _firebaseAuth.signInWithCredential(credential);
        return _pastikanProfilTerisi(result.user, googleUser);
      }
      debugPrint('Login Google gagal: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Setelah link/sign-in Google, User.displayName/photoURL Firebase Auth
  /// kadang masih null (Firebase tidak otomatis menyalin profil provider
  /// saat proses link). Isi manual dari data profil Google kalau memang
  /// kosong, lalu reload supaya currentUser mencerminkan data terbaru.
  Future<User?> _pastikanProfilTerisi(User? user, GoogleSignInAccount googleUser) async {
    if (user == null) return null;

    final perluNama = (user.displayName == null || user.displayName!.isEmpty) &&
        (googleUser.displayName != null && googleUser.displayName!.isNotEmpty);
    final perluFoto = (user.photoURL == null || user.photoURL!.isEmpty) &&
        (googleUser.photoUrl != null && googleUser.photoUrl!.isNotEmpty);

    if (!perluNama && !perluFoto) return user;

    if (perluNama) await user.updateDisplayName(googleUser.displayName);
    if (perluFoto) await user.updatePhotoURL(googleUser.photoUrl);
    await user.reload();
    return _firebaseAuth.currentUser;
  }

  /// Sign out dari Google + Firebase, lalu langsung buat sesi anonymous
  /// baru supaya app tetap bisa dipakai dalam mode "belum login".
  Future<User> signOutAndResetToAnonymous() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _firebaseAuth.signOut();
    return ensureSignedIn();
  }
}
