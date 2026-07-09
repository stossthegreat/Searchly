import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../theme/app_theme.dart';
import '../services/revenuecat_service.dart';

/// Full-screen dark paywall.
class PaywallScreen extends StatefulWidget {
  final String? triggerText;

  const PaywallScreen({super.key, this.triggerText});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _showClose = false;
  bool _annual = true;
  bool _purchasing = false;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showClose = true);
    });
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await RevenueCatService.instance.loadOfferings();
    if (mounted) setState(() => _offerings = offerings);
  }

  Package? _selectedPackage() {
    final current = _offerings?.current;
    if (current == null) return null;
    return _annual ? current.annual : current.monthly;
  }

  Future<void> _handlePurchase() async {
    if (_purchasing) return;
    HapticFeedback.mediumImpact();

    final pkg = _selectedPackage();
    if (pkg == null) {
      _showSnack(
        'Subscriptions are not available right now. Please try again later.',
      );
      return;
    }

    setState(() => _purchasing = true);
    final result = await RevenueCatService.instance.purchase(pkg);
    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (result) {
      case SearchlyPurchaseResult.success:
        _showSnack('Welcome to Searchly Pro!');
        Navigator.of(context).pop(true);
        break;
      case SearchlyPurchaseResult.cancelled:
        // Silent — user backed out.
        break;
      case SearchlyPurchaseResult.notEntitled:
        _showSnack('Purchase completed but entitlement not active yet. '
            'Try Restore Purchase.');
        break;
      case SearchlyPurchaseResult.notConfigured:
        _showSnack('Payments aren\'t configured in this build.');
        break;
      case SearchlyPurchaseResult.error:
        _showSnack('Purchase failed. Please try again.');
        break;
    }
  }

  Future<void> _handleRestore() async {
    HapticFeedback.selectionClick();
    final result = await RevenueCatService.instance.restore();
    if (!mounted) return;
    switch (result) {
      case SearchlyRestoreResult.restored:
        _showSnack('Pro restored. Welcome back!');
        Navigator.of(context).pop(true);
        break;
      case SearchlyRestoreResult.nothingToRestore:
        _showSnack('No previous purchases found on this account.');
        break;
      case SearchlyRestoreResult.notConfigured:
        _showSnack('Payments aren\'t configured in this build.');
        break;
      case SearchlyRestoreResult.error:
        _showSnack('Restore failed. Please try again.');
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          child: Column(
            children: [
              // Close
              Align(
                alignment: Alignment.topRight,
                child: AnimatedOpacity(
                  opacity: _showClose ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    onTap: _showClose ? () => Navigator.pop(context) : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // Logo
              Image.asset('assets/logo.png', width: 72, height: 72),
              const SizedBox(height: 16),
              const Text(
                'Go Pro',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              if (widget.triggerText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.triggerText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _feature(Icons.auto_awesome_rounded,
                  'Unlimited AI searches & meal plans'),
              const SizedBox(height: 14),
              _feature(
                  Icons.tune_rounded, 'Ingredient scaling for any serving size'),
              const SizedBox(height: 14),
              _feature(Icons.menu_book_rounded, 'Unlimited cookbooks'),
              const Spacer(flex: 1),
              // Pricing cards — identical height
              Row(
                children: [
                  Expanded(
                    child: _priceCard(
                      label: 'Monthly',
                      price: '\$4.99',
                      sub: '/month',
                      isSelected: !_annual,
                      onTap: () => setState(() => _annual = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _priceCard(
                      label: 'Annual',
                      price: '\$29.99',
                      sub: '/year',
                      badge: 'SAVE 50%',
                      perDay: '7-day free trial',
                      isSelected: _annual,
                      onTap: () => setState(() => _annual = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _purchasing ? null : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _purchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _annual
                              ? 'Start 7-Day Free Trial'
                              : 'Subscribe — \$4.99/month',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // Free-trial disclaimer (annual only) — required for App Store clarity
              if (_annual)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Free for 7 days, then \$29.99/year. Cancel anytime in your '
                    'App Store settings before the trial ends and you won\'t be charged.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              if (_annual) const SizedBox(height: 8),
              // Restore + legal links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _smallLink('Restore purchase', _handleRestore),
                  _dot(),
                  _smallLink('Terms', () => _showLegal(context, 'terms')),
                  _dot(),
                  _smallLink('Privacy', () => _showLegal(context, 'privacy')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceCard({
    required String label,
    required String price,
    required String sub,
    String? badge,
    String? perDay,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryLight
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                if (badge != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
            if (perDay != null) ...[
              const SizedBox(height: 2),
              Text(
                perDay,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryLight.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _smallLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.35),
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  void _showLegal(BuildContext context, String type) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  type == 'terms' ? 'Terms of Service' : 'Privacy Policy',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  type == 'terms'
                      ? 'By subscribing to Searchly Pro you agree to the terms outlined in our full Terms of Service accessible from the Settings screen. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your device\'s app store settings at any time.'
                      : 'Searchly collects your dietary preferences and recipe data locally on your device. When using AI features, your query and profile context are sent to our secure backend over HTTPS. Audio recordings for voice search are processed and immediately discarded. We do not sell your data. Full privacy policy is accessible from the Settings screen.',
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
    );
  }
}
