// CORS headers for Edge Functions.
// Uses ALLOWED_ORIGIN env var in production, falls back to restrictive default.
const allowedOrigin = Deno.env.get('ALLOWED_ORIGIN') || 'https://dashboard.bnp.gov.np';

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': allowedOrigin,
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
