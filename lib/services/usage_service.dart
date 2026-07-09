import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks free-tier usage limits and gates premium features.
///
/// Free tier:
/// - 3 AI agent searches total
/// - 1 AI week plan total
/// - 1 cookbook
/// - Manual everything: unlimited
/// - Ingredient auto-scale: Pro only
///
/// After limits are exhausted, meal planner locks to manual-only.
class UsageService extends ChangeNotifier {
  UsageService._();
  static final UsageService _instance = UsageService._();
  static UsageService get instance => _instance;

  static const _searchCountKey = 'searchly_usage_ai_searches';
  static const _planCountKey = 'searchly_usage_ai_plans';
  static const _isProKey = 'searchly_is_pro';
  static const _hasRatedKey = 'searchly_has_rated';
  static const _totalAiUsesKey = 'searchly_total_ai_uses';

  static const int maxFreeSearches = 3;
  static const int maxFreePlans = 1;
  static const int maxFreeCookbooks = 1;

  int _searchCount = 0;
  int _planCount = 0;
  bool _isPro = false;
  bool _hasRated = false;
  int _totalAiUses = 0;

  bool _loaded = false;
  bool get loaded => _loaded;

  // --- Public getters ---

  bool get isPro => _isPro;
  int get searchesUsed => _searchCount;
  int get plansUsed => _planCount;
  int get totalAiUses => _totalAiUses;
  bool get hasRated => _hasRated;

  int get searchesRemaining => isPro ? 999 : (maxFreeSearches - _searchCount).clamp(0, maxFreeSearches);
  int get plansRemaining => isPro ? 999 : (maxFreePlans - _planCount).clamp(0, maxFreePlans);

  bool get canSearch => isPro || _searchCount < maxFreeSearches;
  bool get canPlanWeek => isPro || _planCount < maxFreePlans;
  bool get canAutoScale => isPro;
  bool get canCreateCookbook => isPro; // beyond the 1st (checked by caller)

  /// True if user has exhausted AI and should see planner in manual-only mode
  bool get aiExhausted => !isPro && _searchCount >= maxFreeSearches && _planCount >= maxFreePlans;

  /// True if we should show the rating popup (after 2nd total AI use, not yet rated)
  bool get shouldShowRating => _totalAiUses >= 2 && !_hasRated;

  // --- Lifecycle ---

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchCount = prefs.getInt(_searchCountKey) ?? 0;
      _planCount = prefs.getInt(_planCountKey) ?? 0;
      _isPro = prefs.getBool(_isProKey) ?? false;
      _hasRated = prefs.getBool(_hasRatedKey) ?? false;
      _totalAiUses = prefs.getInt(_totalAiUsesKey) ?? 0;
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  // --- Record usage ---

  Future<void> recordSearch() async {
    _searchCount++;
    _totalAiUses++;
    notifyListeners();
    await _save();
  }

  Future<void> recordPlan() async {
    _planCount++;
    _totalAiUses++;
    notifyListeners();
    await _save();
  }

  Future<void> markRated() async {
    _hasRated = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  // --- Pro upgrade (placeholder until RevenueCat) ---

  Future<void> setPro(bool value) async {
    _isPro = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProKey, value);
  }

  // --- Reset (for testing / clear data) ---

  Future<void> reset() async {
    _searchCount = 0;
    _planCount = 0;
    _isPro = false;
    _hasRated = false;
    _totalAiUses = 0;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_searchCountKey, _searchCount);
      await prefs.setInt(_planCountKey, _planCount);
      await prefs.setInt(_totalAiUsesKey, _totalAiUses);
    } catch (_) {}
  }
}
