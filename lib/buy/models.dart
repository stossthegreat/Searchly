// Dart mirrors of the backend `/api/decide` response shapes (types/buying.ts).

int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? d : d);
double? _dbl(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
String _str(dynamic v, [String d = '']) => v == null ? d : v.toString();
List<String> _strs(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

class Identification {
  final String productName, description, searchSeed;
  final String? brand, followUpHint;
  final String category;
  final int confidence;
  final bool needsBetterPhoto;
  Identification({
    required this.productName, required this.description, required this.searchSeed,
    required this.category, required this.confidence, required this.needsBetterPhoto,
    this.brand, this.followUpHint,
  });
  factory Identification.fromJson(Map j) => Identification(
        productName: _str(j['productName'], 'Unknown item'),
        brand: j['brand'] == null ? null : _str(j['brand']),
        category: _str(j['category'], 'general'),
        description: _str(j['description']),
        confidence: _int(j['confidence'], 50),
        searchSeed: _str(j['searchSeed']),
        needsBetterPhoto: j['needsBetterPhoto'] == true,
        followUpHint: j['followUpHint'] == null ? null : _str(j['followUpHint']),
      );
}

class Verdict {
  final String decision, headline, reasoning, whoShouldBuy, whoShouldAvoid;
  final int confidence, valueScore, qualityScore;
  final List<String> redFlags;
  final String? bestAlternativeId;
  Verdict({
    required this.decision, required this.headline, required this.reasoning,
    required this.whoShouldBuy, required this.whoShouldAvoid, required this.confidence,
    required this.valueScore, required this.qualityScore, required this.redFlags, this.bestAlternativeId,
  });
  factory Verdict.fromJson(Map j) => Verdict(
        decision: _str(j['decision'], 'find_cheaper'),
        headline: _str(j['headline'], 'Here’s the smart move'),
        reasoning: _str(j['reasoning']),
        whoShouldBuy: _str(j['whoShouldBuy']),
        whoShouldAvoid: _str(j['whoShouldAvoid']),
        confidence: _int(j['confidence'], 60),
        valueScore: _int(j['valueScore'], 50),
        qualityScore: _int(j['qualityScore'], 50),
        redFlags: _strs(j['redFlags']),
        bestAlternativeId: j['bestAlternativeId']?.toString(),
      );
}

class Offer {
  final String id, title, retailer, retailerDomain, url, priceDisplay, currency, image, matchType, reason;
  final double? price, rating;
  final int? reviewCount;
  final int trustScore;
  final double? savingsVsAvg;
  final String? delivery;
  Offer({
    required this.id, required this.title, required this.retailer, required this.retailerDomain,
    required this.url, required this.priceDisplay, required this.currency, required this.image,
    required this.matchType, required this.reason, required this.trustScore,
    this.price, this.rating, this.reviewCount, this.savingsVsAvg, this.delivery,
  });
  factory Offer.fromJson(Map j) => Offer(
        id: _str(j['id']),
        title: _str(j['title']),
        retailer: _str(j['retailer'], 'Unknown'),
        retailerDomain: _str(j['retailerDomain']),
        url: _str(j['url']),
        priceDisplay: _str(j['priceDisplay']),
        currency: _str(j['currency'], 'GBP'),
        image: _str(j['image']),
        matchType: _str(j['matchType'], 'similar'),
        reason: _str(j['reason']),
        trustScore: _int(j['trustScore'], 50),
        price: _dbl(j['price']),
        rating: _dbl(j['rating']),
        reviewCount: j['reviewCount'] == null ? null : _int(j['reviewCount']),
        savingsVsAvg: _dbl(j['savingsVsAvg']),
        delivery: j['delivery'] == null ? null : _str(j['delivery']),
      );
}

class Authenticity {
  final String estimate, disclaimer;
  final int confidence;
  final List<String> looksCorrect, redFlags, cannotVerify, followUpPhotos;
  Authenticity({
    required this.estimate, required this.confidence, required this.looksCorrect,
    required this.redFlags, required this.cannotVerify, required this.followUpPhotos, required this.disclaimer,
  });
  factory Authenticity.fromJson(Map j) => Authenticity(
        estimate: _str(j['estimate'], 'inconclusive'),
        confidence: _int(j['confidence'], 40),
        looksCorrect: _strs(j['looksCorrect']),
        redFlags: _strs(j['redFlags']),
        cannotVerify: _strs(j['cannotVerify']),
        followUpPhotos: _strs(j['followUpPhotos']),
        disclaimer: _str(j['disclaimer'], 'Image-based estimate only — expert verification may be needed.'),
      );
}

class SharePayload {
  final String verb, stat, line;
  SharePayload(this.verb, this.stat, this.line);
  factory SharePayload.fromJson(Map j) => SharePayload(_str(j['verb']), _str(j['stat']), _str(j['line']));
}

class DecisionResult {
  final String mode;
  final Identification identification;
  final Verdict verdict;
  final List<Offer> offers;
  final double? bestPrice, priceMin, priceMax, priceAvg;
  final Authenticity? authenticity;
  final SharePayload share;
  final int durationMs;
  DecisionResult({
    required this.mode, required this.identification, required this.verdict, required this.offers,
    required this.share, required this.durationMs,
    this.bestPrice, this.priceMin, this.priceMax, this.priceAvg, this.authenticity,
  });
  factory DecisionResult.fromJson(Map j) {
    final range = (j['priceRange'] is Map) ? j['priceRange'] as Map : const {};
    return DecisionResult(
      mode: _str(j['mode'], 'worthit'),
      identification: Identification.fromJson((j['identification'] as Map?) ?? const {}),
      verdict: Verdict.fromJson((j['verdict'] as Map?) ?? const {}),
      offers: (j['offers'] as List? ?? const []).map((e) => Offer.fromJson(e as Map)).toList(),
      bestPrice: _dbl(j['bestPrice']),
      priceMin: _dbl(range['min']),
      priceMax: _dbl(range['max']),
      priceAvg: _dbl(range['avg']),
      authenticity: j['authenticity'] is Map ? Authenticity.fromJson(j['authenticity'] as Map) : null,
      share: SharePayload.fromJson((j['sharePayload'] as Map?) ?? const {}),
      durationMs: _int(j['durationMs']),
    );
  }
}

/// The eight modes, with their chip presentation.
class BuyMode {
  final String id, label, emoji;
  const BuyMode(this.id, this.label, this.emoji);
  static const all = [
    BuyMode('worthit', 'Worth It', '⚖️'),
    BuyMode('cheaper', 'Cheaper', '💸'),
    BuyMode('dupes', 'Dupes', '🎭'),
    BuyMode('realfake', 'Real / Fake', '🔎'),
    BuyMode('better', 'Better', '⭐'),
    BuyMode('find', 'Find It', '🎯'),
  ];
}
