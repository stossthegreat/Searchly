import type { Mode, Category } from '../types/buying.js';

/**
 * THE QUERY INTENT PRESET ENGINE.
 *
 * A pro buyer never runs one search — they run a *pattern* of searches shaped by
 * their intent and the category. This module encodes those patterns. For a given
 * (mode × category) we emit two batteries:
 *
 *   shopping[] → fired at Serper /shopping to collect buyable offers
 *   evidence[] → fired at Serper /search to collect reviews / forums / auth guides
 *
 * `{p}` is replaced with the product seed, `{b}` with the brand, `{c}` with the
 * category noun. Templates that need a brand and have none are dropped.
 */

export interface QueryBattery {
  shopping: string[];
  evidence: string[];
}

interface Seeds {
  product: string; // "Nike Air Max 90"
  brand: string | null; // "Nike"
  category: Category;
}

const CATEGORY_NOUN: Record<Category, string> = {
  sneakers: 'trainers',
  watches: 'watch',
  handbags: 'handbag',
  fashion: 'clothing',
  electronics: 'gadget',
  beauty: 'product',
  furniture: 'furniture',
  homeware: 'homeware',
  fitness: 'fitness gear',
  general: 'product',
};

/** Categories where authenticity + dupes dominate buyer behaviour. */
const AUTHENTICITY_HEAVY: Category[] = ['sneakers', 'watches', 'handbags'];
const DUPE_HEAVY: Category[] = ['sneakers', 'watches', 'handbags', 'fashion', 'beauty', 'furniture'];

function fill(tpl: string, s: Seeds): string | null {
  if (tpl.includes('{b}') && !s.brand) return null;
  return tpl
    .replace(/\{p\}/g, s.product)
    .replace(/\{b\}/g, s.brand || '')
    .replace(/\{c\}/g, CATEGORY_NOUN[s.category])
    .replace(/\s+/g, ' ')
    .trim();
}

function build(shoppingTpls: string[], evidenceTpls: string[], s: Seeds): QueryBattery {
  const uniq = (arr: string[]) =>
    Array.from(new Set(arr.map((t) => fill(t, s)).filter((q): q is string => !!q)));
  return { shopping: uniq(shoppingTpls), evidence: uniq(evidenceTpls) };
}

/**
 * Base shopping intents shared by most modes — the "where to buy + price" spine.
 */
const BASE_SHOPPING = ['{p}', '{p} best price uk', '{p} buy uk'];

export function queryBattery(mode: Mode, seeds: Seeds): QueryBattery {
  const s = seeds;
  const authHeavy = AUTHENTICITY_HEAVY.includes(s.category);
  const dupeHeavy = DUPE_HEAVY.includes(s.category);

  switch (mode) {
    case 'find':
      return build(
        [...BASE_SHOPPING, '{p} {c}', '{b} {p}'],
        ['{p} review', 'what is {p}'],
        s,
      );

    case 'cheaper':
      return build(
        [
          '{p}',
          '{p} cheapest uk',
          '{p} deal',
          '{p} discount code',
          '{p} sale uk',
          '{p} price comparison',
          '{p} refurbished',
        ],
        ['{p} discount code reddit', '{p} cheapest place to buy'],
        s,
      );

    case 'better':
      return build(
        ['best {c} 2026', 'best {c} for the money', '{p} alternative', 'top rated {c}'],
        [
          'best {c} 2026 reddit',
          'best {c} wirecutter rtings',
          '{p} vs',
          'better than {p}',
        ],
        s,
      );

    case 'dupes':
      return build(
        [
          '{p} dupe',
          '{b} {c} lookalike',
          'cheaper alternative to {p}',
          '{p} similar cheaper',
          dupeHeavy ? '{c} that looks like {p}' : '{p} budget version',
        ],
        ['{p} dupe reddit', 'best {p} dupes', 'looks like {p} but cheaper'],
        s,
      );

    case 'realfake':
      // Shopping still runs so we can price the genuine article for context.
      return build(
        ['{p} official', '{b} {p} authentic'],
        [
          '{p} real vs fake',
          'how to spot fake {b} {c}',
          '{p} legit check reddit',
          authHeavy ? '{b} {c} authentication guide' : '{p} genuine vs replica',
          '{p} fake serial number',
        ],
        s,
      );

    case 'worthit':
      return build(
        [...BASE_SHOPPING],
        [
          '{p} review reddit',
          '{p} long term review',
          '{p} problems complaints',
          'is {p} worth it',
          '{p} vs',
          'best {c} 2026 which',
        ],
        s,
      );

    case 'compare':
      return build(
        ['{p}', '{p} price uk'],
        ['{p} comparison', '{p} vs alternatives', '{p} review reddit'],
        s,
      );

    case 'complete':
      return build(
        [
          '{p} matching set',
          'complete the look {p}',
          'goes with {p}',
          '{c} to match {p}',
          'accessories for {p}',
        ],
        ['how to style {p}', '{p} outfit ideas reddit'],
        s,
      );

    default:
      return build(BASE_SHOPPING, ['{p} review'], s);
  }
}

/** Follow-up photo requests for authenticity, tuned per category. */
export function authFollowUps(category: Category): string[] {
  switch (category) {
    case 'sneakers':
      return ['box label', 'tongue tag', 'stitching close-up', 'sole/insole', 'size tag'];
    case 'watches':
      return ['dial close-up', 'caseback engraving', 'clasp', 'serial number', 'movement'];
    case 'handbags':
      return ['logo hardware', 'interior tag', 'stitching', 'date/serial code', 'zipper pulls'];
    default:
      return ['logo close-up', 'label / tag', 'serial number', 'box', 'receipt'];
  }
}
