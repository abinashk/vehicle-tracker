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
      .from('passages')
      .insert({
        client_id: fixedClientId,
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'mobile',
        ranger_id: ranger.id,
      })
      .select()
      .single()

    assertEquals(firstError, null, 'First passage should be created without error')
    assertExists(firstPassage, 'First passage should exist')

    // Insert SAME passage again with same clientId
    // This should NOT error (upsert behavior or conflict ignore)
    const { error: secondError } = await supabase
      .from('passages')
      .insert({
        client_id: fixedClientId,
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'mobile',
        ranger_id: ranger.id,
      })

    // Should not error due to conflict handling
    assertEquals(secondError, null, 'Second insert with same client_id should not error')

    // Query passages where client_id = fixedId
    const { data: passages, error: queryError } = await supabase
      .from('passages')
      .select('*')
      .eq('client_id', fixedClientId)

    assertEquals(queryError, null, 'Should query passages without error')
    assertEquals(passages?.length, 1, 'Should have exactly 1 row (duplicate prevented)')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
