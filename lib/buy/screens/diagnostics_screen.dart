import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../buy_theme.dart';
import '../decide_service.dart';
import '../../services/app_settings_service.dart';

/// Developer diagnostics for the buying engine. Reachable from the gear icon on
/// the scan home screen. Runs live probes against the backend so you can see
/// whether it's reachable, whether the API keys are valid, and what a real
/// /api/decide call actually returns — instead of guessing why "nothing happens".
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final _urlCtrl = TextEditingController(text: AppSettingsService.instance.backendUrl);
  bool _running = false;
  final List<_Line> _out = [];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _log(String label, String body, {bool ok = true}) {
    setState(() => _out.add(_Line(label, body, ok)));
  }

  Future<void> _saveUrl() async {
    await AppSettingsService.instance.setBackendUrl(_urlCtrl.text.trim());
    _urlCtrl.text = AppSettingsService.instance.backendUrl;
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend set to ${AppSettingsService.instance.backendUrl}')),
    );
    setState(() {});
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _out.clear();
    });

    final base = DecideService.instance.baseUrl;
    _log('Backend URL', base.isEmpty ? '(none configured)' : base, ok: base.isNotEmpty);

    // 1. /health
    final health = await DecideService.instance.ping();
    _log('GET /health · ${health.statusCode ?? 'ERR'} · ${health.durationMs}ms', health.prettyBody, ok: health.ok);

    // 2. /api/diagnose (pings OpenAI + Serper)
    final diag = await DecideService.instance.diagnose();
    _log('GET /api/diagnose · ${diag.statusCode ?? 'ERR'} · ${diag.durationMs}ms', diag.prettyBody, ok: diag.ok);

    // 3. A real decide call
    final result = await DecideService.instance.decide(mode: 'worthit', query: 'sony wh-1000xm5');
    final dbg = DecideService.instance.lastDebug;
    _log(
      'POST /api/decide · ${dbg?.summary ?? '?'}',
      dbg?.isLive == true
          ? 'Product: ${result.identification.productName}\n'
              'Verdict: ${result.verdict.decision} — ${result.verdict.headline}\n'
              'Offers: ${result.offers.length}\n'
              'Evidence-based, live from backend ✅'
          : 'Fell back to DEMO data.\nReason: ${dbg?.error ?? 'unknown'}',
      ok: dbg?.isLive == true,
    );

    if (!mounted) return;
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Buy.ground,
      appBar: AppBar(
        backgroundColor: Buy.ground,
        foregroundColor: Buy.ink,
        elevation: 0,
        title: const Text('Diagnostics', style: TextStyle(fontFamily: 'SF Pro Display', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text('BACKEND URL', style: Buy.label.copyWith(fontSize: 10, letterSpacing: 1.8)),
            const SizedBox(height: 8),
            Container(
              decoration: Buy.glassBox(radius: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(fontFamily: Buy.mono, color: Buy.ink, fontSize: 12.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'https://…up.railway.app',
                        hintStyle: Buy.muted.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _saveUrl, child: const Text('Save', style: TextStyle(color: Buy.cyan, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _running ? null : _runAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Buy.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _running
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Text('▶  Run all checks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Runs /health, /api/diagnose (pings OpenAI + Serper), and a real /api/decide. '
              'If decide falls back to DEMO, the reason is shown below.',
              style: Buy.muted.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 20),
            ..._out.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(_Line l) {
    final color = l.ok ? Buy.good : Buy.bad;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: Buy.glassBox(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(
              children: [
                Icon(l.ok ? Icons.check_circle_rounded : Icons.error_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(l.label, style: TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 12.5, fontWeight: FontWeight.w700))),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: '${l.label}\n${l.body}'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  child: const Icon(Icons.copy_rounded, color: Buy.mut, size: 15),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(l.body, style: const TextStyle(fontFamily: Buy.mono, color: Buy.mut, fontSize: 11.5, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _Line {
  final String label, body;
  final bool ok;
  _Line(this.label, this.body, this.ok);
}
