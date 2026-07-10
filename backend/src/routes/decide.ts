import type { FastifyInstance } from 'fastify';
import { createHash } from 'node:crypto';
import type {
  DecideRequest,
  DecisionResult,
  EvidenceSource,
  Mode,
  MatchType,
  Offer,
} from '../types/buying.js';
import { identifyProduct, synthesizeVerdict, assessAuthenticity } from '../services/buyer_agent.js';
import { queryBattery } from '../services/presets.js';
import { serperShopping, serperOrganic, type ShoppingResult } from '../services/product_search.js';
import { retailerFor, reviewSourceFor } from '../data/retailers.js';
import { TtlCache } from '../lib/cache.js';
import { config } from '../config.js';

const cache = new TtlCache<DecisionResult>(config.cacheTtlSeconds);

const VALID_MODES: Mode[] = [
  'find',
  'cheaper',
  'better',
  'dupes',
  'realfake',
  'worthit',
  'compare',
  'complete',
];

/** How many queries from each battery we actually fire (cost control). */
const MAX_SHOPPING_QUERIES = 8;
const MAX_EVIDENCE_QUERIES = 6;

function hash(s: string): string {
  return createHash('sha1').update(s).digest('hex').slice(0, 12);
}

const STOP = new Set(['the', 'a', 'an', 'for', 'with', 'and', 'of', 'in', 'uk', 'best', 'buy']);
function tokens(s: string): string[] {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1 && !STOP.has(t));
}

/** Fraction of the product seed's words present in a candidate title. */
function seedOverlap(title: string, seed: string): number {
  const seedT = tokens(seed);
  if (!seedT.length) return 0;
  const titleT = new Set(tokens(title));
  const hit = seedT.filter((t) => titleT.has(t)).length;
  return hit / seedT.length;
}

function shoppingToOffer(r: ShoppingResult, seed: string): Offer | null {
  if (!r.link || !r.title) return null;
  const rt = retailerFor(r.link);
  return {
    id: hash(r.link + r.title),
    title: r.title.slice(0, 140),
    retailer: rt.name || r.source || 'Unknown',
    retailerDomain: rt.domain,
    url: r.link,
    price: r.priceValue,
    priceDisplay: r.price || (r.priceValue != null ? `£${r.priceValue}` : ''),
    currency: r.currency,
    image: r.imageUrl,
    rating: r.rating,
    reviewCount: r.ratingCount,
    delivery: r.delivery,
    trustScore: rt.suspicious ? Math.min(rt.trust, 35) : rt.trust,
    matchType: 'similar',
    reason: '',
    savingsVsAvg: null,
  };
}

/** Dedup by retailer+normalized title, keeping the cheapest offer of each. */
function dedupeOffers(offers: Offer[]): Offer[] {
  const byKey = new Map<string, Offer>();
  for (const o of offers) {
    const key = `${o.retailerDomain}|${tokens(o.title).slice(0, 6).join(' ')}`;
    const prev = byKey.get(key);
    if (!prev) {
      byKey.set(key, o);
    } else if ((o.price ?? Infinity) < (prev.price ?? Infinity)) {
      byKey.set(key, o);
    }
  }
  return [...byKey.values()];
}

/** Assign match types + one-line reasons using price context and mode. */
function classify(offers: Offer[], mode: Mode, seed: string, avg: number | null): void {
  for (const o of offers) {
    const overlap = seedOverlap(o.title, seed);
    let mt: MatchType;
    if (mode === 'dupes') mt = 'dupe';
    else if (mode === 'better') {
      mt = avg != null && o.price != null ? (o.price > avg * 1.15 ? 'upgrade' : o.price < avg * 0.85 ? 'budget' : 'similar') : 'similar';
    } else {
      mt = overlap >= 0.6 ? 'exact' : overlap >= 0.3 ? 'similar' : mode === 'cheaper' ? 'exact' : 'similar';
    }
    o.matchType = mt;

    const saving = avg != null && o.price != null ? Math.round(avg - o.price) : null;
    o.savingsVsAvg = saving;
    if (mt === 'dupe') o.reason = 'Same look, lower price';
    else if (mt === 'upgrade') o.reason = 'Step up in quality';
    else if (mt === 'budget') o.reason = 'Best budget pick';
    else if (saving != null && saving > 3) o.reason = `£${saving} below average`;
    else if (o.rating && o.rating >= 4.4) o.reason = `Highly rated · ${o.rating}★`;
    else if (o.trustScore >= 90) o.reason = 'Trusted retailer';
    else o.reason = mt === 'exact' ? 'Exact match' : 'Close alternative';
  }
}

/** Rank: exact/cheaper first, then trust, rating, and low price. */
function rankOffers(offers: Offer[], mode: Mode): Offer[] {
  const matchWeight: Record<MatchType, number> = { exact: 3, dupe: 2, budget: 2, upgrade: 1, similar: 1 };
  return offers.slice().sort((a, b) => {
    if (mode === 'cheaper') return (a.price ?? Infinity) - (b.price ?? Infinity);
    const mw = matchWeight[b.matchType] - matchWeight[a.matchType];
    if (mw) return mw;
    const trust = b.trustScore - a.trustScore;
    if (trust) return trust;
    const rating = (b.rating ?? 0) - (a.rating ?? 0);
    if (rating) return rating;
    return (a.price ?? Infinity) - (b.price ?? Infinity);
  });
}

