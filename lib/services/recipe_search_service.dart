import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recipe_result.dart';
import '../models/week_plan.dart';
import 'user_profile_service.dart';
import 'app_settings_service.dart';

/// Calls the Searchly backend for AI-powered recipe search.
/// Reads the backend URL at call time from AppSettingsService so the user
/// can configure it at runtime in the settings screen.
class RecipeSearchService {
  RecipeSearchService._();
  static final RecipeSearchService instance = RecipeSearchService._();

  String get _backendUrl => AppSettingsService.instance.backendUrl;

  /// Search for recipes matching [query].
  /// Automatically includes the user's profile as context so the agent
  /// respects allergies, diet, dislikes.
  Future<SearchResponse> search(String query) async {
    _assertBackendConfigured();
    final userContext = UserProfileService.instance.profile.toAgentContext();

    final uri = Uri.parse('$_backendUrl/api/search');
    debugPrint('🌐 POST $uri  query="$query"');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'query': query,
              'userContext': userContext,
            }),
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('🌐 ← ${response.statusCode} (${response.body.length} bytes)');
      if (response.statusCode != 200) {
        debugPrint('🌐 ← body: ${response.body}');
        throw RecipeSearchException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response.body),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SearchResponse.fromJson(data);
    } on RecipeSearchException {
      rethrow;
    } catch (e) {
      debugPrint('🌐 ✖ search error: $e');
      throw RecipeSearchException(
        statusCode: 0,
        message: 'Could not reach backend at $_backendUrl.\n${_friendlyNetworkError(e)}',
      );
    }
  }

  /// Generate a meal plan with real recipes for [days] days (1–7).
  Future<WeekPlanResponse> planWeek(String prompt, {int days = 7}) async {
    _assertBackendConfigured();
    final userContext = UserProfileService.instance.profile.toAgentContext();

    final uri = Uri.parse('$_backendUrl/api/plan-week');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'prompt': prompt,
              'userContext': userContext,
              'days': days.clamp(1, 7),
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw RecipeSearchException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response.body),
        );
      }

      return WeekPlanResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on RecipeSearchException {
      rethrow;
    } catch (e) {
      throw RecipeSearchException(
        statusCode: 0,
        message:
            'Could not reach backend at $_backendUrl.\n${_friendlyNetworkError(e)}',
      );
    }
  }

  /// Extract a recipe from a pasted URL via the backend's JSON-LD parser.
  Future<RecipeResult?> parseUrl(String url) async {
    _assertBackendConfigured();
    // Normalize the URL
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.parse('$_backendUrl/api/parse-url');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': cleanUrl}),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 422) {
      // Page fetched but no recipe found
      throw RecipeSearchException(
        statusCode: 422,
        message: 'No recipe found on that page. Try a direct recipe page URL, not a TikTok or Instagram link.',
      );
    }
    if (response.statusCode != 200) {
      final msg = _extractErrorMessage(response.body);
      throw RecipeSearchException(
        statusCode: response.statusCode,
        message: msg,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final recipeData = data['recipe'];
    if (recipeData is Map) {
      return RecipeResult.fromJson(recipeData.cast<String, dynamic>());
    }
    return null;
  }

  /// Quick health check to verify the backend is reachable.
  Future<Map<String, dynamic>> checkHealth() async {
    _assertBackendConfigured();
    final uri = Uri.parse('$_backendUrl/health');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw RecipeSearchException(
        statusCode: response.statusCode,
        message: 'Health check failed',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Deep diagnose — actually tests OpenAI and Serper keys.
  /// Much slower than /health but tells you if the keys actually work.
  Future<Map<String, dynamic>> diagnose() async {
    _assertBackendConfigured();
    final uri = Uri.parse('$_backendUrl/api/diagnose');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw RecipeSearchException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response.body),
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on RecipeSearchException {
      rethrow;
    } catch (e) {
      throw RecipeSearchException(
        statusCode: 0,
        message: _friendlyNetworkError(e),
      );
    }
  }

  void _assertBackendConfigured() {
    if (_backendUrl.isEmpty) {
      throw RecipeSearchException(
        statusCode: 0,
        message: 'Backend URL not set. Open Settings and paste your Railway URL.',
      );
    }
  }

  String _friendlyNetworkError(Object e) {
    final msg = e.toString();
    if (msg.contains('Operation not permitted') || msg.contains('cleartext')) {
      return 'Android is blocking HTTP. Your backend URL must start with https://';
    }
    if (msg.contains('Failed host lookup')) {
      return 'Could not resolve the hostname. Is the URL correct?';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The backend took too long to respond.';
    }
    if (msg.contains('Connection refused')) {
      return 'Connection refused — is the server running?';
    }
    return msg;
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['error'] ?? decoded['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}

class RecipeSearchException implements Exception {
  final int statusCode;
  final String message;

  RecipeSearchException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
