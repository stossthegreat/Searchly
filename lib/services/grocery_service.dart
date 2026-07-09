import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grocery_item.dart';
import 'ingredient_categorizer.dart';

/// Persistent grocery list with auto-population from planned meals.
///
/// Items either come from a meal in the planner (and carry the meal key
/// so we can clean them up when the meal is removed) or are added manually
/// by the user. Manual items are never auto-removed.
class GroceryService extends ChangeNotifier {
  GroceryService._();
  static final GroceryService _instance = GroceryService._();
  static GroceryService get instance => _instance;

  static const _storageKey = 'searchly_grocery_v1';

  List<GroceryItem> _items = [];
  List<GroceryItem> get items => List.unmodifiable(_items);

  int get count => _items.length;
  int get checkedCount => _items.where((i) => i.checked).length;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items = list
            .map((e) => GroceryItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      _items = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Add a manual item (not tied to any meal)
  Future<void> addManual({
    required String name,
    required String category,
  }) async {
    final item = GroceryItem(
      id: 'g_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      checked: false,
    );
    _items.add(item);
    notifyListeners();
    await _save();
  }

  /// Add all ingredients from a meal recipe in one batch.
  /// Each ingredient is auto-categorized and tagged with the meal key
  /// so it can be cleaned up later if the meal is removed.
  Future<void> addFromMeal({
    required String mealKey,
    required String mealName,
    required List<String> ingredients,
  }) async {
    if (ingredients.isEmpty) return;

    // Remove any existing auto items from this same slot first so we
    // don't accumulate dupes when a meal is replaced
    _items.removeWhere((item) => item.sourceMealKey == mealKey);

    var counter = DateTime.now().microsecondsSinceEpoch;
    for (final ingredient in ingredients) {
      final trimmed = ingredient.trim();
      if (trimmed.isEmpty) continue;

      // Smart merge: check if an existing auto item has the same core
      // ingredient. If so, skip adding a duplicate.
      final normalized = _normalizeIngredient(trimmed);
      final existingIndex = _items.indexWhere(
        (i) => i.isAuto && _normalizeIngredient(i.name) == normalized,
      );

      if (existingIndex >= 0) {
        // Same ingredient already exists from another meal — keep the
        // existing one but note both meals use it
        final existing = _items[existingIndex];
        final combinedSource = existing.sourceMealName != null &&
                !existing.sourceMealName!.contains(mealName)
            ? '${existing.sourceMealName} + $mealName'
            : existing.sourceMealName ?? mealName;
        _items[existingIndex] = existing.copyWith(
          sourceMealName: combinedSource,
        );
      } else {
        _items.add(
          GroceryItem(
            id: 'g_${counter++}',
            name: trimmed,
            category: IngredientCategorizer.categorize(trimmed),
            checked: false,
            sourceMealKey: mealKey,
            sourceMealName: mealName,
          ),
        );
      }
    }
    notifyListeners();
    await _save();
  }

  /// Strip quantities and normalize for dedup comparison.
  /// "2 cups flour" → "flour"
  /// "1 large lemon, juiced" → "large lemon juiced"
  /// "salt and pepper" → "salt and pepper"
  String _normalizeIngredient(String ingredient) {
    var s = ingredient.toLowerCase().trim();
    // Strip leading numbers, fractions, units
    s = s.replaceAll(RegExp(r'^[\d\s/.½¼¾⅓⅔]+'), '');
    // Strip common units
    s = s.replaceAll(
      RegExp(
        r'\b(cups?|tablespoons?|tbsp|teaspoons?|tsp|ounces?|oz|pounds?|lbs?|grams?|g|ml|liters?|l|pinch|dash|cloves?|cans?|packages?|bunch|head|stalk|medium|large|small)\b',
      ),
      '',
    );
    // Strip punctuation, collapse spaces
    s = s.replaceAll(RegExp(r'[,.()\-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Remove all auto items tied to a specific meal slot.
  /// Called by MealPlanService when a meal is removed.
  Future<void> removeByMealKey(String mealKey) async {
    final before = _items.length;
    _items.removeWhere((item) => item.sourceMealKey == mealKey);
    if (_items.length != before) {
      notifyListeners();
      await _save();
    }
  }

  /// Remove ALL auto items (any item with a sourceMealKey).
  /// Called when the meal plan is cleared or replaced wholesale.
  Future<void> clearAuto() async {
    final before = _items.length;
    _items.removeWhere((item) => item.isAuto);
    if (_items.length != before) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> toggle(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx < 0) return;
    _items[idx] = _items[idx].copyWith(checked: !_items[idx].checked);
    notifyListeners();
    await _save();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> clearChecked() async {
    _items.removeWhere((i) => i.checked);
    notifyListeners();
    await _save();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _save();
  }

  /// Insert at a specific position — used to undo a swipe-to-delete.
  Future<void> insertAt(int index, GroceryItem item) async {
    final i = index.clamp(0, _items.length);
    _items.insert(i, item);
    notifyListeners();
    await _save();
  }

  /// All items in a given category (for grouped display)
  List<GroceryItem> itemsForCategory(String category) {
    return _items.where((i) => i.category == category).toList();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(_items.map((i) => i.toJson()).toList()),
      );
    } catch (_) {}
  }
}
