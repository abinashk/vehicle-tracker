import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient, SUPABASE_ANON_KEY } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Admin can create ranger via edge function", async () => {
  const testUsers: string[] = []

  try {
    // Create test admin, get JWT
    const admin = await createTestAdmin()
    testUsers.push(admin.id)

    // Use Supabase client's functions.invoke() which handles auth correctly
    const adminClient = getUserClient(admin.jwt)

    const rangerUsername = `e2e_ranger_${Date.now()}`
    const { data, error } = await adminClient.functions.invoke('create-ranger', {
      body: {
        username: rangerUsername,
        password: 'securepass123!',
        full_name: 'E2E Ranger',
        assigned_checkpost_id: SEED.checkposts.east.id,
        assigned_park_id: SEED.park.id,
      },
    })

    assertEquals(error, null, `Should not error: ${error?.message}`)
    assertExists(data, 'Response should contain data')
    assertExists(data.user, 'Response should contain user')
    assertEquals(data.user.role, 'ranger', 'Created user should have role=ranger')

    // Store created user id for cleanup
    testUsers.push(data.user.id)

  } finally {
    await cleanupUsers(testUsers)
  }
})

Deno.test({ name: "Non-admin cannot create ranger", sanitizeResources: false, fn: async () => {
  const testUsers: string[] = []

  try {
    // Create test ranger (not admin), get JWT
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.id)

    // Use Supabase client's functions.invoke()
    const rangerClient = getUserClient(ranger.jwt)

    const rangerUsername = `e2e_ranger_${Date.now()}`
    const { data, error } = await rangerClient.functions.invoke('create-ranger', {
      body: {
        username: rangerUsername,
        password: 'securepass123!',
        full_name: 'E2E Ranger',
        assigned_checkpost_id: SEED.checkposts.east.id,
        assigned_park_id: SEED.park.id,
      },
    })

    // The function should return 403 which the client surfaces as an error
    assertExists(error, 'Non-admin should receive an error')

  } finally {
    await cleanupUsers(testUsers)
  }
}})
