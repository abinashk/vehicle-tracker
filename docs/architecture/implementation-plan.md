# Implementation Plan: National Park Vehicle Speed Monitoring System

## Context

Vehicles speeding through Nepal's national park highway segments endanger wildlife and visitors. This system uses time-based speed detection: two checkposts at each end record vehicle entry/exit, and if travel time falls outside thresholds (too fast = speeding, too slow = potential poaching), rangers are alerted. The requirements doc at `docs/requirements/requirements.md` is final and authoritative.

**Key architectural drivers:**
- Offline-first (checkposts have ~90% data, ~10% downtime)
- Under $5K budget → Supabase free tier, on-device OCR
- 24/7 operation in low-light → dark theme, minimal taps, audio alerts
- Legally-backed enforcement → reliable evidence chain (photo + timestamp)

---

## 1. Tech Stack

| Layer | Technology | Justification |
|-------|-----------|---------------|
| Mobile | Flutter (iOS + Android) | Cross-platform, single codebase |
| Web Dashboard | Flutter Web | Shares models/logic with mobile |
| Backend | Supabase (PostgreSQL, Auth, Edge Functions, Realtime, Storage) | Free tier covers pilot scale, zero server management |
| State Management | Riverpod v2 + code generation | Async-first, testable, no BuildContext dependency |
| Local DB | Drift v2 (type-safe SQLite) | Compile-time query safety, reactive streams, migrations |
| OCR | Google ML Kit Text Recognition | On-device, free, supports Devanagari script |
| Camera | `camera` package | Official Flutter, flash control for night use |
| Routing | go_router | Declarative, auth redirect guards |
| Connectivity | connectivity_plus | Triggers sync and SMS fallback |
| Push Notifications | Firebase Cloud Messaging + flutter_local_notifications | Proactive overstay alerts |
| Monorepo | Melos | Multi-package Dart monorepo tooling |
| Models | Plain Dart classes with hand-written fromJson/toJson | Simple, no build step overhead |
| Auth | Supabase Auth with email-format usernames (e.g., `ranger1@bnp.local`) | App auto-appends domain; rangers just type username |

---

## 2. Monorepo Structure

