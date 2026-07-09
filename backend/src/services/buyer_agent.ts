import OpenAI from 'openai';
import { config, assertKeysConfigured } from '../config.js';
import type {
  Authenticity,
  Category,
  Identification,
  Mode,
  Offer,
  EvidenceSource,
  Verdict,
} from '../types/buying.js';
import { authFollowUps } from './presets.js';

let _client: OpenAI | null = null;
function client(): OpenAI {
  assertKeysConfigured();
  if (!_client) _client = new OpenAI({ apiKey: config.openaiApiKey });
  return _client;
}

const CATEGORIES: Category[] = [
  'sneakers',
  'watches',
  'handbags',
  'fashion',
  'electronics',
  'beauty',
  'furniture',
  'homeware',
  'fitness',
  'general',
];

function coerceCategory(v: unknown): Category {
  const s = String(v || '').toLowerCase();
  return (CATEGORIES.find((c) => c === s) as Category) || 'general';
}

function clamp(n: unknown, lo = 0, hi = 100): number {
  const x = typeof n === 'number' ? n : parseFloat(String(n));
  if (!Number.isFinite(x)) return lo;
  return Math.max(lo, Math.min(hi, Math.round(x)));
}

function toDataUrl(imageBase64: string): string {
  return imageBase64.startsWith('data:') ? imageBase64 : `data:image/jpeg;base64,${imageBase64}`;
}

async function json<T>(messages: OpenAI.Chat.ChatCompletionMessageParam[], maxTokens = 700): Promise<T> {
  const res = await client().chat.completions.create({
    model: config.openaiModel,
    messages,
    temperature: 0.2,
    max_tokens: maxTokens,
    response_format: { type: 'json_object' },
  });
  return JSON.parse(res.choices[0]?.message?.content || '{}') as T;
}

/**
 * TRIAGE: figure out what the user is pointing at, from text and/or a photo.
 * Honest by design — low confidence sets needsBetterPhoto + a follow-up hint.
 */
export async function identifyProduct(input: {
  query?: string;
  imageBase64?: string;
  categoryHint?: Category;
}): Promise<Identification> {
  const sys = `You are an expert product identifier for a premium shopping app. Identify the product from the user's text and/or image. Be precise about brand and model when visible; do NOT invent specifics you cannot see.
Return JSON only:
{
  "productName": "specific name incl brand+model if known",
  "brand": "brand or null",
  "category": one of ${CATEGORIES.join(', ')},
  "description": "one vivid sentence",
  "confidence": 0-100 (how sure you are of the exact item),
  "searchSeed": "the cleanest phrase to search shopping sites with",
  "needsBetterPhoto": true if you are guessing,
  "followUpHint": "if unsure, a short instruction like 'Snap the tongue label and I'll nail it', else null"
}`;

  const userContent: OpenAI.Chat.ChatCompletionContentPart[] = [];
  userContent.push({
    type: 'text',
    text: input.query ? `User request: ${input.query}` : 'Identify the product in the image.',
  });
  if (input.imageBase64) {
    userContent.push({ type: 'image_url', image_url: { url: toDataUrl(input.imageBase64), detail: 'low' } });
  }

  const raw = await json<Partial<Identification>>([
    { role: 'system', content: sys },
    { role: 'user', content: userContent },
  ]);

  const confidence = clamp(raw.confidence ?? 50);
  return {
    productName: (raw.productName || input.query || 'Unknown item').toString().slice(0, 120),
    brand: raw.brand ? String(raw.brand).slice(0, 60) : null,
    category: input.categoryHint || coerceCategory(raw.category),
    description: (raw.description || '').toString().slice(0, 240),
    confidence,
    searchSeed: (raw.searchSeed || raw.productName || input.query || '').toString().slice(0, 120),
    needsBetterPhoto: Boolean(raw.needsBetterPhoto) || confidence < 55,
    followUpHint: raw.followUpHint ? String(raw.followUpHint).slice(0, 120) : undefined,
  };
}

/** Compact the offers + evidence into a token-cheap digest for the verdict model. */
function digest(offers: Offer[], evidence: EvidenceSource[]): string {
  const priced = offers.filter((o) => o.price != null);
  const offerLines = offers
    .slice(0, 10)
    .map(
      (o) =>
        `- [${o.id}] ${o.matchType.toUpperCase()} ${o.title} @ ${o.retailer} ${o.priceDisplay || '?'} (retailerTrust ${o.trustScore}${o.rating ? `, ${o.rating}★×${o.reviewCount ?? '?'}` : ''})`,
    )
    .join('\n');
  const evLines = evidence
    .slice(0, 12)
    .map((e) => `- (${e.kind}, trust ${e.sourceTrust}) ${e.title}: ${e.snippet}`.slice(0, 240))
    .join('\n');
  const prices = priced.map((o) => o.price as number);
  const stat = prices.length
    ? `min £${Math.min(...prices)}, max £${Math.max(...prices)}, ${prices.length} priced offers`
    : 'no reliable prices found';
  return `PRICE SUMMARY: ${stat}\n\nOFFERS:\n${offerLines || '(none)'}\n\nEVIDENCE:\n${evLines || '(none)'}`;
}

/**
 * THE VERDICT. Everything the app does leads here. Decisive, but honest about
 * confidence and grounded ONLY in the offers/evidence provided.
 */
