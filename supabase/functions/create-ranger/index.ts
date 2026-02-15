// Create Ranger Edge Function (stub - Agent 1 will implement)
// Creates auth user + user_profiles row atomically.
//
// POST /functions/v1/create-ranger
// - Validate admin JWT
// - Create auth.users entry with email (ranger1@bnp.local format)
// - Create user_profiles row with role='ranger'
// - Return created user details

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (_req) => {
  return new Response(
    JSON.stringify({ error: 'Not implemented - Agent 1 will implement' }),
    { status: 501, headers: { 'Content-Type': 'application/json' } },
  );
});
