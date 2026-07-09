import 'package:flutter/material.dart';
import '../buy_theme.dart';
import '../models.dart';

/// Emoji stand-in for a product image (real build swaps in Image.network).
String emojiFor(String category) {
  switch (category) {
    case 'sneakers': return '👟';
    case 'watches': return '⌚';
    case 'handbags': return '👜';
    case 'electronics': return '🎧';
    case 'beauty': return '💄';
    case 'furniture': return '🛋️';
    case 'homeware': return '🏠';
    case 'fashion': return '🧥';
    case 'fitness': return '🏋️';
    default: return '🛍️';
  }
}

({String label, List<Color> grad}) _verdictStyle(String decision) {
  switch (decision) {
    case 'buy': return (label: 'Buy', grad: const [Color(0xFF12C48B), Color(0xFF0E9E97)]);
    case 'skip': return (label: 'Skip', grad: const [Color(0xFFFF5D73), Color(0xFFE0417A)]);
    case 'wait': return (label: 'Wait', grad: const [Color(0xFFF7B32B), Color(0xFFF08A3C)]);
    case 'better_alternative': return (label: 'Better exists', grad: const [Buy.blue, Buy.violet]);
    default: return (label: 'Find cheaper', grad: const [Buy.cyan, Buy.blue]);
  }
}

/// The hero — gradient-bordered white card: identification + verdict + price + CTA.
class VerdictCard extends StatelessWidget {
  final DecisionResult r;
  final VoidCallback onCta;
  const VerdictCard({super.key, required this.r, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final v = r.verdict;
    final vs = _verdictStyle(v.decision);
    final id = r.identification;
    final auth = r.authenticity;
    final isAuth = auth != null;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: Buy.verdictBorderGrad,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Buy.blue.withValues(alpha: 0.55), blurRadius: 60, spreadRadius: -26, offset: const Offset(0, 26))],
      ),
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(color: Buy.card, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 90, height: 90, alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFDBE4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Text(emojiFor(id.category), style: const TextStyle(fontSize: 44)),
              ),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((id.brand ?? id.category).toUpperCase(), style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.blue, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                const SizedBox(height: 4),
                Text(id.productName, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                _ConfMeter(id.confidence),
              ])),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF3F6FF), Color(0xFFEAF0FF)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E9FF)),
              ),
              child: Row(children: [
                _VerdictPill(label: vs.label, grad: vs.grad),
                const SizedBox(width: 12),
                Expanded(child: Text(v.headline, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.25))),
              ]),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAuth ? 'AUTHENTICITY' : 'BEST PRICE', style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk3, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
                const SizedBox(height: 3),
                if (isAuth)
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('${auth.confidence}', style: Buy.priceStyle(30, c: Buy.cardInk)),
                    Text('% est.', style: Buy.cardMuted),
                  ])
                else
                  Text(r.bestPrice != null ? '£${_fmt(r.bestPrice!)}' : '—', style: Buy.priceStyle(30, c: Buy.cardInk)),
                const SizedBox(height: 2),
                Text(isAuth ? 'image-based estimate' : (r.offers.isNotEmpty ? '${r.offers.first.retailer} · in stock' : 'across sellers'), style: Buy.cardMuted),
              ])),
              _Cta(label: isAuth ? 'Add photos' : 'View Best Deal', onTap: onCta),
            ]),
          ],
        ),
      ),
    );
  }
}

String _fmt(double v) {
  final s = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

class _ConfMeter extends StatelessWidget {
  final int pct;
  const _ConfMeter(this.pct);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$pct% match', style: Buy.priceStyle(12, c: Buy.cardInk2, w: FontWeight.w700)),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: 6, child: Stack(children: [
          Container(color: const Color(0xFFE7ECFB)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 950),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => FractionallySizedBox(widthFactor: val, alignment: Alignment.centerLeft, child: Container(decoration: const BoxDecoration(gradient: Buy.accentGrad))),
          ),
        ])),
      )),
    ]);
  }
}

class _VerdictPill extends StatelessWidget {
  final String label;
  final List<Color> grad;
  const _VerdictPill({required this.label, required this.grad});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(gradient: LinearGradient(colors: grad), borderRadius: BorderRadius.circular(12)),
      child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _Cta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: Buy.altGrad,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Buy.blue.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 10))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
        ]),
      ),
    );
  }
}

