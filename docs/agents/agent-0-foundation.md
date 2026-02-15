# Agent 0: Foundation

## Objective

Set up monorepo, shared package, database schema, CI/CD, architecture docs, and all 8 guidelines docs. This agent runs first (sequential) -- all other agents depend on its output being merged to `main`.

## Branch

`foundation/setup`

---

## Owned Files

| Area | Files |
|------|-------|
| Monorepo config | `/melos.yaml`, `/analysis_options.yaml`, `/.gitignore`, `/README.md` |
| Shared package | `/packages/shared/` -- all models, enums, constants, utils |
| Database | `/supabase/config.toml`, `/supabase/seed.sql`, `/supabase/migrations/*` |
| CI/CD | `/.github/workflows/*` |
| Guidelines | `/docs/guidelines/*` (all 8 guidelines docs) |
| Architecture | `/docs/architecture/*` |
| Agent objectives | `/docs/agents/*` (all 5 agent objective docs) |
| App stubs | `/apps/mobile/pubspec.yaml`, `/apps/web/pubspec.yaml` (just enough for `melos bootstrap`) |

### Shared Package Structure

```
packages/shared/
  pubspec.yaml
  lib/
    shared.dart                      # Barrel export
    src/
      models/
        park.dart
        highway_segment.dart
        checkpost.dart
        user_profile.dart
        vehicle_passage.dart
        violation.dart
        violation_outcome.dart
        sync_queue_item.dart
      enums/
        vehicle_type.dart
        violation_type.dart
        sync_status.dart
        user_role.dart
        outcome_type.dart
      constants/
        app_constants.dart
        sms_format.dart
        plate_regex.dart
        api_constants.dart
      utils/
        plate_normalizer.dart
        speed_calculator.dart
        sms_encoder.dart
        sms_decoder.dart
  test/
    models/
    utils/
```

### SQL Migration Files

```
supabase/migrations/
  00001_create_parks.sql
  00002_create_highway_segments.sql
  00003_create_checkposts.sql
  00004_create_user_profiles.sql
  00005_create_vehicle_passages.sql
  00006_create_violations.sql
  00007_create_violation_outcomes.sql
  00008_create_proactive_overstay_alerts.sql
  00009_create_sync_metadata.sql
  00010_create_indexes.sql
  00011_create_rls_policies.sql
  00012_create_functions.sql
```

---

## Key Deliverables

### 1. PlateNormalizer.normalize(raw)

Devanagari to Latin transliteration for Nepali vehicle plates. Takes raw OCR text and returns a normalized English transliteration of the plate number.

### 2. SpeedCalculator.check(distance, travelTime, maxSpeed, minSpeed)

Returns `{violationType?, speed, threshold}`. Determines if a given travel time over a distance constitutes a speeding or overstay violation.

### 3. SmsEncoder.encode() / SmsDecoder.decode()

Compact SMS format V1: `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`

Example: `V1|BNP-A|BA1PA1234|CAR|1709123456|9801`

### 4. All 12 SQL Migration Files

Complete database schema as defined in the implementation plan Section 3. Includes:
- `parks`, `highway_segments`, `checkposts`, `user_profiles`
- `vehicle_passages` (core high-volume table with idempotency via `client_id`)
- `violations`, `violation_outcomes`, `proactive_overstay_alerts`
- `sync_metadata`
- Indexes (matching lookup, checkpost listing, partial index for unmatched entries)
- RLS policy scaffolding
- Database functions

### 5. Seed Data

Banke National Park pilot data:
- 1 park (Banke National Park)
- 1 highway segment
- 2 checkposts

### 6. All 8 Guidelines Docs

| Doc | Purpose |
|-----|---------|
| `pr-creation.md` | Branch naming, commit message format, PR description template |
| `pr-review.md` | Review checklist, approval criteria, findings handling |
| `testing.md` | Unit/widget/integration test requirements, coverage targets, mocking |
| `coding-standards.md` | Dart/Flutter style, file naming, imports, error handling |
| `api-contracts.md` | Supabase table/function contracts, SMS format spec |
| `offline-first.md` | Write-local-first rule, sync queue patterns, conflict resolution |
| `security.md` | Auth, RLS, secrets, input validation, CORS |
| `git-workflow.md` | Branch strategy, PR flow, agent coordination, merge order |

---

## Acceptance Criteria

1. **`melos bootstrap` succeeds** -- monorepo properly configured, all packages resolve.
2. **`dart analyze packages/shared` -- zero issues** -- all shared code compiles and passes static analysis.
3. **`dart test packages/shared` -- all pass** -- tests for PlateNormalizer, SpeedCalculator, SmsEncoder, SmsDecoder all green.
4. **`supabase db reset` applies all migrations + seed without error** -- database schema is valid and seed data loads cleanly.

---

## Dependencies

None. This agent runs first.

---

## Notes

- Models use plain Dart classes with hand-written `fromJson`/`toJson` (no freezed, no build_runner).
- Riverpod v2 with code generation is the state management approach.
- Drift v2 for local SQLite (type-safe, compile-time query safety).
- Auth uses Supabase Auth with email-format usernames (e.g., `ranger1@bnp.local`). The app auto-appends `@bnp.local` to whatever the ranger types.
- App stubs only need enough structure for `melos bootstrap` to succeed -- just `pubspec.yaml` with dependencies declared.
