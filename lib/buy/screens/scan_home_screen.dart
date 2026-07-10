import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../buy_theme.dart';
import '../models.dart';
import '../decide_service.dart';
import '../widgets/aurora_background.dart';
import '../widgets/scan_overlay.dart';
import '../widgets/result_widgets.dart';
import 'diagnostics_screen.dart';

enum _Phase { idle, scanning, result }

class ScanHomeScreen extends StatefulWidget {
  const ScanHomeScreen({super.key});
  @override
  State<ScanHomeScreen> createState() => _ScanHomeScreenState();
}

class _ScanHomeScreenState extends State<ScanHomeScreen> {
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();
  String _mode = 'worthit';
  _Phase _phase = _Phase.idle;
  DecisionResult? _result;
  Future<DecisionResult>? _pending;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _start({String? query, String? imageB64}) {
    HapticFeedback.mediumImpact();
    _pending = DecideService.instance.decide(mode: _mode, query: query, imageBase64: imageB64);
    setState(() => _phase = _Phase.scanning);
  }

  Future<void> _onScanDone() async {
    DecisionResult r;
    try {
      r = await (_pending ?? DecideService.instance.decide(mode: _mode));
    } catch (e) {
      // decide() is designed never to throw, but guard so a failure can never
      // leave the scan overlay stuck on screen forever.
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      _snack('Something went wrong: $e');
      return;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _result = r;
      _phase = _Phase.result;
    });

