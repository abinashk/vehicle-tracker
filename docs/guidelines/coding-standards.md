# Coding Standards

## Dart/Flutter Style

Follow the official [Effective Dart](https://dart.dev/effective-dart) style guide. The rules below are project-specific additions and clarifications.

---

## File Naming

All Dart files use `snake_case.dart`.

```
Good:
  vehicle_passage.dart
  speed_calculator.dart
  capture_screen.dart
  sync_queue_item.dart

Bad:
  VehiclePassage.dart
  speedCalculator.dart
  CaptureScreen.dart
```

---

## Import Ordering

Imports must be grouped in this order, separated by blank lines:

1. `dart:` standard library imports
2. `package:` third-party and local package imports
3. Relative imports (within the same package only)

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/shared.dart';

import '../widgets/plate_input_field.dart';
import 'capture_controller.dart';
```

**Rule:** Never use relative imports across package boundaries. Always use `package:` imports to reference code in a different package.

```dart
// Good: importing shared package from mobile app
import 'package:shared/shared.dart';

// Bad: relative import crossing package boundary
import '../../../packages/shared/lib/src/models/vehicle_passage.dart';
```

---

## Model Classes

Use **plain Dart classes** with hand-written `fromJson` / `toJson`. Do NOT use freezed, json_serializable, or any code generation for models.

```dart
class VehiclePassage {
  final String id;
  final String clientId;
  final String plateNumber;
  final String? plateNumberRaw;
  final VehicleType vehicleType;
  final String checkpostId;
  final String segmentId;
  final DateTime recordedAt;
  final String rangerId;
  final String? photoPath;
  final String source;

  const VehiclePassage({
    required this.id,
    required this.clientId,
    required this.plateNumber,
    this.plateNumberRaw,
    required this.vehicleType,
    required this.checkpostId,
    required this.segmentId,
    required this.recordedAt,
    required this.rangerId,
    this.photoPath,
    this.source = 'app',
  });

  factory VehiclePassage.fromJson(Map<String, dynamic> json) {
    return VehiclePassage(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      plateNumber: json['plate_number'] as String,
      plateNumberRaw: json['plate_number_raw'] as String?,
      vehicleType: VehicleType.fromString(json['vehicle_type'] as String),
      checkpostId: json['checkpost_id'] as String,
      segmentId: json['segment_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      rangerId: json['ranger_id'] as String,
      photoPath: json['photo_path'] as String?,
      source: json['source'] as String? ?? 'app',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'plate_number': plateNumber,
      'plate_number_raw': plateNumberRaw,
      'vehicle_type': vehicleType.value,
      'checkpost_id': checkpostId,
      'segment_id': segmentId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'ranger_id': rangerId,
      'photo_path': photoPath,
      'source': source,
    };
  }
}
```

**Rules:**
- Use `const` constructors where possible.
- JSON keys use `snake_case` (matching Supabase/PostgreSQL column names).
- Parse enums via a `fromString` factory, not by index.
- Nullable fields use `?` and handle `null` in fromJson.

---

## Enum Definitions

All enums are defined **once** in the `packages/shared` package. No duplicate enum definitions in mobile or web apps.

```dart
// packages/shared/lib/src/enums/vehicle_type.dart
enum VehicleType {
  car('car', 'CAR'),
  motorcycle('motorcycle', 'MCY'),
  bus('bus', 'BUS'),
  truck('truck', 'TRK'),
  other('other', 'OTH');

  final String value;
  final String smsCode;

  const VehicleType(this.value, this.smsCode);

  static VehicleType fromString(String value) {
    return VehicleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VehicleType.other,
    );
  }

  static VehicleType fromSmsCode(String code) {
    return VehicleType.values.firstWhere(
      (e) => e.smsCode == code,
      orElse: () => VehicleType.other,
    );
  }
}
```

---

## Riverpod Providers

Use **Riverpod code generation** with the `@riverpod` annotation. Do not write providers manually.

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'passage_list_controller.g.dart';

@riverpod
class PassageListController extends _$PassageListController {
  @override
  Future<List<VehiclePassage>> build() async {
    final repo = ref.watch(passageRepositoryProvider);
    return repo.getPassagesForCheckpost(checkpostId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncGuard(() => build());
  }
}
```

**Rules:**
- Always include the `part` directive for generated code.
- Use `AsyncValue` for all async state. Never use raw `Future` in provider state.
- Access providers via `ref.watch()` for reactive dependencies, `ref.read()` for one-time reads (e.g., in callbacks).

---

## Drift Tables

Define tables using the **Drift DSL**. Do not write raw SQL for table definitions.

```dart
class LocalPassages extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text().unique()();
  TextColumn get plateNumber => text()();
  TextColumn get plateNumberRaw => text().nullable()();
  TextColumn get vehicleType => text()();
  TextColumn get checkpostId => text()();
  TextColumn get segmentId => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get rangerId => text()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('app'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Error Handling

### Typed Exceptions

Never use a generic `catch (e)`. Always catch specific exception types.

```dart
// Good
try {
  await supabaseClient.from('vehicle_passages').insert(data);
} on PostgrestException catch (e) {
  if (e.code == '23505') {
    // Unique constraint violation (duplicate client_id) -- treat as success
    return;
  }
  throw PassageSyncException('Failed to sync passage: ${e.message}');
} on SocketException catch (_) {
  throw NoConnectivityException();
}

// Bad
try {
  await supabaseClient.from('vehicle_passages').insert(data);
} catch (e) {
  print(e); // Never do this
}
```

### Custom Exception Classes

Define typed exceptions for each domain area:

```dart
class PassageSyncException implements Exception {
  final String message;
  const PassageSyncException(this.message);
}

class NoConnectivityException implements Exception {}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);
}
```

---

## Repository Pattern

**No direct Supabase calls from UI code.** All data access goes through the repository layer.

```
UI (Screens/Widgets)
    |
    v
