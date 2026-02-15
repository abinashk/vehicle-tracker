# Agent 1: Backend

## Objective

Implement all Supabase Edge Functions, RLS policies, database triggers, SMS webhook, and overstay cron. This agent runs in parallel with Agents 2 and 3, after Agent 0 merges to `main`.

## Branch

`feature/backend-services`

---

## Owned Files

| Area | Files |
|------|-------|
| SMS Webhook | `/supabase/functions/sms-webhook/index.ts` |
| Overstay Cron | `/supabase/functions/check-overstay/index.ts` |
| Match Passage | `/supabase/functions/match-passage/index.ts` |
| Create Ranger | `/supabase/functions/create-ranger/index.ts` |
| Shared Utils | `/supabase/functions/_shared/*` (`cors.ts`, `supabase-client.ts`, `sms-parser.ts`) |
| Additional Migrations | May add migrations `00013+` for RLS policy refinements |

---

## Dependencies from Agent 0

Before starting, verify that Agent 0's `foundation/setup` branch has been merged to `main` and the following are available:

- `/supabase/migrations/*` -- all 12 migration files (schema must exist)
- `/supabase/config.toml` -- Supabase project configuration
- `/supabase/seed.sql` -- Banke National Park pilot data
- `/packages/shared/lib/src/constants/sms_format.dart` -- SMS V1 format constants
- `/packages/shared/lib/src/utils/sms_decoder.dart` -- reference decoder logic

---

## Key Deliverables

### 1. fn_auto_match_passage() -- Database Trigger

The core matching and violation-creation logic. This trigger fires on every INSERT to `vehicle_passages`.

**Logic:**
1. On INSERT to `vehicle_passages`, find an unmatched entry with the same `plate_number` and `segment_id` from the opposite checkpost.
2. If a match is found:
   - Link the two passages by setting `matched_passage_id` on both records.
   - Determine `is_entry` (earlier passage) and exit (later passage).
   - Calculate `travel_time_minutes` from the difference between the two `recorded_at` timestamps.
   - Fetch `min_travel_time_minutes` and `max_travel_time_minutes` from `highway_segments`.
   - If `travel_time_minutes < min_travel_time_minutes` --> create SPEEDING violation.
   - If `travel_time_minutes > max_travel_time_minutes` --> create OVERSTAY violation.
   - Resolve any existing `proactive_overstay_alerts` for the matched entry passage.
3. Use `SELECT ... FOR UPDATE` to prevent double-matching race conditions.

**SQL Reference:**

```sql
CREATE OR REPLACE FUNCTION fn_auto_match_passage()
RETURNS TRIGGER AS $$
DECLARE
  v_opposite RECORD;
  v_segment  RECORD;
  v_entry_id uuid;
  v_exit_id  uuid;
  v_entry_time timestamptz;
  v_exit_time  timestamptz;
  v_travel_minutes numeric;
  v_violation_type text;
  v_threshold numeric;
BEGIN
  -- Find unmatched passage from opposite checkpost, same plate + segment
  SELECT vp.* INTO v_opposite
  FROM vehicle_passages vp
  WHERE vp.plate_number = NEW.plate_number
    AND vp.segment_id = NEW.segment_id
    AND vp.checkpost_id != NEW.checkpost_id
    AND vp.matched_passage_id IS NULL
    AND vp.id != NEW.id
  ORDER BY vp.recorded_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF v_opposite IS NULL THEN
    RETURN NEW;
  END IF;

  -- Determine entry/exit
  IF NEW.recorded_at > v_opposite.recorded_at THEN
    v_entry_id   := v_opposite.id;
    v_exit_id    := NEW.id;
    v_entry_time := v_opposite.recorded_at;
    v_exit_time  := NEW.recorded_at;
  ELSE
    v_entry_id   := NEW.id;
    v_exit_id    := v_opposite.id;
    v_entry_time := NEW.recorded_at;
    v_exit_time  := v_opposite.recorded_at;
  END IF;

  v_travel_minutes := EXTRACT(EPOCH FROM (v_exit_time - v_entry_time)) / 60.0;

  -- Link passages
  UPDATE vehicle_passages SET matched_passage_id = v_exit_id,  is_entry = true  WHERE id = v_entry_id;
  UPDATE vehicle_passages SET matched_passage_id = v_entry_id, is_entry = false WHERE id = v_exit_id;

  -- Fetch segment thresholds
  SELECT * INTO v_segment FROM highway_segments WHERE id = NEW.segment_id;

  -- Check for violations
  IF v_travel_minutes < v_segment.min_travel_time_minutes THEN
    v_violation_type := 'speeding';
    v_threshold := v_segment.min_travel_time_minutes;
  ELSIF v_travel_minutes > v_segment.max_travel_time_minutes THEN
    v_violation_type := 'overstay';
    v_threshold := v_segment.max_travel_time_minutes;
  END IF;

  IF v_violation_type IS NOT NULL THEN
    INSERT INTO violations (
      id, entry_passage_id, exit_passage_id, segment_id,
      violation_type, plate_number, vehicle_type,
      entry_time, exit_time, travel_time_minutes,
      threshold_minutes, calculated_speed_kmh,
      speed_limit_kmh, distance_km
    ) VALUES (
      gen_random_uuid(), v_entry_id, v_exit_id, NEW.segment_id,
      v_violation_type, NEW.plate_number, NEW.vehicle_type,
      v_entry_time, v_exit_time, v_travel_minutes,
      v_threshold, (v_segment.distance_km / (v_travel_minutes / 60.0)),
      v_segment.max_speed_kmh, v_segment.distance_km
    );
  END IF;

  -- Resolve proactive overstay alerts
  UPDATE proactive_overstay_alerts
  SET resolved = true,
      resolved_at = now(),
      resolved_by_passage_id = v_exit_id
  WHERE entry_passage_id = v_entry_id
    AND resolved = false;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_match_passage
  AFTER INSERT ON vehicle_passages
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_match_passage();
```

