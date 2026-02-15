# Agent 4: Integration Testing

## Objective

Write comprehensive end-to-end tests covering all critical paths including offline scenarios, sync behavior, SMS fallback, and data integrity. This agent runs sequentially after Agents 1, 2, and 3 have all been merged to `main`.

## Branch

`feature/integration-tests`

---

## Owned Files

**Entire `/tests/e2e/` directory**, including:

```
tests/e2e/
  scenarios/
    happy_path_test.dart
    speeding_detection_test.dart
    overstay_detection_test.dart
    offline_sync_test.dart
    sms_fallback_test.dart
    duplicate_handling_test.dart
    conflict_resolution_test.dart
    data_integrity_test.dart
  helpers/
    test_setup.dart
    supabase_helper.dart
    mock_connectivity.dart
    mock_sms.dart
    test_data.dart
```

---

## Dependencies

All of the following must be merged to `main` before starting:

### From Agent 0 (Foundation)
- `/packages/shared/` -- all models, enums, constants, utils
- `/supabase/migrations/*` -- database schema
- `/supabase/seed.sql` -- test data baseline
- `/melos.yaml`, `/analysis_options.yaml`

### From Agent 1 (Backend)
- `/supabase/functions/*` -- all Edge Functions
- Database trigger `fn_auto_match_passage()`
- RLS policies on all tables
- `updated_at` triggers

### From Agent 2 (Mobile App)
- `/apps/mobile/` -- complete mobile app with Drift DB, sync engine, matching service, SMS fallback

### From Agent 3 (Web Dashboard)
- `/apps/web/` -- complete web dashboard

---

## Test Scenarios

### 1. Happy Path

**Scenario:** A vehicle enters at checkpost A and exits at checkpost B within normal travel time. No violation is generated.

**Steps:**
1. Record passage at checkpost A (entry) with plate `BA1PA1234`, vehicle type `car`
2. Sync the entry passage to the server
3. Wait for a travel time that is within `min_travel_time_minutes` and `max_travel_time_minutes`
4. Record passage at checkpost B (exit) with the same plate `BA1PA1234`
5. Sync the exit passage to the server

**Assertions:**
- Both passages exist in `vehicle_passages`
- Both passages have `matched_passage_id` set (pointing to each other)
- Entry passage has `is_entry = true`, exit passage has `is_entry = false`
- No record created in `violations` table
- No record created in `proactive_overstay_alerts` table

### 2. Speeding Detection

**Scenario:** A vehicle traverses the segment faster than the minimum allowed time, triggering a SPEEDING violation.

**Steps:**
1. Record entry passage at checkpost A
2. Sync to server
3. Record exit passage at checkpost B with `recorded_at` set so that travel time is less than `min_travel_time_minutes`
4. Sync to server

**Assertions:**
- Both passages are matched
- A `violations` record is created with `violation_type = 'speeding'`
- `travel_time_minutes` is less than `threshold_minutes`
- `calculated_speed_kmh` is greater than `speed_limit_kmh`
- `distance_km` and `speed_limit_kmh` are snapshot values from the segment at the time of violation

### 3. Overstay Detection

**Scenario:** A vehicle enters but does not exit within the maximum allowed time. A proactive alert is generated. When the vehicle eventually exits, an OVERSTAY violation is created and the alert is resolved.

**Steps:**
1. Record entry passage at checkpost A
2. Sync to server
3. Wait (or simulate) until `recorded_at + max_travel_time_minutes` has passed
4. Run the overstay cron (`POST /functions/v1/check-overstay`)
5. Verify proactive alert is created
6. Record exit passage at checkpost B with `recorded_at` after `max_travel_time_minutes`
7. Sync to server

**Assertions:**
- `proactive_overstay_alerts` record exists with correct `expected_exit_by`
- After exit passage syncs, passages are matched
- `violations` record created with `violation_type = 'overstay'`
- `travel_time_minutes` exceeds `threshold_minutes`
- Proactive alert is resolved: `resolved = true`, `resolved_at` set, `resolved_by_passage_id` points to exit passage

### 4. Offline Sync

**Scenario:** A ranger records a vehicle while offline. The passage is stored locally in Drift. When connectivity returns, the passage syncs to the server and matching occurs.

**Steps:**
1. Simulate offline state (no connectivity)
2. Record passage via the mobile app flow (Camera -> Review -> Submit)
3. Verify passage is in Drift `local_passages` table
4. Verify `sync_queue` has an entry with status `pending`
5. Restore connectivity
6. Wait for sync engine to push (30s timer or manual trigger)
7. Verify passage appears in server `vehicle_passages`
8. Verify `sync_queue` status changes to `synced`

