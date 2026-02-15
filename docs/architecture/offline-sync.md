# Offline Sync Architecture

## Overview

The mobile app is designed offline-first. Checkposts experience approximately 90% uptime and 10% downtime for data connectivity. The system must operate fully during offline periods with no data loss and seamless synchronization when connectivity returns.

This document covers the data flow, sync queue state machine, conflict resolution rules, SMS fallback trigger conditions, and matching logic.

For full system context, see `/docs/architecture/implementation-plan.md`.

---

## Data Flow Diagram

```
MOBILE DEVICE                              |  SERVER (SUPABASE)
                                           |
[Camera/OCR] -> [Review Screen]            |
      |                                    |
      v                                    |
[Record Passage Use Case]                  |
      |                                    |
      |---> Drift: local_passages (INSERT) |
      |---> Drift: sync_queue (pending)    |
      |---> Matching Service               |
      |       |---> cached_remote_entries  |
      |       |---> If match -> violation  |
      |            -> Alert UI             |
      v                                    |
[Sync Engine] (30s timer + connectivity)   |
      |                                    |
      |-- OUTBOUND ----------------------> Supabase REST API -> vehicle_passages
      |   POST with client_id             |                      |
      |   409 = already exists = OK       |                auto_match trigger
      |                                   |                      |
      |-- INBOUND <---------------------- Supabase REST API      v
      |   GET unmatched from opposite CP  |                violations table
      |   -> cache in Drift               |
      |                                   |
      |-- PHOTOS -----------------------> Supabase Storage (non-blocking)
      |                                   |
      |                                   |
[SMS Fallback] (if offline > 5 min)       |
      |                                   |
      |-- SMS via device ----------------> Twilio -> sms-webhook Edge Function
                                          |                |
                                          |          vehicle_passages (source='sms')
                                          |                |
                                          |          auto_match trigger
```

---

## Write-Local-First Rule

Every write operation follows this pattern:

1. **Write to Drift first** -- the passage is immediately stored in the local SQLite database.
2. **Create sync queue entry** -- a sync queue item is created with status `pending`.
3. **Return success to the UI** -- the ranger sees immediate confirmation. No waiting for network.
4. **Sync asynchronously** -- the sync engine handles pushing to the server in the background.

This rule is absolute. The UI layer never writes directly to Supabase. All writes go through repositories that enforce local-first.

---

## Sync Queue State Machine

```
                       +----------+
                       |  pending |<-----------+
                       +-----+----+            |
                             |                 |
                         sync attempt          |
                             |             failure
                             v            (attempts < 5)
                       +-----------+           |
                       | in_flight +------->---+
                       +-----+-----+
                             |
              +--------------+--------------+
              |                             |
          success (201)              failure (attempts >= 5)
          or duplicate (409)                |
              |                             v
              v                       +--------+
          +--------+                  | failed |
          | synced |                  +----+---+
          +--------+                       |
                                     triggers SMS
                                      fallback
```

### States

| State | Description |
|-------|-------------|
| `pending` | Recorded locally, waiting for sync attempt. Initial state for all new passages. |
| `in_flight` | Currently being sent to the server. Prevents duplicate concurrent sends. |
| `synced` | Successfully received by the server (201 Created or 409 Conflict). Terminal state. |
| `failed` | Failed after 5 attempts. Triggers SMS fallback. |

### Transitions

| From | To | Trigger |
|------|-----|---------|
| `pending` | `in_flight` | Sync engine picks up item for sending |
| `in_flight` | `synced` | Server returns 201 (created) or 409 (duplicate -- treated as success) |
| `in_flight` | `pending` | Server returns error (network failure, 5xx). `attempts` counter incremented. |
| `in_flight` | `failed` | Server returns error AND `attempts >= 5` |
| `failed` | (SMS) | SMS fallback is triggered for this passage |

### Sync Queue Table (Drift)

| Column | Type | Description |
|--------|------|-------------|
| id | int | Auto-increment PK |
| passage_client_id | uuid | References the local passage |
| status | text | pending, in_flight, synced, failed |
| attempts | int | Number of sync attempts (starts at 0) |
| last_attempt_at | datetime | Timestamp of most recent attempt |
| sms_sent | boolean | Whether SMS fallback has been sent for this item |
| created_at | datetime | When the queue item was created |

