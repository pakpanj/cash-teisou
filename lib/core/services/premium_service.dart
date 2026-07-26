import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cash_teisou/core/services/database_service.dart';

class PremiumService {
  // PENTING: product ID ini BELUM didaftarkan di Play Console asli.
  // Perlu dibuat manual dulu di Play Console > Monetize > Products >
  // Subscriptions (dengan ID PERSIS 'premium_bulanan') sebelum fitur
  // pembelian ini benar-benar berfungsi di device asli.
  static const String premiumBulananId = 'premium_bulanan';

  final InAppPurchase _iap = InAppPurchase.instance;
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  String? _userId;

  /// Mulai dengarkan purchaseStream. Panggil sekali saat halaman
  /// Langganan dibuka (bukan di awal app, karena butuh userId).
  void mulaiDengarPembelian({
    required String userId,
    required void Function(String pesan) onError,
  }) {
    _userId = userId;
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _tanganiUpdatePembelian,
      onError: (Object e) => onError('Terjadi kesalahan pada proses pembelian: $e'),
    );
  }

  void berhentiDengar() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  Future<void> _tanganiUpdatePembelian(List<PurchaseDetails> purchases) async {
    final userId = _userId;
    if (userId == null) return;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == premiumBulananId) {
          await _dbService.perbaruiStatusPremium(
            userId,
            isPremium: true,
            premiumExpiresAt: DateTime.now().add(const Duration(days: 30)),
          );
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Pembelian gagal: ${purchase.error}');
      }
    }
  }

  /// Trigger flow pembelian standar in_app_purchase. Karena produk asli
  /// belum terdaftar di Play Console, dibungkus try-catch supaya user
  /// dapat pesan jelas alih-alih crash.
  Future<void> initiateePurchase({required void Function(String pesan) onGagal}) async {
    try {
      final tersedia = await _iap.isAvailable();
      if (!tersedia) {
        onGagal('Fitur pembelian belum aktif, coba lagi nanti.');
        return;
      }

      final response = await _iap.queryProductDetails({premiumBulananId});
      if (response.error != null || response.productDetails.isEmpty) {
        onGagal('Fitur pembelian belum aktif, coba lagi nanti.');
        return;
      }

      final purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
      // Langganan bulanan diperlakukan sebagai non-consumable oleh
      // in_app_purchase (store yang mengurus siklus renewal-nya).
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onGagal('Fitur pembelian belum aktif, coba lagi nanti.');
    }
  }
}
