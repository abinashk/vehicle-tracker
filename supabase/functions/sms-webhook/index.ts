// SMS Webhook Edge Function
// Receives Twilio webhook POST, verifies signature, parses V1 SMS format,
// inserts vehicle passage with source='sms'.
//
// POST /functions/v1/sms-webhook
// Content-Type: application/x-www-form-urlencoded (Twilio webhook format)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { encode as encodeBase64 } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';
import { parseSmsBody } from '../_shared/sms-parser.ts';

// Map SMS parser vehicle types to DB-compatible vehicle_type values.
// The vehicle_passages CHECK constraint allows:
//   'car', 'jeep', 'pickup', 'van', 'minibus', 'bus', 'truck', 'tanker', 'motorcycle', 'other'
const VEHICLE_TYPE_DB_MAP: Record<string, string> = {
  car: 'car',
  jeep_suv: 'jeep',
  minibus: 'minibus',
  bus: 'bus',
  truck: 'truck',
  tanker: 'tanker',
  motorcycle: 'motorcycle',
  auto_rickshaw: 'other',
  tractor: 'other',
  other: 'other',
};

/**
 * Generate a deterministic UUID v5-like ID from the SMS content.
 * Uses SHA-256 hash of the SMS body to create a stable UUID for idempotency.
 */
async function generateDeterministicId(smsBody: string): Promise<string> {
  const data = new TextEncoder().encode(smsBody);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = new Uint8Array(hashBuffer);

  // Format as UUID v5 (set version nibble to 5, variant bits to 10xx)
  hashArray[6] = (hashArray[6] & 0x0f) | 0x50; // version 5
  hashArray[8] = (hashArray[8] & 0x3f) | 0x80; // variant 10xx

  const hex = Array.from(hashArray.slice(0, 16))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}

/**
 * Verify the Twilio request signature.
 * See: https://www.twilio.com/docs/usage/security#validating-requests
 */
async function verifyTwilioSignature(
  signature: string,
  url: string,
  params: Record<string, string>,
  authToken: string,
): Promise<boolean> {
  // Build the data string: URL + sorted params concatenated as key+value
  const sortedKeys = Object.keys(params).sort();
  let dataString = url;
  for (const key of sortedKeys) {
    dataString += key + params[key];
  }

  // HMAC-SHA1 the data string with the auth token
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(authToken),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );

  const signatureBytes = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(dataString),
  );

  const computedSignature = encodeBase64(signatureBytes);
  return computedSignature === signature;
}

/**
 * Build a TwiML XML response.
 */