**Assertions:**
- Passage is immediately available locally even without connectivity
- Sync occurs automatically when connectivity returns
- Server-side `fn_auto_match_passage()` trigger fires on the synced insert
- No data loss between offline recording and online sync

### 5. SMS Fallback

**Scenario:** Extended offline period triggers SMS fallback. The server receives the SMS via webhook and creates the passage.

**Steps:**
1. Simulate extended offline state (>5 minutes)
2. Record a passage while offline
3. Verify `sync_queue` item is in `pending` state for >5 minutes
4. Verify SMS fallback triggers and sends V1 format message
5. Simulate Twilio webhook call to `POST /functions/v1/sms-webhook` with the SMS content
6. Verify passage is created on the server with `source = 'sms'`
7. Restore connectivity
8. Verify the original passage sync results in a 409 (duplicate, handled as success)

**Assertions:**
- SMS format matches V1 specification: `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`
- Server correctly parses the SMS and creates a passage
- `source` field is set to `'sms'` on the server record
- When the app later syncs the same passage, the `client_id` uniqueness prevents duplicates
- `sync_queue` item transitions to `synced`

### 6. Duplicate Handling

**Scenario:** Two rangers at the same checkpost photograph the same vehicle. Both passages are stored, but only the first is used for matching.

**Steps:**
1. Ranger A records passage for plate `BA1PA1234` at checkpost A at time T
2. Ranger B records passage for the same plate `BA1PA1234` at checkpost A at time T+30s
3. Sync both passages
4. Record matching exit at checkpost B
5. Sync exit passage

**Assertions:**
- Both passages from Rangers A and B exist in `vehicle_passages`
- The auto-match trigger matches the exit passage with only one entry (the most recent unmatched from opposite checkpost, per the `ORDER BY recorded_at DESC LIMIT 1` query)
- Only one `violations` record is created (if applicable)
- No duplicate violations

### 7. Conflict Resolution

**Scenario:** The same `client_id` is uploaded twice (e.g., due to a network timeout where the response was lost but the server received the data).

**Steps:**
1. Record a passage with `client_id = 'abc-123'`
2. POST to server -- succeeds (201)
3. Simulate lost response (app thinks it failed)
4. POST the same passage again with `client_id = 'abc-123'`

**Assertions:**
- Second POST returns 409 (conflict) or is silently ignored (`ON CONFLICT (client_id) DO NOTHING`)
- Only one record exists in `vehicle_passages` with that `client_id`
- The sync engine treats 409 as success and marks the item as `synced`
- No duplicate records, no duplicate violations

### 8. Data Integrity

**Scenario:** Verify RLS enforcement, generated column behavior, and cascade deletes.

**Steps and Assertions:**

**RLS enforcement:**
- Ranger A (assigned to segment 1) cannot SELECT passages from segment 2
- Ranger A cannot INSERT passages for a checkpost not assigned to them
- Admin can SELECT and INSERT on all tables
- Unauthenticated requests are rejected

**Generated columns:**
- Update `distance_km` on a segment -> `min_travel_time_minutes` and `max_travel_time_minutes` recalculate automatically
- Update `max_speed_kmh` -> `min_travel_time_minutes` recalculates
- Update `min_speed_kmh` -> `max_travel_time_minutes` recalculates

**Cascade deletes:**
- Deleting a user from `auth.users` cascades to `user_profiles` (ON DELETE CASCADE)

**Timestamps:**
- All `recorded_at` values are stored as UTC `timestamptz`
- `server_received_at` is set by the server, not the client
- `updated_at` triggers fire on row updates

---

## Acceptance Criteria

1. **All 8 test scenarios pass against local Supabase** -- run `supabase start` locally, apply migrations, seed data, and execute all tests.
2. **Clean state per test** -- each test starts from a known state and cleans up after itself. No test depends on the side effects of another test. No data leakage between tests.
3. **Tests complete within 5 minutes total** -- all scenarios combined run efficiently, no unnecessary waits or polling.

---

## Test Infrastructure Notes

- **Local Supabase**: Tests run against a local Supabase instance (`supabase start`). No remote dependencies.
- **Test data factory**: Use helpers to generate valid test passages, violations, and users with unique `client_id` values.
- **State cleanup**: Each test should either use a transaction rollback or explicit cleanup to reset state.
- **Mock connectivity**: Use a mock `ConnectivityService` to simulate online/offline transitions.
- **Mock SMS**: Use a mock `SmsService` to capture outbound SMS messages without actually sending them.
- **Time simulation**: For overstay tests, manipulate `recorded_at` timestamps rather than waiting real time.
