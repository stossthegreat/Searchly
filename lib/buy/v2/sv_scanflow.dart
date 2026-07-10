import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../decide_service.dart';
import '../screens/diagnostics_screen.dart';
import 'sv_theme.dart';
import 'sv_result.dart';

/// The immersive scan flow: a cinematic "thinking" loader while the backend
/// works, then the verdict. Pushed full-screen so it takes over from the shell.
class ScanFlowScreen extends StatefulWidget {
  final String? query;
  final String? imageB64;
  const ScanFlowScreen({super.key, this.query, this.imageB64});

  @override
  State<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends State<ScanFlowScreen> {
  DecisionResult? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final pending = DecideService.instance.decide(mode: 'worthit', query: widget.query, imageBase64: widget.imageB64);
    final settled = await Future.wait<Object>([
      pending,
      Future.delayed(const Duration(milliseconds: 2100), () => 0),
    ]);
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _result = settled[0] as DecisionResult);

    final dbg = DecideService.instance.lastDebug;
    if (dbg != null && !dbg.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Showing demo — backend not reachable. Tap to diagnose.'),
        backgroundColor: SV.bg2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Debug', textColor: SV.iris, onPressed: _openDiagnostics),
      ));
    }
  }

  void _openDiagnostics() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty || url == '#') return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SV.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _result == null
            ? const ScanLoader(key: ValueKey('loading'))
            : ResultV2(
                key: const ValueKey('result'),
                r: _result!,
                debug: DecideService.instance.lastDebug,
                onBack: () => Navigator.of(context).maybePop(),
                onOpenUrl: _openUrl,
                onDiagnostics: _openDiagnostics,
              ),
      ),
    );
  }
}

/// The cinematic "AI is thinking" loader — rotating gem, filling %, five steps.
class ScanLoader extends StatefulWidget {
  const ScanLoader({super.key});
  @override
  State<ScanLoader> createState() => _ScanLoaderState();
}

class _ScanLoaderState extends State<ScanLoader> with TickerProviderStateMixin {
  static const _steps = [
    'Identifying the product',
    'Reading 9 trusted sources',
    'Checking real prices',
    'Weighing the value',
    'Forming a verdict',
  ];

  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final AnimationController _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 2100))..forward();

  @override
  void dispose() {
    _spin.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SV.bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: SV.irisGlow, blurRadius: 70, spreadRadius: -8)]),
                ),
                RotationTransition(
                  turns: _spin,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(colors: [SV.iris, SV.gem, SV.buy, SV.iris]),
                    ),
                  ),
                ),
                Container(width: 108, height: 108, decoration: BoxDecoration(shape: BoxShape.circle, color: SV.bg, border: Border.all(color: SV.hair))),
                AnimatedBuilder(
                  animation: _fill,
                  builder: (_, __) => Text('${(_fill.value * 100).round()}%', style: SV.price(size: 27, w: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 46),
          AnimatedBuilder(
            animation: _fill,
            builder: (_, __) {
              final active = (_fill.value * _steps.length).floor().clamp(0, _steps.length - 1);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (int i = 0; i < _steps.length; i++) _stepRow(i, active)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stepRow(int i, int active) {
    final done = i < active;
    final on = i == active;
    final color = done ? SV.dim : (on ? SV.ink : SV.faint);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? SV.buy : Colors.transparent,
              border: Border.all(color: done ? SV.buy : (on ? SV.iris : SV.hair), width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 12, color: Color(0xFF03150E)) : null,
          ),
          const SizedBox(width: 13),
          Text(_steps[i], style: TextStyle(fontFamily: SV.font, color: color, fontSize: 14.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
        ],
      ),
    );
  }
}
