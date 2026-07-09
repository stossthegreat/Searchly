import { config } from '../config.js';

/**
 * Product-oriented Serper access for the buying engine.
 *
 * Two endpoints:
 *  - /shopping → structured product cards (price, retailer, image, rating). This is
 *    the unlock: we get buyable offers without scraping most of the time.
 *  - /search   → organic web results, used to pull review/forum/authentication
 *    snippets (reddit, wirecutter, legit-check guides) that feed the verdict.
 *
 * UK-localized by default (gl=gb). Never appends "recipe" (that was the recipe app).
 */

const SEARCH_GL = 'gb';
const SEARCH_HL = 'en';

export interface ShoppingResult {
  title: string;
  source: string; // retailer name as Google reports it
  link: string;
  price: string; // "£78.00"
  priceValue: number | null;
  currency: string;
  imageUrl: string;
  rating: number | null;
  ratingCount: number | null;
  delivery?: string;
}

export interface OrganicResult {
  title: string;
  link: string;
  snippet: string;
}

function requireKey(): string {
  if (!config.serperApiKey) throw new Error('SERPER_API_KEY not set');
  return config.serperApiKey;
}

/** Parse "£78.00" / "$1,299" / "78.00 GBP" into a number + currency. */
export function parsePrice(raw: string | undefined | null): {
  value: number | null;
  currency: string;
} {
  if (!raw) return { value: null, currency: 'GBP' };
  const currency = /£|GBP/.test(raw)
    ? 'GBP'
    : /\$|USD/.test(raw)
      ? 'USD'
      : /€|EUR/.test(raw)
        ? 'EUR'
        : 'GBP';
  const num = raw.replace(/[^0-9.]/g, '');
  const value = num ? parseFloat(num) : null;
  return { value: Number.isFinite(value as number) ? value : null, currency };
}

async function serperPost<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`https://google.serper.dev/${path}`, {
    method: 'POST',
    headers: { 'X-API-KEY': requireKey(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ gl: SEARCH_GL, hl: SEARCH_HL, ...body }),
  });
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Serper ${path} failed: ${response.status} ${text}`);
  }
  return (await response.json()) as T;
}

/** Structured shopping results — the buyable offers. */
export async function serperShopping(query: string, num = 20): Promise<ShoppingResult[]> {
  const data = await serperPost<{ shopping?: RawShopping[] }>('shopping', { q: query, num });
  return (data.shopping || []).map((r) => {
    const { value, currency } = parsePrice(r.price);
    return {
      title: r.title || '',
      source: r.source || '',
      link: r.link || '',
      price: r.price || '',
      priceValue: value,
      currency,
      imageUrl: r.imageUrl || '',
      rating: typeof r.rating === 'number' ? r.rating : null,
      ratingCount: typeof r.ratingCount === 'number' ? r.ratingCount : null,
      delivery: r.delivery,
    };
  });
}

/** Organic results — the evidence for the verdict. */
export async function serperOrganic(query: string, num = 10): Promise<OrganicResult[]> {
  const data = await serperPost<{ organic?: RawOrganic[] }>('search', { q: query, num });
  return (data.organic || []).map((r) => ({
    title: r.title || '',
    link: r.link || '',
    snippet: r.snippet || '',
  }));
}

interface RawShopping {
  title?: string;
  source?: string;
  link?: string;
  price?: string;
  imageUrl?: string;
  rating?: number;
  ratingCount?: number;
  delivery?: string;
}

interface RawOrganic {
  title?: string;
  link?: string;
  snippet?: string;
}
