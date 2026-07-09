/**
 * Trust maps for the buying engine (UK-first).
 *
 * TRUSTED_RETAILERS — where we're happy to send buyers. Higher = safer.
 * REVIEW_SOURCES    — where shoppers actually trust opinions (reddit, wirecutter…).
 * SUSPICIOUS_MARKETS — flag, don't auto-block (dupes legitimately live here).
 */

export interface RetailerInfo {
  name: string;
  trust: number; // 0–100
}

export const TRUSTED_RETAILERS: Record<string, RetailerInfo> = {
  // Marketplaces / majors
  'amazon.co.uk': { name: 'Amazon', trust: 88 },
  'amazon.com': { name: 'Amazon', trust: 85 },
  'ebay.co.uk': { name: 'eBay', trust: 72 },
  'argos.co.uk': { name: 'Argos', trust: 90 },
  'johnlewis.com': { name: 'John Lewis', trust: 96 },
  'currys.co.uk': { name: 'Currys', trust: 90 },
  'very.co.uk': { name: 'Very', trust: 82 },
  // Fashion / trainers
  'jdsports.co.uk': { name: 'JD Sports', trust: 90 },
  'size.co.uk': { name: 'size?', trust: 88 },
  'schuh.co.uk': { name: 'Schuh', trust: 88 },
  'nike.com': { name: 'Nike', trust: 97 },
  'adidas.co.uk': { name: 'adidas', trust: 96 },
  'asos.com': { name: 'ASOS', trust: 86 },
  'next.co.uk': { name: 'Next', trust: 92 },
  'endclothing.com': { name: 'END.', trust: 90 },
  'zalando.co.uk': { name: 'Zalando', trust: 86 },
  'selfridges.com': { name: 'Selfridges', trust: 95 },
  'net-a-porter.com': { name: 'NET-A-PORTER', trust: 95 },
  'farfetch.com': { name: 'Farfetch', trust: 88 },
  // Beauty
  'boots.com': { name: 'Boots', trust: 94 },
  'superdrug.com': { name: 'Superdrug', trust: 90 },
  'lookfantastic.com': { name: 'Lookfantastic', trust: 88 },
  'cultbeauty.co.uk': { name: 'Cult Beauty', trust: 88 },
  'sephora.co.uk': { name: 'Sephora', trust: 92 },
  // Home / furniture
  'ikea.com': { name: 'IKEA', trust: 93 },
  'dunelm.com': { name: 'Dunelm', trust: 90 },
  'made.com': { name: 'Made', trust: 78 },
  'wayfair.co.uk': { name: 'Wayfair', trust: 82 },
  'ao.com': { name: 'AO', trust: 88 },
};

/** Where shoppers actually trust opinions. Powers the verdict, not the price. */
export const REVIEW_SOURCES: Record<string, { trust: number; kind: EvidenceKind }> = {
  'reddit.com': { trust: 92, kind: 'forum' },
  'nytimes.com': { trust: 95, kind: 'expert' }, // Wirecutter
  'wirecutter.com': { trust: 96, kind: 'expert' },
  'rtings.com': { trust: 95, kind: 'expert' },
  'techradar.com': { trust: 84, kind: 'expert' },
  'tomsguide.com': { trust: 84, kind: 'expert' },
  'whathifi.com': { trust: 86, kind: 'expert' },
  'trustedreviews.com': { trust: 82, kind: 'expert' },
  'which.co.uk': { trust: 94, kind: 'expert' },
  'youtube.com': { trust: 80, kind: 'review' },
  'quora.com': { trust: 60, kind: 'forum' },
  'trustpilot.com': { trust: 74, kind: 'review' },
  'stackexchange.com': { trust: 82, kind: 'forum' },
  'substack.com': { trust: 66, kind: 'review' },
};

export type EvidenceKind =
  | 'review'
  | 'forum'
  | 'expert'
  | 'authentication'
  | 'news'
  | 'other';

/** Marketplaces where fakes/dupes cluster — flag as caution, never silently trust. */
export const SUSPICIOUS_MARKETS = new Set([
  'aliexpress.com',
  'dhgate.com',
  'wish.com',
  'temu.com',
  'alibaba.com',
]);

const DEFAULT_RETAILER_TRUST = 55;

function hostOf(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}

function matchMap<T>(host: string, map: Record<string, T>): T | null {
  if (map[host]) return map[host];
  for (const key of Object.keys(map)) {
    if (host === key || host.endsWith('.' + key)) return map[key];
  }
  return null;
}

export function retailerFor(url: string): RetailerInfo & { domain: string; suspicious: boolean } {
  const host = hostOf(url);
  const hit = matchMap(host, TRUSTED_RETAILERS);
  const suspicious = [...SUSPICIOUS_MARKETS].some((m) => host === m || host.endsWith('.' + m));
  if (hit) return { domain: host, suspicious, ...hit };
  const name = host.split('.').slice(0, -1).join('.') || host || 'Unknown';
  return {
    domain: host,
    suspicious,
    name: name.charAt(0).toUpperCase() + name.slice(1),
    trust: suspicious ? 30 : DEFAULT_RETAILER_TRUST,
  };
}

export function reviewSourceFor(
  url: string,
): { trust: number; kind: EvidenceKind; domain: string } {
  const host = hostOf(url);
  const hit = matchMap(host, REVIEW_SOURCES);
  if (hit) return { domain: host, ...hit };
  return { domain: host, trust: 45, kind: 'other' };
}
