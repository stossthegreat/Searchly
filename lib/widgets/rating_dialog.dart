import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/usage_service.dart';

/// Beautiful rating popup. Stars + optional feedback.
/// - 4-5 stars → opens App Store/Play Store review
/// - 1-3 stars → shows feedback text field (keeps bad reviews internal)
///
/// Call `showRatingDialog(context)` after the 2nd AI use.
Future<void> showRatingDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RatingDialog(),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _stars = 0;
  bool _showFeedback = false;
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await UsageService.instance.markRated();
    HapticFeedback.lightImpact();

    if (_stars >= 4) {
      // High rating → try to open the app store
      if (!mounted) return;
      Navigator.pop(context);
      // TODO: Replace with actual store URLs when published
      try {
        await launchUrl(
          Uri.parse('market://details?id=com.searchly.searchly'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // Store not available (e.g. emulator) — that's fine
      }
    } else if (_stars >= 1 && !_showFeedback) {
      // Low rating → show feedback field first
      setState(() => _showFeedback = true);
    } else {
      // Feedback submitted (or dismissed)
      if (!mounted) return;
      Navigator.pop(context);
      // TODO: Send feedback to backend or analytics
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thanks for your feedback'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Image.asset(
              'assets/logo.png',
              width: 60,
              height: 60,
            ),
            const SizedBox(height: 18),
            // Title
            const Text(
              'Enjoying Searchly?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your feedback helps us make cooking easier for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isFilled = starIndex <= _stars;
                return GestureDetector(
                  onTap: () {
                    setState(() => _stars = starIndex);
                    HapticFeedback.selectionClick();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: isFilled ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isFilled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: isFilled
                            ? AppColors.star
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                );
              }),
            ),
            // Feedback field (only for low ratings)
            if (_showFeedback) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What can we do better?',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: () async {
                        await UsageService.instance.markRated();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _stars > 0 ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.borderLight,
                        disabledForegroundColor: AppColors.textHint,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _showFeedback ? 'Send' : 'Submit',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
