# Agent 2: Mobile App

## Objective

Build the Flutter mobile app with full offline capability, camera/OCR, violation alerts, and SMS fallback. This agent runs in parallel with Agents 1 and 3, after Agent 0 merges to `main`.

## Branch

`feature/mobile-app`

---

## Owned Files

**Entire `/apps/mobile/` directory**, including:

```
apps/mobile/
  pubspec.yaml
  lib/
    main.dart
    app.dart
    core/
      theme/app_theme.dart              # Dark theme
      router/app_router.dart
      di/providers.dart                 # Riverpod providers
      services/
        connectivity_service.dart
        sms_service.dart
        notification_service.dart
        audio_alert_service.dart
    data/
      local/                            # Drift DB
        database.dart
        tables/
        daos/
      remote/                           # Supabase data sources
      repositories/
        passage_repository.dart
        violation_repository.dart
        auth_repository.dart
        sync_repository.dart
    domain/
      usecases/
        record_passage.dart
        check_for_violation.dart
        sync_passages.dart
        send_sms_fallback.dart
      services/
        matching_service.dart
        ocr_service.dart
    presentation/
      screens/
        login/
        home/
        capture/
        review/
        alert/
        outcome/
        history/
      widgets/
  test/
  android/
  ios/
  assets/
    sounds/
    images/
```

---

## Dependencies from Agent 0

Before starting, verify that Agent 0's `foundation/setup` branch has been merged to `main` and the following are available:

- `/packages/shared/` -- all models, enums, constants, and utils
  - Models: `Park`, `HighwaySegment`, `Checkpost`, `UserProfile`, `VehiclePassage`, `Violation`, `ViolationOutcome`, `SyncQueueItem`
  - Enums: `VehicleType`, `ViolationType`, `SyncStatus`, `UserRole`, `OutcomeType`
  - Constants: `AppConstants`, `SmsFormat`, `PlateRegex`, `ApiConstants`
  - Utils: `PlateNormalizer`, `SpeedCalculator`, `SmsEncoder`, `SmsDecoder`
- `/apps/mobile/pubspec.yaml` -- stub pubspec (extend it with all needed dependencies)
- `/melos.yaml` -- monorepo config
- `/analysis_options.yaml` -- lint rules

---

## Key Deliverables

### 1. Drift Local Database

Mirror the server schema locally using Drift v2 (type-safe SQLite). Tables include:
- `local_passages` -- mirrors `vehicle_passages`
- `cached_remote_passages` -- entries synced from opposite checkpost for local matching
- `local_violations` -- locally detected violations
- `sync_queue` -- tracks outbound sync state per passage

The Drift database must support:
- Compile-time query safety
- Reactive streams (watch queries for UI updates)
- Schema migrations

### 2. Sync Engine

Outbound and inbound synchronization with the Supabase backend.

**Outbound push (every 30 seconds + on connectivity change):**
- Reads `sync_queue` for items in `pending` state
- Sets state to `in_flight`
- POSTs to `vehicle_passages` REST API with `client_id`
- On success: sets state to `synced`
- On 409 (duplicate): treats as success, sets state to `synced`
- On failure: increments `attempts`, sets back to `pending`
- After 5 failed attempts: sets state to `failed`, triggers SMS fallback

**Inbound pull:**
- Fetches unmatched passages from the opposite checkpost
- Query: `GET /rest/v1/vehicle_passages?segment_id=eq.{sid}&checkpost_id=neq.{my_cp}&matched_passage_id=is.null&recorded_at=gte.{cutoff}&order=recorded_at.desc&limit=500`
- Caches results in `cached_remote_passages` Drift table
- Used by the local matching service

**Photo upload:**
- Non-blocking background upload to Supabase Storage
- Path: `passage-photos/{passage_id}.jpg`
- 2MB limit, JPEG/PNG only
- Failure does not block passage recording

### 3. OCR Service

Uses Google ML Kit Text Recognition for on-device plate number extraction.

- Supports both Latin and Devanagari scripts
- Processes camera image and extracts text candidates
- Pipes results through `PlateNormalizer.normalize()` from the shared package
- Target: extraction within 3 seconds
- Returns normalized plate number for the Review screen

### 4. Local Matching Service

Searches cached remote entries for matching passages and calculates violations locally.

**Logic:**
1. When a new passage is recorded, search `cached_remote_passages` for an unmatched entry with the same `plate_number` and `segment_id` from the opposite checkpost.
2. If match found, calculate `travel_time_minutes`.
3. Use `SpeedCalculator.check()` from the shared package to determine violation type.
4. If violation detected, trigger the Alert screen with audio.

This provides immediate feedback to the ranger even when offline. The server-side trigger (`fn_auto_match_passage()`) provides the authoritative match when data syncs.

### 5. SMS Fallback