    // Tell the user when we're showing demo data instead of a live result, so
    // a broken backend is never mistaken for a working one.
    final dbg = DecideService.instance.lastDebug;
    if (dbg != null && !dbg.isLive) {
      _snack('Showing demo — backend not reachable. Tap ⚙ to diagnose.', action: 'Debug', onAction: _openDiagnostics);
    }
  }

  void _snack(String msg, {String? action, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Buy.elevated,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: action != null ? SnackBarAction(label: action, textColor: Buy.cyan, onPressed: onAction ?? () {}) : null,
    ));
  }

  void _openDiagnostics() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
  }

  void _pickMode(String id) {
    setState(() => _mode = id);
    _start(query: _searchCtrl.text.trim().isEmpty ? (_result?.identification.searchSeed) : _searchCtrl.text.trim());
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1280, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      _start(imageB64: base64Encode(bytes));
    } catch (_) {
      _start(query: 'Nike Air Max 90'); // demo-safe fallback
    }
  }

  void _submitSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _start(query: q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Buy.ground,
      body: AuroraBackground(
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _topBar()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _searchField(),
                        const SizedBox(height: 12),
                        _cameraZone(),
                        const SizedBox(height: 14),
                        _modeChips(),
                        const SizedBox(height: 8),
                        if (_phase == _Phase.result && _result != null)
                          _resultView(_result!)
                        else
                          _emptyHint(),
                      ]),
                    ),
                  ),
                ],
              ),
              if (_phase == _Phase.scanning)
                Positioned.fill(child: ScanOverlay(key: UniqueKey(), onDone: _onScanDone)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 18, 16),
      child: Row(
        children: [
          Container(width: 26, height: 26, decoration: BoxDecoration(gradient: Buy.accentGrad, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Buy.blue.withValues(alpha: 0.5), blurRadius: 16)])),
          const SizedBox(width: 10),
          const Text('Searchly', style: TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const Spacer(),
          _iconBtn(Icons.bookmark_border_rounded, onTap: () => _snack('Saved results are coming soon.')),
          const SizedBox(width: 8),
          _iconBtn(Icons.settings_outlined, onTap: _openDiagnostics),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData i, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36, height: 36, alignment: Alignment.center,
          decoration: Buy.glassBox(radius: 11),
          child: Icon(i, size: 17, color: Buy.mut),
        ),
      );

  Widget _searchField() {
    return Container(
      decoration: Buy.glassBox(radius: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 14.5),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              onChanged: (_) => setState(() {}), // toggle the submit button
              cursorColor: Buy.cyan,
              decoration: InputDecoration(
                hintText: 'Search anything you want to buy…',
                hintStyle: Buy.muted.copyWith(fontSize: 14.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Buy.cyan, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
              ),
            ),
          ),
          // Explicit submit button — don't make users hunt for the keyboard's
          // return key (the #1 reason "typing does nothing").
          GestureDetector(
            onTap: _submitSearch,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.fromLTRB(2, 5, 5, 5),
              width: 46,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _searchCtrl.text.trim().isEmpty ? null : Buy.accentGrad,
                color: _searchCtrl.text.trim().isEmpty ? Buy.glass : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: _searchCtrl.text.trim().isEmpty ? Buy.mut2 : const Color(0xFF06121F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraZone() {
    return GestureDetector(
      onTap: () => _showSourceSheet(),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF101020), Color(0xFF0B0B14)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Buy.hair),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(width: 150, height: 150, child: CustomPaint(painter: _ReticlePainter())),
            const Text('👟', style: TextStyle(fontSize: 58)),
            Positioned(
              bottom: 14,
              child: Text('Tap to scan · point at any product', style: Buy.muted.copyWith(fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Buy.elevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetBtn(Icons.camera_alt_rounded, 'Take a photo', () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            }),
            const SizedBox(height: 10),
            _sheetBtn(Icons.photo_library_rounded, 'Upload from library', () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _sheetBtn(IconData i, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: Buy.glassBox(radius: 14, fill: Buy.glass2),
          child: Row(children: [
            Icon(i, color: Buy.cyan, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _modeChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BuyMode.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = BuyMode.all[i];
          final on = m.id == _mode && _phase != _Phase.idle;
          return GestureDetector(
            onTap: () => _pickMode(m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: on ? Buy.accentGrad : null,
                color: on ? null : Buy.glass,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: on ? Colors.transparent : Buy.hair),
                boxShadow: on ? [BoxShadow(color: Buy.blue.withValues(alpha: 0.5), blurRadius: 18, spreadRadius: -6, offset: const Offset(0, 8))] : null,
              ),
              child: Row(children: [
                Text(m.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 7),
                Text(m.label,
                    style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        color: on ? const Color(0xFF06121F) : Buy.mut,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(children: [
        Text('⚖️', style: TextStyle(fontSize: 40, color: Buy.mut2)),
        const SizedBox(height: 14),
        Text('Point. Know. Buy smarter.', style: Buy.h1.copyWith(color: Buy.mut)),
        const SizedBox(height: 8),
        Text('Scan or search anything — Searchly gives you a\ndecision, not ten blue links.',
            textAlign: TextAlign.center, style: Buy.muted.copyWith(height: 1.5)),
      ]),
    );
  }

  Widget _resultView(DecisionResult r) {
    final isAuth = r.authenticity != null;
    final dbg = DecideService.instance.lastDebug;
    return Column(
      key: ValueKey(r.mode + r.identification.productName),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (dbg != null) _sourceBadge(dbg),
        VerdictCard(r: r, onCta: () => _openBestDeal(r)),
        const SizedBox(height: 16),
        if (isAuth) ..._authSection(r) else ..._offerSection(r),
        const SizedBox(height: 16),
        ShareCard(s: r.share),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _shareResult(r),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: Buy.glassBox(radius: 14),
            child: const Text('↗  Share this result',
                style: TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _sourceBadge(DecideDebug dbg) {
    final live = dbg.isLive;
    final color = live ? Buy.good : Buy.warn;
    return GestureDetector(
      onTap: _openDiagnostics,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(live ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 14, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              live ? 'Live result · ${dbg.durationMs}ms' : 'Demo data — backend unreachable · tap to debug',
              style: TextStyle(fontFamily: 'SF Pro Display', color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _offerSection(DecisionResult r) {
    final title = switch (r.mode) {
      'dupes' => 'Dupes & the original',
      'cheaper' => 'Cheapest trusted sellers',
      'better' => 'Better alternatives',
      _ => 'Matches & options',
    };
    return [
      SectionHeader(title, count: '${r.offers.length} found'),
      const SizedBox(height: 10),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: r.offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 11),
          itemBuilder: (_, i) => OfferCard(o: r.offers[i], onTap: () => _openUrl(r.offers[i].url)),
        ),
      ),
      const SizedBox(height: 16),
      ExpertBlock(r: r),
      if (r.verdict.redFlags.isNotEmpty) ...[
        const SizedBox(height: 12),
        ...r.verdict.redFlags.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: FlagRow(f))),
      ],
    ];
  }

  List<Widget> _authSection(DecisionResult r) {
    final a = r.authenticity!;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: Buy.glassBox(radius: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.verdict.reasoning, style: Buy.body),
          const SizedBox(height: 13),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _authList('Looks correct', a.looksCorrect, Buy.good)),
            const SizedBox(width: 9),
            Expanded(child: _authList('Can’t verify', a.cannotVerify, Buy.bad)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      const SectionHeader('📸  Send these to narrow it down'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: a.followUpPhotos
            .map((f) => Container(
                  width: (MediaQuery.of(context).size.width - 36 - 8) / 2,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Buy.glass,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Buy.hair2, style: BorderStyle.solid),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_a_photo_outlined, size: 16, color: Buy.cyan),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: Buy.muted.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ]),
                ))
            .toList(),
      ),
      const SizedBox(height: 12),
      Center(child: Text(a.disclaimer, textAlign: TextAlign.center, style: Buy.muted.copyWith(fontSize: 11, fontStyle: FontStyle.italic, color: Buy.mut2))),
    ];
  }

  Widget _authList(String head, List<String> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(13), border: Border.all(color: Buy.hair)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head.toUpperCase(), style: Buy.label.copyWith(color: color, fontSize: 9.5, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        ...items.map((x) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $x', style: Buy.muted.copyWith(fontSize: 11.5, height: 1.3)),
            )),
      ]),
    );
  }

  void _openBestDeal(DecisionResult r) {
    if (r.offers.isNotEmpty) {
      _openUrl(r.offers.first.url);
    } else {
      _showSourceSheet();
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty || url == '#') return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareResult(DecisionResult r) {
    final s = r.share;
    Share.share('${s.verb} ${s.stat} — ${s.line}\n\n${r.identification.productName} · via Searchly · Point. Know. Buy smarter.');
  }
}

/// Corner-bracket scan reticle.
class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Buy.cyan.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 26.0;
    final w = size.width, h = size.height;
    // TL
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), p);
    // TR
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, len), p);
    // BL
    canvas.drawLine(Offset(0, h - len), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(len, h), p);
    // BR
    canvas.drawLine(Offset(w - len, h), Offset(w, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
