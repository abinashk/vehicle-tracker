# Database Schema

## Overview

The database runs on PostgreSQL via Supabase. All tables use UUID primary keys, `timestamptz` for timestamps (stored as UTC, displayed in Nepal Time UTC+5:45), and Row Level Security (RLS) for access control. The schema is defined across 12 migration files in `/supabase/migrations/`.

---

## Tables

### parks

Base configuration table for national parks.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| name | text | NOT NULL, UNIQUE |
| code | text | NOT NULL, UNIQUE, max 10 chars |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at | timestamptz | NOT NULL, DEFAULT now() |
| updated_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00001_create_parks.sql`

**Notes:**
- `code` is a short identifier used in SMS and references (e.g., "BNP" for Banke National Park).
- The system is designed to support multiple parks, even though the pilot uses only one.

---

### highway_segments

A highway segment is a stretch of road between two checkposts where speed is monitored.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| park_id | uuid | FK -> parks.id, NOT NULL |
| name | text | NOT NULL |
| distance_km | numeric(6,2) | NOT NULL, CHECK > 0 |
| max_speed_kmh | numeric(5,2) | NOT NULL, CHECK > 0 |
| min_speed_kmh | numeric(5,2) | NOT NULL, CHECK > 0 |
| min_travel_time_minutes | numeric(8,2) | GENERATED: (distance_km / max_speed_kmh) * 60 |
| max_travel_time_minutes | numeric(8,2) | GENERATED: (distance_km / min_speed_kmh) * 60 |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at | timestamptz | NOT NULL, DEFAULT now() |
| updated_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00002_create_highway_segments.sql`

**Generated column formulas:**
- `min_travel_time_minutes = (distance_km / max_speed_kmh) * 60` -- the fastest legal traversal time
- `max_travel_time_minutes = (distance_km / min_speed_kmh) * 60` -- the slowest expected traversal time

These are PostgreSQL generated columns (STORED). They automatically recalculate when `distance_km`, `max_speed_kmh`, or `min_speed_kmh` are updated. No application code needed.

**Violation logic:**
- Travel time < `min_travel_time_minutes` --> SPEEDING
- Travel time > `max_travel_time_minutes` --> OVERSTAY (potential poaching)

---

### checkposts

A checkpost is a physical location at one end of a highway segment where rangers record vehicle passages.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| segment_id | uuid | FK -> highway_segments.id, NOT NULL |
| name | text | NOT NULL |
| code | text | NOT NULL, UNIQUE (used in SMS format) |
| position_index | smallint | NOT NULL, CHECK IN (0, 1) |
| latitude | numeric | NULLABLE |
| longitude | numeric | NULLABLE |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00003_create_checkposts.sql`

**Constraints:**
- UNIQUE constraint on `(segment_id, position_index)` -- each segment has exactly two checkposts (index 0 and index 1).
- `code` is globally unique and used in the SMS compact format (e.g., "BNP-A", "BNP-B").
- `position_index` values: 0 = first checkpost, 1 = second checkpost.

---

### user_profiles

Extended profile for authenticated users (rangers and admins).

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, FK -> auth.users.id ON DELETE CASCADE |
| full_name | text | NOT NULL |
| role | text | NOT NULL, CHECK IN ('ranger', 'admin') |
| phone_number | text | NULLABLE |
| assigned_checkpost_id | uuid | FK -> checkposts.id, NULLABLE |
| assigned_park_id | uuid | FK -> parks.id, NULLABLE |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at | timestamptz | NOT NULL, DEFAULT now() |
| updated_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00004_create_user_profiles.sql`

**Notes:**
- `id` references `auth.users.id` with `ON DELETE CASCADE` -- deleting the auth user removes the profile.
- `assigned_checkpost_id` determines which checkpost a ranger operates from and is used for RLS policies.
- `phone_number` is used for SMS fallback ranger identification (matching the suffix in SMS messages).
- Auth uses email-format usernames: `ranger1@bnp.local`. The app auto-appends `@bnp.local`.

---

### vehicle_passages

