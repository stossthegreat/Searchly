import 'sv_theme.dart';
import '../models.dart';
import 'package:flutter/material.dart';

/// Maps a backend DecisionResult into the V2 verdict language: a single word,
/// a semantic colour and an icon. No percentages — an opinion.
class VerdictStyle {
  final String word;
  final Color color;
  final String icon;
  const VerdictStyle(this.word, this.color, this.icon);
}

VerdictStyle verdictStyleFor(DecisionResult r) {
  if (r.authenticity != null) return const VerdictStyle('Check It', SV.wait, '🔎');
  switch (r.verdict.decision) {
    case 'buy':
      return const VerdictStyle('Worth It', SV.buy, '✅');
    case 'skip':
      return const VerdictStyle('Skip', SV.skip, '⚠');
    case 'wait':
      return const VerdictStyle('Wait', SV.wait, '⏳');
    case 'find_cheaper':
      return const VerdictStyle('Overpriced', SV.over, '📉');
    case 'better_alternative':
      return const VerdictStyle('Better Exists', SV.iris, '🔄');
    default:
      return const VerdictStyle('Worth It', SV.buy, '✅');
  }
}

/// A large, recognisable glyph standing in for the product photo.
String categoryEmoji(String category) {
  switch (category) {
    case 'sneakers':
      return '👟';
    case 'watches':
      return '⌚';
    case 'handbags':
      return '👜';
    case 'fashion':
      return '🧥';
    case 'electronics':
      return '📱';
    case 'beauty':
      return '💄';
    case 'furniture':
      return '🛋️';
    case 'homeware':
      return '🏠';
    case 'fitness':
      return '🏋️';
    default:
      return '📦';
  }
}

/// A soft plate-tint per category so the product plate isn't a flat grey.
Color categoryTint(String category) {
  switch (category) {
    case 'sneakers':
      return const Color(0xFF2A1C1C);
    case 'watches':
      return const Color(0xFF1A2230);
    case 'beauty':
      return const Color(0xFF2A1C26);
    case 'furniture':
      return const Color(0xFF221B2C);
    case 'electronics':
      return const Color(0xFF1B2330);
    default:
      return const Color(0xFF1A1F2B);
  }
}

/// Three concise reasons — no essays. Prefer the model's red flags, then fall
/// back to sentences from its reasoning, then who-should-buy.
List<String> reasonsFor(DecisionResult r) {
  final out = <String>[];
  for (final f in r.verdict.redFlags) {
    final t = f.trim();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  if (out.length < 3) {
    final sentences = r.verdict.reasoning
        .split(RegExp(r'[.!?]+\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 8);
    for (final s in sentences) {
      if (out.length >= 3) break;
      if (!out.contains(s)) out.add(s);
    }
  }
  if (out.isEmpty && r.verdict.whoShouldBuy.trim().isNotEmpty) {
    out.add(r.verdict.whoShouldBuy.trim());
  }
  return out.take(3).toList();
}

/// Up to two premium alternatives — upgrades/budget/dupes first, then similar.
List<Offer> altsFor(DecisionResult r) {
  bool isAlt(Offer o) => o.matchType == 'upgrade' || o.matchType == 'budget' || o.matchType == 'dupe';
  final primary = r.offers.where(isAlt).toList();
  final pick = primary.isNotEmpty ? primary : r.offers.where((o) => o.matchType == 'similar').toList();
  return pick.take(2).toList();
}

/// The one-sentence AI summary — the share line.
String summaryFor(DecisionResult r) {
  if (r.share.line.trim().isNotEmpty) return r.share.line.trim();
  if (r.verdict.headline.trim().isNotEmpty) return r.verdict.headline.trim();
  return 'Here is the smart move.';
}