export async function registerDecideRoute(app: FastifyInstance): Promise<void> {
  app.post<{ Body: DecideRequest }>('/api/decide', async (request, reply) => {
    const body = request.body || {};
    const mode: Mode = VALID_MODES.includes(body.mode as Mode) ? (body.mode as Mode) : 'worthit';
    const hasImage = !!body.imageBase64;

    if (!body.query && !hasImage) {
      return reply.status(400).send({ error: 'Provide a query or an image.' });
    }

    // Text-only requests are cacheable; image requests are not.
    const cacheKey = !hasImage ? `${mode}:${(body.query || '').trim().toLowerCase()}` : '';
    if (cacheKey) {
      const cached = cache.get(cacheKey);
      if (cached) return { ...cached, cached: true };
    }

    const started = Date.now();
    try {
      // 1) TRIAGE — what is it?
      const identification = await identifyProduct({
        query: body.query,
        imageBase64: body.imageBase64,
        categoryHint: body.category,
      });

      const seed = identification.searchSeed || identification.productName;
      const battery = queryBattery(mode, {
        product: seed,
        brand: identification.brand,
        category: identification.category,
      });

      // 2) FAN OUT — shopping + evidence batteries, all in parallel.
      const shoppingQs = battery.shopping.slice(0, MAX_SHOPPING_QUERIES);
      const evidenceQs = battery.evidence.slice(0, MAX_EVIDENCE_QUERIES);

      const [shoppingSettled, evidenceSettled] = await Promise.all([
        Promise.allSettled(shoppingQs.map((q) => serperShopping(q, 15))),
        Promise.allSettled(evidenceQs.map((q) => serperOrganic(q, 6))),
      ]);

      // 3) NORMALIZE offers
      const rawOffers: Offer[] = [];
      for (const s of shoppingSettled) {
        if (s.status !== 'fulfilled') continue;
        for (const r of s.value) {
          const o = shoppingToOffer(r, seed);
          if (o) rawOffers.push(o);
        }
      }
      let offers = dedupeOffers(rawOffers);

      // price stats
      const prices = offers.map((o) => o.price).filter((p): p is number => p != null);
      const min = prices.length ? Math.min(...prices) : null;
      const max = prices.length ? Math.max(...prices) : null;
      const avg = prices.length ? Math.round(prices.reduce((a, b) => a + b, 0) / prices.length) : null;

      classify(offers, mode, seed, avg);
      offers = rankOffers(offers, mode).slice(0, 18);

      // 4) NORMALIZE evidence
      const evidence: EvidenceSource[] = [];
      for (const e of evidenceSettled) {
        if (e.status !== 'fulfilled') continue;
        for (const r of e.value) {
          if (!r.link) continue;
          const src = reviewSourceFor(r.link);
          evidence.push({
            title: r.title.slice(0, 140),
            url: r.link,
            domain: src.domain,
            snippet: (r.snippet || '').slice(0, 300),
            sourceTrust: src.trust,
            kind: src.kind,
          });
        }
      }
      evidence.sort((a, b) => b.sourceTrust - a.sourceTrust);
      const topEvidence = evidence.slice(0, 12);

      // 5) VERDICT
      const verdict = await synthesizeVerdict({
        mode,
        productName: identification.productName,
        category: identification.category,
        identificationConfidence: identification.confidence,
        offers,
        evidence: topEvidence,
      });

      // 6) AUTHENTICITY (real/fake mode only)
      const authenticity =
        mode === 'realfake'
          ? await assessAuthenticity({
              productName: identification.productName,
              category: identification.category,
              hasImage,
              evidence: topEvidence,
            })
          : undefined;

      // 7) SHARE PAYLOAD — the viral screenshot
      const bestSaving = offers.reduce((m, o) => Math.max(m, o.savingsVsAvg ?? 0), 0);
      const sharePayload = buildShare(mode, verdict, bestSaving, authenticity?.confidence);

      const result: DecisionResult = {
        mode,
        identification,
        verdict,
        offers,
        bestPrice: min,
        priceRange: { min, max, avg },
        authenticity,
        evidence: topEvidence,
        sharePayload,
        durationMs: Date.now() - started,
        cached: false,
      };

      if (cacheKey && offers.length > 0) cache.set(cacheKey, result);
      return result;
    } catch (err) {
      app.log.error({ err }, 'decide pipeline failed');
      return reply.status(500).send({
        error: 'Decision failed',
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });
}

function buildShare(
  mode: Mode,
  verdict: { decision: string },
  bestSaving: number,
  authConfidence?: number,
): DecisionResult['sharePayload'] {
  if (mode === 'realfake' && authConfidence != null) {
    return { verb: 'Real or fake?', stat: `${authConfidence}%`, line: 'AI authenticity check' };
  }
  if (verdict.decision === 'find_cheaper' && bestSaving > 0) {
    return { verb: 'Found it cheaper', stat: `£${Math.round(bestSaving)}`, line: `AI saved me £${Math.round(bestSaving)}` };
  }
  if (verdict.decision === 'skip') {
    return { verb: 'AI says', stat: 'SKIP', line: 'Better option found' };
  }
  if (verdict.decision === 'buy') {
    return { verb: 'AI says', stat: 'BUY', line: 'Worth it — best price locked' };
  }
  if (verdict.decision === 'wait') {
    return { verb: 'AI says', stat: 'WAIT', line: 'Price likely to drop' };
  }
  return { verb: 'Smart move', stat: bestSaving > 0 ? `£${Math.round(bestSaving)}` : '✓', line: 'Buy smarter with Gobly' };
}
