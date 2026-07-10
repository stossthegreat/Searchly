import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../decide_service.dart';
import 'sv_theme.dart';
import 'sv_verdict.dart';

/// The elite, verdict-first result screen. Surfaces everything the advisor
/// found: the verdict, price intelligence, every place to buy (with trust &
/// ratings), the real research sources behind the call, and pros/cons.
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
    final summary = summaryFor(r);
    final prices = r.offers.map((o) => o.price).whereType<double>().toList();
    final cheapest = prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b);

    return Container(
      color: SV.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(context, v, summary),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 48),
                children: [
                  if (debug != null) _sourceBadge(debug!),
                  _plate(),
                  _idBlock(),
                  if (prices.isNotEmpty) _priceIntel(v),
                  _verdictCard(v),
                  if (reasons.isNotEmpty) _reasons(reasons),
                  _prosCons(v),
                  if (r.offers.isNotEmpty) _offersSection(cheapest),
                  if (r.evidence.isNotEmpty) _research(),
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

  // ---- top bar ----
  Widget _topBar(BuildContext context, VerdictStyle v, String summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_ios_new_rounded, onBack),
          const Spacer(),
          _circleBtn(Icons.ios_share_rounded, () => showShareCard(context, r, v, summary)),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: SV.glass(radius: 13), child: Icon(icon, size: 17, color: SV.dim)),
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
          decoration: BoxDecoration(color: SV.tint(c, 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: SV.tint(c, 0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(live ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, size: 14, color: c),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                live ? 'Live · ${r.offers.length} listings · ${r.evidence.length} sources · ${d.durationMs}ms' : 'Demo data — backend unreachable · tap to debug',
                style: TextStyle(fontFamily: SV.font, color: c, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---- product plate ----
  Widget _plate() {
    final tint = categoryTint(r.identification.category);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      height: 228,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SV.hair),
        gradient: RadialGradient(center: const Alignment(0, -0.5), radius: 1.1, colors: [tint, const Color(0xFF0C0E14)]),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8), border: Border.all(color: SV.hair)),
              child: Text(r.identification.category.toUpperCase(), style: SV.label(color: SV.dim, size: 10, spacing: 1.4)),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 26),
              child: ProductImage(url: heroImageFor(r), emoji: categoryEmoji(r.identification.category), glyphSize: 116, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    );
  }

  // ---- identity ----
  Widget _idBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((r.identification.brand ?? '').trim().isNotEmpty)
                Expanded(child: Text(r.identification.brand!.toUpperCase(), style: SV.label(size: 12, spacing: 1.4))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: SV.tint(SV.iris, 0.14), borderRadius: BorderRadius.circular(8)),
                child: Text('${r.identification.confidence}% match', style: SV.label(color: SV.iris, size: 10, spacing: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.identification.productName, style: SV.h2),
          if (r.identification.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.identification.description.trim(), style: SV.bodyDim),
          ],
        ],
      ),
    );
  }

  // ---- price intelligence ----
  Widget _priceIntel(VerdictStyle v) {
    final min = r.priceMin, max = r.priceMax, avg = r.priceAvg, best = r.bestPrice ?? r.priceMin;
    double frac = 0.15;
    if (min != null && max != null && max > min && best != null) {
      frac = ((best - min) / (max - min)).clamp(0.02, 0.98);
    }
    final saving = (avg != null && best != null && avg > best) ? (avg - best).round() : null;
    final over = (avg != null && best != null && best > avg) ? (best - avg).round() : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: SV.glass(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BEST PRICE', style: SV.label(size: 10, spacing: 1.4)),
                    const SizedBox(height: 4),
                    Text(best != null ? '£${best.round()}' : '—', style: SV.price(size: 30, w: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                if (saving != null)
                  _pricePill('£$saving under avg', SV.buy)
                else if (over != null)
                  _pricePill('£$over over avg', SV.over),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 5, decoration: BoxDecoration(color: SV.bg2, borderRadius: BorderRadius.circular(4))),
                  Align(
                    alignment: Alignment(frac * 2 - 1, 0),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: v.color, shape: BoxShape.circle, border: Border.all(color: SV.bg1, width: 3), boxShadow: [BoxShadow(color: SV.tint(v.color, 0.6), blurRadius: 10)]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(min != null ? 'low £${min.round()}' : '', style: SV.price(color: SV.faint, size: 11.5, w: FontWeight.w500)),
                if (avg != null) Text('avg £${avg.round()}', style: SV.price(color: SV.dim, size: 11.5, w: FontWeight.w600)),
                Text(max != null ? 'high £${max.round()}' : '', style: SV.price(color: SV.faint, size: 11.5, w: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pricePill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: SV.tint(c, 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: SV.tint(c, 0.35))),
        child: Text(text, style: TextStyle(fontFamily: SV.font, color: c, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  // ---- verdict card ----
  Widget _verdictCard(VerdictStyle v) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(SV.tint(v.color, 0.15), SV.bg1), SV.bg1]),
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
                decoration: BoxDecoration(color: SV.tint(v.color, 0.18), borderRadius: BorderRadius.circular(18), border: Border.all(color: SV.tint(v.color, 0.4))),
                child: Text(v.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(v.word, style: TextStyle(fontFamily: SV.font, color: v.color, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1))),
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
                TextSpan(text: 'Recommendation  ', style: TextStyle(fontFamily: SV.font, color: v.color, fontSize: 14, fontWeight: FontWeight.w700)),
                TextSpan(text: r.verdict.whoShouldBuy.trim(), style: const TextStyle(fontFamily: SV.font, color: SV.dim, fontSize: 14, height: 1.4)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {String? count}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.toUpperCase(), style: SV.label(size: 11, spacing: 1.6)),
            if (count != null) Text(count.toUpperCase(), style: SV.label(size: 11, spacing: 0.8)),
          ],
        ),
      );

  // ---- reasons ----
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == reasons.length - 1 ? Colors.transparent : SV.hair))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: Text('0${i + 1}', style: SV.label(size: 12, spacing: 0.5))),
                  Expanded(child: Text(reasons[i], style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 15.5, height: 1.45, letterSpacing: -0.1))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- pros & cons ----
  Widget _prosCons(VerdictStyle v) {
    final buy = r.verdict.whoShouldBuy.trim();
    final avoid = r.verdict.whoShouldAvoid.trim();
    final flags = r.verdict.redFlags.where((f) => f.trim().isNotEmpty).toList();
    if (buy.isEmpty && avoid.isEmpty && flags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _sectionHeader('The verdict, unpacked')),
          if (buy.isNotEmpty || avoid.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (buy.isNotEmpty) Expanded(child: _pcCard('Buy if', buy, SV.buy, Icons.check_circle_rounded)),
                if (buy.isNotEmpty && avoid.isNotEmpty) const SizedBox(width: 12),
                if (avoid.isNotEmpty) Expanded(child: _pcCard('Skip if', avoid, SV.skip, Icons.cancel_rounded)),
              ],
            ),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: SV.tint(SV.wait, 0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: SV.tint(SV.wait, 0.25))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WATCH OUT', style: SV.label(color: SV.wait, size: 10, spacing: 1.4)),
                  const SizedBox(height: 10),
                  for (final f in flags)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.warning_amber_rounded, size: 15, color: SV.wait)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(f.trim(), style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 13.5, height: 1.4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pcCard(String head, String body, Color c, IconData icon) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: SV.tint(c, 0.07), borderRadius: BorderRadius.circular(18), border: Border.all(color: SV.tint(c, 0.22))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 15, color: c), const SizedBox(width: 7), Text(head.toUpperCase(), style: SV.label(color: c, size: 10, spacing: 1.0))]),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 13.5, height: 1.4)),
          ],
        ),
      );

  // ---- all the places to buy ----
  Widget _offersSection(double? cheapest) {
    final offers = r.offers.take(12).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _sectionHeader('Where to buy', count: '${r.offers.length} found')),
          for (final o in offers) _offerRow(o, cheapest),
        ],
      ),
    );
  }

  Widget _offerRow(Offer o, double? cheapest) {
    final tag = _offerTag(o, cheapest);
    return GestureDetector(
      onTap: () => onOpenUrl(o.url),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: SV.glass(radius: 20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SV.hair),
                gradient: RadialGradient(center: const Alignment(0, -0.5), radius: 1.1, colors: [categoryTint(r.identification.category), const Color(0xFF0C0E14)]),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: ProductImage(url: o.image.trim().startsWith('http') ? o.image.trim() : null, emoji: categoryEmoji(r.identification.category), glyphSize: 28, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: trustColor(o.trustScore), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(o.retailer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: SV.font, color: SV.dim, fontSize: 12.5))),
                      if (o.rating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, size: 13, color: SV.wait),
                        const SizedBox(width: 2),
                        Text(o.rating!.toStringAsFixed(1), style: SV.price(color: SV.dim, size: 11.5, w: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(o.priceDisplay.isNotEmpty ? o.priceDisplay : (o.price != null ? '£${o.price!.round()}' : '—'), style: SV.price(size: 15.5, w: FontWeight.w800)),
                if (tag != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: SV.tint(tag.$2, 0.16), borderRadius: BorderRadius.circular(7)),
                    child: Text(tag.$1, style: SV.label(color: tag.$2, size: 9.5, spacing: 0.3)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, Color)? _offerTag(Offer o, double? cheapest) {
    if (o.price != null && cheapest != null && o.price == cheapest) return ('CHEAPEST', SV.buy);
    if (o.matchType == 'dupe') return ('DUPE', SV.gem);
    if (o.matchType == 'upgrade') return ('UPGRADE', SV.iris);
    if (o.matchType == 'budget') return ('BUDGET', SV.buy);
    if (o.trustScore >= 95) return ('TRUSTED', SV.dim);
    return null;
  }

  // ---- research sources ----
  Widget _research() {
    final sources = r.evidence.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _sectionHeader('What the research says', count: '${r.evidence.length} sources')),
          for (final e in sources) _sourceRow(e),
        ],
      ),
    );
  }

  Widget _sourceRow(Evidence e) {
    final c = kindColor(e.kind);
    return GestureDetector(
      onTap: () => onOpenUrl(e.url),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: SV.glass(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: SV.tint(c, 0.15), borderRadius: BorderRadius.circular(7)),
                  child: Text(kindLabel(e.kind, e.domain), style: SV.label(color: c, size: 9.5, spacing: 0.4)),
                ),
                const Spacer(),
                Icon(Icons.north_east_rounded, size: 14, color: SV.faint),
              ],
            ),
            const SizedBox(height: 10),
            Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
            if (e.snippet.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(e.snippet.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: SV.bodyDim.copyWith(fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }

  // ---- summary + share ----
  Widget _summary(String summary) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SV.hair),
        gradient: RadialGradient(center: const Alignment(0, -1), radius: 1.2, colors: [const Color(0xFF171A24), SV.bg1]),
      ),
      child: Column(
        children: [
          Text('AI SUMMARY', style: SV.label(size: 10.5, spacing: 1.6)),
          const SizedBox(height: 14),
          Text('“$summary”', textAlign: TextAlign.center, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.7, height: 1.25)),
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
              const Text('Share this verdict', style: TextStyle(fontFamily: SV.font, color: Color(0xFF0A0B10), fontSize: 15.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A real product photo from the web, with a graceful emoji-glyph fallback.
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
        return Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: SV.faint)));
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
                  gradient: RadialGradient(center: const Alignment(0, -1), radius: 1.3, colors: [Color.alphaBlend(SV.tint(v.color, 0.22), const Color(0xFF0B0D13)), const Color(0xFF07080B)]),
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
                    SizedBox(height: 108, child: ProductImage(url: heroImageFor(r), emoji: categoryEmoji(r.identification.category), glyphSize: 100, fit: BoxFit.contain)),
                    const SizedBox(height: 10),
                    Text(
                      '${(r.identification.brand ?? '').isNotEmpty ? '${r.identification.brand} · ' : ''}${r.identification.productName}'.toUpperCase(),
                      textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: SV.label(color: SV.dim, size: 11, spacing: 1.0),
                    ),
                    const SizedBox(height: 14),
                    Text(v.word.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontFamily: SV.font, color: v.color, fontSize: 50, fontWeight: FontWeight.w800, letterSpacing: -1.8, height: 0.98)),
                    const SizedBox(height: 16),
                    Text(summary, textAlign: TextAlign.center, style: const TextStyle(fontFamily: SV.font, color: SV.ink, fontSize: 17, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: -0.2)),
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
