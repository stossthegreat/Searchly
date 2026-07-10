import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/diagnostics_screen.dart';
import '../decide_service.dart';
import '../../services/app_settings_service.dart';
import 'sv_theme.dart';
import 'sv_home.dart';

/// The app shell — three tabs behind a floating glass pill nav (Opal-grade).
class SearchlyShell extends StatefulWidget {
  const SearchlyShell({super.key});
  @override
  State<SearchlyShell> createState() => _SearchlyShellState();
}

class _SearchlyShellState extends State<SearchlyShell> {
  int _index = 0;

  static const _tabs = [
    (Icons.center_focus_strong_rounded, 'Scan'),
    (Icons.bookmark_rounded, 'Saved'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SV.bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [HomeTab(), _SavedTab(), _ProfileTab()],
        ),
      ),
      bottomNavigationBar: _pillNav(),
    );
  }

  Widget _pillNav() {
    // Sits at the very bottom (SafeArea handles the home-indicator inset).
    // Row(center) keeps it horizontally centred WITHOUT expanding vertically —
    // a Center here would stretch the bar to full height and float the pill in
    // the middle of the screen.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14161C).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: SV.hair),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: -6, offset: const Offset(0, 12))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _tabs.length; i++) _navItem(i),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final active = i == _index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _index = i);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: active ? 20 : 18, vertical: 11),
        decoration: BoxDecoration(
          color: active ? SV.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(_tabs[i].$1, size: 20, color: active ? SV.ink : SV.faint),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(_tabs[i].$2, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved verdicts — elite empty state for now.
class _SavedTab extends StatelessWidget {
  const _SavedTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
      children: [
        const SizedBox(height: 4),
        const Text('Saved', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SV.surface, border: Border.all(color: SV.hair)),
                child: const Icon(Icons.bookmark_border_rounded, color: SV.dim, size: 30),
              ),
              const SizedBox(height: 20),
              const Text('No saved verdicts yet', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              const Text('Scan something and tap Share to keep\nthe verdicts that matter.', textAlign: TextAlign.center, style: TextStyle(fontFamily: SV.font, color: SV.faint, fontSize: 13.5, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Profile — identity + a clean route into diagnostics.
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    final backend = AppSettingsService.instance.backendUrl;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
      children: [
        const SizedBox(height: 4),
        const Text('Profile', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: SV.glass(radius: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SV.iris, boxShadow: [BoxShadow(color: SV.irisGlow, blurRadius: 22, spreadRadius: -4)]),
                child: const Icon(Icons.person_rounded, color: Color(0xFF0A0B10), size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your buying advisor', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    SizedBox(height: 4),
                    Text('Point · Know · Buy smarter', style: TextStyle(fontFamily: SV.font, color: SV.faint, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('SYSTEM', style: SV.label(spacing: 1.6)),
        const SizedBox(height: 12),
        _row(context, Icons.wifi_tethering_rounded, 'Diagnostics', 'Test the backend & API keys',
            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen()))),
        _row(context, Icons.dns_rounded, 'Backend', backend.replaceFirst('https://', ''), null),
        _row(context, Icons.verified_user_rounded, 'Status',
            (DecideService.instance.lastDebug?.isLive ?? false) ? 'Live' : 'Not yet checked', null),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String sub, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: SV.glass(radius: 18),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: SV.surface2, border: Border.all(color: SV.hair)),
              child: Icon(icon, size: 19, color: SV.dim),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: SV.font, color: SV.faint, fontSize: 12.5)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: SV.faint),
          ],
        ),
      ),
    );
  }
}
