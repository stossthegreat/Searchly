import 'dart:ui';
import 'package:flutter/material.dart';

/// Searchly buying-engine design system — deep blue ground, white cards, electric
/// cyan→blue→violet accents. On-blue text is light (Buy.ink family); on-card
/// text is dark (Buy.cardInk family). Opal-grade: glossy, buttery, premium.
class Buy {
  // deep-blue grounds
  static const ground = Color(0xFF071445);
  static const ground2 = Color(0xFF0A1C6B);
  static const elevated = Color(0xFF0E2170); // sheets

  // translucent glass on blue
  static Color glass = Colors.white.withValues(alpha: 0.10);
  static Color glass2 = Colors.white.withValues(alpha: 0.16);
  static Color hair = Colors.white.withValues(alpha: 0.16);
  static Color hair2 = Colors.white.withValues(alpha: 0.24);

  // text ON BLUE (light)
  static const ink = Color(0xFFEAF0FF);
  static const mut = Color(0xFF9DB0E8);
  static const mut2 = Color(0xFF6478B8);

  // white cards + text ON CARD (dark)
  static const card = Colors.white;
  static const cardInk = Color(0xFF0A1440);
  static const cardInk2 = Color(0xFF5A6796);
  static const cardInk3 = Color(0xFF8A95BD);
  static const cardTrack = Color(0xFFE9EDFB);

  // accents
  static const cyan = Color(0xFF38E1FF);
  static const blue = Color(0xFF2E5BFF);
  static const violet = Color(0xFF8B5CFF);

  // semantics
  static const good = Color(0xFF12C48B);
  static const warn = Color(0xFFF7B32B);
  static const bad = Color(0xFFFF5D73);

  static const accentGrad = LinearGradient(colors: [cyan, blue], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const altGrad = LinearGradient(colors: [blue, violet], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const shareGrad = LinearGradient(colors: [Color(0xFF1A3FD0), Color(0xFF5B34E0), Color(0xFFA24BD8)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const verdictBorderGrad = LinearGradient(colors: [cyan, blue, violet], begin: Alignment.topLeft, end: Alignment.bottomRight);

  // type
  static const _sans = 'SF Pro Display';
  static const mono = 'monospace';

  static const h1 = TextStyle(fontFamily: _sans, color: ink, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.15);
  static const body = TextStyle(fontFamily: _sans, color: Color(0xFFD4DEFF), fontSize: 13.5, height: 1.5);
  static const label = TextStyle(fontFamily: _sans, color: mut, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.4);
  static const muted = TextStyle(fontFamily: _sans, color: mut, fontSize: 12.5, height: 1.4);

  static const cardBody = TextStyle(fontFamily: _sans, color: Color(0xFF37436E), fontSize: 13.5, height: 1.55);
  static const cardMuted = TextStyle(fontFamily: _sans, color: cardInk2, fontSize: 12.5, height: 1.4);

  static TextStyle priceStyle(double size, {Color c = ink, FontWeight w = FontWeight.w800}) => TextStyle(
        fontFamily: mono, color: c, fontSize: size, fontWeight: w, letterSpacing: -0.4, fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Translucent glass surface on the blue ground.
  static BoxDecoration glassBox({double radius = 18, Color? border, Color? fill}) => BoxDecoration(
        color: fill ?? glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? hair, width: 1),
      );

  /// Opaque white card with soft depth — the output-card surface.
  static BoxDecoration cardBox({double radius = 20}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: const Color(0xFF040A2D).withValues(alpha: 0.55), blurRadius: 40, spreadRadius: -18, offset: const Offset(0, 22))],
      );

  static Color matchColor(String t) {
    switch (t) {
      case 'exact': return good;
      case 'dupe': return violet;
      case 'budget': return cyan;
      case 'upgrade': return blue;
      default: return cardInk3;
    }
  }
}

/// Frosted-glass wrapper with a real backdrop blur (for on-blue surfaces).
class Frost extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? fill;
  final Color? border;
  const Frost({super.key, required this.child, this.radius = 18, this.blur = 14, this.padding, this.fill, this.border});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(padding: padding, decoration: Buy.glassBox(radius: radius, fill: fill, border: border), child: child),
      ),
    );
  }
}
