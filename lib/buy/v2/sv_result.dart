import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../decide_service.dart';
import 'sv_theme.dart';
import 'sv_verdict.dart';

/// The verdict-first result screen. Product plate → name → one huge verdict
/// card → why → alternatives → buy-or-wait → one-sentence summary → share.
class ResultV2 extends StatelessWidget {
  final DecisionResult r;
  final DecideDebug? debug;
  final VoidCallback onBack;
  final void Function(String url) onOpenUrl;
  final VoidCallback onDiagnostics;

  const ResultV2({
    super.key,
    required this.r,
    required this.debug,
    required this.onBack,
    required this.onOpenUrl,
    required this.onDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final v = verdictStyleFor(r);
    final reasons = reasonsFor(r);
    final alts = altsFor(r);
    final summary = summaryFor(r);

    return Container(
      color: SV.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 44),
                children: [
                  if (debug != null) _sourceBadge(debug!),
                  _plate(v),
                  _idBlock(),
                  _verdictCard(v),
                  if (reasons.isNotEmpty) _reasons(reasons),
                  if (alts.isNotEmpty) _alternatives(alts),
                  _timeline(v),
                  _summary(summary),
                  _shareButton(context, v, summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_ios_new_rounded, onBack),
          const Spacer(),
          _circleBtn(Icons.ios_share_rounded, () {}),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: SV.glass(radius: 13),
          child: Icon(icon, size: 17, color: SV.dim),
        ),
      );

  Widget _sourceBadge(DecideDebug d) {
    final live = d.isLive;
    final c = live ? SV.buy : SV.wait;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: GestureDetector(
        onTap: onDiagnostics,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: SV.tint(c, 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: SV.tint(c, 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(live ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 14, color: c),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                live ? 'Live result · ${d.durationMs}ms' : 'Demo data — backend unreachable · tap to debug',
                style: TextStyle(fontFamily: SV.font, color: c, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _plate(VerdictStyle v) {
    final tint = categoryTint(r.identification.category);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      height: 228,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SV.hair),
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.1,
          colors: [tint, const Color(0xFF0C0E14)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SV.hair),
              ),
              child: Text(r.identification.category.toUpperCase(), style: SV.label(color: SV.dim, size: 10, spacing: 1.4)),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 26),
              child: ProductImage(
                url: heroImageFor(r),
                emoji: categoryEmoji(r.identification.category),
                glyphSize: 116,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idBlock() {
    final hasPrice = r.bestPrice != null || r.priceMin != null;
    final now = r.bestPrice ?? r.priceMin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((r.identification.brand ?? '').trim().isNotEmpty)
            Text(r.identification.brand!.toUpperCase(), style: SV.label(size: 12, spacing: 1.4)),
          const SizedBox(height: 8),
          Text(r.identification.productName, style: SV.h2),
          if (hasPrice) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (now != null) Text('£${now.round()}', style: SV.price(size: 20)),
                if (r.priceAvg != null) ...[
                  const SizedBox(width: 10),
                  Text('fair £${r.priceAvg!.round()}', style: SV.price(color: SV.faint, size: 13, w: FontWeight.w500)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _verdictCard(VerdictStyle v) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(SV.tint(v.color, 0.15), SV.bg1), SV.bg1],
        ),
        border: Border.all(color: SV.tint(v.color, 0.4)),
        boxShadow: [BoxShadow(color: SV.tint(v.color, 0.22), blurRadius: 44, spreadRadius: -20, offset: const Offset(0, 22))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEARCHLY VERDICT', style: SV.label(color: v.color, size: 11, spacing: 2.0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SV.tint(v.color, 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SV.tint(v.color, 0.4)),
                ),
                child: Text(v.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  v.word,
                  style: TextStyle(
                      fontFamily: SV.font, color: v.color, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1),
                ),
              ),
            ],
          ),
          if (r.verdict.reasoning.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(r.verdict.reasoning.trim(), style: SV.body),
          ],
          if (r.verdict.whoShouldBuy.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: SV.hair),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Recommendation  ',
                    style: TextStyle(fontFamily: SV.font, color: v.color, fontSize: 14, fontWeight: FontWeight.w700)),
                TextSpan(text: r.verdict.whoShouldBuy.trim(), style: const TextStyle(fontFamily: SV.font, color: SV.dim, fontSize: 14, height: 1.4)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(title.toUpperCase(), style: SV.label(size: 11, spacing: 1.6)),
      );

  Widget _reasons(List<String> reasons) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Why?'),
          for (int i = 0; i < reasons.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: i == reasons.length - 1 ? Colors.transparent : SV.hair)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: Text('0${i + 1}', style: SV.label(size: 12, spacing: 0.5))),
                  Expanded(
                    child: Text(reasons[i],
                        style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15.5, height: 1.45, letterSpacing: -0.1)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _alternatives(List<Offer> alts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _sectionHeader(alts.length > 1 ? 'Better alternatives' : 'Better alternative'),
          ),
          for (final o in alts) _altCard(o),
        ],
      ),
    );
  }

  Widget _altCard(Offer o) {
    return GestureDetector(
      onTap: () => onOpenUrl(o.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: SV.glass(radius: 22),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SV.hair),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.1,
                  colors: [categoryTint(r.identification.category), const Color(0xFF0C0E14)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: ProductImage(
                  url: o.image.trim().startsWith('http') ? o.image.trim() : null,
                  emoji: categoryEmoji(r.identification.category),
                  glyphSize: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                  const SizedBox(height: 5),
                  Text(o.reason.isNotEmpty ? o.reason : o.retailer,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: SV.bodyDim.copyWith(fontSize: 13)),
                  if (o.priceDisplay.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(o.priceDisplay, style: SV.price(color: SV.buy, size: 14)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: SV.hair)),
              child: Text('Compare', style: SV.label(color: SV.dim, size: 11, spacing: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(VerdictStyle v) {
    final today = r.bestPrice ?? r.priceMin;
    final fair = r.priceAvg;
    final savings = (fair != null && today != null && fair > today) ? (fair - today).round() : null;
    final todayLabel = today != null ? '£${today.round()}' : '—';
    final nextLabel = fair != null ? 'fair £${fair.round()}' : 'watch price';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Buy or wait'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SV.glass(radius: 22),
            child: Column(
              children: [
                SizedBox(
                  height: 14,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(height: 4, decoration: BoxDecoration(color: SV.bg2, borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.36,
                        child: Container(height: 4, decoration: BoxDecoration(color: v.color, borderRadius: BorderRadius.circular(4))),
                      ),
                      Align(
                        alignment: const Alignment(-0.28, 0),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: v.color, shape: BoxShape.circle, border: Border.all(color: SV.bg1, width: 2)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _tlCol('TODAY', todayLabel, SV.ink),
                    _tlCol('ADVICE', v.word, v.color),
                    _tlCol('NEXT', nextLabel, SV.ink),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: SV.hair),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estimated upside', style: SV.bodyDim.copyWith(fontSize: 13)),
                    Text(savings != null ? 'Save £$savings' : (v.word),
                        style: SV.price(color: v.color, size: 18, w: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tlCol(String k, String val, Color c) => Expanded(
        child: Column(
          children: [
            Text(k, style: SV.label(size: 10.5, spacing: 0.8)),
            const SizedBox(height: 6),
            Text(val, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: SV.font, color: c, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _summary(String summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SV.hair),
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.2,
          colors: [const Color(0xFF171A24), SV.bg1],
        ),
      ),
      child: Column(
        children: [
          Text('AI SUMMARY', style: SV.label(size: 10.5, spacing: 1.6)),
          const SizedBox(height: 14),
          Text('“$summary”',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.7, height: 1.25)),
        ],
      ),
    );
  }

  Widget _shareButton(BuildContext context, VerdictStyle v, String summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          showShareCard(context, r, v, summary);
        },
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: SV.ink, borderRadius: BorderRadius.circular(18)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.ios_share_rounded, size: 18, color: Color(0xFF0A0B10)),
              const SizedBox(width: 9),
              Text('Share this verdict',
                  style: const TextStyle(fontFamily: SV.font, color: Color(0xFF0A0B10), fontSize: 15.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A real product photo from the web, with a graceful emoji-glyph fallback
/// while loading or if the listing has no image.
class ProductImage extends StatelessWidget {
  final String? url;
  final String emoji;
  final double glyphSize;
  final BoxFit fit;
  const ProductImage({super.key, required this.url, required this.emoji, this.glyphSize = 40, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return _glyph();
    return Image.network(
      u,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _glyph(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: SV.faint),
          ),
        );
      },
    );
  }

  Widget _glyph() => Center(child: Text(emoji, style: TextStyle(fontSize: glyphSize)));
}

/// The dark share card overlay — product, giant verdict word, one line.
void showShareCard(BuildContext context, DecisionResult r, VerdictStyle v, String summary) {
  showGeneralDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    barrierDismissible: true,
    barrierLabel: 'share',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => _ShareOverlay(r: r, v: v, summary: summary),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
    ),
  );
}

class _ShareOverlay extends StatelessWidget {
  final DecisionResult r;
  final VerdictStyle v;
  final String summary;
  const _ShareOverlay({required this.r, required this.v, required this.summary});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: SV.tint(v.color, 0.3)),
                  gradient: RadialGradient(
                    center: const Alignment(0, -1),
                    radius: 1.3,
                    colors: [Color.alphaBlend(SV.tint(v.color, 0.22), const Color(0xFF0B0D13)), const Color(0xFF07080B)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(width: 20, height: 20, decoration: BoxDecoration(color: SV.iris, borderRadius: BorderRadius.circular(6))),
                        const SizedBox(width: 9),
                        const Text('Searchly', style: TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('AI VERDICT', style: SV.label(size: 10, spacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 108,
                      child: ProductImage(
                        url: heroImageFor(r),
                        emoji: categoryEmoji(r.identification.category),
                        glyphSize: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('${(r.identification.brand ?? '').isNotEmpty ? '${r.identification.brand} · ' : ''}${r.identification.productName}'.toUpperCase(),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: SV.label(color: SV.dim, size: 11, spacing: 1.0)),
                    const SizedBox(height: 14),
                    Text(v.word.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: SV.font, color: v.color, fontSize: 50, fontWeight: FontWeight.w800, letterSpacing: -1.8, height: 0.98)),
                    const SizedBox(height: 16),
                    Text(summary,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 17, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: -0.2)),
                    const SizedBox(height: 24),
                    Text('POINT · KNOW · BUY SMARTER', style: SV.label(size: 10.5, spacing: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: SV.hair)),
                  child: const Text('Close', style: TextStyle(fontFamily: SV.font, color: SV.dim, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
