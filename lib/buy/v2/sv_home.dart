import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'sv_theme.dart';
import 'sv_scanflow.dart';

/// Searchly V2 home tab — the AI buying advisor entry. Clean: a signature
/// glowing orb you scan with, a search field, recent/suggested queries.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _recent = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scan({String? query, String? imageB64}) {
    HapticFeedback.mediumImpact();
    if (query != null && query.trim().isNotEmpty) {
      setState(() {
        _recent.remove(query);
        _recent.insert(0, query);
        if (_recent.length > 4) _recent.removeLast();
      });
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanFlowScreen(query: query, imageB64: imageB64),
    ));
  }

  void _submitSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _scan(query: q);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1280, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      _scan(imageB64: base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the camera or library.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        _header(),
        const SizedBox(height: 34),
        Center(child: _orb()),
        const SizedBox(height: 26),
        const Center(child: Text('Scan anything', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4))),
        const SizedBox(height: 6),
        const Center(child: Text('Point at any product for an instant verdict', style: TextStyle(fontFamily: SV.font, color: SV.faint, fontSize: 13.5))),
        const SizedBox(height: 30),
        _searchBar(),
        _recentBlock(),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: SV.iris, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: SV.irisGlow, blurRadius: 20, spreadRadius: -2)])),
              const SizedBox(width: 11),
              const Text('Searchly', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
            ],
          ),
          const SizedBox(height: 26),
          Text('POINT · KNOW · NEVER OVERPAY', style: SV.label(spacing: 2.2)),
          const SizedBox(height: 14),
          const Text('Tell me what\nto buy.', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 40, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.6)),
          Text("I'll stop the mistake.", style: TextStyle(fontFamily: SV.font, color: SV.dim, fontSize: 40, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.6)),
        ],
      ),
    );
  }

  /// The signature Searchly orb — a glowing gem on a soft pedestal glow.
  Widget _orb() {
    return GestureDetector(
      onTap: _showSourceSheet,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ambient glow
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: SV.irisGlow, blurRadius: 100, spreadRadius: -10)]),
            ),
            const _OrbSpin(),
            // gem body
            Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 1.0,
                  colors: [Color(0xFF9AA0FF), Color(0xFF5560E6), Color(0xFF141833)],
                  stops: [0.0, 0.45, 1.0],
                ),
                boxShadow: [BoxShadow(color: Color(0x807C82FF), blurRadius: 50, spreadRadius: -12)],
              ),
            ),
            // glossy top highlight
            Positioned(
              top: 46,
              child: Container(
                width: 120,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
            // core scan glyph
            Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SV.bg.withValues(alpha: 0.42),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    final hasText = _searchCtrl.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 58,
        padding: const EdgeInsets.only(left: 16, right: 6),
        decoration: SV.glass(radius: 18),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 19, color: SV.faint),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submitSearch(),
                textInputAction: TextInputAction.search,
                cursorColor: SV.iris,
                style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15.5),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search anything you want to buy…',
                  hintStyle: TextStyle(fontFamily: SV.font, color: SV.faint, fontSize: 15.5),
                ),
              ),
            ),
            GestureDetector(
              onTap: _submitSearch,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: hasText ? SV.iris : SV.surface, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.arrow_forward_rounded, size: 20, color: hasText ? const Color(0xFF0A0B10) : SV.faint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentBlock() {
    final items = _recent.isNotEmpty ? _recent : const ['AirPods Pro 2', 'Dyson Airwrap', 'iPhone 15'];
    final label = _recent.isNotEmpty ? 'RECENT' : 'TRY';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SV.label(spacing: 1.6)),
          const SizedBox(height: 10),
          for (final q in items)
            GestureDetector(
              onTap: () {
                _searchCtrl.text = q;
                _scan(query: q);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: SV.hair))),
                child: Row(
                  children: [
                    Icon(_recent.isNotEmpty ? Icons.history_rounded : Icons.north_east_rounded, size: 18, color: SV.faint),
                    const SizedBox(width: 14),
                    Expanded(child: Text(q, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 16, fontWeight: FontWeight.w500))),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: SV.faint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: SV.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetBtn(Icons.camera_alt_rounded, 'Take a photo', () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              }),
              const SizedBox(height: 10),
              _sheetBtn(Icons.photo_library_rounded, 'Upload from library', () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBtn(IconData i, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: SV.glass(radius: 14, fill: SV.surface2),
          child: Row(children: [
            Icon(i, color: SV.iris, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// Slow-rotating accent arc behind the orb.
class _OrbSpin extends StatefulWidget {
  const _OrbSpin();
  @override
  State<_OrbSpin> createState() => _OrbSpinState();
}

class _OrbSpinState extends State<_OrbSpin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(colors: [Colors.transparent, Colors.transparent, SV.iris.withValues(alpha: 0.9), SV.gem.withValues(alpha: 0.7), Colors.transparent], stops: const [0.0, 0.55, 0.78, 0.9, 1.0]),
        ),
      ),
    );
  }
}
