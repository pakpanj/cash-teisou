import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static const String _bannerAdUnitIdTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _bannerAdUnitIdProd = 'ca-app-pub-7168330620893919/5736292385';
  static const String _interstitialAdUnitIdTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String _interstitialAdUnitIdProd = 'ca-app-pub-7168330620893919/3110129045';

  // Test ID resmi Google dipakai di debug mode supaya aman diklik
  // berkali-kali saat development tanpa risiko suspend akun AdMob.
  String get bannerAdUnitId => kDebugMode ? _bannerAdUnitIdTest : _bannerAdUnitIdProd;
  String get interstitialAdUnitId => kDebugMode ? _interstitialAdUnitIdTest : _interstitialAdUnitIdProd;

  int _hitunganInterstitial = 0;
  static const int _setiapKePanggilan = 5;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // Membuat & memuat BannerAd. Return null kalau user premium (tidak pernah
  // lihat iklan). Caller (widget) yang memegang & wajib dispose instance-nya.
  BannerAd? muatBannerAd({
    required bool isPremiumUser,
    required void Function(Ad ad) onAdLoaded,
    required void Function(Ad ad, LoadAdError error) onAdFailedToLoad,
  }) {
    if (isPremiumUser) return null;

    final bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );
    bannerAd.load();
    return bannerAd;
  }

  // Naikkan counter tiap dipanggil, tapi cuma benar-benar load & tampilkan
  // interstitial setiap panggilan ke-5 supaya tidak mengganggu tiap kali
  // user nambah transaksi. isPremiumUser == true -> skip total, counter pun
  // tidak ikut naik.
  void muatDanTampilkanInterstitial({required bool isPremiumUser}) {
    if (isPremiumUser) return;

    _hitunganInterstitial++;
    if (_hitunganInterstitial % _setiapKePanggilan != 0) return;

    _muatDanTampilkanSegera();
  }

  // Tanpa counter/frequency-cap - langsung coba tampilkan tiap dipanggil.
  // Dipakai di titik-titik yang sudah jarang terjadi secara alami (mis.
  // setelah export Excel atau restore backup), bukan aksi rutin sesering
  // nambah transaksi.
  void showInterstitialSegera({required bool isPremiumUser}) {
    if (isPremiumUser) return;
    _muatDanTampilkanSegera();
  }

  void _muatDanTampilkanSegera() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) => ad.dispose(),
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Gagal memuat interstitial ad: $error');
        },
      ),
    );
  }
}
