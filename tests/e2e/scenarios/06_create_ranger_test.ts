import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Admin can create ranger via edge function", async () => {
  const testUsers: string[] = []

  try {
    // Create test admin, get JWT
    const admin = await createTestAdmin()
    testUsers.push(admin.id)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'

    // Call POST create-ranger with admin JWT
    const rangerUsername = `e2e_ranger_${Date.now()}`
    const response = await fetch(`${supabaseUrl}/functions/v1/create-ranger`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${admin.jwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        username: rangerUsername,
        password: 'securepass123!',
        full_name: 'E2E Ranger',
        assigned_checkpost_id: SEED.checkposts.east.id,
        assigned_park_id: SEED.park.id,
      }),
    })

    // Assert response status = 201
    assertEquals(response.status, 201, 'Should return 201 Created')

    // Parse response body
    const responseData = await response.json()
    assertExists(responseData.profile, 'Response should contain profile')
    assertEquals(responseData.profile.role, 'ranger', 'Created user should have role=ranger')

    // Store created user id for cleanup
    testUsers.push(responseData.profile.id)

  } finally {
    await cleanupUsers(testUsers)
  }
})

Deno.test("Non-admin cannot create ranger", async () => {
  const testUsers: string[] = []

  try {
    // Create test ranger (not admin), get JWT
    const ranger = await createTestRanger(SEED.checkposts.east.id)
    testUsers.push(ranger.id)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') || 'http://127.0.0.1:54321'

    // Call POST create-ranger with ranger JWT
    const rangerUsername = `e2e_ranger_${Date.now()}`
    const response = await fetch(`${supabaseUrl}/functions/v1/create-ranger`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${ranger.jwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        username: rangerUsername,
        password: 'securepass123!',
        full_name: 'E2E Ranger',
        assigned_checkpost_id: SEED.checkposts.east.id,
        assigned_park_id: SEED.park.id,
      }),
    })

    // Assert response status = 403
    assertEquals(response.status, 403, 'Non-admin should receive 403 Forbidden')

  } finally {
    await cleanupUsers(testUsers)
  }
})
