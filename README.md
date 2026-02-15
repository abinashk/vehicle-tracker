# Vehicle Tracker

National Park Vehicle Speed Monitoring System for Nepal.

Time-based speed detection system using two checkposts at each end of highway segments passing through national parks. Records vehicle entry/exit times via license plate OCR and alerts rangers when vehicles are speeding or overstaying.

## Pilot

**Banke National Park** - 1 highway segment, 2 checkposts, ~500-2000 vehicles/day.

## Architecture

| Component | Technology |
|-----------|-----------|
| Mobile App | Flutter (iOS + Android) |
| Web Dashboard | Flutter Web |
| Backend | Supabase (PostgreSQL, Auth, Edge Functions, Realtime, Storage) |
| OCR | Google ML Kit Text Recognition (on-device) |
| State Management | Riverpod v2 |
| Local DB | Drift (SQLite) |

## Project Structure

```
vehicle-tracker/
├── packages/shared/     # Shared Dart models, enums, constants, utils
├── apps/mobile/         # Ranger mobile app (Flutter)
├── apps/web/            # Admin dashboard (Flutter Web)
├── supabase/            # Backend: migrations, edge functions, seed data
├── tests/e2e/           # Integration tests
└── docs/                # Requirements, architecture, guidelines
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.16.0
- Dart SDK >= 3.2.0
- Supabase CLI
- Melos (`dart pub global activate melos`)

### Setup

```bash
# Install dependencies across all packages
melos bootstrap

# Start local Supabase
supabase start

# Apply migrations and seed data
supabase db reset

# Run the mobile app
cd apps/mobile && flutter run

# Run the web dashboard
cd apps/web && flutter run -d chrome
```

### Testing

```bash
# Run all tests
melos run test

# Run shared package tests only
cd packages/shared && dart test

# Run analyze across all packages
melos run analyze
```

## Documentation

- [Requirements](docs/requirements/requirements.md) - Finalized requirements specification
- [Implementation Plan](docs/architecture/implementation-plan.md) - Architecture and agent decomposition
- [Guidelines](docs/guidelines/) - PR creation, review, testing, coding standards, etc.

## License

Proprietary - Banke National Park Authority
