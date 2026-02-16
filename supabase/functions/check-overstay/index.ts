// Check Overstay Edge Function
// Runs every 15 minutes via pg_cron or manual trigger.
// Finds unmatched entry passages past max_travel_time and creates
// proactive_overstay_alerts.
//
// POST /functions/v1/check-overstay
// Authorization: Bearer <service_role_key> or admin JWT

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';

/**
 * Validate that the request comes from either:
 * 1. A service role key (for pg_cron invocations)
 * 2. An authenticated admin user
 */
async function validateCaller(req: Request): Promise<{ valid: boolean; error?: string }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return { valid: false, error: 'Missing Authorization header' };
  }

  const token = authHeader.replace('Bearer ', '');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  // Check if it's the service role key (used by pg_cron)
  if (token === serviceRoleKey) {
    return { valid: true };
  }

  // Otherwise, verify it's an admin JWT
  const supabase = createServiceClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);

  if (authError || !user) {
    return { valid: false, error: 'Invalid or expired token' };
  }

  // Check if user has admin role
  const { data: profile, error: profileError } = await supabase
    .from('user_profiles')
    .select('role')
    .eq('id', user.id)
    .single();

  if (profileError || !profile || profile.role !== 'admin') {
    return { valid: false, error: 'Forbidden: admin role required' };
  }

  return { valid: true };
}

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }

  try {
    // Validate caller authorization
    const authResult = await validateCaller(req);
    if (!authResult.valid) {
      const status = authResult.error?.includes('Forbidden') ? 403 : 401;
      return new Response(
        JSON.stringify({ error: authResult.error }),
        {
          status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const supabase = createServiceClient();

    // Find unmatched passages that have exceeded max_travel_time_minutes,
    // excluding those that already have a proactive_overstay_alert.
    // Uses the find_overdue_unmatched_passages RPC (migration 00013).
    const { data: overduePassages, error: queryError } = await supabase
      .rpc('find_overdue_unmatched_passages');

    if (queryError) {
      console.error('Error calling find_overdue_unmatched_passages RPC:', queryError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to query overdue passages' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const passages: Array<{
      id: string;
      plate_number: string;
      vehicle_type: string;
      recorded_at: string;
      segment_id: string;
      max_travel_time_minutes: number;
    }> = overduePassages || [];

    if (passages.length === 0) {
      return new Response(
        JSON.stringify({ alerts_created: 0, message: 'No overdue passages found' }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Create proactive_overstay_alerts for each qualifying passage
    const alertsToInsert = passages.map((p) => {
      const recordedAt = new Date(p.recorded_at);
      const expectedExitBy = new Date(
        recordedAt.getTime() + p.max_travel_time_minutes * 60 * 1000,
      );

      return {
        entry_passage_id: p.id,
        segment_id: p.segment_id,
        plate_number: p.plate_number,
        vehicle_type: p.vehicle_type,
        entry_time: p.recorded_at,
        expected_exit_by: expectedExitBy.toISOString(),
      };
    });

    const { data: insertedAlerts, error: insertError } = await supabase
      .from('proactive_overstay_alerts')
      .insert(alertsToInsert)
      .select('id');

    if (insertError) {
      // Handle unique constraint violations gracefully (concurrent runs)
      if (insertError.code === '23505') {
        console.warn('Some alerts already existed (concurrent run), continuing');
        return new Response(
          JSON.stringify({
            alerts_created: 0,
            message: 'Alerts already exist for overdue passages',
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }

      console.error('Error inserting alerts:', insertError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to create overstay alerts' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const alertCount = insertedAlerts?.length || 0;
    console.log(`Created ${alertCount} proactive overstay alerts`);

    return new Response(
      JSON.stringify({
        alerts_created: alertCount,
        message: `Created ${alertCount} new overstay alert(s)`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('Unexpected error in check-overstay:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
