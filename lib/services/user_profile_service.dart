import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Singleton service that manages the user's profile.
/// Uses ChangeNotifier so any widget can listen to profile updates.
class UserProfileService extends ChangeNotifier {
  UserProfileService._();
  static final UserProfileService _instance = UserProfileService._();
  static UserProfileService get instance => _instance;

  static const _storageKey = 'searchly_user_profile_v1';

  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Load profile from disk. Call once on app startup.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _profile = UserProfile.fromJsonString(jsonStr);
      }
    } catch (_) {
      // If decoding fails, keep default empty profile
      _profile = const UserProfile();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Update profile and persist to disk.
  Future<void> update(UserProfile newProfile) async {
    _profile = newProfile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, _profile.toJsonString());
    } catch (_) {
      // Silent fail — UI already updated
    }
  }

  /// Reset to default empty profile.
  Future<void> reset() async {
    _profile = const UserProfile();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
