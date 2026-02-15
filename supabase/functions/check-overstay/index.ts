// Check Overstay Edge Function (stub - Agent 1 will implement)
// Runs every 15 min via pg_cron. Finds unmatched entries past max_travel_time,
// creates proactive_overstay_alerts.
//
// POST /functions/v1/check-overstay
// - Query unmatched entry passages past max threshold
// - Create proactive_overstay_alerts for new entries
// - Skip entries that already have alerts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (_req) => {
  return new Response(
    JSON.stringify({ error: 'Not implemented - Agent 1 will implement' }),
    { status: 501, headers: { 'Content-Type': 'application/json' } },
  );
});
