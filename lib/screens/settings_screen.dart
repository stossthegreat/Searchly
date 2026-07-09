import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/app_settings_service.dart';
import '../services/recipe_search_service.dart';
import '../services/meal_plan_service.dart';
import '../services/saved_recipes_service.dart';
import '../services/cookbooks_service.dart';
import '../services/usage_service.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserProfile _draft;
  final _nameController = TextEditingController();
  final _backendController = TextEditingController();
  String? _backendStatus;
  bool _backendTesting = false;

  // Common options for chip selectors
  static const _commonAllergies = [
    'Gluten', 'Dairy', 'Nuts', 'Peanuts', 'Shellfish',
    'Eggs', 'Soy', 'Fish', 'Sesame',
  ];

  static const _dietOptions = [
    {'value': 'none', 'label': 'No restriction', 'icon': Icons.restaurant_rounded},
    {'value': 'vegetarian', 'label': 'Vegetarian', 'icon': Icons.eco_rounded},
    {'value': 'vegan', 'label': 'Vegan', 'icon': Icons.grass_rounded},
    {'value': 'pescatarian', 'label': 'Pescatarian', 'icon': Icons.set_meal_rounded},
    {'value': 'keto', 'label': 'Keto', 'icon': Icons.local_fire_department_rounded},
    {'value': 'paleo', 'label': 'Paleo', 'icon': Icons.hiking_rounded},
    {'value': 'gluten-free', 'label': 'Gluten-free', 'icon': Icons.no_food_rounded},
  ];

  static const _cuisines = [
    'Italian', 'Mexican', 'Japanese', 'Chinese', 'Thai',
    'Indian', 'Mediterranean', 'French', 'American', 'Korean',
    'Middle Eastern', 'Greek', 'Spanish', 'Vietnamese', 'Caribbean',
  ];

  static const _cookingSkills = [
    {'value': 'beginner', 'label': 'Beginner'},
    {'value': 'intermediate', 'label': 'Intermediate'},
    {'value': 'advanced', 'label': 'Advanced'},
  ];

  static const _timePrefs = [
    {'value': 'quick', 'label': 'Quick (<30 min)'},
    {'value': 'balanced', 'label': 'Balanced (30-60 min)'},
    {'value': 'any', 'label': 'Any length'},
  ];

  static const _budgetPrefs = [
    {'value': 'budget', 'label': 'Budget'},
    {'value': 'balanced', 'label': 'Balanced'},
    {'value': 'premium', 'label': 'Premium'},
  ];

  @override
  void initState() {
    super.initState();
    _draft = UserProfileService.instance.profile;
    _nameController.text = _draft.name;
    _backendController.text = AppSettingsService.instance.backendUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backendController.dispose();
    super.dispose();
  }

  Future<void> _saveBackendUrl() async {
    await AppSettingsService.instance.setBackendUrl(_backendController.text);
    _backendController.text = AppSettingsService.instance.backendUrl;
    if (!mounted) return;
    setState(() => _backendStatus = null);
    HapticFeedback.lightImpact();
  }

  Future<void> _testBackend() async {
    await _saveBackendUrl();
    if (AppSettingsService.instance.backendUrl.isEmpty) {
      setState(() => _backendStatus = 'Enter a URL first');
      return;
    }
    setState(() {
      _backendTesting = true;
      _backendStatus = null;
    });
    try {
      // Use the deep diagnose endpoint which actually tests the keys
      final result = await RecipeSearchService.instance.diagnose();
      final checks = (result['checks'] as Map?)?.cast<String, dynamic>() ?? {};
      final openai = (checks['openai'] as Map?)?.cast<String, dynamic>() ?? {};
      final serper = (checks['serper'] as Map?)?.cast<String, dynamic>() ?? {};
      final openaiOk = openai['ok'] == true;
      final serperOk = serper['ok'] == true;

      if (openaiOk && serperOk) {
        setState(() => _backendStatus = 'Connected. Agent ready.');
      } else {
        final issues = <String>[];
        if (!openaiOk) {
          issues.add('OpenAI: ${openai['error'] ?? 'failed'}');
        }
        if (!serperOk) {
          issues.add('Serper: ${serper['error'] ?? 'failed'}');
        }
        setState(() => _backendStatus = issues.join('\n'));
      }
    } catch (e) {
      setState(() => _backendStatus = e.toString());
    } finally {
      if (mounted) setState(() => _backendTesting = false);
    }
  }

  Future<void> _save() async {
    await UserProfileService.instance.update(
      _draft.copyWith(name: _nameController.text.trim()),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildIntroCard(),
                  const SizedBox(height: 24),
                  _buildSection(
                    'Allergies',
                    Icons.warning_rounded,
                    _buildChipGrid(
                      options: _commonAllergies,
                      selected: _draft.allergies,
                      onToggle: (item) {
                        setState(() {
                          final list = List<String>.from(_draft.allergies);
                          if (list.contains(item)) {
                            list.remove(item);
                          } else {
                            list.add(item);
                          }
                          _draft = _draft.copyWith(allergies: list);
                        });
                        HapticFeedback.selectionClick();
                      },
                      color: AppColors.error,
                    ),
                    subtitle: 'We will never suggest recipes with these',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Dislikes',
                    Icons.thumb_down_rounded,
                    _buildDislikesInput(),
                    subtitle: 'Foods you\'d rather not eat',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Diet',
                    Icons.restaurant_menu_rounded,
                    _buildDietSelector(),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Favorite Cuisines',
                    Icons.public_rounded,
                    _buildChipGrid(
                      options: _cuisines,
                      selected: _draft.favoriteCuisines,
                      onToggle: (item) {
                        setState(() {
                          final list = List<String>.from(_draft.favoriteCuisines);
                          if (list.contains(item)) {
                            list.remove(item);
                          } else {
                            list.add(item);
                          }
                          _draft = _draft.copyWith(favoriteCuisines: list);
                        });
                        HapticFeedback.selectionClick();
                      },
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Household Size',
                    Icons.group_rounded,
                    _buildHouseholdSize(),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Cooking Skill',
                    Icons.local_dining_rounded,
                    _buildSegmentedSelector(
                      options: _cookingSkills,
                      selected: _draft.cookingSkill,
                      onSelect: (v) {
                        setState(() => _draft = _draft.copyWith(cookingSkill: v));
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Time Preference',
                    Icons.access_time_rounded,
                    _buildSegmentedSelector(
                      options: _timePrefs,
                      selected: _draft.timePreference,
                      onSelect: (v) {
                        setState(() => _draft = _draft.copyWith(timePreference: v));
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Budget',
                    Icons.payments_rounded,
                    _buildSegmentedSelector(
                      options: _budgetPrefs,
                      selected: _draft.budgetPreference,
                      onSelect: (v) {
                        setState(() => _draft = _draft.copyWith(budgetPreference: v));
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildSettingsSectionLabel('Account'),
                  const SizedBox(height: 10),
                  _buildLinkRow(
                    icon: Icons.policy_rounded,
                    color: AppColors.textSecondary,
                    title: 'Terms of Service',
                    onTap: () => _showStaticDoc(
                      title: 'Terms of Service',
                      body: _termsText,
                    ),
                  ),
                  _buildLinkRow(
                    icon: Icons.privacy_tip_rounded,
                    color: AppColors.textSecondary,
                    title: 'Privacy Policy',
                    onTap: () => _showStaticDoc(
                      title: 'Privacy Policy',
                      body: _privacyText,
                    ),
                  ),
                  _buildLinkRow(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                    title: 'About Searchly',
                    trailing: 'v0.1.0',
                    onTap: _showAboutSheet,
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsSectionLabel('Danger Zone'),
                  const SizedBox(height: 10),
                  _buildLinkRow(
                    icon: Icons.cleaning_services_rounded,
                    color: const Color(0xFFFFB300),
                    title: 'Clear all data',
                    subtitle: 'Wipes recipes, plans, profile',
                    onTap: _confirmClearAllData,
                  ),
                  _buildLinkRow(
                    icon: Icons.logout_rounded,
                    color: AppColors.textSecondary,
                    title: 'Sign out',
                    subtitle: 'Local-only — no account yet',
                    onTap: _confirmSignOut,
                  ),
                  _buildLinkRow(
                    icon: Icons.delete_forever_rounded,
                    color: AppColors.error,
                    title: 'Delete account',
                    subtitle: 'Permanently remove all data',
                    onTap: _confirmDeleteAccount,
                    isDanger: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildSaveBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hidden — kept for future developer mode
  // ignore: unused_element
  Widget _buildBackendCard() {
    final isSuccess = _backendStatus?.startsWith('Connected') ?? false;
    final statusColor = _backendStatus == null
        ? null
        : isSuccess
            ? AppColors.primary
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backend URL',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your Railway URL — required for AI search',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _backendController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'https://your-app.up.railway.app',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, color: AppColors.textHint),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _backendController.text = data!.text!;
                    }
                  },
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (_) => setState(() => _backendStatus = null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _backendTesting ? null : _testBackend,
                      icon: _backendTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        _backendTesting ? 'Testing...' : 'Save & Test',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _backendTesting
                        ? null
                        : () async {
                            await AppSettingsService.instance.resetToDefault();
                            _backendController.text =
                                AppSettingsService.instance.backendUrl;
                            setState(() => _backendStatus = null);
                            HapticFeedback.lightImpact();
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_backendStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (statusColor ?? AppColors.textSecondary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (statusColor ?? AppColors.textSecondary).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        _backendStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primarySoft,
              AppColors.primarySoft.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryMuted.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Teach me about you',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The more I know, the better I cook for you.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'What should I call you?',
        hintStyle: TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildChipGrid({
    required List<String> options,
    required List<String> selected,
    required Function(String) onToggle,
    Color? color,
  }) {
    final c = color ?? AppColors.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () => onToggle(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? c.withValues(alpha: 0.12) : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? c.withValues(alpha: 0.5) : AppColors.borderLight,
                width: isSelected ? 1.3 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, size: 14, color: c),
                  const SizedBox(width: 4),
                ],
                Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? c : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDislikesInput() {
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Type and press enter (e.g. "cilantro")',
            hintStyle: TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && !_draft.dislikes.contains(text)) {
                  setState(() {
                    _draft = _draft.copyWith(
                      dislikes: [..._draft.dislikes, text],
                    );
                  });
                  controller.clear();
                  HapticFeedback.lightImpact();
                }
              },
            ),
          ),
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isNotEmpty && !_draft.dislikes.contains(trimmed)) {
              setState(() {
                _draft = _draft.copyWith(
                  dislikes: [..._draft.dislikes, trimmed],
                );
              });
              controller.clear();
              HapticFeedback.lightImpact();
            }
          },
        ),
        if (_draft.dislikes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _draft.dislikes.map((item) {
              return Container(
                padding: const EdgeInsets.only(left: 12, right: 6, top: 7, bottom: 7),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _draft = _draft.copyWith(
                            dislikes: _draft.dislikes.where((d) => d != item).toList(),
                          );
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDietSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _dietOptions.map((opt) {
        final value = opt['value'] as String;
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = _draft.dietaryPreference == value;
        return GestureDetector(
          onTap: () {
            setState(() => _draft = _draft.copyWith(dietaryPreference: value));
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.borderLight,
                width: isSelected ? 1.3 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHouseholdSize() {
    final isPro = UsageService.instance.isPro;
    // Free users are locked to 1. Force the draft to match so the AI and the
    // detail sheet always render 1-serving until they upgrade.
    if (!isPro && _draft.householdSize != 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _draft = _draft.copyWith(householdSize: 1));
        }
      });
    }
    return Column(
      children: [
        Row(
          children: [
            _buildCountButton(
              Icons.remove_rounded,
              () {
                if (!isPro) {
                  _openPaywall();
                  return;
                }
                if (_draft.householdSize > 1) {
                  setState(() =>
                      _draft = _draft.copyWith(householdSize: _draft.householdSize - 1));
                  HapticFeedback.lightImpact();
                }
              },
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '${_draft.householdSize}',
                    key: ValueKey(_draft.householdSize),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isPro ? AppColors.primary : AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
            _buildCountButton(
              isPro ? Icons.add_rounded : Icons.lock_rounded,
              () {
                if (!isPro) {
                  _openPaywall();
                  return;
                }
                if (_draft.householdSize < 12) {
                  setState(() =>
                      _draft = _draft.copyWith(householdSize: _draft.householdSize + 1));
                  HapticFeedback.lightImpact();
                }
              },
            ),
          ],
        ),
        if (!isPro)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Unlock household size 1–12 with Pro',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _openPaywall() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const PaywallScreen(triggerText: 'Household size is a Pro feature'),
      ),
    );
  }

  Widget _buildCountButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector({
    required List<Map<String, String>> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.map((opt) {
          final value = opt['value']!;
          final label = opt['label']!;
          final isSelected = selected == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Account & legal section helpers
  // ==========================================================================

  Widget _buildSettingsSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 20, 0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textHint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLinkRow({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    String? trailing,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDanger
                    ? AppColors.error.withValues(alpha: 0.2)
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDanger
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStaticDoc({required String title, required String body}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Image.asset(
                'assets/logo.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 18),
              const Text(
                'Searchly',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The fastest way to find the right recipe and plan your week.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Built with care.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClearAllData() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all data?'),
        content: const Text(
          'This will remove all saved recipes, meal plans, cookbooks, and your profile. The app will return to a fresh state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await SavedRecipesService.instance.clear();
              await MealPlanService.instance.clear();
              await CookbooksService.instance.delete('');
              for (final cb in CookbooksService.instance.cookbooks.toList()) {
                await CookbooksService.instance.delete(cb.id);
              }
              await UserProfileService.instance.reset();
              if (!context.mounted) return;
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All data cleared'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?'),
        content: const Text(
          'Searchly is local-only right now — there is no cloud account to sign out of. Cloud sign-in is coming soon. For now, this just closes the screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete account?',
          style: TextStyle(color: AppColors.error),
        ),
        content: const Text(
          'This will permanently delete all your data: profile, recipes, meal plans, cookbooks, and settings. You cannot undo this.\n\nTo confirm, you will need to clear data twice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _confirmClearAllData();
            },
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  static const _termsText = 'TERMS OF SERVICE\n'
      'Last updated: April 2026\n\n'
      '1. ACCEPTANCE OF TERMS\n'
      'By downloading, installing, or using the Searchly application '
      '("the App"), you agree to be bound by these Terms of Service '
      '("Terms"). If you do not agree to these Terms, do not use the App.\n\n'
      '2. DESCRIPTION OF SERVICE\n'
      'Searchly is a recipe discovery and meal planning application that '
      'uses artificial intelligence to help users find recipes, plan '
      'weekly meals, and generate grocery lists. The App provides access '
      'to recipes sourced from third-party publishers via web search.\n\n'
      '3. USER ACCOUNTS & DATA\n'
      'Searchly does not currently require account registration. Your '
      'profile information, saved recipes, meal plans, cookbooks, and '
      'grocery lists are stored locally on your device. You are '
      'responsible for maintaining the security of your device and data.\n\n'
      '4. ACCEPTABLE USE\n'
      'You agree to use the App only for its intended purpose of personal '
      'recipe discovery and meal planning. You shall not:\n'
      '• Attempt to reverse-engineer, decompile, or disassemble the App\n'
      '• Use the App to scrape, harvest, or collect data for commercial redistribution\n'
      '• Attempt to disrupt, overload, or interfere with the backend services\n'
      '• Use the App for any unlawful purpose or in violation of any applicable laws\n'
      '• Circumvent any rate limits, access controls, or security measures\n\n'
      '5. THIRD-PARTY CONTENT\n'
      'Recipes displayed in the App are sourced from third-party '
      'publishers and food websites. These recipes remain the '
      'intellectual property of their respective creators and publishers. '
      'Searchly provides links and attribution to original sources. We do '
      'not claim ownership of any third-party recipe content.\n\n'
      '6. AI-GENERATED CONTENT\n'
      'The App uses artificial intelligence (OpenAI) to assist with '
      'query processing, meal plan generation, and voice transcription. '
      'AI-generated suggestions are provided for convenience and should '
      'not be relied upon as medical, nutritional, or dietary advice. '
      'Always verify ingredients for allergens and consult a healthcare '
      'professional for specific dietary needs.\n\n'
      '7. DISCLAIMER OF WARRANTIES\n'
      'The App is provided on an "as is" and "as available" basis '
      'without warranties of any kind, either express or implied, '
      'including but not limited to warranties of merchantability, '
      'fitness for a particular purpose, or non-infringement. We do not '
      'warrant that the App will be uninterrupted, error-free, or free '
      'of harmful components.\n\n'
      '8. LIMITATION OF LIABILITY\n'
      'To the maximum extent permitted by applicable law, in no event '
      'shall Searchly, its developers, or affiliates be liable for any '
      'indirect, incidental, special, consequential, or punitive damages, '
      'including but not limited to loss of data, loss of profits, or '
      'personal injury arising from your use of the App. Our total '
      'liability shall not exceed the amount you paid for the App in '
      'the twelve months preceding the claim.\n\n'
      '9. FOOD SAFETY & ALLERGIES\n'
      'While Searchly respects allergy and dietary preferences you set in '
      'your profile, we cannot guarantee that every recipe suggestion '
      'will be free of allergens or meet specific dietary requirements. '
      'Always read the full ingredient list of any recipe before '
      'preparing food, especially if you or someone you are cooking '
      'for has food allergies or dietary restrictions.\n\n'
      '10. MODIFICATIONS TO TERMS\n'
      'We reserve the right to modify these Terms at any time. Material '
      'changes will be communicated through the App. Your continued use '
      'of the App after such changes constitutes acceptance of the '
      'revised Terms.\n\n'
      '11. TERMINATION\n'
      'We reserve the right to suspend or terminate your access to the '
      'App at any time, with or without cause, and with or without '
      'notice. You may stop using the App at any time by uninstalling '
      'it from your device.\n\n'
      '12. GOVERNING LAW\n'
      'These Terms shall be governed by and construed in accordance '
      'with the laws of the United Kingdom, without regard to conflict '
      'of law principles.\n\n'
      '13. CONTACT\n'
      'For questions about these Terms, contact us at support@searchly.app.';

  static const _privacyText = 'PRIVACY POLICY\n'
      'Last updated: April 2026\n\n'
      'Searchly ("we", "our", "the App") is committed to protecting your '
      'privacy. This Privacy Policy explains what data we collect, how '
      'we use it, and your rights regarding your personal information.\n\n'
      '1. DATA WE COLLECT\n\n'
      'a) Data stored locally on your device:\n'
      '• Profile information: name, dietary preferences, allergies, '
      'dislikes, favourite cuisines, household size, cooking skill, '
      'time and budget preferences\n'
      '• Saved recipes, cookbooks, and meal plans\n'
      '• Grocery lists (both auto-generated and manually created)\n'
      '• App settings and preferences\n'
      '• Photos you add to recipes (stored in app documents directory)\n\n'
      'This data is stored exclusively on your device using local '
      'storage (SharedPreferences and the app documents directory). '
      'It is not uploaded to our servers unless you use a feature that '
      'explicitly requires it.\n\n'
      'b) Data sent to our backend when you use AI features:\n'
      '• Recipe search: your search query text and your profile context '
      '(allergies, diet, dislikes) so the AI respects your preferences\n'
      '• Meal plan generation: your meal plan prompt and profile context\n'
      '• Voice transcription: your audio recording is sent to our '
      'backend, which forwards it to OpenAI Whisper for transcription. '
      'The audio is processed in memory and deleted immediately after '
      'transcription — it is never stored on disk server-side.\n\n'
      '2. HOW WE USE YOUR DATA\n'
      '• To provide personalised recipe recommendations that respect '
      'your allergies, diet, and preferences\n'
      '• To generate meal plans tailored to your household and skill level\n'
      '• To transcribe voice queries into text for recipe search\n'
      '• To auto-generate grocery lists from your planned meals\n'
      '• We do NOT use your data for advertising, profiling, or selling '
      'to third parties\n\n'
      '3. THIRD-PARTY SERVICES\n'
      'When you use AI-powered features, your queries are processed '
      'through the following third-party services:\n\n'
      '• OpenAI (GPT-4o mini, Whisper): processes search queries, '
      'generates meal plans, and transcribes voice input. Subject to '
      'OpenAI\'s usage policies (https://openai.com/policies).\n'
      '• Brave Search / Serper.dev: performs web searches to find '
      'recipes. Only the search query is sent — no personal data.\n\n'
      'These services process data in transit and do not receive your '
      'full profile, stored recipes, or any data beyond what is '
      'described above.\n\n'
      '4. DATA RETENTION\n'
      '• Local data: retained on your device until you delete it via '
      'Settings → Clear all data, or uninstall the App\n'
      '• Server-side: search results are cached in memory for up to '
      '1 hour to improve response times for repeated queries. No '
      'query history, user profiles, or personal data is stored '
      'persistently on our servers.\n'
      '• Voice recordings: processed in real-time and immediately '
      'discarded. Never stored server-side.\n\n'
      '5. DATA SECURITY\n'
      'All communication between the App and our backend is encrypted '
      'using HTTPS/TLS. Local data on your device is protected by '
      'your device\'s built-in security (screen lock, encryption). '
      'We do not have access to your locally stored data.\n\n'
      '6. YOUR RIGHTS\n'
      'You have the right to:\n'
      '• Access all data the App stores about you (it is all on your '
      'device — open Settings to see your profile)\n'
      '• Delete all your data at any time via Settings → Clear all data\n'
      '• Uninstall the App, which removes all locally stored data\n'
      '• Opt out of AI features by simply not using search, meal '
      'planning, or voice input — the App functions in manual mode '
      'without sending any data to our servers\n\n'
      '7. CHILDREN\'S PRIVACY\n'
      'Searchly is not directed at children under 13. We do not knowingly '
      'collect personal information from children. If you are a parent '
      'or guardian and believe your child has provided us with personal '
      'information, please contact us at privacy@searchly.app.\n\n'
      '8. CHANGES TO THIS POLICY\n'
      'We may update this Privacy Policy from time to time. We will '
      'notify you of material changes through the App. Your continued '
      'use of the App after changes constitutes acceptance.\n\n'
      '9. CONTACT US\n'
      'For privacy-related questions or requests:\n'
      'Email: privacy@searchly.app\n\n'
      '10. GDPR & UK DATA PROTECTION\n'
      'If you are located in the European Economic Area or the United '
      'Kingdom, you have additional rights under GDPR / UK GDPR '
      'including the right to access, rectification, erasure, '
      'restriction of processing, data portability, and the right to '
      'object. Since all personal data is stored locally on your device '
      'and we do not maintain server-side user accounts or profiles, '
      'you exercise these rights directly through the App\'s Settings. '
      'For any requests we cannot fulfil through the App, contact '
      'privacy@searchly.app.';
}
