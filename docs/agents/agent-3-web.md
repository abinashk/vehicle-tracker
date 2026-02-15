# Agent 3: Web Dashboard

## Objective

Build the Flutter Web admin dashboard for park administrators to manage rangers, configure highway segments, view passage logs, monitor violations, and track system health. This agent runs in parallel with Agents 1 and 2, after Agent 0 merges to `main`.

## Branch

`feature/web-dashboard`

---

## Owned Files

**Entire `/apps/web/` directory**, including:

```
apps/web/
  pubspec.yaml
  lib/
    main.dart
    presentation/screens/
      login/
      dashboard/
      rangers/
      segments/
      passages/
      violations/
      unmatched/
  test/
  web/
```

---

## Dependencies from Agent 0

Before starting, verify that Agent 0's `foundation/setup` branch has been merged to `main` and the following are available:

- `/packages/shared/` -- all models, enums, constants, and utils
  - Models: `Park`, `HighwaySegment`, `Checkpost`, `UserProfile`, `VehiclePassage`, `Violation`, `ViolationOutcome`
  - Enums: `VehicleType`, `ViolationType`, `UserRole`, `OutcomeType`
  - Constants: `AppConstants`, `ApiConstants`
- `/apps/web/pubspec.yaml` -- stub pubspec (extend it with all needed dependencies)
- `/melos.yaml` -- monorepo config
- `/analysis_options.yaml` -- lint rules

### Dependencies from Agent 1

The web dashboard calls the following Edge Functions built by Agent 1:
- `POST /functions/v1/create-ranger` -- for creating new ranger accounts
- Other CRUD operations use standard Supabase REST API

**Note:** Agent 3 can develop against the Supabase REST API contract and mock the Edge Function responses. The actual Edge Functions will be available when Agent 1's branch merges.

---

## Key Deliverables

### 1. Admin Auth

- Supabase Auth login with email/password
- Role check on login: reject users where `user_profiles.role != 'admin'`
- Show clear error message if a ranger attempts to log in
- Auth guard on all routes -- redirect to login if not authenticated
- Session persistence (auto-login on refresh if token valid)

### 2. Ranger CRUD

- **List rangers**: table view with name, username, phone, assigned checkpost, active status
- **Create ranger**: form calling `POST /functions/v1/create-ranger`
  - Fields: username, password, full_name, phone_number, assigned_checkpost_id, assigned_park_id
  - Username auto-appends `@bnp.local`
  - Form validation on all fields
- **Edit ranger**: update profile fields (full_name, phone_number, assigned_checkpost_id)
- **Toggle active**: enable/disable ranger accounts
- Confirmation dialogs for destructive actions

### 3. Segment Configuration

- **List segments**: table showing name, distance, max speed, min speed, calculated thresholds
- **Edit segment**: update `distance_km`, `max_speed_kmh`, `min_speed_kmh`
  - Live preview of calculated `min_travel_time_minutes` and `max_travel_time_minutes` (generated columns update on save)
  - Validation: all values must be > 0, max_speed > min_speed
- **View checkposts**: nested under segments, showing checkpost details
- Changes to segment thresholds are reflected immediately via PostgreSQL generated columns

### 4. Passage Log

- Paginated table of all vehicle passages
- **Filterable by:**
  - Date range
  - Checkpost
  - Vehicle type
  - Plate number (search)
  - Source (app / sms)
  - Matched/unmatched status
- **Columns:** plate number, vehicle type, checkpost, recorded_at, source, matched status, ranger
- Sortable by recorded_at (default: descending)
- First page loads in under 2 seconds
- Click row to view passage details including photo (if available)

### 5. Violation Log

- Paginated table of all violations
- **Filterable by:**
  - Violation type (speeding / overstay)
  - Date range
  - Plate number
  - Outcome status (has outcome / no outcome)
- **Columns:** plate number, vehicle type, violation type, travel time, threshold, calculated speed, entry/exit times, outcome
- **CSV export**: download filtered violations as CSV file
  - Include all violation fields plus outcome details
  - File named with date range and filter description
- Click row to view full violation details with entry/exit passage info

### 6. Unmatched Entries View

- List of vehicle passages where `matched_passage_id IS NULL` and `recorded_at + max_travel_time < now()`
- These represent vehicles that entered but never exited (or vice versa)
- **For each entry show:** plate number, vehicle type, checkpost, recorded_at, time elapsed
- **Admin resolve action**: manually mark as resolved with notes (e.g., "vehicle parked at lodge", "false plate read")
- Sort by oldest first (most overdue at top)

### 7. Dashboard

- **Today's summary counts:**
  - Total passages recorded today
  - Violations detected today (broken down by type)
  - Unmatched entries count
  - Active proactive overstay alerts
- **Last 7 days chart:**
  - Bar chart or line chart showing daily passage counts
  - Overlay violation counts
- **Active proactive alerts panel:**
  - Real-time updates via Supabase Realtime subscription
  - Shows vehicles that have exceeded max travel time without exit
  - Auto-updates when alerts are resolved
- **System health indicators:**
  - Last sync time per checkpost
  - Active rangers online

### 8. Responsive Sidebar Layout

- Persistent sidebar navigation on desktop (>1024px)
- Collapsible sidebar on tablet
- Links: Dashboard, Rangers, Segments, Passages, Violations, Unmatched
- Active page indicator
- User profile / logout in sidebar footer

---

## Acceptance Criteria

1. **Admin login works, non-admin rejected** -- rangers see a clear error message, admins proceed to dashboard.
2. **Ranger CRUD end-to-end** -- create a ranger via the Edge Function, edit profile, toggle active status.
3. **Threshold changes reflected immediately** -- updating segment distance/speed recalculates `min_travel_time_minutes` and `max_travel_time_minutes` (PostgreSQL generated columns).
4. **Passage log paginates, first page < 2s** -- efficient queries with proper indexing, no loading all data at once.
5. **CSV export works** -- filtered violations download as a properly formatted CSV file.
6. **Realtime updates on dashboard** -- new violations and proactive alerts appear without page refresh via Supabase Realtime.
7. **Form validation on all inputs** -- required fields enforced, numeric ranges validated, clear error messages.
8. **Unit tests for repositories** -- data fetching and transformation logic tested.
9. **Widget tests for key screens** -- login, dashboard, ranger list, violation list.

---

## Architecture Notes

- **Supabase REST API** for all data operations (except create-ranger which uses an Edge Function).
- **Riverpod v2** with code generation for state management.
- **go_router** for declarative routing with auth redirect guards.
- **Repository pattern**: no direct Supabase calls from UI. Repositories handle all data access.
- **Shared package models**: use the same Dart classes as the mobile app for consistency.
- **No Drift**: the web dashboard does not need offline storage. It connects directly to Supabase.
- **Supabase Realtime**: subscribe to `violations` and `proactive_overstay_alerts` tables for live dashboard updates.
- All timestamps displayed in Nepal Time (UTC+5:45), stored as UTC.
