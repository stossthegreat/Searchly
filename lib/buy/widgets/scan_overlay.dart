import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../buy_theme.dart';

/// The reasoning-step scan animation. A rotating gradient orb + a filling %
/// core, while 5 steps tick to done, then [onDone]. The "AI is working" moment.
class ScanOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const ScanOverlay({super.key, required this.onDone});
  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay> with TickerProviderStateMixin {
  static const _steps = [
    ('Scanning visual details', Icons.center_focus_strong_rounded),
    ('Identifying the product', Icons.auto_awesome_rounded),
    ('Searching 8 trusted sources', Icons.travel_explore_rounded),
    ('Comparing live prices', Icons.payments_rounded),
    ('Building your verdict', Icons.balance_rounded),
  ];

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) Future.delayed(const Duration(milliseconds: 260), widget.onDone);
    });
    _c.forward();
  }

  void _onTick() {
    final next = (_c.value * _steps.length).floor().clamp(0, _steps.length - 1);
    if (next != _active) {
      setState(() => _active = next);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.25),
              radius: 1.1,
              colors: [Color(0xE6142D82), Color(0xF0060F37)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _orb()),
                const SizedBox(height: 38),
                for (int i = 0; i < _steps.length; i++) _stepRow(i),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orb() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // glow
          Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Buy.cyan.withValues(alpha: 0.5), blurRadius: 60, spreadRadius: -6)],
            ),
          ),
          // rotating gradient blob
          RotationTransition(
            turns: _spin,
            child: Container(
              width: 132, height: 132,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Buy.cyan, Buy.blue, Buy.violet, Color(0xFFFF6FD8), Buy.cyan]),
              ),
            ),
          ),
          // blur the blob edges
          ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: const SizedBox(width: 132, height: 132))),
          // glass core with %
          Container(
            width: 78, height: 78, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Buy.ground.withValues(alpha: 0.72),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Text('${(_c.value * 100).round()}%', style: Buy.priceStyle(21, c: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int i) {
    final done = i < _active;
    final active = i == _active;
    final color = done ? Buy.mut : (active ? Buy.ink : Buy.mut2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? Buy.good : Colors.transparent,
            border: Border.all(color: done ? Buy.good : (active ? Buy.cyan : Buy.hair2), width: 2),
            boxShadow: active ? [BoxShadow(color: Buy.cyan.withValues(alpha: 0.6), blurRadius: 16)] : null,
          ),
          child: Icon(done ? Icons.check_rounded : _steps[i].$2, size: 13, color: done ? const Color(0xFF04140C) : (active ? Buy.cyan : Buy.mut2)),
        ),
        const SizedBox(width: 13),
        Expanded(child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(fontFamily: 'SF Pro Display', color: color, fontSize: 14.5, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
          child: Text(_steps[i].$1),
        )),
      ]),
    );
  }
}
