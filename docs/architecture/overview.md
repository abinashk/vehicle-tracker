# Architecture Overview

## Purpose

This document provides a high-level view of the National Park Vehicle Speed Monitoring System. The system uses time-based speed detection: two checkposts at each end of a highway segment record vehicle entry/exit, and if travel time falls outside thresholds (too fast = speeding, too slow = potential poaching), rangers are alerted.

For full implementation details, see `/docs/architecture/implementation-plan.md`.

---

## System Diagram

```
                          ┌─────────────────────────────────────┐
                          │          SUPABASE BACKEND           │
                          │                                     │
                          │  ┌──────────┐  ┌────────────────┐  │
                          │  │PostgreSQL │  │  Edge Functions │  │
                          │  │          │  │                │  │
                          │  │ Tables    │  │ sms-webhook    │  │
  ┌──────────────┐        │  │ RLS       │  │ check-overstay │  │        ┌──────────────┐
  │              │        │  │ Triggers  │  │ match-passage  │  │        │              │
  │  MOBILE APP  │◄──────►│  │ Generated │  │ create-ranger  │  │◄──────►│ WEB DASHBOARD│
  │  (Rangers)   │  REST  │  │ Columns   │  └────────────────┘  │  REST  │  (Admins)    │
  │              │  API   │  └──────────┘                       │  API   │              │
  └──────┬───────┘        │                                     │        └──────────────┘
         │                │  ┌──────────┐  ┌────────────────┐  │
         │                │  │ Realtime │  │    Storage      │  │
         │                │  │          │  │  (Photos)       │  │
         │                │  └──────────┘  └────────────────┘  │
         │                │                                     │
         │                └──────────┬──────────────────────────┘
         │                           │
         │ SMS (fallback)            │ Webhook
         │                           │
         ▼                           ▼
  ┌──────────────┐          ┌──────────────┐
  │  SMS Gateway │─────────►│   Twilio     │
  │  (Device)    │          │   Webhook    │
  └──────────────┘          └──────────────┘
```

---

## Components

### Mobile App (Rangers)

**Technology:** Flutter (iOS + Android)

The primary operational interface used by park rangers at checkposts. Rangers photograph vehicles, the app extracts plate numbers via OCR, and records are stored locally then synced to the server.

**Key capabilities:**
- On-device OCR (Google ML Kit) for plate number extraction
- Offline-first architecture with local Drift (SQLite) database
- Automatic sync engine (30-second timer + connectivity-triggered)
- Local matching service for immediate violation alerts
- SMS fallback when extended offline (>5 minutes)
- Dark theme optimized for outdoor/night use
- Audio alerts for violations

**Connectivity graceful degradation:**
1. Full online -- sync immediately, pull remote data
2. Core offline -- store locally, match against cached data, sync when back
3. SMS last resort -- send compact passage data via SMS to gateway

### Web Dashboard (Admins)

**Technology:** Flutter Web

The administrative interface for park management. Admins manage rangers, configure highway segment thresholds, view passage and violation logs, and monitor real-time system activity.

**Key capabilities:**
- Ranger account CRUD (create, edit, toggle active)
- Highway segment configuration (distance, speed limits, auto-calculated thresholds)
- Paginated and filterable passage/violation logs
- CSV export for violation reports
- Real-time dashboard with live violation and alert updates
- Unmatched entry management

### Supabase Backend

**Technology:** Supabase (PostgreSQL, Auth, Edge Functions, Realtime, Storage)

The entire backend runs on Supabase's managed infrastructure, keeping costs within the $5K budget constraint via the free tier.

**Sub-components:**

| Component | Purpose |
|-----------|---------|
| **PostgreSQL** | Primary data store with RLS, triggers, generated columns |
| **Auth** | Email-format authentication (`ranger1@bnp.local`) |
| **Edge Functions** | SMS webhook, overstay cron, passage matching, ranger creation |
| **Realtime** | Live dashboard updates for violations and alerts |
| **Storage** | Vehicle passage photos (2MB limit, JPEG/PNG) |

**Key database features:**
- Row Level Security (RLS) on all tables -- rangers see only their segment, admins see all
- `fn_auto_match_passage()` trigger -- automatically matches entry/exit passages and creates violations
- Generated columns for `min_travel_time_minutes` and `max_travel_time_minutes`
- `client_id` UNIQUE constraint for idempotent sync
- `SELECT ... FOR UPDATE` to prevent double-matching race conditions

### SMS Gateway (Twilio)

**Technology:** Twilio (inbound SMS webhook)

Fallback communication channel when mobile data is unavailable. Rangers' devices send compact passage data via SMS. Twilio receives the SMS and forwards it to the Supabase Edge Function via webhook.

**V1 compact format:** `V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>`

For full SMS protocol details, see `/docs/architecture/sms-protocol.md`.

---

## Data Flow

### Recording a Vehicle (Online)

```
1. Ranger taps "RECORD VEHICLE"
2. Camera captures vehicle photo
3. Google ML Kit OCR extracts plate number
4. Ranger confirms/edits plate, selects vehicle type, taps "SUBMIT"
5. Passage saved to local Drift DB (immediate)
6. Sync queue item created (status: pending)
7. Sync engine pushes to Supabase REST API (within 30 seconds)
8. Server-side trigger fn_auto_match_passage() fires
9. If matching entry/exit found:
   a. Both passages linked (matched_passage_id)
   b. Travel time calculated
   c. If outside thresholds → violation record created
10. Mobile app pulls updated data on next sync cycle
```

### Recording a Vehicle (Offline)

```
1-6. Same as online flow (all local)
7. Sync engine detects no connectivity -- keeps items as "pending"
8. After 5+ minutes offline with pending items → SMS fallback triggers
9. Device sends V1 format SMS to Twilio number
10. Twilio webhook POSTs to Supabase Edge Function
11. Edge Function parses SMS, inserts passage with source='sms'
12. Server trigger fires (matching, violations)
13. When connectivity returns:
    a. Sync engine pushes original passage
    b. Server returns 409 (duplicate, client_id already exists)
    c. Sync engine treats 409 as success
```

### Violation Detection

```
Entry passage at Checkpost A → recorded_at = T1
Exit passage at Checkpost B  → recorded_at = T2

travel_time = T2 - T1

If travel_time < min_travel_time (distance / max_speed * 60):
  → SPEEDING violation

If travel_time > max_travel_time (distance / min_speed * 60):
  → OVERSTAY violation (potential poaching concern)

If min_travel_time ≤ travel_time ≤ max_travel_time:
  → Normal passage, no violation
```

---

## Tech Stack Summary

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
| Auth | Supabase Auth with email-format usernames | App auto-appends domain; rangers just type username |

---

## Related Documents

- `/docs/architecture/implementation-plan.md` -- Full implementation plan with agent decomposition
- `/docs/architecture/database-schema.md` -- Complete database schema documentation
- `/docs/architecture/offline-sync.md` -- Offline sync architecture details
- `/docs/architecture/sms-protocol.md` -- SMS compact format specification
- `/docs/agents/` -- Individual agent objective documents
