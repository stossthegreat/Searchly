import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/recipe_scaler.dart';

/// Persists user-saved recipes across tabs and app restarts.
class SavedRecipesService extends ChangeNotifier {
  SavedRecipesService._();
  static final SavedRecipesService _instance = SavedRecipesService._();
  static SavedRecipesService get instance => _instance;

  static const _storageKey = 'searchly_saved_recipes_v1';

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> get recipes => List.unmodifiable(_recipes);

  int get count => _recipes.length;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        var migrated = false;
        _recipes = list.map((e) {
          final raw = Map<String, dynamic>.from(e as Map);
          if (raw['_normalizedToOne'] == true) return raw;
          migrated = true;
          return normalizeRecipeToOneServing(raw);
        }).toList();
        if (migrated) {
          await _save();
        }
      }
    } catch (_) {
      _recipes = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Map<String, dynamic> recipe) async {
    _recipes.insert(0, normalizeRecipeToOneServing(recipe));
    notifyListeners();
    await _save();
  }

  Future<void> insertAt(int index, Map<String, dynamic> recipe) async {
    final i = index.clamp(0, _recipes.length);
    _recipes.insert(i, normalizeRecipeToOneServing(recipe));
    notifyListeners();
    await _save();
  }

  Future<void> removeAt(int index) async {
    if (index >= 0 && index < _recipes.length) {
      _recipes.removeAt(index);
      notifyListeners();
      await _save();
    }
  }

  Future<void> clear() async {
    _recipes.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_recipes));
    } catch (_) {}
  }
}