---

## Sync Engine Behavior

### Outbound Push

**Trigger:** Every 30 seconds via periodic timer AND immediately on connectivity change (offline -> online).

**Process:**
1. Query sync queue for items where `status = 'pending'`, ordered by `created_at` ASC (FIFO).
2. For each item:
   a. Set `status = 'in_flight'`, `last_attempt_at = now()`.
   b. POST to `POST /rest/v1/vehicle_passages` with the passage data including `client_id`.
   c. On 201 (created): set `status = 'synced'`.
   d. On 409 (conflict, `client_id` already exists): set `status = 'synced'` -- the server already has this record (likely from SMS fallback).
   e. On network error or 5xx: increment `attempts`, set `status = 'pending'`.
   f. If `attempts >= 5`: set `status = 'failed'`.
3. Process items sequentially (FIFO order preserved).

**Important:** The `client_id` is generated once when the passage is first recorded and never changes, even across retries. This is the idempotency key.

### Inbound Pull

**Trigger:** After each successful outbound push cycle AND on connectivity change.

**Process:**
1. Query the server for unmatched passages from the opposite checkpost:
   ```
   GET /rest/v1/vehicle_passages
     ?segment_id=eq.{my_segment_id}
     &checkpost_id=neq.{my_checkpost_id}
     &matched_passage_id=is.null
     &recorded_at=gte.{cutoff_timestamp}
     &order=recorded_at.desc
     &limit=500
   ```
2. Upsert results into the Drift `cached_remote_passages` table.
3. These cached entries are used by the local matching service for immediate violation detection.

**Cutoff timestamp:** Typically `now() - max_travel_time_minutes - buffer` to ensure we have all potentially matchable entries.

### Photo Upload

**Trigger:** After passage is synced (status = `synced`), if a photo exists locally.

**Process:**
1. Upload JPEG/PNG to `POST /storage/v1/object/passage-photos/{passage_id}.jpg`.
2. 2MB size limit.
3. On success: update passage record with `photo_path`.
4. On failure: silently retry on next sync cycle. Photo upload never blocks the passage record.

**Non-blocking:** Photo upload failure does not affect the passage record or sync status. The passage data is the priority; photos are supplementary evidence.

---

## SMS Fallback

### Trigger Conditions

SMS fallback activates when ALL of the following are true:

1. **No connectivity detected** -- `connectivity_plus` reports no network.
2. **Sync queue has pending items older than 5 minutes** -- at least one sync queue item has `status = 'pending'` and `created_at < now() - 5 minutes`.
3. **SMS has not already been sent for that item** -- `sms_sent = false` on the sync queue item.

### Behavior

1. For each eligible sync queue item:
   a. Encode the passage using `SmsEncoder.encode()` from the shared package.
   b. Format: `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`
   c. Send SMS via the device's native SMS capability to the configured gateway phone number.
   d. Set `sms_sent = true` on the sync queue item.
2. The sync queue item remains in `failed` status (it will be synced normally when connectivity returns).
3. When the app later syncs this passage normally, the server returns 409 (client_id already exists from SMS insert), which is treated as success.

### Why 5 Minutes?

- Too short (e.g., 1 minute): Would trigger SMS for brief connectivity drops, wasting SMS credits.
- Too long (e.g., 30 minutes): Delays data reaching the server, reducing the value of real-time matching.
- 5 minutes balances cost (SMS is not free) against timeliness (matching happens within a reasonable window).

---

## Matching Logic

### Client-Side Matching (Immediate)

Performed on the mobile device for immediate ranger feedback.

**When:** After every new passage is recorded locally (step in the Record Passage use case).

**Process:**
1. Search `cached_remote_passages` (Drift table) for entries where:
   - `plate_number` matches the new passage's plate number
   - `segment_id` matches
   - `checkpost_id` is different (opposite checkpost)
   - `matched_passage_id IS NULL` (not already matched)
2. If a match is found:
   - Calculate `travel_time_minutes = abs(new.recorded_at - cached.recorded_at)` in minutes.
   - Call `SpeedCalculator.check(distance, travelTime, maxSpeed, minSpeed)` from the shared package.
   - If violation detected: trigger Alert screen with appropriate audio alert.