```
vehicle-tracker/
├── docs/
│   ├── requirements/requirements.md          # FINAL - do not modify
│   ├── guidelines/
│   │   ├── pr-creation.md
│   │   ├── pr-review.md
│   │   ├── testing.md
│   │   ├── coding-standards.md
│   │   ├── api-contracts.md
│   │   ├── offline-first.md
│   │   ├── security.md
│   │   └── git-workflow.md
│   ├── architecture/
│   │   ├── overview.md
│   │   ├── database-schema.md
│   │   ├── offline-sync.md
│   │   └── sms-protocol.md
│   └── agents/
│       ├── agent-0-foundation.md
│       ├── agent-1-backend.md
│       ├── agent-2-mobile.md
│       ├── agent-3-web.md
│       └── agent-4-integration.md
├── packages/
│   └── shared/                             # Shared Dart package
│       ├── pubspec.yaml
│       ├── lib/
│       │   ├── shared.dart                 # Barrel export
│       │   └── src/
│       │       ├── models/                 # Plain Dart classes
│       │       │   ├── park.dart
│       │       │   ├── highway_segment.dart
│       │       │   ├── checkpost.dart
│       │       │   ├── user_profile.dart
│       │       │   ├── vehicle_passage.dart
│       │       │   ├── violation.dart
│       │       │   ├── violation_outcome.dart
│       │       │   └── sync_queue_item.dart
│       │       ├── enums/
│       │       │   ├── vehicle_type.dart
│       │       │   ├── violation_type.dart
│       │       │   ├── sync_status.dart
│       │       │   ├── user_role.dart
│       │       │   └── outcome_type.dart
│       │       ├── constants/
│       │       │   ├── app_constants.dart
│       │       │   ├── sms_format.dart
│       │       │   ├── plate_regex.dart
│       │       │   └── api_constants.dart
│       │       └── utils/
│       │           ├── plate_normalizer.dart
│       │           ├── speed_calculator.dart
│       │           ├── sms_encoder.dart
│       │           └── sms_decoder.dart
│       └── test/
├── apps/
│   ├── mobile/                             # Ranger mobile app
│   │   ├── pubspec.yaml
│   │   └── lib/
│   │       ├── main.dart
│   │       ├── app.dart
│   │       ├── core/
│   │       │   ├── theme/app_theme.dart    # Dark theme
│   │       │   ├── router/app_router.dart
│   │       │   ├── di/providers.dart       # Riverpod providers
│   │       │   └── services/
│   │       │       ├── connectivity_service.dart
│   │       │       ├── sms_service.dart
│   │       │       ├── notification_service.dart
│   │       │       └── audio_alert_service.dart
│   │       ├── data/
│   │       │   ├── local/                  # Drift DB
│   │       │   │   ├── database.dart
│   │       │   │   ├── tables/
│   │       │   │   └── daos/
│   │       │   ├── remote/                 # Supabase data sources
│   │       │   └── repositories/           # Mediate local ↔ remote
│   │       │       ├── passage_repository.dart
│   │       │       ├── violation_repository.dart
│   │       │       ├── auth_repository.dart
│   │       │       └── sync_repository.dart
│   │       ├── domain/
│   │       │   ├── usecases/
│   │       │   │   ├── record_passage.dart
│   │       │   │   ├── check_for_violation.dart
│   │       │   │   ├── sync_passages.dart
│   │       │   │   └── send_sms_fallback.dart
│   │       │   └── services/
│   │       │       ├── matching_service.dart
│   │       │       └── ocr_service.dart
│   │       └── presentation/
│   │           ├── screens/
│   │           │   ├── login/
│   │           │   ├── home/
│   │           │   ├── capture/
│   │           │   ├── review/
│   │           │   ├── alert/
│   │           │   ├── outcome/
│   │           │   └── history/
│   │           └── widgets/
│   └── web/                                # Admin dashboard
│       ├── pubspec.yaml
│       └── lib/
│           ├── main.dart
│           └── presentation/screens/
│               ├── login/
│               ├── dashboard/
│               ├── rangers/
│               ├── segments/
│               ├── passages/
│               ├── violations/
│               └── unmatched/
├── supabase/
│   ├── config.toml
│   ├── seed.sql                            # Banke National Park pilot data
│   ├── migrations/
│   │   ├── 00001_create_parks.sql
│   │   ├── 00002_create_highway_segments.sql
│   │   ├── 00003_create_checkposts.sql
│   │   ├── 00004_create_user_profiles.sql
│   │   ├── 00005_create_vehicle_passages.sql
│   │   ├── 00006_create_violations.sql
│   │   ├── 00007_create_violation_outcomes.sql
│   │   ├── 00008_create_proactive_overstay_alerts.sql
│   │   ├── 00009_create_sync_metadata.sql
│   │   ├── 00010_create_indexes.sql
│   │   ├── 00011_create_rls_policies.sql
│   │   └── 00012_create_functions.sql
│   └── functions/
│       ├── sms-webhook/index.ts
│       ├── check-overstay/index.ts
│       ├── match-passage/index.ts
│       ├── create-ranger/index.ts
│       └── _shared/
│           ├── cors.ts
│           ├── supabase-client.ts
│           └── sms-parser.ts
├── tests/e2e/                              # Integration tests
├── melos.yaml
├── analysis_options.yaml
└── .github/workflows/
    ├── ci-shared.yml
    ├── ci-mobile.yml
    ├── ci-web.yml
    └── ci-backend.yml
```

---

## 3. Database Schema

### parks
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| name | text | NOT NULL, UNIQUE |
| code | text | NOT NULL, UNIQUE, max 10 |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at | timestamptz | NOT NULL, DEFAULT now() |
| updated_at | timestamptz | NOT NULL, DEFAULT now() |

