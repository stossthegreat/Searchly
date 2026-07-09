import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planned_meal.dart';
import '../models/recipe_result.dart';
import 'grocery_service.dart';

/// Persists the 7-day meal plan across tabs and app restarts.
/// Keys use format: "Mon_Breakfast", "Tue_Lunch", etc.
/// Values are PlannedMeal objects so we can attach full recipe data
/// when the AI agent returns it.
class MealPlanService extends ChangeNotifier {
  MealPlanService._();
  static final MealPlanService _instance = MealPlanService._();
  static MealPlanService get instance => _instance;

  static const _storageKey = 'searchly_meal_plan_v1';

  Map<String, PlannedMeal> _meals = {};
  Map<String, PlannedMeal> get meals => Map.unmodifiable(_meals);

  bool _loaded = false;
  bool get loaded => _loaded;

  int get count => _meals.length;

  PlannedMeal? get(String key) => _meals[key];
  String? getName(String key) => _meals[key]?.name;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _meals = map.map((k, v) => MapEntry(k, PlannedMeal.fromStored(v)));
      }
    } catch (_) {
      _meals = {};
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMeal(String key, String name, {RecipeResult? recipe}) async {
    _meals[key] = PlannedMeal(name: name, recipe: recipe);
    notifyListeners();
    await _save();

    // Auto-grocery: if this meal has a real recipe with ingredients,
    // populate them into the grocery list tagged with this meal slot.
    // If a previous meal had auto-grocery items here they get replaced.
    if (recipe != null && recipe.ingredients.isNotEmpty) {
      await GroceryService.instance.addFromMeal(
        mealKey: key,
        mealName: name,
        ingredients: recipe.ingredients,
      );
    } else {
      // No recipe (manual meal) — clean any leftover auto items from
      // a previous recipe-backed meal in this slot
      await GroceryService.instance.removeByMealKey(key);
    }
  }

  /// Replace the whole week atomically. Used by the AI week planner
  /// so all 21 meals appear at once instead of 21 separate updates.
  Future<void> setAll(Map<String, PlannedMeal> meals) async {
    _meals = Map<String, PlannedMeal>.from(meals);
    notifyListeners();
    await _save();

    // Wipe all previous auto-grocery items, then add fresh ones for
    // every meal in the new plan that has a recipe attached
    await GroceryService.instance.clearAuto();
    for (final entry in _meals.entries) {
      final recipe = entry.value.recipe;
      if (recipe != null && recipe.ingredients.isNotEmpty) {
        await GroceryService.instance.addFromMeal(
          mealKey: entry.key,
          mealName: entry.value.name,
          ingredients: recipe.ingredients,
        );
      }
    }
  }

  Future<void> removeMeal(String key) async {
    _meals.remove(key);
    notifyListeners();
    await _save();
    // Clean up any auto-grocery items from this slot
    await GroceryService.instance.removeByMealKey(key);
  }

  Future<void> clear() async {
    _meals.clear();
    notifyListeners();
    await _save();
    // All auto items came from cleared meals — wipe them
    await GroceryService.instance.clearAuto();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonMap = _meals.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString(_storageKey, jsonEncode(jsonMap));
    } catch (_) {}
  }
}
