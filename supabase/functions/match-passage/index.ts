// Match Passage Edge Function
// Validates and records a client-proposed entry/exit match.
// Uses SELECT FOR UPDATE to prevent double-matching race conditions.
//
// POST /functions/v1/match-passage
// Authorization: Bearer <user_jwt>
// Body: { entry_passage_id: string, exit_passage_id: string }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient, createUserClient } from '../_shared/supabase-client.ts';

interface MatchRequest {
  entry_passage_id: string;
  exit_passage_id: string;
}

interface MatchResult {
  entry_passage_id: string;
  exit_passage_id: string;
  plate_number: string;
  segment_id: string;
  travel_time_minutes: number;
  violation: {
    id: string;
    type: string;
    threshold_minutes: number;
    calculated_speed_kmh: number | null;
  } | null;
  alerts_resolved: number;
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
    // Validate JWT from Authorization header
    let userClient;
    try {
      userClient = createUserClient(req);
    } catch {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify the user is authenticated
    // Pass JWT explicitly — auth.getUser() without args uses internal session state
    // which is empty when the client is created with only global headers.
    const token = req.headers.get('Authorization')?.replace('Bearer ', '') ?? '';
    const { data: { user }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Parse request body
    let body: MatchRequest;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON body' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const { entry_passage_id, exit_passage_id } = body;

    if (!entry_passage_id || !exit_passage_id) {
      return new Response(
        JSON.stringify({ error: 'Both entry_passage_id and exit_passage_id are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (entry_passage_id === exit_passage_id) {
      return new Response(
        JSON.stringify({ error: 'Entry and exit passages must be different' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Use service client for the matching operation (needs to bypass RLS for
    // cross-checkpost updates and use transactional locking)
    const supabase = createServiceClient();

    // Fetch both passages and verify they exist
    const { data: passages, error: fetchError } = await supabase
      .from('vehicle_passages')
      .select('id, plate_number, vehicle_type, checkpost_id, segment_id, recorded_at, matched_passage_id')
      .in('id', [entry_passage_id, exit_passage_id]);

    if (fetchError) {
      console.error('Error fetching passages:', fetchError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch passages' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (!passages || passages.length !== 2) {
      return new Response(
        JSON.stringify({ error: 'One or both passages not found' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const passageA = passages.find((p) => p.id === entry_passage_id)!;
    const passageB = passages.find((p) => p.id === exit_passage_id)!;

    // Verify both are unmatched
    if (passageA.matched_passage_id !== null) {
      return new Response(
        JSON.stringify({ error: 'Entry passage is already matched', passage_id: entry_passage_id }),
        {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    if (passageB.matched_passage_id !== null) {
      return new Response(
        JSON.stringify({ error: 'Exit passage is already matched', passage_id: exit_passage_id }),
        {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify same plate_number
    if (passageA.plate_number !== passageB.plate_number) {
      return new Response(
        JSON.stringify({
          error: 'Passages have different plate numbers',
          entry_plate: passageA.plate_number,
          exit_plate: passageB.plate_number,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify same segment
    if (passageA.segment_id !== passageB.segment_id) {
      return new Response(
        JSON.stringify({ error: 'Passages are on different segments' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify different checkposts
    if (passageA.checkpost_id === passageB.checkpost_id) {
      return new Response(
        JSON.stringify({ error: 'Passages are from the same checkpost' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Determine entry (earlier recorded_at) and exit (later recorded_at)
    const entryTime = new Date(passageA.recorded_at);
    const exitTime = new Date(passageB.recorded_at);
    let actualEntryId: string;
    let actualExitId: string;
    let actualEntryTime: Date;
    let actualExitTime: Date;

    if (entryTime <= exitTime) {
      actualEntryId = passageA.id;
      actualExitId = passageB.id;
      actualEntryTime = entryTime;
      actualExitTime = exitTime;
    } else {
      actualEntryId = passageB.id;
      actualExitId = passageA.id;
      actualEntryTime = exitTime;
      actualExitTime = entryTime;
    }

    // Use RPC to perform the match atomically with SELECT FOR UPDATE.
    // This prevents double-matching race conditions via row-level locking.
    const { data: matchRpcResult, error: rpcError } = await supabase.rpc(
      'fn_match_passages',
      {
        p_entry_id: actualEntryId,
        p_exit_id: actualExitId,
      },
    );

    if (rpcError) {
      // Check if it's a "passage already matched" error from the RPC
      if (rpcError.message?.includes('already matched')) {
        return new Response(
          JSON.stringify({ error: rpcError.message }),
          {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }

      console.error('Error in fn_match_passages RPC:', rpcError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to match passages' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Calculate travel time
    const travelTimeMs = actualExitTime.getTime() - actualEntryTime.getTime();
    const travelTimeMinutes = travelTimeMs / (1000 * 60);

    // Fetch segment thresholds
    const { data: segment, error: segmentError } = await supabase
      .from('highway_segments')
      .select('id, min_travel_time_minutes, max_travel_time_minutes, max_speed_kmh, distance_km')
      .eq('id', passageA.segment_id)
      .single();

    if (segmentError || !segment) {
      console.error('Error fetching segment:', segmentError?.message);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch segment thresholds' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Check for violations
    let violation: MatchResult['violation'] = null;
    const minTravelTime = Number(segment.min_travel_time_minutes);
    const maxTravelTime = Number(segment.max_travel_time_minutes);
    const distanceKm = Number(segment.distance_km);
    const calculatedSpeedKmh = travelTimeMinutes > 0
      ? distanceKm / (travelTimeMinutes / 60)
      : null;

    let violationType: string | null = null;
    let thresholdMinutes: number | null = null;

    if (travelTimeMinutes < minTravelTime) {
      violationType = 'speeding';
      thresholdMinutes = minTravelTime;
    } else if (travelTimeMinutes > maxTravelTime) {
      violationType = 'overstay';
      thresholdMinutes = maxTravelTime;
    }

    if (violationType && thresholdMinutes !== null) {
      const { data: violationData, error: violationError } = await supabase
        .from('violations')
        .insert({
          entry_passage_id: actualEntryId,
          exit_passage_id: actualExitId,
          segment_id: passageA.segment_id,
          violation_type: violationType,
          plate_number: passageA.plate_number,
          vehicle_type: passageA.vehicle_type,
          entry_time: actualEntryTime.toISOString(),
          exit_time: actualExitTime.toISOString(),
          travel_time_minutes: Math.round(travelTimeMinutes * 100) / 100,
          threshold_minutes: thresholdMinutes,
          calculated_speed_kmh: calculatedSpeedKmh
            ? Math.round(calculatedSpeedKmh * 100) / 100
            : null,
          speed_limit_kmh: Number(segment.max_speed_kmh),
          distance_km: distanceKm,
        })
        .select('id')
        .single();

      if (violationError) {
        // Unique constraint on entry_passage_id means violation already exists
        if (violationError.code === '23505') {
          console.warn('Violation already exists for this entry passage');
        } else {
          console.error('Error creating violation:', violationError.message);
        }
      } else if (violationData) {
        violation = {
          id: violationData.id,
          type: violationType,
          threshold_minutes: thresholdMinutes,
          calculated_speed_kmh: calculatedSpeedKmh
            ? Math.round(calculatedSpeedKmh * 100) / 100
            : null,
        };
      }
    }

    // Resolve any proactive_overstay_alerts for this entry passage
    const { data: resolvedAlerts, error: resolveError } = await supabase
      .from('proactive_overstay_alerts')
      .update({
        resolved: true,
        resolved_at: new Date().toISOString(),
        resolved_by_passage_id: actualExitId,
      })
      .eq('entry_passage_id', actualEntryId)
      .eq('resolved', false)
      .select('id');

    if (resolveError) {
      console.warn('Error resolving overstay alerts:', resolveError.message);
    }

    const result: MatchResult = {
      entry_passage_id: actualEntryId,
      exit_passage_id: actualExitId,
      plate_number: passageA.plate_number,
      segment_id: passageA.segment_id,
      travel_time_minutes: Math.round(travelTimeMinutes * 100) / 100,
      violation,
      alerts_resolved: resolvedAlerts?.length || 0,
    };

    console.log(
      `Match completed: ${passageA.plate_number} | ` +
      `travel=${travelTimeMinutes.toFixed(1)}min | ` +
      `violation=${violationType || 'none'}`,
    );

    return new Response(
      JSON.stringify(result),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('Unexpected error in match-passage:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