### highway_segments
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| park_id | uuid | FK → parks.id, NOT NULL |
| name | text | NOT NULL |
| distance_km | numeric(6,2) | NOT NULL, CHECK > 0 |
| max_speed_kmh | numeric(5,2) | NOT NULL, CHECK > 0 |
| min_speed_kmh | numeric(5,2) | NOT NULL, CHECK > 0 |
| min_travel_time_minutes | numeric(8,2) | GENERATED: (distance_km / max_speed_kmh) * 60 |
| max_travel_time_minutes | numeric(8,2) | GENERATED: (distance_km / min_speed_kmh) * 60 |
| is_active | boolean | NOT NULL, DEFAULT true |
| created_at / updated_at | timestamptz | |

### checkposts
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| segment_id | uuid | FK → highway_segments.id, NOT NULL |
| name | text | NOT NULL |
| code | text | NOT NULL, UNIQUE (used in SMS) |
| position_index | smallint | NOT NULL, CHECK IN (0,1) |
| latitude / longitude | numeric | NULLABLE |
| is_active | boolean | DEFAULT true |
| created_at | timestamptz | |

UNIQUE constraint: (segment_id, position_index)

### user_profiles
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, FK → auth.users.id ON DELETE CASCADE |
| full_name | text | NOT NULL |
| role | text | CHECK IN ('ranger', 'admin') |
| phone_number | text | NULLABLE |
| assigned_checkpost_id | uuid | FK → checkposts.id, NULLABLE |
| assigned_park_id | uuid | FK → parks.id, NULLABLE |
| is_active | boolean | DEFAULT true |
| created_at / updated_at | timestamptz | |

### vehicle_passages (core high-volume table)
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| client_id | uuid | NOT NULL, UNIQUE (idempotency key) |
| plate_number | text | NOT NULL (normalized English transliteration) |
| plate_number_raw | text | NULLABLE (original OCR output) |
| vehicle_type | text | NOT NULL, CHECK IN enum values |
| checkpost_id | uuid | FK → checkposts.id, NOT NULL |
| segment_id | uuid | FK → highway_segments.id, NOT NULL |
| recorded_at | timestamptz | NOT NULL (device time at capture) |
| server_received_at | timestamptz | DEFAULT now() |
| ranger_id | uuid | FK → user_profiles.id, NOT NULL |
| photo_path | text | NULLABLE (Supabase Storage path) |
| source | text | DEFAULT 'app', CHECK IN ('app', 'sms') |
| matched_passage_id | uuid | FK → self, NULLABLE |
| is_entry | boolean | NULLABLE |
| created_at | timestamptz | DEFAULT now() |

**Key indexes:**
- `(plate_number, segment_id, recorded_at DESC)` — matching lookup
- `(checkpost_id, recorded_at DESC)` — checkpost listing
- `(segment_id, recorded_at) WHERE matched_passage_id IS NULL` — partial index for unmatched entries
- `client_id` UNIQUE — deduplication

### violations
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| entry_passage_id | uuid | FK → vehicle_passages.id, UNIQUE |
| exit_passage_id | uuid | FK → vehicle_passages.id |
| segment_id | uuid | FK |
| violation_type | text | CHECK IN ('speeding', 'overstay') |
| plate_number | text | Denormalized |
| vehicle_type | text | Denormalized |
| entry_time / exit_time | timestamptz | Denormalized |
| travel_time_minutes | numeric(8,2) | Actual travel time |
| threshold_minutes | numeric(8,2) | Threshold that was violated |
| calculated_speed_kmh | numeric(6,2) | |
| speed_limit_kmh / distance_km | numeric | Snapshot at time of violation |
| alert_delivered_at | timestamptz | NULLABLE |
| created_at | timestamptz | |

### violation_outcomes
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| violation_id | uuid | FK → violations.id, UNIQUE |
| outcome_type | text | CHECK IN ('warned', 'fined', 'let_go', 'not_found', 'other') |
| fine_amount | numeric(10,2) | NULLABLE |
| notes | text | NULLABLE |
| recorded_by | uuid | FK → user_profiles.id |
| recorded_at | timestamptz | |

### proactive_overstay_alerts
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| entry_passage_id | uuid | FK → vehicle_passages.id |
| segment_id | uuid | FK |
| plate_number / vehicle_type | text | |
| entry_time | timestamptz | |
| expected_exit_by | timestamptz | entry_time + max_travel_time |
| resolved | boolean | DEFAULT false |
| resolved_at | timestamptz | NULLABLE |
| resolved_by_passage_id | uuid | FK, NULLABLE |

