import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe_result.dart';
import '../theme/app_theme.dart';
import '../widgets/share_recipe_card.dart';

/// Shows a share preview bottom sheet with the branded card,
/// then captures and shares it when the user taps "Share".
/// This approach works reliably on both iOS and Android because
/// the card is actually rendered on screen (images load properly).
class ShareService {
  ShareService._();

  /// Share a single recipe — shows preview, captures, shares.
  static Future<void> shareRecipe(
    BuildContext context,
    RecipeResult recipe,
  ) async {
    final card = ShareRecipeCard(
      title: recipe.title,
      imageUrl: recipe.image,
      source: recipe.source.name,
      rating: recipe.rating.value,
      time: recipe.time.display,
      description: recipe.description.isNotEmpty ? recipe.description : null,
      ingredients: recipe.ingredients.isNotEmpty ? recipe.ingredients : null,
    );

    await _showSharePreview(
      context,
      card: card,
      shareText: '${recipe.title} — found on Searchly',
    );
  }

  /// Share a single recipe from a saved recipe map.
  static Future<void> shareRecipeFromMap(
    BuildContext context,
    Map<String, dynamic> recipe,
  ) async {
    final card = ShareRecipeCard(
      title: recipe['title'] as String? ?? '',
      imageUrl: (recipe['image'] as String?)?.startsWith('http') == true
          ? recipe['image'] as String
          : null,
      localImagePath: (recipe['image'] as String?)?.startsWith('/') == true
          ? recipe['image'] as String
          : null,
      source: recipe['source'] as String? ?? '',
      rating: (recipe['rating'] as num?)?.toDouble() ?? 0.0,
      time: recipe['time'] as String? ?? '',
      ingredients: (recipe['ingredients'] as List?)?.cast<String>(),
    );

    await _showSharePreview(
      context,
      card: card,
      shareText: '${recipe['title']} — found on Searchly',
    );
  }

  /// Share a carousel: cover + recipe cards. Picks recipes → generates
  /// images sequentially → shares all at once.
  static Future<void> shareCarousel(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> recipes,
  }) async {
    // For carousel, generate images one by one using preview captures
    // For now, share as text list + first recipe card
    if (recipes.isEmpty) return;

    // Share the first recipe as the hero card
    final first = recipes.first;
    final card = ShareRecipeCard(
      title: first['title'] as String? ?? '',
      imageUrl: (first['image'] as String?)?.startsWith('http') == true
          ? first['image'] as String
          : null,
      localImagePath: (first['image'] as String?)?.startsWith('/') == true
          ? first['image'] as String
          : null,
      source: first['source'] as String? ?? '',
      rating: (first['rating'] as num?)?.toDouble() ?? 0.0,
      time: first['time'] as String? ?? '',
      ingredients: (first['ingredients'] as List?)?.cast<String>(),
    );

    final mealList = recipes
        .map((r) => '• ${r['title'] ?? 'Untitled'}')
        .join('\n');

    await _showSharePreview(
      context,
      card: card,
      shareText: '$title — ${recipes.length} meals\n\n$mealList\n\nPlanned with Searchly',
    );
  }

  /// Shows a bottom sheet with the card preview + a "Share" button
  /// that captures the visible card and shares it.
  static Future<void> _showSharePreview(
    BuildContext context, {
    required Widget card,
    required String shareText,
  }) async {
    final captureKey = GlobalKey();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
              const SizedBox(height: 16),
              const Text(
                'Share preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              // The card — scaled down for preview, captured at full res
              SizedBox(
                height: 340,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: captureKey,
                    child: card,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final boundary = captureKey.currentContext
                          ?.findRenderObject() as RenderRepaintBoundary?;
                      if (boundary == null) return;

                      final image = await boundary.toImage(pixelRatio: 3.0);
                      final byteData = await image.toByteData(
                        format: ui.ImageByteFormat.png,
                      );
                      if (byteData == null) return;

                      final tempDir = await getTemporaryDirectory();
                      final file = File(
                        '${tempDir.path}/searchly_share_${DateTime.now().millisecondsSinceEpoch}.png',
                      );
                      await file.writeAsBytes(
                        byteData.buffer.asUint8List(),
                      );

                      Navigator.pop(sheetContext); // ignore: use_build_context_synchronously
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        text: shareText,
                      );
                    } catch (e) {
                      debugPrint('Share capture error: $e');
                      // Fallback: share text only
                      Navigator.pop(sheetContext); // ignore: use_build_context_synchronously
                      await Share.share(shareText);
                    }
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Share',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
