import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Happy path: normal travel time produces no violation", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger assigned to east gate
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.id)

    // Generate unique plate
    const plateNumber = `HAPPY-${Date.now()}`
    testPlates.push(plateNumber)

    const supabase = getServiceClient()

    // Insert entry passage at east gate (120 minutes ago)
    const entryTime = new Date(Date.now() - 120 * 60 * 1000)
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

    // Insert exit passage at west gate (now)
    const exitTime = new Date()
    const { data: exitPassage, error: exitError } = await supabase
      .from('vehicle_passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.west.id,
        segment_id: SEED.segment.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: exitTime.toISOString(),
        source: 'app',
        ranger_id: ranger.id,
      })
      .select()
      .single()

    assertEquals(exitError, null, 'Exit passage should be created without error')
    assertExists(exitPassage, 'Exit passage should exist')

    // Wait for trigger to process
    await new Promise(resolve => setTimeout(resolve, 500))

    // Query both passages to verify they are matched
    const { data: passages, error: passagesError } = await supabase
      .from('vehicle_passages')
      .select('*')
      .eq('plate_number', plateNumber)
      .order('recorded_at', { ascending: true })

    assertEquals(passagesError, null, 'Should query passages without error')
    assertEquals(passages?.length, 2, 'Should have 2 passages')
    assertExists(passages?.[0].matched_passage_id, 'Entry passage should have matched_passage_id')
    assertExists(passages?.[1].matched_passage_id, 'Exit passage should have matched_passage_id')

    // Query violations - should be 0 for normal travel time
    const { data: violations, error: violationsError } = await supabase
      .from('violations')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(violationsError, null, 'Should query violations without error')
    assertEquals(violations?.length, 0, 'Should have no violations for normal travel time')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
