import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-bleed 9:16 share card designed for Instagram Stories and TikTok.
/// The food photo IS the card. Everything else is just a subtle overlay.
/// No borders, no boxes, no menu layout — just photography + type.
class ShareRecipeCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? localImagePath;
  final String source;
  final double rating;
  final String time;
  final String? calories;
  final String? description;
  final List<String>? ingredients;

  const ShareRecipeCard({
    super.key,
    required this.title,
    required this.source,
    required this.rating,
    required this.time,
    this.imageUrl,
    this.localImagePath,
    this.calories,
    this.description,
    this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080 / 3,
      height: 1920 / 3,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(0),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // FULL-BLEED FOOD PHOTO — the hero, the whole card
          Positioned.fill(
            child: _buildFullBleedImage(),
          ),

          // DARK GRADIENT OVERLAY — bottom third only, for text legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // TOP — tiny Searchly mark, rating pill
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Searchly logo + name — frosted pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'searchly',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Rating pill
                if (rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // BOTTOM — title + details on the dark gradient
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recipe title — big, bold, max impact
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        blurRadius: 20,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Description or ingredients teaser
                Builder(builder: (_) {
                  String text = '';
                  if (description != null && description!.isNotEmpty) {
                    text = description!;
                  } else if (ingredients != null &&
                      ingredients!.isNotEmpty) {
                    text = ingredients!
                        .take(3)
                        .map((i) =>
                            i.length > 35 ? '${i.substring(0, 35)}...' : i)
                        .join('  ·  ');
                  }
                  if (text.isEmpty) return const SizedBox.shrink();
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
                const SizedBox(height: 12),
                // Meta row — time + source in a clean row
                Row(
                  children: [
                    if (time.isNotEmpty) ...[
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (source.isNotEmpty)
                      Expanded(
                        child: Text(
                          source,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBleedImage() {
    if (localImagePath != null &&
        localImagePath!.isNotEmpty &&
        File(localImagePath!).existsSync()) {
      return Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
      );
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A3A1A),
            Color(0xFF0D1F0D),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cover card for a carousel share.
class ShareCarouselCover extends StatelessWidget {
  final String title;
  final int mealCount;
  final List<String> mealNames;

  const ShareCarouselCover({
    super.key,
    required this.title,
    required this.mealCount,
    required this.mealNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080 / 3,
      height: 1920 / 3,
      color: const Color(0xFF0D1F0D),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Logo
            Row(
              children: [
                Image.asset('assets/logo.png', width: 28, height: 28),
                const SizedBox(width: 8),
                Text(
                  'searchly',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Spacer(flex: 2),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$mealCount meals',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Meal list
            ...mealNames.take(7).map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (mealNames.length > 7)
              Text(
                '+${mealNames.length - 7} more',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