Triggers when:
- No connectivity detected
- Sync queue has pending items older than 5 minutes
- SMS has not already been sent for that item

**Behavior:**
- Uses `SmsEncoder.encode()` from the shared package
- Sends V1 format: `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`
- Sends via device SMS capability to a configured gateway number
- Marks the sync queue item to prevent duplicate SMS sends

### 6. All Screens

#### Login Screen
- Username field (app auto-appends `@bnp.local`)
- Password field
- Login button
- Error display for invalid credentials
- Redirect to Home on success

#### Home Screen
- "RECORD VEHICLE" button: 72dp tall, full-width, amber color
- Connectivity status indicator (always visible)
- Sync status summary (pending count, last sync time)
- Quick stats (today's recordings, violations)
- Navigation to History

#### Camera/Capture Screen
- Full-screen camera preview
- Shutter button: 80dp circle
- Auto-flash in low-light conditions
- Flash toggle control
- Viewfinder guide overlay for plate positioning

#### Review Screen
- Captured photo display
- Plate number field: pre-filled from OCR, editable
- Vehicle type selector: defaults to "Car", options for all vehicle types
- "SUBMIT" button: 56dp height, green
- "RETAKE" option to go back to camera
- Timestamp display (device time at capture)

#### Alert Screen
- Auto-appears when a violation is detected after submission
- Distinct audio alert plays immediately (different sounds for speeding vs overstay)
- Large violation type indicator (SPEEDING / OVERSTAY)
- Vehicle details (plate, type)
- Calculated speed and threshold comparison
- Travel time details
- "RECORD OUTCOME" button to proceed
- "DISMISS" to return to home

#### Outcome Screen
- Outcome type selector: warned, fined, let_go, not_found, other
- Fine amount field (conditional, appears when "fined" selected)
- Notes text field
- "SAVE" button
- Can be accessed later from History for unresolved violations

#### History Screen
- List of recent recordings at this checkpost
- Filter/search by plate number
- Shows matched/unmatched status
- Shows violation status if applicable
- Tap to view details

### 7. Dark Theme

True outdoor/night-optimized dark theme:
- Background: true black (#121212)
- High contrast text and UI elements
- Minimum 48dp touch targets on all interactive elements
- Minimum 16sp font sizes
- Amber accent for primary actions
- Red for alerts/violations
- Green for safe/submit actions

### 8. Audio Alerts

- Distinct sound for SPEEDING violation
- Distinct sound for OVERSTAY violation
- Plays immediately when violation detected
- Loud enough for outdoor/road environment
- Audio files in `/apps/mobile/assets/sounds/`

---

## UX Flow (3 Taps Happy Path)

```
1. Home Screen
   └── Tap "RECORD VEHICLE" (72dp tall, full-width, amber)

2. Camera Screen
   └── Tap shutter button (80dp circle, auto-flash in low light)

3. Review Screen
   └── OCR pre-fills plate number, vehicle type defaults to Car
   └── Tap "SUBMIT" (56dp, green)

4. (Conditional) Alert Screen
   └── Auto-appears with audio if violation detected
   └── Ranger records outcome or dismisses
```

The goal is that the most common operation -- recording a vehicle passage -- requires only 3 taps from the home screen to submission.

---

## Acceptance Criteria

1. **Builds on iOS and Android simulators** -- no compilation errors, app launches and is functional.
2. **OCR extracts plate text within 3 seconds** -- from camera capture to normalized plate number.
3. **Full recording flow works offline** -- passage saved to Drift, sync queue item created, no network required.
4. **Sync pushes/pulls when connectivity returns** -- outbound pushes pending items, inbound pulls opposite checkpost entries.
5. **Violation alert with audio + visual on match** -- when local matching detects a violation, Alert screen appears with appropriate audio.
6. **SMS fallback sends correctly formatted message** -- after 5 minutes of no connectivity with pending items.
7. **Dark theme with large touch targets** -- true black background, 48dp minimum targets, 16sp minimum fonts, connectivity indicator always visible.
8. **Unit tests** -- matching service, sync repository, OCR service.
9. **Widget tests** -- each screen has at least basic widget tests.

---

## Architecture Notes

- **Write-local-first**: Every write goes to Drift first, then to the sync queue. Never write directly to Supabase from the UI.
- **Read-local-first**: Show local data immediately. Network data supplements but never blocks the UI.
- **No spinners waiting for network**: Always display local data, update when remote data arrives.
- **Repository pattern**: No direct Supabase calls from UI or domain layer. Repositories mediate between local and remote data sources.
- **Riverpod v2** with code generation for state management.
- **go_router** for declarative routing with auth redirect guards.
- **connectivity_plus** to detect network state and trigger sync/SMS fallback.
- **recorded_at** is always the device time at camera shutter moment, not submission time.
- **client_id** is generated once per passage and never regenerated on retry.
