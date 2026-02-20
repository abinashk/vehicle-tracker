// Create Ranger Edge Function
// Creates an auth user and user_profile atomically.
// Only callable by admin users.
//
// POST /functions/v1/create-ranger
// Authorization: Bearer <admin_jwt>
// Body: {
//   username: string,
//   password: string,
//   full_name: string,
//   phone_number?: string,
//   assigned_checkpost_id?: string,
//   assigned_park_id?: string,
// }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient, createUserClient } from '../_shared/supabase-client.ts';

interface CreateRangerRequest {
  username: string;
  password: string;
  full_name: string;
  phone_number?: string;
  assigned_checkpost_id?: string;
  assigned_park_id?: string;
}

function validateRequest(body: CreateRangerRequest): string | null {
  if (!body.username || typeof body.username !== 'string' || body.username.trim().length === 0) {
    return 'username is required and must be a non-empty string';
  }

  if (!body.password || typeof body.password !== 'string' || body.password.length < 8) {
    return 'password is required and must be at least 8 characters';
  }

  if (!body.full_name || typeof body.full_name !== 'string' || body.full_name.trim().length === 0) {
    return 'full_name is required and must be a non-empty string';
  }

  // Username should be alphanumeric with optional dots/underscores/hyphens
  const usernameRegex = /^[a-zA-Z0-9._-]+$/;
  if (!usernameRegex.test(body.username.trim())) {
    return 'username must contain only letters, numbers, dots, underscores, or hyphens';
  }

  return null;
}

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }

  try {
    // Validate JWT from Authorization header
    let userClient;
    try {
      userClient = createUserClient(req);
    } catch {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify the caller is authenticated
    // Pass JWT explicitly — auth.getUser() without args uses internal session state
    // which is empty when the client is created with only global headers.
    const token = req.headers.get('Authorization')?.replace('Bearer ', '') ?? '';
    const { data: { user: caller }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !caller) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Verify the caller has admin role
    const supabase = createServiceClient();
    const { data: callerProfile, error: profileError } = await supabase
      .from('user_profiles')
      .select('role')
      .eq('id', caller.id)
      .single();

    if (profileError || !callerProfile || callerProfile.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Forbidden: only admins can create rangers' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Parse request body
    let body: CreateRangerRequest;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON body' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Validate request fields
    const validationError = validateRequest(body);
    if (validationError) {
      return new Response(
        JSON.stringify({ error: validationError }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const username = body.username.trim();
    const email = `${username}@bnp.local`;

    // Validate assigned_checkpost_id if provided
    if (body.assigned_checkpost_id) {
      const { data: checkpost, error: checkpostError } = await supabase
        .from('checkposts')
        .select('id')
        .eq('id', body.assigned_checkpost_id)
        .single();

      if (checkpostError || !checkpost) {
        return new Response(
          JSON.stringify({ error: 'Invalid assigned_checkpost_id: checkpost not found' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }
    }

    // Validate assigned_park_id if provided
    if (body.assigned_park_id) {
      const { data: park, error: parkError } = await supabase
        .from('parks')
        .select('id')
        .eq('id', body.assigned_park_id)
        .single();

      if (parkError || !park) {
        return new Response(
          JSON.stringify({ error: 'Invalid assigned_park_id: park not found' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }
    }

    // Step 1: Create auth user via Supabase Admin API
    const { data: authData, error: createAuthError } = await supabase.auth.admin.createUser({
      email,
      password: body.password,
      email_confirm: true, // Auto-confirm since these are internal accounts
      user_metadata: {
        full_name: body.full_name.trim(),
        role: 'ranger',
      },
    });

    if (createAuthError) {
      // Check for duplicate email
      if (createAuthError.message?.includes('already') || createAuthError.message?.includes('duplicate')) {
        return new Response(
          JSON.stringify({ error: `Username "${username}" is already taken` }),
          {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          },
        );
      }

      console.error('Error creating auth user:', createAuthError.message);
      return new Response(
        JSON.stringify({ error: 'Failed to create auth user' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    const authUser = authData.user;
    if (!authUser) {
      return new Response(
        JSON.stringify({ error: 'Auth user creation returned no user' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    // Step 2: Create user_profiles row
    const profileData: Record<string, unknown> = {
      id: authUser.id,
      full_name: body.full_name.trim(),
      role: 'ranger',
      is_active: true,
    };

    if (body.phone_number) {
      profileData.phone_number = body.phone_number.trim();
    }

    if (body.assigned_checkpost_id) {
      profileData.assigned_checkpost_id = body.assigned_checkpost_id;
    }

    if (body.assigned_park_id) {
      profileData.assigned_park_id = body.assigned_park_id;
    }

    const { data: profile, error: profileInsertError } = await supabase
      .from('user_profiles')
      .insert(profileData)
      .select('id, full_name, role, phone_number, assigned_checkpost_id, assigned_park_id, is_active, created_at')
      .single();

    if (profileInsertError) {
      // Cleanup: delete the auth user since profile creation failed
      console.error('Error creating profile, rolling back auth user:', profileInsertError.message);
      const { error: deleteError } = await supabase.auth.admin.deleteUser(authUser.id);
      if (deleteError) {
        console.error('Failed to clean up auth user after profile error:', deleteError.message);
      }

      return new Response(
        JSON.stringify({ error: 'Failed to create user profile' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      );
    }

    console.log(`Ranger created: ${username} (${authUser.id})`);

    return new Response(
      JSON.stringify({
        user: {
          id: authUser.id,
          email,
          ...profile,
        },
      }),
      {
        status: 201,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('Unexpected error in create-ranger:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  }
});
