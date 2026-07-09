/**
 * Type system for the Gobly buying / decision engine.
 *
 * The whole app ends at ONE thing: a Verdict. Every mode gathers evidence
 * (offers, dupes, reviews, authenticity signals) that feeds the verdict.
 */

/** The eight decision modes. Each maps to a distinct query battery + card layout. */
export type Mode =
  | 'find' // What is it + where to buy
  | 'cheaper' // Same/near-identical item, lowest trusted price
  | 'better' // Better alternatives (best / value / premium / budget)
  | 'dupes' // Cheaper lookalikes with the same aesthetic
  | 'realfake' // Authenticity estimate + follow-up photo requests
  | 'worthit' // The decision: buy / skip / wait
  | 'compare' // Side-by-side of 2–4 products
  | 'complete'; // Complete the look / room / setup

/** Coarse product category — steers which query battery + retailers we use. */
export type Category =
  | 'sneakers'
  | 'watches'
  | 'handbags'
  | 'fashion'
  | 'electronics'
  | 'beauty'
  | 'furniture'
  | 'homeware'
  | 'fitness'
  | 'general';

/** How a returned product relates to the thing the user scanned. */
export type MatchType = 'exact' | 'similar' | 'dupe' | 'upgrade' | 'budget';

/** The final call. This is the screenshot. */
export type Decision =
  | 'buy'
  | 'skip'
  | 'wait'
  | 'find_cheaper'
  | 'better_alternative';

/** One buyable offer, normalized from Serper shopping or a scraped product page. */
export interface Offer {
  id: string;
  title: string;
  retailer: string;
  retailerDomain: string;
  url: string;
  price: number | null; // numeric, in the search currency
  priceDisplay: string; // "£78.00"
  currency: string; // "GBP"
  image: string;
  rating: number | null; // 0–5
  reviewCount: number | null;
  delivery?: string;
  trustScore: number; // 0–100 retailer trust
  matchType: MatchType;
  reason: string; // one-line why this card is here
  savingsVsAvg?: number | null; // £ below the average price of the set
}

/** A non-shopping evidence source (reddit thread, review site, authentication guide). */
export interface EvidenceSource {
  title: string;
  url: string;
  domain: string;
  snippet: string;
  sourceTrust: number; // 0–100 how much shoppers trust this source
  kind: 'review' | 'forum' | 'expert' | 'authentication' | 'news' | 'other';
}

/** The decision object. Everything else exists to justify this. */
export interface Verdict {
  decision: Decision;
  headline: string; // "Skip it — the £34 version is identical"
  confidence: number; // 0–100 how sure the identification + call is
  valueScore: number; // 0–100
  qualityScore: number; // 0–100
  reasoning: string; // 2–4 sentence expert explanation
  whoShouldBuy: string;
  whoShouldAvoid: string;
  redFlags: string[];
  bestAlternativeId?: string; // points at an Offer.id
}

/** Authenticity assessment for real/fake mode. Never certain from one image. */
export interface Authenticity {
  estimate: 'likely_authentic' | 'suspicious' | 'inconclusive';
  confidence: number; // 0–100
  looksCorrect: string[];
  redFlags: string[];
  cannotVerify: string[];
  followUpPhotos: string[]; // "logo close-up", "stitching", "serial number"...
  disclaimer: string;
}

/** What the vision/triage step returns about the scanned thing. */
export interface Identification {
  productName: string;
  brand: string | null;
  category: Category;
  description: string;
  confidence: number; // 0–100
  searchSeed: string; // the cleanest phrase to search on
  needsBetterPhoto: boolean;
  followUpHint?: string; // "Snap the tongue label and I'll nail it"
}

/** The full response the app renders. */
export interface DecisionResult {
  mode: Mode;
  identification: Identification;
  verdict: Verdict;
  offers: Offer[];
  bestPrice: number | null;
  priceRange: { min: number | null; max: number | null; avg: number | null };
  authenticity?: Authenticity;
  evidence: EvidenceSource[];
  sharePayload: {
    verb: string; // "Saved", "Skip", "Real?"
    stat: string; // "£42", "72%"
    line: string; // "AI says skip — better option found"
  };
  durationMs: number;
  cached: boolean;
}

export interface DecideRequest {
  mode?: Mode;
  query?: string;
  imageBase64?: string; // data URL or bare base64
  category?: Category; // optional hint to skip triage guessing
}
