// Centralized environment configuration.
// API keys are optional at boot so the server starts cleanly on Railway
// and the health check passes before you add credentials. Endpoints that
// need the keys will throw a clear error at request time if they're missing.

function optional(name: string, fallback: string): string {
  return process.env[name] || fallback;
}

function optionalInt(name: string, fallback: number): number {
  const value = process.env[name];
  if (!value) return fallback;
  const parsed = parseInt(value, 10);
  return isNaN(parsed) ? fallback : parsed;
}

/**
 * Normalize the OpenAI model name. Tolerates the common `gpt4o` typo (a missing
 * hyphen), so `OPENAI_MODEL=gpt4o-mini` still resolves to the real `gpt-4o-mini`
 * instead of a 404 "model does not exist" at request time.
 */
function normalizeModel(raw: string): string {
  const v = (raw || '').trim();
  if (!v) return 'gpt-4o-mini';
  return v.replace(/^gpt4o/i, 'gpt-4o');
}

export const config = {
  port: optionalInt('PORT', 3000),
  openaiApiKey: optional('OPENAI_API_KEY', ''),
  openaiModel: normalizeModel(optional('OPENAI_MODEL', 'gpt-4o-mini')),
  // Either BRAVE_API_KEY or SERPER_API_KEY works. Brave is preferred when both are set.
  braveApiKey: optional('BRAVE_API_KEY', ''),
  serperApiKey: optional('SERPER_API_KEY', ''),
  cacheTtlSeconds: optionalInt('CACHE_TTL_SECONDS', 3600),
  maxCandidates: optionalInt('MAX_CANDIDATES', 6),
  resultsPerQuery: optionalInt('RESULTS_PER_QUERY', 3),
};

/** True if at least one web search provider is configured */
export function hasSearchProvider(): boolean {
  return !!config.braveApiKey || !!config.serperApiKey;
}

/** Returns which search provider will be used */
export function activeSearchProvider(): 'brave' | 'serper' | 'none' {
  if (config.braveApiKey) return 'brave';
  if (config.serperApiKey) return 'serper';
  return 'none';
}

export function assertKeysConfigured(): void {
  const missing: string[] = [];
  if (!config.openaiApiKey) missing.push('OPENAI_API_KEY');
  if (!hasSearchProvider()) missing.push('BRAVE_API_KEY or SERPER_API_KEY');
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}. ` +
        'Set them in Railway dashboard under Variables.',
    );
  }
}

/** Returns a status object for the /health endpoint */
export function configStatus(): {
  ok: boolean;
  openaiConfigured: boolean;
  braveConfigured: boolean;
  serperConfigured: boolean;
  searchProvider: 'brave' | 'serper' | 'none';
} {
  return {
    ok: true,
    openaiConfigured: !!config.openaiApiKey,
    braveConfigured: !!config.braveApiKey,
    serperConfigured: !!config.serperApiKey,
    searchProvider: activeSearchProvider(),
  };
}
