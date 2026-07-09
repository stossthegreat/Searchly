import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'buy/screens/scan_home_screen.dart';
import 'screens/home_screen.dart';
import 'screens/planner_screen.dart';
import 'screens/grocery_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_profile_service.dart';
import 'services/meal_plan_service.dart';
import 'services/saved_recipes_service.dart';
import 'services/app_settings_service.dart';
import 'services/cookbooks_service.dart';
import 'services/grocery_service.dart';
import 'services/usage_service.dart';
import 'services/analytics_service.dart';
import 'services/revenuecat_service.dart';

void main() async {
  // Catch ALL flutter errors — never show red screen to users
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ FLUTTER ERROR: ${details.exception}');
    debugPrint('❌ STACK: ${details.stack}');
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase — graceful fallback if config is missing
    // (e.g. iOS without GoogleService-Info.plist)
    bool firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      debugPrint('✅ Firebase initialized');
    } catch (e) {
      debugPrint('⚠️ Firebase init failed (app continues without analytics): $e');
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // dark buying-engine UI
      ),
    );

    // Load all services + check onboarding status in parallel
    late final bool onboardingSeen;
    await Future.wait([
      UserProfileService.instance.load(),
      MealPlanService.instance.load(),
      SavedRecipesService.instance.load(),
      AppSettingsService.instance.load(),
      CookbooksService.instance.load(),
      GroceryService.instance.load(),
      UsageService.instance.load(),
      OnboardingScreen.hasBeenSeen().then((v) => onboardingSeen = v),
    ]);
    debugPrint('✅ All services loaded');

    // Initialize RevenueCat after UsageService so the entitlement sync has
    // somewhere to write. Runs in the background — never blocks app start.
    // ignore: discarded_futures
    RevenueCatService.instance.init();

    // Log app open
    if (firebaseReady) {
      try {
        AnalyticsService.instance.logAppOpen();
      } catch (_) {}
    }

    // Replace red error screens with invisible widgets in production
    ErrorWidget.builder = (FlutterErrorDetails details) {
      debugPrint('❌ Widget build error: ${details.exception}');
      return const SizedBox.shrink();
    };

    runApp(SearchlyApp(
      showOnboarding: !onboardingSeen,
      firebaseReady: firebaseReady,
    ));
  } catch (e, stack) {
    // App crashed during init — show error on screen instead of white death
    debugPrint('❌ CRITICAL INIT CRASH: $e');
    debugPrint('❌ STACK: $stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ APP INIT CRASHED',
                  style: TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  style: const TextStyle(
                    color: Color(0xFFFF4444),
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  stack.toString().split('\n').take(10).join('\n'),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class SearchlyApp extends StatelessWidget {
  final bool showOnboarding;
  final bool firebaseReady;

  const SearchlyApp({
    super.key,
    required this.showOnboarding,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Searchly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorObservers:
          firebaseReady ? [AnalyticsService.instance.observer] : [],
      // Searchly buying engine is now the app entry point.
      home: const ScanHomeScreen(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    PlannerScreen(),
    GroceryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                    0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _buildNavItem(1, Icons.calendar_month_rounded,
                    Icons.calendar_month_outlined, 'Plan'),
                _buildNavItem(2, Icons.shopping_cart_rounded,
                    Icons.shopping_cart_outlined, 'Groceries'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        HapticFeedback.selectionClick();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppColors.primary : AppColors.textHint,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