Core high-volume table recording every vehicle passage through a checkpost.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| client_id | uuid | NOT NULL, UNIQUE (idempotency key) |
| plate_number | text | NOT NULL (normalized English transliteration) |
| plate_number_raw | text | NULLABLE (original OCR output before normalization) |
| vehicle_type | text | NOT NULL, CHECK IN enum values |
| checkpost_id | uuid | FK -> checkposts.id, NOT NULL |
| segment_id | uuid | FK -> highway_segments.id, NOT NULL |
| recorded_at | timestamptz | NOT NULL (device time at camera shutter moment) |
| server_received_at | timestamptz | DEFAULT now() |
| ranger_id | uuid | FK -> user_profiles.id, NOT NULL |
| photo_path | text | NULLABLE (Supabase Storage path) |
| source | text | DEFAULT 'app', CHECK IN ('app', 'sms') |
| matched_passage_id | uuid | FK -> self (vehicle_passages.id), NULLABLE |
| is_entry | boolean | NULLABLE |
| created_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00005_create_vehicle_passages.sql`

**Key design decisions:**

- **`client_id` (UNIQUE):** Generated on the mobile device when the passage is first recorded. Never regenerated on retry. This serves as an idempotency key -- `ON CONFLICT (client_id) DO NOTHING` prevents duplicate inserts during sync retries or SMS+app dual-submission.
- **`recorded_at`:** The device timestamp at the exact moment the camera shutter fires. This is the authoritative time used for speed calculations. It is NOT the time the record was synced or received by the server.
- **`server_received_at`:** Set by the server on INSERT. Used for audit purposes only.
- **`plate_number`:** Normalized English transliteration of the plate (output of `PlateNormalizer.normalize()`).
- **`plate_number_raw`:** Original OCR output preserved for debugging and audit.
- **`source`:** Indicates whether the passage was recorded via the app ('app') or via SMS fallback ('sms').
- **`matched_passage_id`:** Self-referential FK. When two passages are matched (entry + exit), each points to the other.
- **`is_entry`:** Set during matching. `true` for the earlier passage (entry), `false` for the later passage (exit). NULL if unmatched.

---

### violations

Created when a matched pair of passages indicates speeding or overstay.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| entry_passage_id | uuid | FK -> vehicle_passages.id, UNIQUE |
| exit_passage_id | uuid | FK -> vehicle_passages.id |
| segment_id | uuid | FK -> highway_segments.id |
| violation_type | text | NOT NULL, CHECK IN ('speeding', 'overstay') |
| plate_number | text | NOT NULL (denormalized) |
| vehicle_type | text | NOT NULL (denormalized) |
| entry_time | timestamptz | NOT NULL (denormalized from entry passage) |
| exit_time | timestamptz | NOT NULL (denormalized from exit passage) |
| travel_time_minutes | numeric(8,2) | NOT NULL (actual travel time) |
| threshold_minutes | numeric(8,2) | NOT NULL (threshold that was violated) |
| calculated_speed_kmh | numeric(6,2) | NOT NULL |
| speed_limit_kmh | numeric(6,2) | NOT NULL (snapshot at time of violation) |
| distance_km | numeric(6,2) | NOT NULL (snapshot at time of violation) |
| alert_delivered_at | timestamptz | NULLABLE |
| created_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00006_create_violations.sql`

**Denormalization rationale:**
- `plate_number`, `vehicle_type`, `entry_time`, `exit_time` are copied from the passages so violation records are self-contained for reporting.
- `speed_limit_kmh` and `distance_km` are snapshots from the `highway_segments` table at the time of violation creation. If segment thresholds change later, historical violations retain the values that were in effect.
- `threshold_minutes` records which threshold was violated (`min_travel_time_minutes` for speeding, `max_travel_time_minutes` for overstay).

**Constraint:** `entry_passage_id` is UNIQUE to prevent the same entry from generating multiple violations.

---

### violation_outcomes

Records the ranger's response to a violation (fine, warning, etc.).

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| violation_id | uuid | FK -> violations.id, UNIQUE |
| outcome_type | text | NOT NULL, CHECK IN ('warned', 'fined', 'let_go', 'not_found', 'other') |
| fine_amount | numeric(10,2) | NULLABLE |
| notes | text | NULLABLE |
| recorded_by | uuid | FK -> user_profiles.id, NOT NULL |
| recorded_at | timestamptz | NOT NULL, DEFAULT now() |

**Migration:** `00007_create_violation_outcomes.sql`

**Notes:**
- UNIQUE on `violation_id` -- each violation has at most one outcome.
- `outcome_type` values:
  - `warned` -- verbal warning given
  - `fined` -- fine issued (amount in `fine_amount`)
  - `let_go` -- released without action
  - `not_found` -- vehicle/driver could not be located
  - `other` -- described in `notes`
- Rangers can INSERT and UPDATE their own outcomes within 24 hours (RLS policy).

---

### proactive_overstay_alerts

