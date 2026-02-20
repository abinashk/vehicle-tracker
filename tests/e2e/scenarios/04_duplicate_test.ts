import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Duplicate: same client_id inserted twice results in one row", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.id)

    // Generate unique plate and fixed client_id
    const plateNumber = `DUP-${Date.now()}`
    testPlates.push(plateNumber)
    const fixedClientId = generateClientId()

    const supabase = getServiceClient()

    // Insert passage with this clientId - should succeed
    const { data: firstPassage, error: firstError } = await supabase
      .from('vehicle_passages')
      .insert({
        client_id: fixedClientId,
        checkpost_id: SEED.checkposts.east.id,
        segment_id: SEED.segment.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'app',
        ranger_id: ranger.id,
      })
      .select()
      .single()

    assertEquals(firstError, null, 'First passage should be created without error')
    assertExists(firstPassage, 'First passage should exist')

    // Insert SAME passage again with same clientId
    // UNIQUE constraint on client_id prevents duplicate — returns error code 23505
    const { error: secondError } = await supabase
      .from('vehicle_passages')
      .insert({
        client_id: fixedClientId,
        checkpost_id: SEED.checkposts.east.id,
        segment_id: SEED.segment.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'app',
        ranger_id: ranger.id,
      })

    // Expect unique constraint violation (23505)
    assertExists(secondError, 'Second insert should return an error')
    assertEquals(secondError.code, '23505', 'Error should be unique constraint violation')

    // Query passages where client_id = fixedId — should still be just 1 row
    const { data: passages, error: queryError } = await supabase
      .from('vehicle_passages')
      .select('*')
      .eq('client_id', fixedClientId)

    assertEquals(queryError, null, 'Should query passages without error')
    assertEquals(passages?.length, 1, 'Should have exactly 1 row (duplicate prevented)')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
