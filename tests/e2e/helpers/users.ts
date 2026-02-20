import { getServiceClient } from "./client.ts";
import { SEED } from "./data.ts";

/**
 * Creates a test admin user and returns their ID and JWT
 */
export async function createTestAdmin(
  suffix?: string,
): Promise<{ id: string; jwt: string }> {
  const serviceClient = getServiceClient();
  const email = `test_admin_${suffix || Date.now()}@bnp.local`;
  const password = "testpass123!";

  // Create user via auth.admin
  const { data: userData, error: createError } = await serviceClient.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
    });

  if (createError || !userData.user) {
    throw new Error(`Failed to create admin user: ${createError?.message}`);
  }

  const userId = userData.user.id;

  // Insert user profile
  const { error: profileError } = await serviceClient
    .from("user_profiles")
    .insert({
      user_id: userId,
      role: "admin",
      full_name: "Test Admin",
      assigned_park_id: SEED.park.id,
    });

  if (profileError) {
    throw new Error(`Failed to create admin profile: ${profileError.message}`);
  }

  // Sign in to get JWT
  const { data: signInData, error: signInError } = await serviceClient.auth
    .signInWithPassword({
      email,
      password,
    });

  if (signInError || !signInData.session) {
    throw new Error(`Failed to sign in admin: ${signInError?.message}`);
  }

  return {
    id: userId,
    jwt: signInData.session.access_token,
  };
}

/**
 * Creates a test ranger user and returns their ID and JWT
 */
export async function createTestRanger(
  checkpostId: string,
  phoneNumber?: string,
): Promise<{ id: string; jwt: string }> {
  const serviceClient = getServiceClient();
  const email = `test_ranger_${Date.now()}@bnp.local`;
  const password = "testpass123!";

  // Create user via auth.admin
  const { data: userData, error: createError } = await serviceClient.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
    });

  if (createError || !userData.user) {
    throw new Error(`Failed to create ranger user: ${createError?.message}`);
  }

  const userId = userData.user.id;

  // Insert user profile
  const profileData: Record<string, unknown> = {
    user_id: userId,
    role: "ranger",
    full_name: "Test Ranger",
    assigned_checkpost_id: checkpostId,
    assigned_park_id: SEED.park.id,
  };
  if (phoneNumber) {
    profileData.phone_number = phoneNumber;
  }

  const { error: profileError } = await serviceClient
    .from("user_profiles")
    .insert(profileData);

  if (profileError) {
    throw new Error(`Failed to create ranger profile: ${profileError.message}`);
  }

  // Sign in to get JWT
  const { data: signInData, error: signInError } = await serviceClient.auth
    .signInWithPassword({
      email,
      password,
    });

  if (signInError || !signInData.session) {
    throw new Error(`Failed to sign in ranger: ${signInError?.message}`);
  }

  return {
    id: userId,
    jwt: signInData.session.access_token,
  };
}

/**
 * Deletes test users by ID. Profile cascades via FK.
 */
export async function cleanupUsers(ids: string[]): Promise<void> {
  const serviceClient = getServiceClient();

  for (const id of ids) {
    try {
      await serviceClient.auth.admin.deleteUser(id);
    } catch (_error) {
      // Ignore errors if user doesn't exist
    }
  }
}