Providers (Riverpod)
    |
    v
Use Cases / Services (optional)
    |
    v
Repositories (mediate local <-> remote)
    |
    +---> Local Data Source (Drift DB)
    +---> Remote Data Source (Supabase client)
```

```dart
// Good: UI reads from provider which uses repository
final passages = ref.watch(passageListProvider);

// Bad: UI calls Supabase directly
final data = await Supabase.instance.client
    .from('vehicle_passages')
    .select();
```

---

## AsyncValue Usage

Use `AsyncValue` patterns in UI to handle loading, data, and error states:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final passagesAsync = ref.watch(passageListProvider);

  return passagesAsync.when(
    data: (passages) => PassageListView(passages: passages),
    loading: () => const PassageListSkeleton(),
    error: (error, stack) => ErrorDisplay(
      message: error.toString(),
      onRetry: () => ref.invalidate(passageListProvider),
    ),
  );
}
```

**Rule:** Never show a loading spinner waiting for a network call. If local data is available, show it immediately. See `offline-first.md`.

---

## Constants

Define constants in `packages/shared/lib/src/constants/`. Never use magic numbers or strings.

```dart
// Good
if (syncItem.attempts >= AppConstants.maxSyncRetries) {
  triggerSmsFallback(syncItem);
}

// Bad
if (syncItem.attempts >= 5) {
  triggerSmsFallback(syncItem);
}
```

---

## Formatting

- Run `dart format` before committing. All code must be formatted.
- Maximum line length: 80 characters (Dart default).
- Use trailing commas for better diffs and auto-formatting.

---

## Documentation

- Public APIs in the shared package must have dartdoc comments (`///`).
- Private implementation details do not need docs if the code is self-explanatory.
- Do not write comments that restate the code. Comments should explain *why*, not *what*.

```dart
/// Normalizes a Nepali license plate string to Latin characters.
///
/// Transliterates Devanagari digits and province codes to their
/// English equivalents. Returns the plate in uppercase without spaces.
///
/// Example: "बा १ प १२३४" -> "BA1PA1234"
String normalize(String rawPlate) {
  // ...
}
```