Alerts generated by the overstay cron when a vehicle has not exited within the expected time.

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| entry_passage_id | uuid | FK -> vehicle_passages.id |
| segment_id | uuid | FK -> highway_segments.id |
| plate_number | text | NOT NULL |
| vehicle_type | text | NOT NULL |
| entry_time | timestamptz | NOT NULL |
| expected_exit_by | timestamptz | NOT NULL (entry_time + max_travel_time) |
| resolved | boolean | NOT NULL, DEFAULT false |
| resolved_at | timestamptz | NULLABLE |
| resolved_by_passage_id | uuid | FK -> vehicle_passages.id, NULLABLE |

**Migration:** `00008_create_proactive_overstay_alerts.sql`

**Notes:**
- Created by the `check-overstay` Edge Function (runs every 15 minutes via pg_cron).
- `expected_exit_by` = `entry_time` + `max_travel_time_minutes` from the segment.
- Automatically resolved by `fn_auto_match_passage()` when the exit passage arrives.
- Can also be manually resolved by admins via the web dashboard.

---

### sync_metadata

Tracks sync state for mobile devices (not a core business table).

**Migration:** `00009_create_sync_metadata.sql`

---

## Indexes

Defined in migration `00010_create_indexes.sql`.

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| Matching lookup | vehicle_passages | `(plate_number, segment_id, recorded_at DESC)` | Finding matching entry/exit passages. The trigger queries by plate + segment and orders by recorded_at to find the most recent unmatched passage. |
| Checkpost listing | vehicle_passages | `(checkpost_id, recorded_at DESC)` | Listing recent passages at a specific checkpost (History screen, admin passage log). |
| Unmatched entries | vehicle_passages | `(segment_id, recorded_at) WHERE matched_passage_id IS NULL` | Partial index for efficiently finding unmatched passages. Used by the overstay cron and the "fetch unmatched from opposite checkpost" API. |
| Client ID | vehicle_passages | `client_id` UNIQUE | Deduplication / idempotency. Prevents duplicate inserts from sync retries. |

**Index rationale:**
- The matching lookup index is the most critical for performance -- it supports the `fn_auto_match_passage()` trigger which runs on every INSERT.
- The partial index on unmatched entries avoids scanning matched passages, which will be the majority over time.
- All indexes are on `vehicle_passages` because it is the highest-volume table.

---

## Entity Relationships

```
parks
  └── highway_segments (park_id FK)
        └── checkposts (segment_id FK)  [exactly 2 per segment]
              └── vehicle_passages (checkpost_id FK)
                    ├── vehicle_passages.matched_passage_id (self-referential FK)
                    ├── violations (entry_passage_id FK, exit_passage_id FK)
                    │     └── violation_outcomes (violation_id FK)
                    └── proactive_overstay_alerts (entry_passage_id FK)

auth.users
  └── user_profiles (id FK, ON DELETE CASCADE)
        ├── assigned_checkpost_id (FK -> checkposts)
        ├── assigned_park_id (FK -> parks)
        ├── vehicle_passages.ranger_id (FK)
        ├── violation_outcomes.recorded_by (FK)
        └── [RLS policies reference user role and assignments]
```

---

## RLS Summary

| Table | Rangers | Admins |
|-------|---------|--------|
| parks | SELECT | ALL |
| highway_segments | SELECT | ALL |
| checkposts | SELECT | ALL |
| user_profiles | SELECT own | ALL |
| vehicle_passages | SELECT own segment, INSERT own checkpost | ALL |
| violations | SELECT own segment | ALL |
| violation_outcomes | SELECT own segment, INSERT, UPDATE own (24h window) | ALL |
| proactive_overstay_alerts | SELECT own segment | ALL |

**"Own segment"** means the segment associated with the ranger's `assigned_checkpost_id`.

---

## Migration Files

| File | Purpose |
|------|---------|
| `00001_create_parks.sql` | Parks table |
| `00002_create_highway_segments.sql` | Highway segments with generated columns |
| `00003_create_checkposts.sql` | Checkposts with unique constraints |
| `00004_create_user_profiles.sql` | User profiles linked to auth.users |
| `00005_create_vehicle_passages.sql` | Core passage recording table |
| `00006_create_violations.sql` | Violation records |
| `00007_create_violation_outcomes.sql` | Violation outcome records |
| `00008_create_proactive_overstay_alerts.sql` | Proactive overstay alerts |
| `00009_create_sync_metadata.sql` | Sync tracking metadata |
| `00010_create_indexes.sql` | All indexes |
| `00011_create_rls_policies.sql` | Row Level Security policies |
| `00012_create_functions.sql` | Database functions and triggers |
