import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Speeding: fast travel creates speeding violation", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.userId)

    // Generate unique plate
    const plateNumber = `SPEED-${Date.now()}`
    testPlates.push(plateNumber)

    const supabase = getServiceClient()

    // Insert entry passage at east gate (30 minutes ago - faster than allowed)
    const entryTime = new Date(Date.now() - 30 * 60 * 1000)
    const { data: entryPassage, error: entryError } = await supabase
      .from('passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: entryTime.toISOString(),
        source: 'mobile',
        ranger_id: ranger.userId,
      })
      .select()
      .single()

    assertEquals(entryError, null, 'Entry passage should be created without error')
    assertExists(entryPassage, 'Entry passage should exist')

    // Insert exit passage at west gate (now - travel time = 30 min < 67.5 threshold)
    const exitTime = new Date()
    const { data: exitPassage, error: exitError } = await supabase
      .from('passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.west.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: exitTime.toISOString(),
        source: 'mobile',
        ranger_id: ranger.userId,
      })
      .select()
      .single()

    assertEquals(exitError, null, 'Exit passage should be created without error')
    assertExists(exitPassage, 'Exit passage should exist')

    // Wait for trigger to process
    await new Promise(resolve => setTimeout(resolve, 500))

    // Query violations for this plate
    const { data: violations, error: violationsError } = await supabase
      .from('violations')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(violationsError, null, 'Should query violations without error')
    assertEquals(violations?.length, 1, 'Should have exactly 1 violation')

    const violation = violations?.[0]
    assertExists(violation, 'Violation should exist')
    assertEquals(violation.violation_type, 'speeding', 'Violation type should be speeding')

    // Assert travel time is close to 30 minutes (allow 1 minute tolerance)
    assert(
      Math.abs(violation.travel_time_minutes - 30) < 1,
      `Travel time should be close to 30 minutes, got ${violation.travel_time_minutes}`
    )

    // Assert calculated speed is close to 90 km/h (45km / 0.5hr)
    // Allow 5 km/h tolerance for timing variations
    assert(
      Math.abs(violation.calculated_speed_kmh - 90) < 5,
      `Calculated speed should be close to 90 km/h, got ${violation.calculated_speed_kmh}`
    )

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
