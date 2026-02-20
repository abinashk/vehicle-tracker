import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient, SUPABASE_ANON_KEY } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

/**
 * Compute Twilio signature for webhook validation
 * HMAC-SHA1(url_with_sorted_params, TWILIO_AUTH_TOKEN), base64 encoded
 */
async function computeTwilioSignature(
  url: string,
  params: Record<string, string>,
  authToken: string
): Promise<string> {
  const sortedKeys = Object.keys(params).sort()
  let dataToSign = url
  for (const key of sortedKeys) {
    dataToSign += key + params[key]
  }

  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(authToken),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(dataToSign)
  )

  return btoa(String.fromCharCode(...new Uint8Array(signature)))
}

Deno.test("SMS webhook creates passage with source=sms", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger with phone number ending in "5678"
    const ranger = await createTestRanger(SEED.checkposts.east.id, '+9779845675678')
    testUsers.push(ranger.id)

    const plateNumber = `SMS${Date.now()}`
    testPlates.push(plateNumber)

    // Build SMS body: V1|BNP-A|PLATE|CAR|TIMESTAMP|LAST4
    const timestamp = Math.floor(Date.now() / 1000)
    const smsBody = `V1|BNP-A|${plateNumber}|CAR|${timestamp}|5678`

    // URL-encode as form data
    const fromNumber = '+9779845675678'
    const formParams = {
      Body: smsBody,
      From: fromNumber,
    }

    const formData = Object.entries(formParams)
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join('&')

    // Get TWILIO_AUTH_TOKEN from env
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN') || 'test_twilio_token_for_ci'
    assertExists(twilioAuthToken, 'TWILIO_AUTH_TOKEN must be set')

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'
    const webhookUrl = `${supabaseUrl}/functions/v1/sms-webhook`

    // Compute Twilio signature
    const signature = await computeTwilioSignature(webhookUrl, formParams, twilioAuthToken)

    // Call POST with Content-Type: application/x-www-form-urlencoded, X-Twilio-Signature header
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'X-Twilio-Signature': signature,
      },
      body: formData,
    })

    // Consume response body (TwiML XML)
    const responseBody = await response.text()

    // Assert response status = 200
    assertEquals(response.status, 200, `SMS webhook should return 200, got ${response.status}: ${responseBody}`)

    // Use service client to query passages where source = 'sms' and plate_number matches
    const supabase = getServiceClient()

    const { data: passages, error: queryError } = await supabase
      .from('vehicle_passages')
      .select('*')
      .eq('source', 'sms')
      .eq('plate_number', plateNumber)

    assertEquals(queryError, null, 'Should query passages without error')
    assertEquals(passages?.length, 1, 'Should have exactly 1 passage from SMS')

    const smsPassage = passages?.[0]
    assertExists(smsPassage, 'SMS passage should exist')
    assertEquals(smsPassage.checkpost_id, SEED.checkposts.east.id, 'Should be at correct checkpost (BNP-A)')
    assertEquals(smsPassage.vehicle_type, 'car', 'Should have correct vehicle type')
    assertEquals(smsPassage.source, 'sms', 'Should have source=sms')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