export async function synthesizeVerdict(params: {
  mode: Mode;
  productName: string;
  category: Category;
  identificationConfidence: number;
  offers: Offer[];
  evidence: EvidenceSource[];
}): Promise<Verdict> {
  const { mode, productName, offers, evidence, identificationConfidence } = params;

  const sys = `You are an elite personal buyer. Give a DECISION, not a summary. Base every claim ONLY on the OFFERS and EVIDENCE provided — never invent prices, ratings, or facts. Be decisive but honest; if evidence is thin, say so and lower confidence.
The user's mode is "${mode}". Return JSON only:
{
  "decision": one of buy | skip | wait | find_cheaper | better_alternative,
  "headline": "punchy screenshot-worthy verdict, <= 60 chars, e.g. 'Skip it — the £34 version is identical'",
  "confidence": 0-100,
  "valueScore": 0-100,
  "qualityScore": 0-100,
  "reasoning": "2-4 sentences an expert would actually say",
  "whoShouldBuy": "one line",
  "whoShouldAvoid": "one line",
  "redFlags": ["short flags, [] if none"],
  "bestAlternativeId": "the [id] of the offer you'd steer them to, or null"
}`;

  const raw = await json<Partial<Verdict>>(
    [
      { role: 'system', content: sys },
      {
        role: 'user',
        content: `PRODUCT: ${productName}\nIdentification confidence: ${identificationConfidence}%\n\n${digest(offers, evidence)}`,
      },
    ],
    600,
  );

  const validDecisions = ['buy', 'skip', 'wait', 'find_cheaper', 'better_alternative'];
  const decision = validDecisions.includes(String(raw.decision))
    ? (raw.decision as Verdict['decision'])
    : 'find_cheaper';

  return {
    decision,
    headline: (raw.headline || 'Here’s the smart move').toString().slice(0, 80),
    confidence: Math.min(clamp(raw.confidence ?? 60), identificationConfidence + 10),
    valueScore: clamp(raw.valueScore ?? 50),
    qualityScore: clamp(raw.qualityScore ?? 50),
    reasoning: (raw.reasoning || '').toString().slice(0, 600),
    whoShouldBuy: (raw.whoShouldBuy || '').toString().slice(0, 160),
    whoShouldAvoid: (raw.whoShouldAvoid || '').toString().slice(0, 160),
    redFlags: Array.isArray(raw.redFlags) ? raw.redFlags.map((f) => String(f).slice(0, 120)).slice(0, 6) : [],
    bestAlternativeId: raw.bestAlternativeId ? String(raw.bestAlternativeId).replace(/[[\]]/g, '') : undefined,
  };
}

/**
 * AUTHENTICITY — real/fake mode. NEVER certain from one image. Estimates only,
 * always asks for verifying follow-up photos, always disclaims.
 */
export async function assessAuthenticity(params: {
  productName: string;
  category: Category;
  hasImage: boolean;
  evidence: EvidenceSource[];
}): Promise<Authenticity> {
  const { productName, category, hasImage, evidence } = params;
  const evLines = evidence
    .slice(0, 10)
    .map((e) => `- ${e.title}: ${e.snippet}`.slice(0, 220))
    .join('\n');

  const sys = `You are a cautious authentication assistant. You NEVER declare certain real/fake from limited info. Use the authentication guidance in EVIDENCE to explain what to check. Return JSON only:
{
  "estimate": one of likely_authentic | suspicious | inconclusive,
  "confidence": 0-100 (keep modest; max 80 from an image alone),
  "looksCorrect": ["what appears right, [] if unknown"],
  "redFlags": ["visible concerns, [] if none"],
  "cannotVerify": ["what can't be judged without more photos"],
  "followUpPhotos": ["specific angles to request"]
}`;

  const raw = await json<Partial<Authenticity>>(
    [
      { role: 'system', content: sys },
      {
        role: 'user',
        content: `PRODUCT: ${productName} (category ${category})\nImage provided: ${hasImage ? 'yes' : 'no'}\n\nAUTHENTICATION EVIDENCE:\n${evLines || '(none found)'}`,
      },
    ],
    500,
  );

  const followUps =
    Array.isArray(raw.followUpPhotos) && raw.followUpPhotos.length
      ? raw.followUpPhotos.map((f) => String(f).slice(0, 60)).slice(0, 8)
      : authFollowUps(category);

  const estimate = (['likely_authentic', 'suspicious', 'inconclusive'] as const).includes(
    raw.estimate as Authenticity['estimate'],
  )
    ? (raw.estimate as Authenticity['estimate'])
    : 'inconclusive';

  return {
    estimate,
    confidence: Math.min(clamp(raw.confidence ?? 40), hasImage ? 80 : 50),
    looksCorrect: Array.isArray(raw.looksCorrect) ? raw.looksCorrect.map((x) => String(x).slice(0, 120)).slice(0, 6) : [],
    redFlags: Array.isArray(raw.redFlags) ? raw.redFlags.map((x) => String(x).slice(0, 120)).slice(0, 6) : [],
    cannotVerify: Array.isArray(raw.cannotVerify) ? raw.cannotVerify.map((x) => String(x).slice(0, 120)).slice(0, 6) : [],
    followUpPhotos: followUps,
    disclaimer: 'Image-based estimate only — expert verification may be needed.',
  };
}