---

## 4. API Contracts

### 4.1 Auth
- Login: `POST /auth/v1/token?grant_type=password` — body: `{ email: "ranger1@bnp.local", password }`. App auto-appends `@bnp.local` to username input.
- Profile: `GET /rest/v1/user_profiles?id=eq.{uid}&select=*,checkposts(*,highway_segments(*))`

### 4.2 Vehicle Passages
- **Record**: `POST /rest/v1/vehicle_passages` with `client_id` for idempotent upsert (`ON CONFLICT (client_id) DO NOTHING`)
- **Fetch unmatched from opposite checkpost**: `GET /rest/v1/vehicle_passages?segment_id=eq.{sid}&checkpost_id=neq.{my_cp}&matched_passage_id=is.null&recorded_at=gte.{cutoff}&order=recorded_at.desc&limit=500`

### 4.3 Matching
**Hybrid: client-first, server-verified.**
- **Client-side**: Mobile searches local Drift cache of synced entries. If match found, calculates violation locally and shows alert immediately.
- **Server-side**: DB trigger `fn_auto_match_passage()` fires on every INSERT to `vehicle_passages`. Finds unmatched entry with same plate + segment from opposite checkpost. Links them, creates violation if thresholds breached. This handles SMS-originated records and late-syncing data.
- **Edge Function `match-passage`**: `POST /functions/v1/match-passage` — validates client-proposed match, uses `SELECT ... FOR UPDATE` to prevent double-matching.

### 4.4 SMS Webhook
`POST /functions/v1/sms-webhook` — receives Twilio webhook, parses compact format, inserts passage with `source='sms'`.

**SMS format (160 chars):** `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`
Example: `V1|BNP-A|BA1PA1234|CAR|1709123456|9801`

### 4.5 Overstay Cron
`POST /functions/v1/check-overstay` — runs every 15 min via pg_cron. Finds unmatched entries past max_travel_time, creates proactive_overstay_alerts.

### 4.6 Admin Operations
- `POST /functions/v1/create-ranger` — creates auth user + profile atomically
- Photo upload: `POST /storage/v1/object/passage-photos/{passage_id}.jpg` (2MB limit, JPEG/PNG)

### 4.7 RLS Summary
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

---

## 5. Agent Decomposition

### Agent 0: Foundation (Sequential — runs first)

**Objective:** Set up monorepo, shared package, database schema, CI/CD, architecture docs, and all 8 guidelines docs.

**Owns:**
- `/melos.yaml`, `/analysis_options.yaml`, `/.gitignore`, `/README.md`
- `/packages/shared/` — all models, enums, constants, utils
- `/supabase/config.toml`, `/supabase/seed.sql`, `/supabase/migrations/*`
- `/.github/workflows/*`
- `/docs/guidelines/*` (all 8 guidelines docs)
- `/docs/architecture/*`
- `/docs/agents/*` (all 5 agent objective docs)
- Stub `/apps/mobile/pubspec.yaml` and `/apps/web/pubspec.yaml` (just enough for melos bootstrap)

**Key deliverables:**
1. `PlateNormalizer.normalize(raw)` — Devanagari → Latin transliteration
2. `SpeedCalculator.check(distance, travelTime, maxSpeed, minSpeed)` → `{violationType?, speed, threshold}`
3. `SmsEncoder.encode()` / `SmsDecoder.decode()` — compact SMS format
4. All 12 SQL migration files
5. Seed data: Banke National Park, 1 segment, 2 checkposts
6. All 8 guidelines docs with clear, enforceable rules

**Acceptance criteria:**
- `melos bootstrap` succeeds
- `dart analyze packages/shared` — zero issues
- `dart test packages/shared` — all pass (PlateNormalizer, SpeedCalculator, SmsEncoder/Decoder tests)
- `supabase db reset` applies all migrations + seed without error

**Branch:** `foundation/setup`

---

### Agent 1: Backend (Parallel — after Agent 0 merges)

