// Minimal Gemini generateContent client: JSON output, timeout, one retry.
// Pure apart from the injected fetch/sleep, so it can be tested without a network.

export class GeminiError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'GeminiError';
  }
}

export interface GeminiOptions {
  fetchFn: typeof fetch;
  apiKey: string;
  model: string;
  system: string;
  user: string;
  timeoutMs?: number;
  retries?: number;
  sleep?: (ms: number) => Promise<void>;
}

const RETRY_DELAY_MS = 600;

function isRetryable(status: number): boolean {
  return status === 429 || status >= 500;
}

/** Returns the model's text (expected to be a JSON document). Throws GeminiError. */
export async function generateJson(options: GeminiOptions): Promise<string> {
  const { fetchFn, apiKey, model, system, user } = options;
  const timeoutMs = options.timeoutMs ?? 8000;
  const retries = options.retries ?? 1;
  const sleep = options.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: 'user', parts: [{ text: user }] }],
    generationConfig: { responseMimeType: 'application/json', temperature: 0.4, maxOutputTokens: 800 },
  });

  let lastError = 'unknown';
  for (let attempt = 0; attempt <= retries; attempt++) {
    if (attempt > 0) await sleep(RETRY_DELAY_MS);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchFn(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
        body,
        signal: controller.signal,
      });
      if (!response.ok) {
        lastError = `http ${response.status}`;
        if (isRetryable(response.status)) continue;
        break;
      }
      const json = await response.json();
      const parts = json?.candidates?.[0]?.content?.parts;
      const text = Array.isArray(parts)
        ? parts.map((p: { text?: unknown }) => (typeof p?.text === 'string' ? p.text : '')).join('')
        : '';
      if (!text.trim()) {
        lastError = 'empty response';
        break;
      }
      return text;
    } catch (e) {
      lastError = (e as Error)?.name === 'AbortError' ? 'timeout' : 'network error';
    } finally {
      clearTimeout(timer);
    }
  }
  throw new GeminiError(lastError);
}
