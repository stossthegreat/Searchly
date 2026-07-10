import 'dart:ui';
import 'package:flutter/material.dart';

/// Searchly V2 design system — one committed cinematic dark world.
/// Cool near-black grounds, a single quiet iris brand accent, and semantic
/// verdict colours that carry all the emotional weight. Apple × Perplexity.
class SV {
  // grounds
  static const bg = Color(0xFF08090C);
  static const bg1 = Color(0xFF0E1014);
  static const bg2 = Color(0xFF141821);

  // glass surfaces on the dark ground
  static final surface = Colors.white.withValues(alpha: 0.045);
  static final surface2 = Colors.white.withValues(alpha: 0.075);
  static final hair = Colors.white.withValues(alpha: 0.09);
  static final hairBright = Colors.white.withValues(alpha: 0.17);

  // text
  static const ink = Color(0xFFF4F6FA);
  static const dim = Color(0xFFA6ADBB);
  static const faint = Color(0xFF5C6470);

  // brand accent (interactive only — CTA, links, focus)
  static const iris = Color(0xFF7C82FF);
  static final irisGlow = const Color(0xFF7C82FF).withValues(alpha: 0.45);

  // semantic verdict palette
  static const buy = Color(0xFF35D6A4); // Worth It / Buy
  static const skip = Color(0xFFFF6B6B); // Skip / Avoid
  static const wait = Color(0xFFFFB020); // Wait / Check
  static const over = Color(0xFFFF8A3D); // Overpriced
  static const gem = Color(0xFF37D0E0); // Hidden Gem
  static const best = Color(0xFFE8B93B); // Best in Class

  // type — 'SF Pro Display' resolves to San Francisco on Apple devices.
  static const font = 'SF Pro Display';
  static const mono = 'monospace';

  static const TextStyle display = TextStyle(
      fontFamily: font, color: ink, fontSize: 34, height: 1.04, fontWeight: FontWeight.w700, letterSpacing: -1.1);
  static const TextStyle h2 = TextStyle(
      fontFamily: font, color: ink, fontSize: 27, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -0.8);
  static const TextStyle body = TextStyle(
      fontFamily: font, color: ink, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500, letterSpacing: -0.1);
  static const TextStyle bodyDim = TextStyle(
      fontFamily: font, color: dim, fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w400);

  /// Uppercase mono eyebrow / label.
  static TextStyle label({Color? color, double size = 11, double spacing = 1.6}) => TextStyle(
      fontFamily: mono, color: color ?? faint, fontSize: size, letterSpacing: spacing, fontWeight: FontWeight.w500);

  /// Tabular mono for prices and figures.
  static TextStyle price({Color color = ink, double size = 20, FontWeight w = FontWeight.w700}) => TextStyle(
      fontFamily: mono, color: color, fontSize: size, fontWeight: w, letterSpacing: -0.3,
      fontFeatures: const [FontFeature.tabularFigures()]);

  /// Glass card surface.
  static BoxDecoration glass({double radius = 18, Color? fill, Color? border}) => BoxDecoration(
        color: fill ?? surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? hair, width: 1),
      );

  /// Tint a semantic colour at [a] opacity — used for verdict washes.
  static Color tint(Color c, double a) => c.withValues(alpha: a);
}
