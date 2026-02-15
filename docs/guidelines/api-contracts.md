# API Contracts

## Overview

All backend communication uses Supabase. This includes:
- REST API (PostgREST) for CRUD on tables
- Edge Functions for custom business logic
- Storage for photo uploads
- Realtime for live dashboard updates
- Auth for authentication

Base URL pattern: `https://<project-ref>.supabase.co`

All requests must include the `Authorization: Bearer <jwt>` header (except auth endpoints which use the anon key).

---

## Authentication Endpoints

### Login

```
POST /auth/v1/token?grant_type=password
Headers:
  apikey: <supabase-anon-key>
  Content-Type: application/json
Body:
  {
    "email": "ranger1@bnp.local",
    "password": "..."
  }
Response 200:
  {
    "access_token": "...",
    "refresh_token": "...",
    "user": { "id": "...", ... }
  }
```

**App behavior:** The login form only asks for a username (e.g., `ranger1`). The app auto-appends `@bnp.local` before calling the auth endpoint.

### Fetch User Profile (with relations)

```
GET /rest/v1/user_profiles?id=eq.{uid}&select=*,checkposts(*,highway_segments(*))
Headers:
  Authorization: Bearer <jwt>
  apikey: <supabase-anon-key>
Response 200:
  [
    {
      "id": "...",
      "full_name": "Ranger One",
      "role": "ranger",
      "phone_number": "+977...",
      "assigned_checkpost_id": "...",
      "assigned_park_id": "...",
      "checkposts": {
        "id": "...",
        "name": "Checkpost A",
        "code": "BNP-A",
        "highway_segments": {
          "id": "...",
          "distance_km": 20.0,
          "max_speed_kmh": 40.0,
          "min_speed_kmh": 15.0
        }
      }
    }
  ]
```

---

## Vehicle Passages

### Record a Passage (Idempotent Upsert)

```
POST /rest/v1/vehicle_passages
Headers:
  Authorization: Bearer <jwt>
  apikey: <supabase-anon-key>
  Content-Type: application/json
  Prefer: resolution=ignore-duplicates
Body:
  {
    "id": "<uuid>",
    "client_id": "<uuid>",
    "plate_number": "BA1PA1234",
    "plate_number_raw": "बा १ प १२३४",
    "vehicle_type": "car",
    "checkpost_id": "<uuid>",
    "segment_id": "<uuid>",
    "recorded_at": "2025-03-01T10:30:00Z",
    "ranger_id": "<uuid>",
    "photo_path": null,
    "source": "app"
  }
Response 201: Created
Response 409: Conflict (client_id already exists) -- treat as success
```

**Idempotency:** The `client_id` column has a UNIQUE constraint. `ON CONFLICT (client_id) DO NOTHING` ensures safe retries. A 409 on retry means the passage was already recorded -- this is a success.

### Fetch Unmatched Passages from Opposite Checkpost

```
GET /rest/v1/vehicle_passages?segment_id=eq.{sid}&checkpost_id=neq.{my_cp}&matched_passage_id=is.null&recorded_at=gte.{cutoff}&order=recorded_at.desc&limit=500
Headers:
  Authorization: Bearer <jwt>
  apikey: <supabase-anon-key>
```

This is used by the mobile app to cache entries from the opposite checkpost for local matching.

---

## Edge Functions

### sms-webhook

Receives incoming SMS from Twilio and creates a passage record.

```
POST /functions/v1/sms-webhook
Headers:
  Content-Type: application/x-www-form-urlencoded
  X-Twilio-Signature: <signature>
Body (form-encoded):
  From=+9779801234567
  Body=V1|BNP-A|BA1PA1234|CAR|1709123456|9801
Response 200:
  { "success": true, "passage_id": "..." }
Response 400:
  { "error": "Invalid SMS format" }
Response 401:
  { "error": "Invalid Twilio signature" }
```

**Security:** Twilio signature must be verified before processing. See `security.md`.

### match-passage

Server-side match verification. Called by client when it finds a local match.