function twimlResponse(message: string): Response {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>${escapeXml(message)}</Message>
</Response>`;

  return new Response(xml, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/xml',
    },
  });
}

/**
 * Build an empty TwiML response (no reply SMS).
 */
function emptyTwimlResponse(): Response {
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<Response></Response>`;

  return new Response(xml, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'text/xml',
    },
  });
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only accept POST requests
  if (req.method !== 'POST') {
    return twimlResponse('Method not allowed');
  }

  try {
    // Parse form-encoded body from Twilio
    const formData = await req.formData();
    const params: Record<string, string> = {};
    formData.forEach((value, key) => {
      params[key] = value.toString();
    });

    // Verify Twilio signature - REQUIRED, never skip
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN');
    if (!twilioAuthToken) {
      console.error('TWILIO_AUTH_TOKEN env var is not set - rejecting request');
      return twimlResponse('Server configuration error');
    }

    const twilioSignature = req.headers.get('X-Twilio-Signature');
    if (!twilioSignature) {
      console.error('Missing X-Twilio-Signature header');
      return twimlResponse('Unauthorized');
    }

    // Use configured webhook URL for signature verification.
    // In Docker/CI, req.url is the internal runtime URL which differs from the
    // external URL that Twilio (or tests) use to compute the signature.
    const validationUrl = Deno.env.get('SMS_WEBHOOK_URL') || new URL(req.url).toString();

    const isValid = await verifyTwilioSignature(
      twilioSignature,
      validationUrl,
      params,
      twilioAuthToken,
    );

    if (!isValid) {
      console.error('Invalid Twilio signature');
      return twimlResponse('Unauthorized');
    }

    // Extract SMS body
    const smsBody = params['Body'];
    if (!smsBody) {
      console.error('Missing SMS Body parameter');
      return twimlResponse('Error: No message body received.');
    }

    // Parse the V1 compact format
    let parsed;
    try {
      parsed = parseSmsBody(smsBody.trim());
    } catch (parseError) {
      console.error('SMS parse error:', parseError);
      return twimlResponse(`Error: ${(parseError as Error).message}`);
    }

    const supabase = createServiceClient();

    // Look up checkpost by code to get checkpost_id and segment_id
    const { data: checkpost, error: checkpostError } = await supabase
      .from('checkposts')
      .select('id, segment_id')
      .eq('code', parsed.checkpostCode)
      .eq('is_active', true)
      .single();

    if (checkpostError || !checkpost) {
      console.error('Checkpost lookup failed:', checkpostError?.message);
      return twimlResponse(`Error: Unknown checkpost code "${parsed.checkpostCode}".`);
    }

    // Look up ranger by phone suffix (last 4 digits of phone_number)
    const { data: rangers, error: rangerError } = await supabase
      .from('user_profiles')
      .select('id')
      .eq('role', 'ranger')
      .eq('is_active', true)
      .like('phone_number', `%${parsed.rangerPhoneSuffix}`);

    if (rangerError || !rangers || rangers.length === 0) {
      console.error('Ranger lookup failed:', rangerError?.message);
      return twimlResponse(`Error: No ranger found with phone suffix "${parsed.rangerPhoneSuffix}".`);
    }

    if (rangers.length > 1) {
      console.error(`Ambiguous ranger lookup: ${rangers.length} rangers match phone suffix "${parsed.rangerPhoneSuffix}"`);
      return twimlResponse(`Error: Multiple rangers match phone suffix "${parsed.rangerPhoneSuffix}". Contact admin.`);
    }

    const rangerId = rangers[0].id;

    // Map vehicle type from SMS parser output to DB-compatible value
    const dbVehicleType = VEHICLE_TYPE_DB_MAP[parsed.vehicleType] || 'other';

    // Generate deterministic client_id from the SMS content for idempotency
    const clientId = await generateDeterministicId(smsBody.trim());

    // Insert into vehicle_passages with ON CONFLICT (client_id) DO NOTHING.
    // Don't use .single() since ignoreDuplicates returns no rows on conflict.
    const { data: passages, error: insertError } = await supabase
      .from('vehicle_passages')
      .upsert(
        {
          client_id: clientId,
          plate_number: parsed.plateNumber,
          vehicle_type: dbVehicleType,
          checkpost_id: checkpost.id,
          segment_id: checkpost.segment_id,
          recorded_at: parsed.recordedAt.toISOString(),
          ranger_id: rangerId,
          source: 'sms',
        },
        {
          onConflict: 'client_id',
          ignoreDuplicates: true,
        },
      )
      .select('id');

    if (insertError) {
      console.error('Insert error:', insertError.message);
      return twimlResponse('Error: Failed to record passage.');
    }

    const passage = passages?.[0];
    if (passage) {
      console.log(`SMS passage recorded: ${passage.id} for plate ${parsed.plateNumber} at ${parsed.checkpostCode}`);
    } else {
      console.log(`SMS passage deduplicated (already exists) for plate ${parsed.plateNumber} at ${parsed.checkpostCode}`);
    }
    return twimlResponse(`OK: ${parsed.plateNumber} recorded at ${parsed.checkpostCode}.`);
  } catch (err) {
    // Always return 200 with TwiML to Twilio, even on unexpected errors
    console.error('Unexpected error in sms-webhook:', err);
    return emptyTwimlResponse();
  }
});
