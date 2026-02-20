import { assertEquals, assertExists, assert } from 'https://deno.land/std@0.220.0/assert/mod.ts'
import { getServiceClient, getUserClient } from '../helpers/client.ts'
import { createTestAdmin, createTestRanger, cleanupUsers } from '../helpers/users.ts'
import { SEED, generateClientId, passage } from '../helpers/data.ts'
import { cleanup } from '../helpers/cleanup.ts'

Deno.test("Generated columns: segment has correct calculated travel times", async () => {
  const supabase = getServiceClient()

  // Query seed segment
  const { data: segment, error: segmentError } = await supabase
    .from('segments')
    .select('*')
    .eq('id', SEED.segment.id)
    .single()

  assertEquals(segmentError, null, 'Should query segment without error')
  assertExists(segment, 'Segment should exist')

  // Assert min_travel_time_minutes = 67.5 (45km / 40km/h * 60min)
  assertEquals(
    segment.min_travel_time_minutes,
    67.5,
    'min_travel_time_minutes should be 67.5'
  )

  // Assert max_travel_time_minutes = 270 (45km / 10km/h * 60min)
  assertEquals(
    segment.max_travel_time_minutes,
    270,
    'max_travel_time_minutes should be 270'
  )
})

Deno.test("Updated_at trigger fires on profile update", async () => {
  const testUsers: string[] = []

  try {
    // Create test admin
    const admin = await createTestAdmin()
    testUsers.push(admin.userId)

    const supabase = getServiceClient()

    // Query their profile, note updated_at
    const { data: profile1, error: error1 } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', admin.userId)
      .single()

    assertEquals(error1, null, 'Should query profile without error')
    assertExists(profile1, 'Profile should exist')
    const updatedAt1 = profile1.updated_at

    // Wait 1 second
    await new Promise(resolve => setTimeout(resolve, 1000))

    // Update profile (e.g. full_name)
    const { error: updateError } = await supabase
      .from('profiles')
      .update({ full_name: 'Updated Name' })
      .eq('id', admin.userId)

    assertEquals(updateError, null, 'Should update profile without error')

    // Query again - assert updated_at changed
    const { data: profile2, error: error2 } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', admin.userId)
      .single()

    assertEquals(error2, null, 'Should query profile without error')
    assertExists(profile2, 'Profile should exist')
    const updatedAt2 = profile2.updated_at

    assert(
      updatedAt2 !== updatedAt1,
      'updated_at should change after update'
    )
    assert(
      new Date(updatedAt2) > new Date(updatedAt1),
      'updated_at should be more recent after update'
    )

  } finally {
    await cleanupUsers(testUsers)
  }
})
