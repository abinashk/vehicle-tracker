import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Ranger can insert passage at assigned checkpost", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create test ranger assigned to east gate, get JWT
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.userId)

    const plateNumber = `RLS-INSERT-${Date.now()}`
    testPlates.push(plateNumber)

    // Use getUserClient(jwt) to insert passage at east gate
    const rangerClient = getUserClient(ranger.jwt)
    const { data: passage, error: insertError } = await rangerClient
      .from('passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'mobile',
      })
      .select()
      .single()

    // Assert insert succeeds (no error)
    assertEquals(insertError, null, 'Ranger should be able to insert passage at assigned checkpost')
    assertExists(passage, 'Passage should be created')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})

Deno.test("Ranger can read passages from own segment", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create ranger
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.userId)

    const plateNumber = `RLS-READ-${Date.now()}`
    testPlates.push(plateNumber)

    // Insert passage using service client
    const supabase = getServiceClient()
    const { data: passage, error: insertError } = await supabase
      .from('passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'mobile',
        ranger_id: ranger.userId,
      })
      .select()
      .single()

    assertEquals(insertError, null, 'Should insert passage without error')
    assertExists(passage, 'Passage should exist')

    // Query passages as ranger
    const rangerClient = getUserClient(ranger.jwt)
    const { data: passages, error: queryError } = await rangerClient
      .from('passages')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(queryError, null, 'Ranger should be able to query passages')
    assertEquals(passages?.length, 1, 'Ranger should see the passage')
    assertEquals(passages?.[0].id, passage.id, 'Should be the same passage')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})

Deno.test("Admin can read all passages", async () => {
  const testUsers: string[] = []
  const testPlates: string[] = []

  try {
    // Create admin + ranger
    const admin = await createTestAdmin()
    testUsers.push(admin.userId)

    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.userId)

    const plateNumber = `RLS-ADMIN-${Date.now()}`
    testPlates.push(plateNumber)

    // Insert passage
    const supabase = getServiceClient()
    const { data: passage, error: insertError } = await supabase
      .from('passages')
      .insert({
        client_id: generateClientId(),
        checkpost_id: SEED.checkposts.east.id,
        plate_number: plateNumber,
        vehicle_type: 'car',
        recorded_at: new Date().toISOString(),
        source: 'mobile',
        ranger_id: ranger.userId,
      })
      .select()
      .single()

    assertEquals(insertError, null, 'Should insert passage without error')
    assertExists(passage, 'Passage should exist')

    // Query passages as admin
    const adminClient = getUserClient(admin.jwt)
    const { data: passages, error: queryError } = await adminClient
      .from('passages')
      .select('*')
      .eq('plate_number', plateNumber)

    assertEquals(queryError, null, 'Admin should be able to query passages')
    assertEquals(passages?.length, 1, 'Admin should see the passage')
    assertEquals(passages?.[0].id, passage.id, 'Should be the same passage')

  } finally {
    await cleanup(testPlates)
    await cleanupUsers(testUsers)
  }
})
