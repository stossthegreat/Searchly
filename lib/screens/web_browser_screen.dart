import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../services/recipe_search_service.dart';
import '../services/saved_recipes_service.dart';

/// In-app web browser with a floating "Save to Searchly" button.
/// User browses recipe sites, taps save, our agent extracts the
/// recipe from whatever page they're on. Like ReciMe's orange button.
class WebBrowserScreen extends StatefulWidget {
  final String? initialSearch;

  const WebBrowserScreen({super.key, this.initialSearch});

  @override
  State<WebBrowserScreen> createState() => _WebBrowserScreenState();
}

class _WebBrowserScreenState extends State<WebBrowserScreen> {
  late final WebViewController _controller;
  String _currentUrl = '';
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final startUrl = widget.initialSearch != null
        ? 'https://www.google.com/search?q=${Uri.encodeQueryComponent('${widget.initialSearch!} recipe')}'
        : 'https://www.google.com';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));
  }

  bool get _isOnRecipeSite {
    if (_currentUrl.isEmpty) return false;
    // Show save button on any page that isn't Google search itself
    return !_currentUrl.contains('google.com/search') &&
        !_currentUrl.contains('google.com/?') &&
        _currentUrl.startsWith('http');
  }

  Future<void> _saveCurrentPage() async {
    if (_currentUrl.isEmpty || _saving) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final recipe =
          await RecipeSearchService.instance.parseUrl(_currentUrl);

      if (!mounted) return;

      if (recipe != null) {
        await SavedRecipesService.instance.add({
          'title': recipe.title,
          'source': recipe.source.name,
          'sourceUrl': recipe.source.url,
          'time': recipe.time.display,
          'emoji': '\u{1F517}',
          'image': recipe.image,
          'rating': recipe.rating.value,
          'ingredients': recipe.ingredients,
          'steps': recipe.instructions,
          'category': 'Saved',
        });
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${recipe.title}" saved!'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No recipe found on this page — try navigating to a recipe page',
            ),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.background,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _loading
                                  ? Icons.hourglass_top_rounded
                                  : Icons.lock_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _currentUrl.isNotEmpty
                                    ? Uri.tryParse(_currentUrl)?.host ?? _currentUrl
                                    : 'Loading...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Loading bar
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              backgroundColor: AppColors.borderLight,
            ),
          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          // Save to Searchly button — shows when on a recipe site
          if (_isOnRecipeSite)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveCurrentPage,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Image.asset(
                            'assets/logo.png',
                            width: 22,
                            height: 22,
                          ),
                    label: Text(
                      _saving ? 'Extracting...' : 'Save to Searchly',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
