// SMS Webhook Edge Function (stub - Agent 1 will implement)
// Receives Twilio webhook, parses V1 SMS format, inserts vehicle passage.
//
// POST /functions/v1/sms-webhook
// - Verify Twilio signature
// - Parse SMS body using V1 compact format
// - Look up checkpost by code
// - Insert vehicle_passages row with source='sms'
// - Return TwiML response

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (_req) => {
  return new Response(
    JSON.stringify({ error: 'Not implemented - Agent 1 will implement' }),
    { status: 501, headers: { 'Content-Type': 'application/json' } },
  );
});
