import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cookbook.dart';

/// Persists user-created cookbooks across sessions.
class CookbooksService extends ChangeNotifier {
  CookbooksService._();
  static final CookbooksService _instance = CookbooksService._();
  static CookbooksService get instance => _instance;

  static const _storageKey = 'searchly_cookbooks_v1';

  List<Cookbook> _cookbooks = [];
  List<Cookbook> get cookbooks => List.unmodifiable(_cookbooks);
  int get count => _cookbooks.length;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _cookbooks = list
            .map((e) => Cookbook.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      _cookbooks = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Cookbook? getById(String id) {
    for (final c in _cookbooks) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<Cookbook> create({required String name, String emoji = '\u{1F4D6}'}) async {
    final cookbook = Cookbook(
      id: 'cb_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      recipes: const [],
      createdAt: DateTime.now(),
    );
    _cookbooks.insert(0, cookbook);
    notifyListeners();
    await _save();
    return cookbook;
  }

  Future<void> rename(String id, String newName) async {
    final idx = _cookbooks.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    _cookbooks[idx] = _cookbooks[idx].copyWith(name: newName);
    notifyListeners();
    await _save();
  }

  Future<void> setEmoji(String id, String emoji) async {
    final idx = _cookbooks.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    _cookbooks[idx] = _cookbooks[idx].copyWith(emoji: emoji);
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _cookbooks.removeWhere((c) => c.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> addRecipe(String cookbookId, Map<String, dynamic> recipe) async {
    final idx = _cookbooks.indexWhere((c) => c.id == cookbookId);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(_cookbooks[idx].recipes);
    // Avoid exact duplicates by title
    final title = recipe['title']?.toString() ?? '';
    if (updated.any((r) => (r['title']?.toString() ?? '') == title)) return;
    updated.insert(0, recipe);
    _cookbooks[idx] = _cookbooks[idx].copyWith(recipes: updated);
    notifyListeners();
    await _save();
  }

  Future<void> removeRecipe(String cookbookId, int recipeIndex) async {
    final idx = _cookbooks.indexWhere((c) => c.id == cookbookId);
    if (idx < 0) return;
    final updated = List<Map<String, dynamic>>.from(_cookbooks[idx].recipes);
    if (recipeIndex < 0 || recipeIndex >= updated.length) return;
    updated.removeAt(recipeIndex);
    _cookbooks[idx] = _cookbooks[idx].copyWith(recipes: updated);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cookbooks.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }
}
