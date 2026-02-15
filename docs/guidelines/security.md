# Security Guidelines

## Parameterized Queries

All database queries must use parameterized inputs. Never construct SQL or query filters using string interpolation.

```dart
// Good: Supabase client methods handle parameterization
await supabase
    .from('vehicle_passages')
    .select()
    .eq('plate_number', plateNumber)
    .eq('segment_id', segmentId);

// Bad: string interpolation in query
await supabase.rpc('custom_query', params: {
  'filter': "plate_number = '$plateNumber'"  // SQL INJECTION RISK
});
```

```sql
-- Good: parameterized in Edge Functions
const { data } = await supabase
  .from('vehicle_passages')
  .select()
  .eq('client_id', clientId);

-- Bad: string interpolation in SQL
const query = `SELECT * FROM vehicle_passages WHERE client_id = '${clientId}'`;
```

---

## Row Level Security (RLS)

### Requirement

Every table must have RLS enabled with appropriate policies. No table should be accessible without RLS policies.

### Policy Summary

| Table | Rangers | Admins |
|-------|---------|--------|
| parks | SELECT | ALL |
| highway_segments | SELECT | ALL |
| checkposts | SELECT | ALL |
| user_profiles | SELECT own row | ALL |
| vehicle_passages | SELECT own segment, INSERT own checkpost | ALL |
| violations | SELECT own segment | ALL |
| violation_outcomes | SELECT own segment, INSERT, UPDATE own within 24h | ALL |
| proactive_overstay_alerts | SELECT own segment | ALL |

### How "Own Segment" Works

A ranger's assigned checkpost belongs to a segment. "Own segment" means data where `segment_id` matches the segment of the ranger's assigned checkpost:

```sql
CREATE POLICY "Rangers can read own segment passages"
ON vehicle_passages FOR SELECT
TO authenticated
USING (
  segment_id IN (
    SELECT c.segment_id FROM checkposts c
    JOIN user_profiles up ON up.assigned_checkpost_id = c.id
    WHERE up.id = auth.uid()
  )
);
```

### Validation

- Run queries as a ranger user and verify they cannot access data from other segments.
- Run queries as an admin user and verify full access.
- Attempt INSERT as a ranger on a checkpost that is not their assigned one -- must fail.

---

## JWT Validation in Edge Functions

Every Edge Function (except the SMS webhook, which uses Twilio signature verification) must validate the JWT token.

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  {
    global: {
      headers: { Authorization: req.headers.get('Authorization')! },
    },
  }
);

const { data: { user }, error } = await supabase.auth.getUser();
if (error || !user) {
  return new Response(JSON.stringify({ error: 'Unauthorized' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

### Admin-Only Operations

For admin-only Edge Functions (like `create-ranger`), additionally verify the user's role:

```typescript
const { data: profile } = await supabase
  .from('user_profiles')
  .select('role')
  .eq('id', user.id)
  .single();

if (profile?.role !== 'admin') {
  return new Response(JSON.stringify({ error: 'Admin role required' }), {
    status: 403,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

---

## Twilio Signature Verification

The SMS webhook must verify that incoming requests actually come from Twilio.

```typescript
import { validateRequest } from 'twilio';

const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')!;
const url = Deno.env.get('SMS_WEBHOOK_URL')!; // Full public URL of the webhook

const signature = req.headers.get('X-Twilio-Signature');
const params = Object.fromEntries(await req.formData());

if (!validateRequest(twilioAuthToken, signature, url, params)) {
  return new Response(JSON.stringify({ error: 'Invalid Twilio signature' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

**Rule:** Never process an SMS webhook request without verifying the Twilio signature first.

---

## Secret Management

### Rules

1. **No hardcoded secrets.** Never put API keys, tokens, passwords, or connection strings in source code.
2. **Use environment variables.** All secrets are read from environment variables at runtime.
3. **Never commit `.env` files.** The `.gitignore` must include `.env`, `.env.local`, and all `.env.*` variants.
4. **`service_role_key` is server-only.** The Supabase `service_role_key` must never be exposed to client apps (mobile or web). It bypasses RLS.

### Required Environment Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `SUPABASE_URL` | All | Supabase project URL |
| `SUPABASE_ANON_KEY` | Mobile, Web | Public anon key (safe for clients) |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions only | Full-access key (server-side only) |
| `TWILIO_AUTH_TOKEN` | sms-webhook | Twilio signature verification |
| `TWILIO_PHONE_NUMBER` | Mobile (SMS fallback) | Phone number to send SMS to |
| `SMS_WEBHOOK_URL` | sms-webhook | Full public URL for signature validation |

### Client-Side Keys

The `SUPABASE_ANON_KEY` is the only key that may be embedded in client apps. It is safe because:
- RLS policies restrict what authenticated users can access.
- The anon key alone provides no access without authentication.

Even so, prefer loading it from a config file or build-time environment variable rather than hardcoding it as a string literal.

---

## File Upload Validation

### Server-Side Validation (Required)

All file uploads to Supabase Storage must be validated server-side:

- **Allowed types:** JPEG and PNG only. Reject all other MIME types.
- **Max size:** 2MB. Reject files exceeding this limit.
- **Path pattern:** `passage-photos/{passage_id}.jpg`. Reject uploads to other paths.

Configure Supabase Storage bucket policies to enforce these constraints:

```sql
-- Storage bucket configuration
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'passage-photos',
  'passage-photos',
  false,
  2097152,  -- 2MB in bytes
  ARRAY['image/jpeg', 'image/png']
);
```

### Client-Side Validation (Defense in Depth)

The mobile app should also validate before upload:
- Compress images to stay under 2MB.
- Convert to JPEG format before upload.
- Show an error if the image cannot be compressed sufficiently.

---

## CORS Configuration

CORS must be restricted to the web dashboard domain only.

```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('WEB_DASHBOARD_URL') ?? 'http://localhost:8080',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
};
```

**Rules:**
- Never use `Access-Control-Allow-Origin: *` in production.
- All Edge Functions must include CORS headers in responses.
- Handle OPTIONS preflight requests explicitly.

---

## Authentication

### Auth Provider

Supabase Auth with email/password. Usernames are in email format: `ranger1@bnp.local`.

### Session Management

- Store JWT tokens securely using Supabase's built-in session management.
- Refresh tokens automatically before expiry.
- On logout, clear all local tokens and session data.
- On token expiry without successful refresh, redirect to login.

### Password Requirements

- Minimum 8 characters (enforced by Supabase Auth config).
- Passwords are set by admins via the `create-ranger` Edge Function.
- Password changes are admin-only operations.

---

## Input Validation

### Plate Numbers

- Validate against the expected regex pattern before processing.
- Normalize before storage (Devanagari to Latin transliteration).
- Never trust raw OCR output for matching -- always normalize first.

### Timestamps

- All timestamps must be stored as UTC `timestamptz`.
- Validate that `recorded_at` is not in the future (with a small tolerance for clock skew).
- Display times in Nepal Time (UTC+5:45) in the UI.

### UUIDs

- Validate UUID format before using in queries.
- Generate UUIDs using a proper UUID v4 generator, not custom random strings.

---

## Logging

- Never log sensitive data (passwords, full JWT tokens, personal phone numbers).
- Log authentication failures for audit purposes.
- Log SMS webhook processing results (success/failure, no message content).
- In Edge Functions, return generic error messages to clients but log detailed errors server-side.
