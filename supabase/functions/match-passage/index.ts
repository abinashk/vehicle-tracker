// Match Passage Edge Function (stub - Agent 1 will implement)
// Validates and records a client-proposed entry/exit match.
//
// POST /functions/v1/match-passage
// - Validate JWT
// - Verify both passages exist, same segment, opposite checkposts
// - Use SELECT FOR UPDATE to prevent double-matching
// - Calculate travel time and check thresholds
// - Create violation if breached

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (_req) => {
  return new Response(
    JSON.stringify({ error: 'Not implemented - Agent 1 will implement' }),
    { status: 501, headers: { 'Content-Type': 'application/json' } },
  );
});
