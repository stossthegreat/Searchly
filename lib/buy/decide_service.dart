import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Talks to the Searchly buying engine (`POST /api/decide`).
/// Falls back to on-device demo scenarios when no backend is configured or a
/// request fails — so the app always demos end-to-end and never shows a dead end.
class DecideService {
  DecideService._();
  static final instance = DecideService._();

  /// Point this at your Railway deployment. Empty → always use demo data.
  static const String baseUrl = String.fromEnvironment('SEARCHLY_API', defaultValue: '');

  Future<DecisionResult> decide({
    required String mode,
    String? query,
    String? imageBase64,
  }) async {
    if (baseUrl.isNotEmpty) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/decide'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'mode': mode,
                if (query != null) 'query': query,
                if (imageBase64 != null) 'imageBase64': imageBase64,
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) {
          return DecisionResult.fromJson(jsonDecode(res.body) as Map);
        }
      } catch (_) {
        // fall through to demo
      }
    }
    return DecisionResult.fromJson(_demo(mode));
  }

  Map _demo(String mode) => Map<String, dynamic>.from(_demoData[mode] ?? _demoData['worthit']!);

  static final Map<String, Map> _demoData = {
    'worthit': {
      'mode': 'worthit',
      'identification': {'productName': 'Sony WH-1000XM5', 'brand': 'Sony', 'category': 'electronics', 'description': 'Flagship noise-cancelling headphones', 'confidence': 94, 'searchSeed': 'Sony WH-1000XM5'},
      'verdict': {'decision': 'buy', 'headline': 'Buy it — class-leading ANC, £70 under launch', 'confidence': 90, 'valueScore': 83, 'qualityScore': 91, 'reasoning': 'Across Reddit, RTINGS and Which? the XM5 is the consensus pick for noise cancelling under £300. At £279 you\'re paying below the 90-day average of £312.', 'whoShouldBuy': 'Commuters & travellers who want the best ANC, no fuss.', 'whoShouldAvoid': 'Bass-heads and anyone who needs a folding travel case.', 'redFlags': ['Non-folding design — bulkier case than the XM4']},
      'offers': [
        {'id': 'a', 'title': 'Sony WH-1000XM5 Black', 'retailer': 'Amazon', 'retailerDomain': 'amazon.co.uk', 'url': '#', 'price': 279, 'priceDisplay': '£279', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 8123, 'trustScore': 88, 'matchType': 'exact', 'reason': '£33 below average', 'savingsVsAvg': 33},
        {'id': 'b', 'title': 'Sony WH-1000XM5', 'retailer': 'John Lewis', 'retailerDomain': 'johnlewis.com', 'url': '#', 'price': 289, 'priceDisplay': '£289', 'currency': 'GBP', 'image': '', 'rating': 4.8, 'reviewCount': 2201, 'trustScore': 96, 'matchType': 'exact', 'reason': '2yr warranty', 'savingsVsAvg': 23},
        {'id': 'c', 'title': 'Bose QC Ultra', 'retailer': 'Currys', 'retailerDomain': 'currys.co.uk', 'url': '#', 'price': 349, 'priceDisplay': '£349', 'currency': 'GBP', 'image': '', 'rating': 4.6, 'reviewCount': 1540, 'trustScore': 90, 'matchType': 'upgrade', 'reason': 'Comfier, pricier'},
        {'id': 'd', 'title': 'Sony WH-1000XM4', 'retailer': 'Argos', 'retailerDomain': 'argos.co.uk', 'url': '#', 'price': 189, 'priceDisplay': '£189', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 6200, 'trustScore': 90, 'matchType': 'budget', 'reason': '90% as good, £90 less'},
      ],
      'bestPrice': 279, 'priceRange': {'min': 189, 'max': 349, 'avg': 312},
      'sharePayload': {'verb': 'AI says', 'stat': 'BUY', 'line': 'Worth it — best price locked'},
      'durationMs': 2400,
    },
    'cheaper': {
      'mode': 'cheaper',
      'identification': {'productName': 'Nike Air Max 90 Infrared', 'brand': 'Nike', 'category': 'sneakers', 'description': 'OG Air Max 90 in the Infrared colourway', 'confidence': 88, 'searchSeed': 'Nike Air Max 90 Infrared'},
      'verdict': {'decision': 'find_cheaper', 'headline': 'Don\'t pay £135 — same pair is £93', 'confidence': 86, 'valueScore': 79, 'qualityScore': 74, 'reasoning': 'The identical Infrared colourway is £135 on Nike but £93 at size? and JD with free returns — both official stockists. Average across 9 UK sellers is £118.', 'whoShouldBuy': 'Anyone buying the exact pair — grab the cheaper listing.', 'whoShouldAvoid': 'Nobody — this is a pure price win.', 'redFlags': ['One £71 listing flagged: unverified marketplace seller, no returns']},
      'offers': [
        {'id': 'a', 'title': 'Air Max 90 Infrared', 'retailer': 'size?', 'retailerDomain': 'size.co.uk', 'url': '#', 'price': 93, 'priceDisplay': '£93', 'currency': 'GBP', 'image': '', 'rating': 4.6, 'reviewCount': 340, 'trustScore': 88, 'matchType': 'exact', 'reason': '£25 below average', 'savingsVsAvg': 25},
        {'id': 'b', 'title': 'Air Max 90 Infrared', 'retailer': 'JD Sports', 'retailerDomain': 'jdsports.co.uk', 'url': '#', 'price': 97, 'priceDisplay': '£97', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 890, 'trustScore': 90, 'matchType': 'exact', 'reason': 'Free returns', 'savingsVsAvg': 21},
        {'id': 'c', 'title': 'Air Max 90 (Nike)', 'retailer': 'Nike', 'retailerDomain': 'nike.com', 'url': '#', 'price': 135, 'priceDisplay': '£135', 'currency': 'GBP', 'image': '', 'rating': 4.8, 'reviewCount': 5100, 'trustScore': 97, 'matchType': 'exact', 'reason': 'RRP — skip'},
        {'id': 'd', 'title': 'Air Max 90 lookalike', 'retailer': 'Marketplace', 'retailerDomain': 'marketplace', 'url': '#', 'price': 71, 'priceDisplay': '£71', 'currency': 'GBP', 'image': '', 'rating': 3.9, 'reviewCount': 12, 'trustScore': 30, 'matchType': 'similar', 'reason': '⚠ unverified seller'},
      ],
      'bestPrice': 93, 'priceRange': {'min': 71, 'max': 135, 'avg': 118},
      'sharePayload': {'verb': 'Found it cheaper', 'stat': '£42', 'line': 'AI saved me £42'},
      'durationMs': 2600,
    },
    'dupes': {
      'mode': 'dupes',
      'identification': {'productName': 'Ligne Roset Togo (style)', 'brand': 'Ligne Roset', 'category': 'furniture', 'description': 'Iconic low-slung quilted floor sofa', 'confidence': 81, 'searchSeed': 'Togo sofa'},
      'verdict': {'decision': 'find_cheaper', 'headline': 'The £3,400 look for £499', 'confidence': 80, 'valueScore': 88, 'qualityScore': 66, 'reasoning': 'The original Togo runs £3,400+. Reddit\'s r/furniture rates the Dunelm and Made ripples as the closest silhouette. Trade-off: lower foam density, so softer support over 5+ years.', 'whoShouldBuy': 'Renters & first flats who want the look now.', 'whoShouldAvoid': 'Buyers who want 15-year foam.', 'redFlags': ['Dupes use lower-density foam — sags faster than the original']},
      'offers': [
        {'id': 'a', 'title': 'Ripple Floor Sofa', 'retailer': 'Dunelm', 'retailerDomain': 'dunelm.com', 'url': '#', 'price': 499, 'priceDisplay': '£499', 'currency': 'GBP', 'image': '', 'rating': 4.4, 'reviewCount': 210, 'trustScore': 90, 'matchType': 'dupe', 'reason': 'Closest silhouette'},
        {'id': 'b', 'title': 'Quilted Lounge Sofa', 'retailer': 'Made', 'retailerDomain': 'made.com', 'url': '#', 'price': 640, 'priceDisplay': '£640', 'currency': 'GBP', 'image': '', 'rating': 4.5, 'reviewCount': 95, 'trustScore': 78, 'matchType': 'dupe', 'reason': 'Better foam, £2.7k less'},
        {'id': 'c', 'title': 'Marshmallow Modular', 'retailer': 'Wayfair', 'retailerDomain': 'wayfair.co.uk', 'url': '#', 'price': 420, 'priceDisplay': '£420', 'currency': 'GBP', 'image': '', 'rating': 4.2, 'reviewCount': 60, 'trustScore': 82, 'matchType': 'dupe', 'reason': 'Budget dupe'},
        {'id': 'd', 'title': 'Ligne Roset Togo', 'retailer': 'Selfridges', 'retailerDomain': 'selfridges.com', 'url': '#', 'price': 3400, 'priceDisplay': '£3,400', 'currency': 'GBP', 'image': '', 'rating': 4.9, 'reviewCount': 320, 'trustScore': 95, 'matchType': 'upgrade', 'reason': 'The original'},
      ],
      'bestPrice': 420, 'priceRange': {'min': 420, 'max': 3400, 'avg': 1240},
      'sharePayload': {'verb': 'Same look for', 'stat': '£2,901', 'line': 'less than the original'},
      'durationMs': 2700,
    },
    'realfake': {
      'mode': 'realfake',
      'identification': {'productName': 'Omega Seamaster 300M', 'brand': 'Omega', 'category': 'watches', 'description': 'Luxury dive watch', 'confidence': 72, 'searchSeed': 'Omega Seamaster 300M', 'needsBetterPhoto': true},
      'verdict': {'decision': 'wait', 'headline': 'Likely genuine — but I can\'t confirm from one photo', 'confidence': 55, 'valueScore': 0, 'qualityScore': 0, 'reasoning': 'The dial and handset are consistent with a genuine 300M, but the crown guards and date font are the usual tells and can\'t be judged at this angle.', 'whoShouldBuy': '', 'whoShouldAvoid': '', 'redFlags': []},
      'offers': [],
      'authenticity': {
        'estimate': 'suspicious', 'confidence': 72,
        'looksCorrect': ['Wave dial pattern spacing looks correct', 'Applied logo, not printed', 'Bracelet taper matches reference'],
        'redFlags': ['Date font slightly thick vs reference'],
        'cannotVerify': ['Serial engraving depth (need macro)', 'Movement / caseback interior', 'Bezel lume under UV'],
        'followUpPhotos': ['Caseback engraving', 'Serial number macro', 'Clasp & bracelet', 'Bezel lume (UV)'],
        'disclaimer': 'Image-based estimate only — expert verification may be needed.',
      },
      'bestPrice': null, 'priceRange': {'min': null, 'max': null, 'avg': null},
      'sharePayload': {'verb': 'Real or fake?', 'stat': '72%', 'line': 'AI authenticity check'},
      'durationMs': 2500,
    },
    'better': {
      'mode': 'better',
      'identification': {'productName': 'iPhone 15', 'brand': 'Apple', 'category': 'electronics', 'description': 'Standard iPhone 15', 'confidence': 90, 'searchSeed': 'iPhone 15'},
      'verdict': {'decision': 'better_alternative', 'headline': 'Skip the 15 — the 15 Pro is only £90 more', 'confidence': 84, 'valueScore': 71, 'qualityScore': 85, 'reasoning': 'For £90 more the 15 Pro adds the A17 chip, titanium and the Action button — Wirecutter and MKBHD call it the better long-term hold.', 'whoShouldBuy': 'Light users who upgrade yearly — the 15 is plenty.', 'whoShouldAvoid': 'Anyone keeping it 3+ years — stretch to the Pro.', 'redFlags': []},
      'offers': [
        {'id': 'a', 'title': 'iPhone 15 Pro 128GB', 'retailer': 'Amazon', 'retailerDomain': 'amazon.co.uk', 'url': '#', 'price': 789, 'priceDisplay': '£789', 'currency': 'GBP', 'image': '', 'rating': 4.8, 'reviewCount': 3400, 'trustScore': 88, 'matchType': 'upgrade', 'reason': 'Best long-term pick'},
        {'id': 'b', 'title': 'iPhone 15 128GB', 'retailer': 'Argos', 'retailerDomain': 'argos.co.uk', 'url': '#', 'price': 699, 'priceDisplay': '£699', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 2100, 'trustScore': 90, 'matchType': 'exact', 'reason': 'Fine, but ages faster'},
        {'id': 'c', 'title': 'iPhone 14 128GB', 'retailer': 'Currys', 'retailerDomain': 'currys.co.uk', 'url': '#', 'price': 579, 'priceDisplay': '£579', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 4200, 'trustScore': 90, 'matchType': 'budget', 'reason': 'Best value now'},
        {'id': 'd', 'title': 'Pixel 8', 'retailer': 'John Lewis', 'retailerDomain': 'johnlewis.com', 'url': '#', 'price': 549, 'priceDisplay': '£549', 'currency': 'GBP', 'image': '', 'rating': 4.5, 'reviewCount': 1800, 'trustScore': 96, 'matchType': 'similar', 'reason': 'Better camera AI'},
      ],
      'bestPrice': 549, 'priceRange': {'min': 549, 'max': 789, 'avg': 654},
      'sharePayload': {'verb': 'AI says', 'stat': '+£90', 'line': 'stretch to the Pro'},
      'durationMs': 2500,
    },
    'find': {
      'mode': 'find',
      'identification': {'productName': 'Nike Air Max 90 OG Infrared', 'brand': 'Nike', 'category': 'sneakers', 'description': '2020 OG Infrared retro', 'confidence': 96, 'searchSeed': 'Nike Air Max 90 Infrared'},
      'verdict': {'decision': 'buy', 'headline': 'Air Max 90 OG Infrared — here\'s where to buy', 'confidence': 92, 'valueScore': 80, 'qualityScore': 78, 'reasoning': 'Matched with 96% confidence from the sole unit and heel TPU. Nine UK sellers stock it, £93–£150.', 'whoShouldBuy': 'You know the pair — go to the cheapest trusted seller.', 'whoShouldAvoid': '—', 'redFlags': []},
      'offers': [
        {'id': 'a', 'title': 'Air Max 90 Infrared', 'retailer': 'size?', 'retailerDomain': 'size.co.uk', 'url': '#', 'price': 93, 'priceDisplay': '£93', 'currency': 'GBP', 'image': '', 'rating': 4.6, 'reviewCount': 340, 'trustScore': 88, 'matchType': 'exact', 'reason': 'Cheapest trusted'},
        {'id': 'b', 'title': 'Air Max 90 Infrared', 'retailer': 'JD Sports', 'retailerDomain': 'jdsports.co.uk', 'url': '#', 'price': 97, 'priceDisplay': '£97', 'currency': 'GBP', 'image': '', 'rating': 4.7, 'reviewCount': 890, 'trustScore': 90, 'matchType': 'exact', 'reason': 'Free returns'},
        {'id': 'c', 'title': 'Air Max 90 Triple White', 'retailer': 'Schuh', 'retailerDomain': 'schuh.co.uk', 'url': '#', 'price': 110, 'priceDisplay': '£110', 'currency': 'GBP', 'image': '', 'rating': 4.6, 'reviewCount': 220, 'trustScore': 88, 'matchType': 'similar', 'reason': 'Similar model'},
      ],
      'bestPrice': 93, 'priceRange': {'min': 93, 'max': 150, 'avg': 118},
      'sharePayload': {'verb': 'Identified', 'stat': '96%', 'line': 'Air Max 90 Infrared'},
      'durationMs': 2300,
    },
  };
}