### 2. SMS Webhook

**Endpoint:** `POST /functions/v1/sms-webhook`

Receives Twilio webhook POST, verifies signature, parses V1 compact format, and inserts a passage with `source='sms'`.

**Requirements:**
- Twilio signature verification (using `X-Twilio-Signature` header)
- Parse V1 format: `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`
- Resolve `checkpost_code` to `checkpost_id` and `segment_id`
- Resolve `ranger_phone_suffix` to `ranger_id` via `user_profiles.phone_number`
- Generate a deterministic `client_id` from the SMS content to prevent duplicate inserts
- Insert into `vehicle_passages` with `source = 'sms'`
- Return 200 with TwiML response

### 3. Overstay Cron

**Endpoint:** `POST /functions/v1/check-overstay`

Runs every 15 minutes via pg_cron. Scans for unmatched entry passages past `max_travel_time_minutes` and creates proactive overstay alerts.

**Requirements:**
- Find `vehicle_passages` where `matched_passage_id IS NULL` and `recorded_at + max_travel_time < now()`
- Skip entries that already have a `proactive_overstay_alerts` record
- Create alert with `expected_exit_by = entry_time + max_travel_time`
- Do not create duplicate alerts

### 4. Create-Ranger Function

**Endpoint:** `POST /functions/v1/create-ranger`

Creates an auth user and user_profile atomically.

**Requirements:**
- Caller must be an admin (JWT role check)
- Body: `{ username, password, full_name, phone_number?, assigned_checkpost_id?, assigned_park_id? }`
- Auto-appends `@bnp.local` to username for auth email
- Creates `auth.users` entry via Supabase Admin API
- Creates `user_profiles` entry with the returned user ID
- If either step fails, roll back (no orphan auth user or profile)
- Return the created profile

### 5. RLS Policies

All tables must have Row Level Security enabled with policies enforcing:

| Table | Rangers | Admins |
|-------|---------|--------|
| parks | SELECT | ALL |
| highway_segments | SELECT | ALL |
| checkposts | SELECT | ALL |
| user_profiles | SELECT own | ALL |
| vehicle_passages | SELECT own segment, INSERT own checkpost | ALL |
| violations | SELECT own segment | ALL |
| violation_outcomes | SELECT own segment, INSERT, UPDATE own (24h) | ALL |
| proactive_overstay_alerts | SELECT own segment | ALL |

### 6. updated_at Trigger

Create a reusable trigger function for automatically updating `updated_at` on all relevant tables (`parks`, `highway_segments`, `checkposts`, `user_profiles`).

---

## Acceptance Criteria

1. **Auto-match trigger correctly creates speeding AND overstay violations** -- inserting two passages with the same plate on opposite checkposts with short travel time creates a SPEEDING violation; with long travel time creates an OVERSTAY violation.
2. **SMS webhook parses V1 format and inserts passage with `source='sms'`** -- verified with curl against local Supabase.
3. **Double-matching prevented** -- concurrent inserts of matching passages do not create duplicate violations (SELECT FOR UPDATE).
4. **Overstay cron doesn't create duplicate alerts** -- running the cron twice for the same unmatched entry produces only one alert.
5. **RLS enforcement** -- a ranger cannot read another segment's data; an admin can read all data.
6. **All edge functions return proper error codes** -- 400 (bad request), 401 (unauthorized), 403 (forbidden), 409 (conflict/duplicate), 500 (server error).

---

## API Contracts Reference

### Auth
- Login: `POST /auth/v1/token?grant_type=password` with `{ email: "ranger1@bnp.local", password }`
- Profile: `GET /rest/v1/user_profiles?id=eq.{uid}&select=*,checkposts(*,highway_segments(*))`

### Vehicle Passages
- Record: `POST /rest/v1/vehicle_passages` with `client_id` for idempotent upsert (`ON CONFLICT (client_id) DO NOTHING`)
- Fetch unmatched: `GET /rest/v1/vehicle_passages?segment_id=eq.{sid}&checkpost_id=neq.{my_cp}&matched_passage_id=is.null&recorded_at=gte.{cutoff}&order=recorded_at.desc&limit=500`

### Matching
Hybrid client-first, server-verified approach:
- **Client-side:** Mobile searches local Drift cache. If match found, calculates violation locally and shows alert immediately.
- **Server-side:** DB trigger `fn_auto_match_passage()` fires on every INSERT. Handles SMS-originated records and late-syncing data.
- **Edge Function:** `POST /functions/v1/match-passage` validates client-proposed match with `SELECT ... FOR UPDATE`.

### SMS Webhook
`POST /functions/v1/sms-webhook` receives Twilio webhook, parses compact format, inserts passage.

### Photo Upload
`POST /storage/v1/object/passage-photos/{passage_id}.jpg` (2MB limit, JPEG/PNG)
