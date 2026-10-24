// Edge Function `recommend`: Gemini-assisted recommendations and food chat.
// Wiring only; the logic lives in logic.ts (tested without Deno or a network).
//
// Secrets (set by the project owner with `supabase secrets set`):
//   GEMINI_API_KEY   required
//   GEMINI_MODEL     optional, default below
//   AI_DAILY_CAP     optional, default 15 Gemini calls per user per day
// SUPABASE_URL and SUPABASE_ANON_KEY are provided by the platform.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { generateJson } from './gemini.ts';
import { handleRequest } from './logic.ts';
import type { Candidate, Deps, RecommendArgs } from './logic.ts';

const DEFAULT_MODEL = 'gemini-3.5-flash-lite';
const DEFAULT_DAILY_CAP = 15;

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
};

// Best-effort, per warm instance. Only Gemini-sourced answers are stored.
const cache: Deps['cache'] = new Map();

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

function toCandidate(row: Record<string, unknown>): Candidate {
  return {
    dish_id: String(row.dish_id),
    dish_name: String(row.dish_name),
    description: String(row.description ?? ''),
    price_inr: Number(row.price_inr),
    is_veg: row.is_veg === true,
    category: String(row.category),
    restaurant_id: String(row.restaurant_id),
    restaurant_name: String(row.restaurant_name),
    area: String(row.area),
    distance_km: Number(row.distance_km),
    score: Number(row.score),
  };
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders });
  if (request.method !== 'POST') return json(405, { error: 'Method not allowed' });

  const authorization = request.headers.get('Authorization') ?? '';
  const token = authorization.replace(/^Bearer\s+/i, '');
  if (!token) return json(401, { error: 'Please sign in' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const geminiKey = Deno.env.get('GEMINI_API_KEY');
  if (!supabaseUrl || !anonKey) return json(500, { error: 'Server is not configured' });

  // Calls run as the user, so RLS and auth.uid() apply to every query.
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await client.auth.getUser(token);
  if (userError || !userData.user) return json(401, { error: 'Please sign in again' });

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json(400, { error: 'Invalid request' });
  }

  const cap = Number(Deno.env.get('AI_DAILY_CAP')) || DEFAULT_DAILY_CAP;
  const model = Deno.env.get('GEMINI_MODEL') || DEFAULT_MODEL;

  const deps: Deps = {
    userId: userData.user.id,
    cache,
    now: () => Date.now(),
    async recommend(args: RecommendArgs) {
      const { data, error } = await client.rpc('recommend_dishes', {
        p_mood_id: args.moodId,
        p_lat: args.lat,
        p_lng: args.lng,
        p_max_price: args.maxPrice,
        p_diet: args.diet,
        p_use_embeddings: true,
        p_limit: args.limit,
      });
      if (error) throw new Error(error.message);
      return (data as Record<string, unknown>[]).map(toCandidate);
    },
    async claimCall() {
      if (!geminiKey) return false; // no key configured: behave like a spent quota
      const { data, error } = await client.rpc('claim_ai_call', { p_cap: cap });
      return !error && data === true;
    },
    gemini: (prompt) =>
      generateJson({ fetchFn: fetch, apiKey: geminiKey ?? '', model, system: prompt.system, user: prompt.user }),
  };

  try {
    const result = await handleRequest(deps, body);
    return json(result.status, result.body);
  } catch (e) {
    // Retrieval failed (for example Mumbai-only check or database error).
    const message = e instanceof Error && e.message === 'We deliver only in Mumbai' ? e.message : 'Could not get recommendations';
    return json(message === 'We deliver only in Mumbai' ? 422 : 502, { error: message });
  }
});
