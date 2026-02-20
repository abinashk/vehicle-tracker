import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Overstay: unmatched entry past max time triggers alert via check-overstay", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.id)

    // Generate unique plate
    const plateNumber = `OVERSTAY-${Date.now()}`
    testPlates.push(plateNumber)

    const supabase = getServiceClient()

    // Insert entry at east gate (300 minutes ago = 5 hours, past 270 min max)
    const entryTime = new Date(Date.now() - 300 * 60 * 1000)
    const { data: entryPassage, error: entryError } = await supabase
      .from('vehicle_passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.east.id,
        segment_id: SEED.segment.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: entryTime.toISOString(),
        source: 'app',
        ranger_id: ranger.id,
      })
      .select()
      .single()

    assertEquals(entryError, null, 'Entry passage should be created without error')
    assertExists(entryPassage, 'Entry passage should exist')

    // No exit passage - vehicle is overstaying

    // Get SUPABASE_SERVICE_ROLE_KEY from env
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    assertExists(serviceRoleKey, 'SUPABASE_SERVICE_ROLE_KEY must be set')

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'

    // Call POST check-overstay edge function
    const response = await fetch(`${supabaseUrl}/functions/v1/check-overstay`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
    })

    assert(response.ok, `check-overstay should return 200, got ${response.status}`)

    // Query proactive_overstay_alerts for this plate
    const { data: alerts, error: alertsError } = await supabase
      .from('proactive_overstay_alerts')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(alertsError, null, 'Should query alerts without error')
    assertEquals(alerts?.length, 1, 'Should have exactly 1 alert')

    const alert = alerts?.[0]
    assertExists(alert, 'Alert should exist')
    assertEquals(alert.resolved, false, 'Alert should not be resolved')

    // Call check-overstay again to verify idempotency
    const response2 = await fetch(`${supabaseUrl}/functions/v1/check-overstay`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
    })

    assert(response2.ok, 'Second check-overstay call should succeed')

    // Query alerts again - should still be 1 (no new alert created)
    const { data: alertsAfter, error: alertsAfterError } = await supabase
      .from('proactive_overstay_alerts')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(alertsAfterError, null, 'Should query alerts without error')
    assertEquals(alertsAfter?.length, 1, 'Should still have exactly 1 alert (idempotent)')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
