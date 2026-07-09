import 'dart:convert';

/// Represents everything Searchly knows about the user.
/// This is sent as context on every agent query to personalize results.
class UserProfile {
  final String name;
  final List<String> allergies;
  final List<String> dislikes;
  final String dietaryPreference; // 'none', 'vegetarian', 'vegan', 'pescatarian', 'keto', 'paleo', 'gluten-free'
  final List<String> favoriteCuisines;
  final int householdSize;
  final String cookingSkill; // 'beginner', 'intermediate', 'advanced'
  final String timePreference; // 'quick' (<30min), 'balanced' (30-60min), 'any'
  final String budgetPreference; // 'budget', 'balanced', 'premium'

  const UserProfile({
    this.name = '',
    this.allergies = const [],
    this.dislikes = const [],
    this.dietaryPreference = 'none',
    this.favoriteCuisines = const [],
    this.householdSize = 2,
    this.cookingSkill = 'intermediate',
    this.timePreference = 'balanced',
    this.budgetPreference = 'balanced',
  });

  /// Is the profile set up enough for personalized results?
  bool get isConfigured => name.isNotEmpty || allergies.isNotEmpty ||
      dislikes.isNotEmpty || dietaryPreference != 'none' ||
      favoriteCuisines.isNotEmpty;

  UserProfile copyWith({
    String? name,
    List<String>? allergies,
    List<String>? dislikes,
    String? dietaryPreference,
    List<String>? favoriteCuisines,
    int? householdSize,
    String? cookingSkill,
    String? timePreference,
    String? budgetPreference,
  }) {
    return UserProfile(
      name: name ?? this.name,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      favoriteCuisines: favoriteCuisines ?? this.favoriteCuisines,
      householdSize: householdSize ?? this.householdSize,
      cookingSkill: cookingSkill ?? this.cookingSkill,
      timePreference: timePreference ?? this.timePreference,
      budgetPreference: budgetPreference ?? this.budgetPreference,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'allergies': allergies,
        'dislikes': dislikes,
        'dietaryPreference': dietaryPreference,
        'favoriteCuisines': favoriteCuisines,
        'householdSize': householdSize,
        'cookingSkill': cookingSkill,
        'timePreference': timePreference,
        'budgetPreference': budgetPreference,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        allergies: List<String>.from(json['allergies'] ?? []),
        dislikes: List<String>.from(json['dislikes'] ?? []),
        dietaryPreference: json['dietaryPreference'] ?? 'none',
        favoriteCuisines: List<String>.from(json['favoriteCuisines'] ?? []),
        householdSize: json['householdSize'] ?? 2,
        cookingSkill: json['cookingSkill'] ?? 'intermediate',
        timePreference: json['timePreference'] ?? 'balanced',
        budgetPreference: json['budgetPreference'] ?? 'balanced',
      );

  String toJsonString() => jsonEncode(toJson());

  factory UserProfile.fromJsonString(String jsonStr) =>
      UserProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  /// Builds a natural-language context string that gets sent to the AI agent
  /// on every query. This is how the agent "knows" the user.
  String toAgentContext() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('User name: $name');
    parts.add('Household size: $householdSize');
    parts.add('Cooking skill: $cookingSkill');
    parts.add('Time preference: $timePreference meals');
    parts.add('Budget: $budgetPreference');
    if (dietaryPreference != 'none') {
      parts.add('Diet: $dietaryPreference');
    }
    if (allergies.isNotEmpty) {
      parts.add('MUST AVOID (allergies): ${allergies.join(', ')}');
    }
    if (dislikes.isNotEmpty) {
      parts.add('Dislikes: ${dislikes.join(', ')}');
    }
    if (favoriteCuisines.isNotEmpty) {
      parts.add('Favorite cuisines: ${favoriteCuisines.join(', ')}');
    }
    return parts.join('\n');
  }
}
