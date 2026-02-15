import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Create a Supabase client with the service role key for admin operations.
export function createServiceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
}

// Create a Supabase client with the user's JWT for authenticated operations.
export function createUserClient(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    throw new Error('Missing Authorization header');
  }

  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    {
      global: {
        headers: { Authorization: authHeader },
      },
    },
  );
}