**Objective:** Implement all Supabase Edge Functions, RLS policies, database triggers, SMS webhook, and overstay cron.

**Owns:**
- `/supabase/functions/sms-webhook/index.ts`
- `/supabase/functions/check-overstay/index.ts`
- `/supabase/functions/match-passage/index.ts`
- `/supabase/functions/create-ranger/index.ts`
- `/supabase/functions/_shared/*`
- RLS policy content in migrations (may add migrations 00013+)

**Key deliverables:**
1. `fn_auto_match_passage()` trigger — the core matching/violation-creation logic
2. SMS webhook — Twilio signature verification, V1 format parsing, passage insert
3. Overstay cron — scans unmatched entries past max time, creates proactive alerts
4. Create-ranger function — atomic auth user + profile creation
5. All RLS policies tested
6. `updated_at` trigger for all relevant tables

**Acceptance criteria:**
- Auto-match trigger correctly creates speeding AND overstay violations
- SMS webhook parses V1 format and inserts passage with `source='sms'`
- Double-matching prevented (SELECT FOR UPDATE)
- Overstay cron doesn't create duplicate alerts
- RLS: ranger can't read other segment's data, admin can read all
- All edge functions return proper error codes (400, 401, 403, 409, 500)

**Branch:** `feature/backend-services`

---

### Agent 2: Mobile App (Parallel — after Agent 0 merges)

**Objective:** Build the Flutter mobile app with full offline capability, camera/OCR, violation alerts, and SMS fallback.

**Owns:** `/apps/mobile/` (entire directory)

