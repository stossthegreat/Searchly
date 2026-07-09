import 'dart:ui';
import 'package:flutter/material.dart';
import '../buy_theme.dart';

/// Deep-blue mesh ground with slow-drifting cyan / violet / blue glow blobs.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 26))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C2072), Buy.ground, Color(0xFF04102F)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = Curves.easeInOut.transform(_c.value);
                return Stack(children: [
                  _blob(Alignment(-0.85 + t * 0.4, -0.95 + t * 0.3), Buy.cyan, 440),
                  _blob(Alignment(0.95 - t * 0.35, 0.95 - t * 0.4), Buy.violet, 480),
                  _blob(Alignment(0.2 - t * 0.3, 0.15 + t * 0.25), Buy.blue, 360),
                ]);
              },
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }

  Widget _blob(Alignment align, Color color, double size) {
    return Align(
      alignment: align,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 95, sigmaY: 95),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: 0.42), color.withValues(alpha: 0.0)]),
          ),
        ),
      ),
    );
  }
}