/// White product card with a gradient match-type tag.
class OfferCard extends StatelessWidget {
  final Offer o;
  final VoidCallback onTap;
  const OfferCard({super.key, required this.o, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final mc = Buy.matchColor(o.matchType);
    final suspicious = o.trustScore < 40;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(11),
        decoration: Buy.cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Container(
              height: 98, alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFDCE4FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🛍️', style: TextStyle(fontSize: 34)),
            ),
            Positioned(top: 8, left: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [mc, mc.withValues(alpha: 0.75)]), borderRadius: BorderRadius.circular(8)),
              child: Text(o.matchType.toUpperCase(), style: const TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            )),
          ]),
          const SizedBox(height: 9),
          SizedBox(height: 32, child: Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2))),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(o.priceDisplay.isEmpty ? '—' : o.priceDisplay, style: Buy.priceStyle(15, c: Buy.cardInk)),
            if (o.rating != null) Row(children: [
              const Icon(Icons.star_rounded, size: 12, color: Buy.warn),
              const SizedBox(width: 2),
              Text(o.rating!.toStringAsFixed(1), style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk2, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: suspicious ? Buy.bad : Buy.good)),
            const SizedBox(width: 5),
            Expanded(child: Text(o.retailer, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk3, fontSize: 10.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(o.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'SF Pro Display', color: suspicious ? Buy.bad : Buy.blue, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// White expert card — value/quality bars + reasoning + who-should.
class ExpertBlock extends StatelessWidget {
  final DecisionResult r;
  const ExpertBlock({super.key, required this.r});
  @override
  Widget build(BuildContext context) {
    final v = r.verdict;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: Buy.cardBox(radius: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ScoreBar('Value for money', v.valueScore, const [Buy.cyan, Buy.blue]),
        const SizedBox(height: 11),
        _ScoreBar('Quality', v.qualityScore, const [Buy.good, Buy.cyan]),
        const SizedBox(height: 14),
        Text(v.reasoning, style: Buy.cardBody),
        if (v.whoShouldBuy.isNotEmpty || v.whoShouldAvoid.isNotEmpty) ...[
          const SizedBox(height: 13),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _WhoBox('Buy if', v.whoShouldBuy, const Color(0xFFE7F9F1), const Color(0xFF0E9E77))),
            const SizedBox(width: 10),
            Expanded(child: _WhoBox('Skip if', v.whoShouldAvoid, const Color(0xFFFFEEF1), const Color(0xFFE0417A))),
          ]),
        ],
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final List<Color> grad;
  const _ScoreBar(this.label, this.score, this.grad);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.cardInk2, fontSize: 11.5, fontWeight: FontWeight.w600)),
        Text('$score/100', style: Buy.priceStyle(12, c: Buy.cardInk, w: FontWeight.w700)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(5), child: SizedBox(height: 8, child: Stack(children: [
        Container(color: Buy.cardTrack),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 950),
          curve: Curves.easeOutCubic,
          builder: (_, val, __) => FractionallySizedBox(widthFactor: val, alignment: Alignment.centerLeft, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: grad)))),
        ),
      ]))),
    ]);
  }
}

class _WhoBox extends StatelessWidget {
  final String head, body;
  final Color bg, fg;
  const _WhoBox(this.head, this.body, this.bg, this.fg);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head.toUpperCase(), style: TextStyle(fontFamily: 'SF Pro Display', color: fg, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
        const SizedBox(height: 4),
        Text(body.isEmpty ? '—' : body, style: const TextStyle(fontFamily: 'SF Pro Display', color: Color(0xFF37436E), fontSize: 11.5, height: 1.35)),
      ]),
    );
  }
}

class FlagRow extends StatelessWidget {
  final String text;
  const FlagRow(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: const Color(0xFFFFEEF1), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: Buy.bad),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: const TextStyle(fontFamily: 'SF Pro Display', color: Color(0xFF8A2740), fontSize: 12.5, height: 1.35))),
      ]),
    );
  }
}

/// The viral screenshot — vibrant gradient, white type.
class ShareCard extends StatelessWidget {
  final SharePayload s;
  const ShareCard({super.key, required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Buy.shareGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Buy.violet.withValues(alpha: 0.55), blurRadius: 60, spreadRadius: -22, offset: const Offset(0, 26))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.verb.toUpperCase(), style: TextStyle(fontFamily: 'SF Pro Display', color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.2)),
        const SizedBox(height: 9),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(s.stat, style: Buy.priceStyle(40, c: Colors.white)),
          const SizedBox(width: 11),
          Expanded(child: Text(s.line, style: const TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.25))),
        ]),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(gradient: Buy.accentGrad, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 6),
            const Text('Searchly', style: TextStyle(fontFamily: 'SF Pro Display', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          Text('Point. Know. Buy smarter.', style: TextStyle(fontFamily: 'SF Pro Display', color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
        ]),
      ]),
    );
  }
}

/// Section header (on the blue ground → light text).
class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  const SectionHeader(this.title, {super.key, this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontFamily: 'SF Pro Display', color: Buy.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        if (count != null) Text(count!, style: Buy.priceStyle(11, c: Buy.mut, w: FontWeight.w500)),
      ]),
    );
  }
}