**Key deliverables:**
1. **Drift local DB** mirroring server schema + sync queue
2. **Sync engine** — outbound push (every 30s + on connectivity change), inbound pull (cached remote entries), photo upload
3. **OCR service** — Google ML Kit, supports Devanagari, returns normalized plate
4. **Local matching service** — searches cached entries, calculates violations
5. **SMS fallback** — triggers after 5 min of no connectivity with pending items
6. **All screens**: Login, Home, Camera, Review, Alert, Outcome, History
7. **Dark theme** — true black (#121212), high contrast, min 48dp touch targets, 16sp+ fonts
8. **Audio alerts** — distinct sounds for speeding vs overstay

**UX Flow (3 taps happy path):**
1. Home → tap "RECORD VEHICLE" (72dp tall, full-width, amber)
2. Camera → tap shutter (80dp circle, auto-flash in low light)
3. Review → OCR pre-filled, vehicle type defaults to Car → tap "SUBMIT" (56dp, green)
4. (Conditional) Alert screen auto-appears with audio if violation detected

**Acceptance criteria:**
- Builds on iOS and Android simulators
- OCR extracts plate text within 3 seconds
- Full recording flow works offline (Drift + sync queue)
- Sync pushes/pulls when connectivity returns
- Violation alert with audio + visual on match
- SMS fallback sends correctly formatted message
- Dark theme, large targets, connectivity indicator always visible
- Unit tests for matching service, sync repository, OCR service
- Widget tests for each screen

**Branch:** `feature/mobile-app`

---

### Agent 3: Web Dashboard (Parallel — after Agent 0 merges)

**Objective:** Build the Flutter Web admin dashboard.

**Owns:** `/apps/web/` (entire directory)

**Key deliverables:**
1. Admin auth (Supabase, role check — reject non-admins)
2. Ranger CRUD (create via `create-ranger` Edge Function, edit, toggle active)
3. Segment config (distance, max speed, min speed — shows calculated thresholds)
4. Passage log (paginated, filterable by date/checkpost/vehicle type/plate)
5. Violation log (filterable by type/date, shows outcome, CSV export)
6. Unmatched entries view (entries past max_travel_time with no match, admin resolve)
7. Dashboard (today's counts, last 7 days chart, active proactive alerts with Realtime)
8. Responsive sidebar layout

**Acceptance criteria:**
- Admin login works, non-admin rejected
- Ranger CRUD end-to-end
- Threshold changes reflected immediately (generated columns)
- Passage log paginates, first page < 2s
- CSV export works
- Realtime updates on dashboard for new violations/alerts
- Form validation on all inputs
- Unit tests for repositories, widget tests for key screens

**Branch:** `feature/web-dashboard`

---

### Agent 4: Integration Testing (Sequential — after Agents 1-3 merge)

**Objective:** E2E tests covering all critical paths including offline and sync scenarios.

**Owns:** `/tests/e2e/` (entire directory)

**Test scenarios:**
1. **Happy path** — entry at A → sync → exit at B → match → no violation
2. **Speeding detection** — travel time below minimum → SPEEDING violation created
3. **Overstay detection** — no exit past max time → proactive alert → late exit → OVERSTAY violation → alert resolved
4. **Offline sync** — record offline → stored in Drift → connectivity → synced → matched
5. **SMS fallback** — extended offline → SMS sent → server receives webhook → passage created
6. **Duplicate handling** — 2 rangers photograph same vehicle → both stored → only first matched
7. **Conflict resolution** — same client_id uploaded twice → idempotent, no duplicate
8. **Data integrity** — RLS enforcement, generated column updates, cascade deletes

**Acceptance criteria:**
- All scenarios pass against local Supabase
- Clean state per test (no leakage)
- Tests complete within 5 minutes total

**Branch:** `feature/integration-tests`

---

## 6. Offline Sync Architecture

```
MOBILE DEVICE                              │  SERVER (SUPABASE)
                                           │
[Camera/OCR] → [Review Screen]             │
      │                                    │
      ▼                                    │
[Record Passage Use Case]                  │
      │                                    │
      ├──→ Drift: local_passages (INSERT)  │
      ├──→ Drift: sync_queue (pending)     │
      ├──→ Matching Service                │
      │       └──→ cached_remote_entries   │
      │       └──→ If match → violation    │
      │            → Alert UI              │
      ▼                                    │
[Sync Engine] (30s timer + connectivity)   │
      │                                    │
      ├── OUTBOUND ──────────────────────→ Supabase REST API → vehicle_passages
      │   POST with client_id              │                    │
      │   409 = already exists = OK        │              auto_match trigger
      │                                    │                    │
      ├── INBOUND ←────────────────────── Supabase REST API    ▼
      │   GET unmatched from opposite CP   │              violations table
      │   → cache in Drift                 │
      │                                    │
      └── PHOTOS ────────────────────────→ Supabase Storage (non-blocking)
```

**Sync queue states:** `pending` → `in_flight` → `synced` (or back to `pending` with attempts++ on failure, `failed` after 5 attempts → triggers SMS fallback)

**SMS fallback triggers when:** no connectivity AND sync queue has pending items older than 5 minutes AND SMS not already sent for that item.

**Conflict resolution:** Server authoritative. `client_id` UNIQUE prevents duplicates. `SELECT FOR UPDATE` prevents double-matching.

---

## 7. Review Agents (5 per PR)

Each PR is reviewed by **5 independent agents**, all evaluating the **full checklist** below. The purpose of 5 reviewers is redundancy — multiple independent perspectives to catch issues any single reviewer might miss. Every reviewer covers all aspects.

### Full Review Checklist (used by all 5 agents)

**Security:**
- Parameterized queries (no string interpolation in SQL)
- RLS policies present and correct for every table
- JWT validation in Edge Functions
- Twilio signature verification on SMS webhook
- No hardcoded secrets (env vars only)
- File type/size validation on uploads
- CORS restricted to web dashboard domain

**Architecture Extensibility:**
- Multi-park queries (filter by park_id/segment_id, never assume single park)
- Schema accommodates future per-vehicle-type thresholds
- Localization-ready strings (keys, not hardcoded English)
- Vehicle type enum defined once in shared package
- Repository pattern enforced (no direct Supabase calls from UI)
- Providers scoped correctly (no tight coupling)

**Pattern Compliance (verify against established Flutter/Dart best practices):**
- Models use plain Dart classes with fromJson/toJson (no freezed)
- Riverpod providers use code generation (@riverpod)
- Drift tables use Drift DSL
- Typed exceptions (not generic catch)
- AsyncValue for async state in Riverpod
- snake_case.dart file naming
- Package imports (not relative across boundaries)
- Arrange-Act-Assert test pattern

**Connectivity Resilience:**
- Every write → local Drift first → sync queue (never direct to Supabase from UI)
- Every read → local fallback if Supabase unreachable
- No unhandled HTTP exceptions
- No spinners waiting for network — show local data immediately
- SMS fallback triggered correctly (not too eager, not too late)
- Realtime subscription reconnects after connectivity loss
- Photo upload non-blocking
- Graceful degradation: full online → core offline → SMS last resort

**Data Integrity:**
- client_id generated once, never regenerated on retry
- recorded_at = camera shutter moment (not submission time)
- Sync queue FIFO processing
- Lost response handling (409 on retry = success)
- Matching is idempotent (no duplicate violations)
- Violations snapshot threshold values at time of detection
- Overstay cron doesn't create duplicate proactive alerts
- All timestamps stored as UTC timestamptz, displayed in Nepal Time (UTC+5:45)

### How Reviews Work
1. Each PR triggers 5 independent review agents (Review Agent 1 through 5)
2. Each agent reviews the PR against the **entire checklist** above
3. Each agent produces: pass/fail verdict + specific line-level comments for any findings
4. A PR requires **all 5 agents to pass** before it can be merged
5. If any agent fails, the work agent addresses findings and re-requests review

---

## 8. Guidelines Docs to Create (8 total)

| Doc | Purpose |
|-----|---------|
| `docs/guidelines/pr-creation.md` | Branch naming, commit message format, PR description template, what to include in PRs |
| `docs/guidelines/pr-review.md` | Review checklist aligned with 5 review agent focuses, approval criteria, how to handle findings |
| `docs/guidelines/testing.md` | Unit/widget/integration test requirements, coverage targets, test naming, mocking patterns |
| `docs/guidelines/coding-standards.md` | Dart/Flutter style, file naming, import ordering, model class conventions, error handling |
| `docs/guidelines/api-contracts.md` | Supabase table/function contracts, SMS format spec, how to add new endpoints |
| `docs/guidelines/offline-first.md` | Write-local-first rule, sync queue patterns, conflict resolution, SMS fallback triggers |
| `docs/guidelines/security.md` | Auth patterns, RLS rules, secret management, input validation, CORS |
| `docs/guidelines/git-workflow.md` | Branch-from-main strategy, PR-to-main flow, how agents coordinate, merge order |

---

## 9. Execution Sequence

```
Phase 1: Agent 0 (Foundation)
  └──→ Branch: foundation/setup
  └──→ PR → main (reviewed by 5 review agents)
  └──→ Merge to main

Phase 2: Agents 1, 2, 3 (Parallel)
  ├── Agent 1 → Branch: feature/backend-services
  ├── Agent 2 → Branch: feature/mobile-app
  └── Agent 3 → Branch: feature/web-dashboard
  └──→ Each creates PR → main (each reviewed by 5 review agents)
  └──→ Merge to main (backend first recommended, then mobile, then web)

Phase 3: Agent 4 (Integration)
  └──→ Branch: feature/integration-tests
  └──→ PR → main (reviewed by 5 review agents)
  └──→ Merge to main
```

---

## 10. Verification Plan

After all agents complete and PRs are merged:

1. **Local Supabase**: `supabase start` → `supabase db reset` → verify schema + seed data
2. **Backend**: Run edge function tests, verify trigger creates violations, test SMS webhook with curl
3. **Mobile**: `flutter run` on iOS/Android simulator → login → record vehicle → verify offline → restore connectivity → verify sync
4. **Web**: `flutter run -d chrome` → admin login → create ranger → configure segment → view logs
5. **E2E**: Run all integration test scenarios against local Supabase
6. **Offline scenario**: Enable airplane mode on mobile device → record 3 vehicles → disable airplane mode → verify all sync within 60 seconds
7. **SMS scenario**: Block data (keep SMS) → record vehicle → verify SMS sent → verify server received via webhook
8. **Night mode**: Test in darkened room — verify theme readability, flash auto-enable, audio alerts
