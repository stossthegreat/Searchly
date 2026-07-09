import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'usage_service.dart';

/// RevenueCat integration for Searchly Pro subscriptions.
///
/// Setup checklist (see /docs/REVENUECAT_SETUP in the repo root or the
/// step-by-step guide provided by Claude):
///
///   1. In RevenueCat dashboard → Project Settings → API Keys:
///        - Copy the PUBLIC "Apple App Store" key  → iosApiKey below
///        - Copy the PUBLIC "Google Play Store" key → androidApiKey below
///
///   2. In RevenueCat → Products:
///        - Create product `searchly_pro_monthly` (link to App Store + Play)
///        - Create product `searchly_pro_annual`  (link to App Store + Play)
///
///   3. In RevenueCat → Entitlements:
///        - Create entitlement with identifier exactly: `pro`
///        - Attach both products to it.
///
///   4. In RevenueCat → Offerings:
///        - The `default` offering should contain two packages:
///            * `$rc_monthly` → searchly_pro_monthly
///            * `$rc_annual`  → searchly_pro_annual
///
/// The app reads whatever offering RevenueCat marks as current, so you can
/// change pricing/trials later without shipping a new build.
class RevenueCatService extends ChangeNotifier {
  RevenueCatService._();
  static final RevenueCatService _instance = RevenueCatService._();
  static RevenueCatService get instance => _instance;

  // ---------------------------------------------------------------------------
  // PASTE YOUR REVENUECAT PUBLIC SDK KEYS HERE
  // (these are safe to ship in the client — they are the "public" keys)
  // ---------------------------------------------------------------------------
  static const String _iosApiKey = 'appl_fljzJSfMZQLirgtUqXYRzsryylx';
  static const String _androidApiKey = 'goog_tfxtzSplaJSUwSaIZndSlgcTXYV';

  /// The entitlement identifier configured in the RevenueCat dashboard.
  /// MUST match exactly (case-sensitive).
  static const String entitlementId = 'pro';

  bool _initialized = false;
  bool get initialized => _initialized;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  /// Best-effort init. Never throws — if keys are missing or the network is
  /// down we just stay in "not-Pro" mode and the paywall falls back gracefully.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;

      if (apiKey.startsWith('appl_YOUR') || apiKey.startsWith('goog_YOUR')) {
        debugPrint('⚠️ RevenueCat keys not configured — skipping init');
        return;
      }

      await Purchases.setLogLevel(
        kDebugMode ? LogLevel.debug : LogLevel.warn,
      );
      await Purchases.configure(PurchasesConfiguration(apiKey));

      // Sync entitlement state from RevenueCat servers to local UsageService.
      await _syncEntitlement();

      // Keep UsageService in sync whenever RevenueCat pushes an update
      // (e.g. renewal, cancellation, family sharing change).
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

      _initialized = true;
      debugPrint('✅ RevenueCat initialized');
    } catch (e) {
      debugPrint('⚠️ RevenueCat init failed: $e');
    }
  }

  Future<void> _syncEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(info);
    } catch (e) {
      debugPrint('⚠️ RevenueCat syncEntitlement failed: $e');
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final active = info.entitlements.active.containsKey(entitlementId);
    if (UsageService.instance.isPro != active) {
      await UsageService.instance.setPro(active);
    }
  }

  /// Loads current offerings. Returns null if RevenueCat isn't configured or
  /// the call fails. Cached after first successful fetch.
  Future<Offerings?> loadOfferings({bool forceRefresh = false}) async {
    if (!_initialized) return null;
    if (_offerings != null && !forceRefresh) return _offerings;
    try {
      _offerings = await Purchases.getOfferings();
      notifyListeners();
      return _offerings;
    } catch (e) {
      debugPrint('⚠️ RevenueCat loadOfferings failed: $e');
      return null;
    }
  }

  /// Purchase a package. Returns SearchlyPurchaseResult with outcome.
  Future<SearchlyPurchaseResult> purchase(Package package) async {
    if (!_initialized) {
      return SearchlyPurchaseResult.notConfigured;
    }
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final active =
          customerInfo.entitlements.active.containsKey(entitlementId);
      if (active) {
        await UsageService.instance.setPro(true);
        return SearchlyPurchaseResult.success;
      }
      return SearchlyPurchaseResult.notEntitled;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return SearchlyPurchaseResult.cancelled;
      }
      debugPrint('⚠️ RevenueCat purchase error: $code / ${e.message}');
      return SearchlyPurchaseResult.error;
    } catch (e) {
      debugPrint('⚠️ RevenueCat purchase error: $e');
      return SearchlyPurchaseResult.error;
    }
  }

  /// Restores prior purchases from the user's App Store / Play account.
  Future<SearchlyRestoreResult> restore() async {
    if (!_initialized) return SearchlyRestoreResult.notConfigured;
    try {
      final info = await Purchases.restorePurchases();
      await _applyCustomerInfo(info);
      final active = info.entitlements.active.containsKey(entitlementId);
      return active ? SearchlyRestoreResult.restored : SearchlyRestoreResult.nothingToRestore;
    } catch (e) {
      debugPrint('⚠️ RevenueCat restore error: $e');
      return SearchlyRestoreResult.error;
    }
  }
}

enum SearchlyPurchaseResult { success, cancelled, notEntitled, notConfigured, error }

enum SearchlyRestoreResult { restored, nothingToRestore, notConfigured, error }