3. Client-side matching is best-effort. It depends on having recently pulled data from the opposite checkpost.

**Limitations:**
- Only works if the opposite checkpost's data has been cached locally (inbound pull must have run recently).
- Does not create authoritative violation records. The server trigger is authoritative.

### Server-Side Matching (Authoritative)

Performed by the `fn_auto_match_passage()` PostgreSQL trigger.

**When:** Fires on every INSERT to `vehicle_passages`.

**Process:**
1. Find unmatched passage from opposite checkpost with same `plate_number` and `segment_id`.
2. Use `SELECT ... FOR UPDATE SKIP LOCKED` to prevent race conditions.
3. Determine entry (earlier) and exit (later) based on `recorded_at`.
4. Link both passages by setting `matched_passage_id` on each.
5. Calculate `travel_time_minutes`.
6. Fetch segment thresholds.
7. If `travel_time < min_travel_time` --> create SPEEDING violation.
8. If `travel_time > max_travel_time` --> create OVERSTAY violation.
9. Resolve any `proactive_overstay_alerts` for the matched entry.

**Why server-side is authoritative:**
- Handles SMS-originated records (no client-side matching for those).
- Handles late-syncing data (one device syncs hours later).
- Uses `SELECT ... FOR UPDATE` to prevent double-matching when two passages arrive simultaneously.
- Creates the official `violations` record in the database.

### Edge Function: match-passage

**Endpoint:** `POST /functions/v1/match-passage`

**Purpose:** Validates client-proposed matches. If the mobile app's client-side matching found a match and wants to confirm it server-side, it can call this function.

**Process:**
1. Receives proposed entry_passage_id and exit_passage_id.
2. Verifies both passages exist and are unmatched.
3. Uses `SELECT ... FOR UPDATE` to lock both rows.
4. Validates the match (same plate, same segment, opposite checkposts).
5. Creates the link and violation if applicable.

---

## Conflict Resolution Rules

### Rule 1: Server is Authoritative

The server's `vehicle_passages` table is the single source of truth. Local Drift data is a cache and staging area.

### Rule 2: client_id Prevents Duplicates

Every passage gets a `client_id` (UUID v4) generated on the device at recording time. The server has a UNIQUE constraint on `client_id`. `ON CONFLICT (client_id) DO NOTHING` ensures idempotent inserts.

**Scenario:** App records passage (client_id=X), SMS fallback also sends it, later app syncs it.
- SMS webhook generates a deterministic `client_id` from the SMS content.
- But the app's `client_id` is different (generated on device).
- Both records may exist, but the auto-match trigger uses `SELECT ... FOR UPDATE SKIP LOCKED` and `LIMIT 1`, so only one match occurs.

### Rule 3: SELECT FOR UPDATE Prevents Double-Matching

When the auto-match trigger finds a candidate match, it locks the row with `FOR UPDATE SKIP LOCKED`. This prevents two concurrent inserts from both matching the same passage.

### Rule 4: FIFO Sync Order

The sync queue processes items in `created_at` order. This ensures that if a ranger records multiple passages quickly, they arrive at the server in chronological order.

### Rule 5: 409 = Success

When the sync engine receives a 409 Conflict response (duplicate `client_id`), it treats this as a successful sync. The data is already on the server.

---

## Graceful Degradation Levels

```
Level 1: FULL ONLINE
  - Sync immediately (30s cycle)
  - Pull opposite checkpost data
  - Client + server matching
  - Real-time violation alerts
  - Photo upload

Level 2: CORE OFFLINE
  - All writes to local Drift
  - Client-side matching against cached data
  - Local violation alerts (best-effort)
  - Sync queue accumulates
  - Photos queued for later upload

Level 3: SMS LAST RESORT (offline > 5 minutes)
  - Compact passage data sent via SMS
  - Server processes via Twilio webhook
  - Server-side matching and violation detection
  - App continues local operation
  - Normal sync resumes when connectivity returns
```

---

## Related Documents

- `/docs/architecture/sms-protocol.md` -- SMS V1 format specification
- `/docs/architecture/database-schema.md` -- Database schema details
- `/docs/agents/agent-2-mobile.md` -- Mobile app agent objectives (Drift DB, sync engine details)
- `/docs/guidelines/offline-first.md` -- Offline-first development guidelines