```
POST /functions/v1/match-passage
Headers:
  Authorization: Bearer <jwt>
  Content-Type: application/json
Body:
  {
    "entry_passage_id": "<uuid>",
    "exit_passage_id": "<uuid>"
  }
Response 200:
  {
    "matched": true,
    "violation": {
      "id": "...",
      "violation_type": "speeding",
      "travel_time_minutes": 15.5,
      "calculated_speed_kmh": 77.4
    }
  }
Response 200 (no violation):
  {
    "matched": true,
    "violation": null
  }
Response 409:
  { "error": "One or both passages already matched" }
```

**Concurrency:** Uses `SELECT ... FOR UPDATE` to prevent double-matching.

### check-overstay

Cron job that runs every 15 minutes. Finds unmatched entry passages past the segment's `max_travel_time_minutes` and creates proactive overstay alerts.

```
POST /functions/v1/check-overstay
Headers:
  Authorization: Bearer <service-role-key>
Response 200:
  { "alerts_created": 3 }
```

**Rule:** Only called by pg_cron with the service role key. Never exposed to clients.

### create-ranger

Admin-only function to create a new ranger user atomically (auth user + profile).

```
POST /functions/v1/create-ranger
Headers:
  Authorization: Bearer <admin-jwt>
  Content-Type: application/json
Body:
  {
    "username": "ranger5",
    "password": "...",
    "full_name": "Ram Bahadur",
    "phone_number": "+9779801234567",
    "assigned_checkpost_id": "<uuid>",
    "assigned_park_id": "<uuid>"
  }
Response 201:
  { "user_id": "...", "profile_id": "..." }
Response 400:
  { "error": "Username already exists" }
Response 403:
  { "error": "Admin role required" }
```

**Auth:** Validates JWT and checks that the caller has `role = 'admin'` in `user_profiles`.

---

## SMS Compact Format V1

Used for SMS fallback when data connectivity is unavailable.

### Format

```
V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>
```

### Fields

| Field | Description | Example |
|-------|-------------|---------|
| Version | Always `V1` | `V1` |
| Checkpost code | `checkposts.code` value | `BNP-A` |
| Plate number | Normalized Latin plate | `BA1PA1234` |
| Vehicle type code | SMS short code from enum | `CAR`, `MCY`, `BUS`, `TRK`, `OTH` |
| Timestamp | Unix epoch seconds (UTC) | `1709123456` |
| Ranger phone suffix | Last 4 digits of ranger's phone | `9801` |

### Example

```
V1|BNP-A|BA1PA1234|CAR|1709123456|9801
```

### Constraints

- Must fit within 160 characters (single SMS).
- Pipe `|` is the delimiter. Fields must not contain pipes.
- Plate number must be pre-normalized before encoding.

---

## Supabase Storage

### Passage Photos

- **Bucket:** `passage-photos`
- **Path pattern:** `{passage_id}.jpg`
- **Upload endpoint:** `POST /storage/v1/object/passage-photos/{passage_id}.jpg`
- **Allowed types:** JPEG, PNG only
- **Max size:** 2MB
- **Access:** Authenticated users can upload. Photos are readable by rangers in the same segment and all admins.

**Rule:** Photo upload is non-blocking. The passage is recorded and synced independently. The photo upload happens in the background and can fail without affecting the passage record. The `photo_path` field is updated after successful upload.

---

## RLS Policy Summary

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

**"Own segment"** means the ranger's assigned checkpost belongs to that segment.
**"Own checkpost"** means the passage's checkpost_id matches the ranger's assigned_checkpost_id.

---

## How to Add New Endpoints

When adding a new table or endpoint to the API:

1. **Create a migration file.** Add a new numbered migration in `/supabase/migrations/` (e.g., `00013_create_new_table.sql`).
2. **Add RLS policies.** Every new table must have RLS enabled and appropriate policies defined. Add these in the same migration or a subsequent one.
3. **Update shared constants.** If the endpoint introduces new enum values, table names, or API paths, add them to `packages/shared/lib/src/constants/api_constants.dart`.
4. **Update shared models.** If the endpoint returns a new data shape, create a model in `packages/shared/lib/src/models/`.
5. **Add tests.** Unit tests for the new model, integration tests for the new endpoint.
6. **Document here.** Add the endpoint contract to this document.
