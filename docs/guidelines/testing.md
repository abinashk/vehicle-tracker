# Testing Guidelines

## Test Requirements by Type

### Unit Tests

**Required for:** All business logic -- models, utils, services, repositories, use cases.

**Location:** Co-located in the package's `test/` directory mirroring the `lib/src/` structure.

```
packages/shared/
  lib/src/models/vehicle_passage.dart
  test/models/vehicle_passage_test.dart

packages/shared/
  lib/src/utils/speed_calculator.dart
  test/utils/speed_calculator_test.dart

apps/mobile/
  lib/domain/usecases/record_passage.dart
  test/domain/usecases/record_passage_test.dart
```

**Coverage rule:** Every public method must have at least one test. No exceptions.

### Widget Tests

**Required for:** All screens and reusable widgets.

**Location:** In the app's `test/` directory mirroring the screen structure.

```
apps/mobile/
  lib/presentation/screens/capture/capture_screen.dart
  test/presentation/screens/capture/capture_screen_test.dart
```

**What to test:**
- Widget renders without errors
- Key UI elements are present (buttons, text fields, labels)
- User interactions trigger expected behavior (tap, input, navigation)
- Error states display correctly
- Loading states display correctly (local data shown, not spinners waiting for network)

### Integration Tests

**Required for:** Critical end-to-end paths.

**Location:** `/tests/e2e/`

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
```

---

## Test Naming

Use descriptive names that state the expected behavior and condition:

```dart
test('should return SPEEDING violation when travel time is below minimum threshold', () {
  // ...
});

test('should normalize Devanagari plate to Latin transliteration', () {
  // ...
});

test('should fallback to local data when Supabase is unreachable', () {
  // ...
});

test('should not create duplicate violation when matching is retried', () {
  // ...
});
```

**Format:** `test('should [expected behavior] when [condition]')`

For group descriptions, use the class or feature name:

```dart
group('SpeedCalculator', () {
  group('check()', () {
    test('should return SPEEDING violation when travel time is below minimum threshold', () {
      // ...
    });

    test('should return null when travel time is within thresholds', () {
      // ...
    });
  });
});
```

---

## Test Pattern: Arrange-Act-Assert

Every test must follow the AAA pattern with clear separation:

```dart
test('should return SPEEDING violation when travel time is below minimum threshold', () {
  // Arrange
  final calculator = SpeedCalculator();
  final distanceKm = 20.0;
  final travelTimeMinutes = 10.0; // Too fast
  final maxSpeedKmh = 40.0;
  final minSpeedKmh = 15.0;

  // Act
  final result = calculator.check(
    distanceKm: distanceKm,
    travelTimeMinutes: travelTimeMinutes,
    maxSpeedKmh: maxSpeedKmh,
    minSpeedKmh: minSpeedKmh,
  );

  // Assert
  expect(result.violationType, ViolationType.speeding);
  expect(result.calculatedSpeedKmh, 120.0);
});
```

Rules:
- Use `// Arrange`, `// Act`, `// Assert` comments to mark sections.
- One logical action per test. If you need multiple acts, split into multiple tests.
- Assertions should be specific. Prefer `expect(result.speed, 120.0)` over `expect(result, isNotNull)`.

---

## Mocking External Dependencies

Never call real external services in unit or widget tests. Mock these dependencies:

| Dependency | Mock Strategy |
|-----------|---------------|
| Supabase client | Mock the repository layer. Never mock Supabase client directly in UI tests. |
| Drift database | Use in-memory Drift database (`NativeDatabase.memory()`) for repository tests. |
| Camera | Mock `CameraController`. Provide fake image bytes. |
| Google ML Kit OCR | Mock `TextRecognizer`. Return predetermined `RecognizedText`. |
| SMS sending | Mock `SmsService`. Verify `encode()` output without sending. |
| Connectivity | Mock `ConnectivityService`. Simulate online/offline states. |
| HTTP calls | Mock at repository boundary, not at HTTP client level. |
| File system | Use `MemoryFileSystem` from `package:file`. |

### Example: Mocking a Repository

```dart
class MockPassageRepository extends Mock implements PassageRepository {}

test('should save passage to local DB when recording', () {
  // Arrange
  final mockRepo = MockPassageRepository();
  when(() => mockRepo.saveLocal(any())).thenAnswer((_) async => passage);
  final useCase = RecordPassage(passageRepository: mockRepo);

  // Act
  await useCase.execute(passageData);

  // Assert
  verify(() => mockRepo.saveLocal(any())).called(1);
  verify(() => mockRepo.addToSyncQueue(any())).called(1);
});
```

---

## What NOT to Test

- Generated code (Drift `.g.dart`, Riverpod `.g.dart`)
- Third-party package internals
- Dart SDK / Flutter framework behavior
- Pure UI layout (pixel-perfect positioning)

---

## Test Execution

```bash
# Run all tests in shared package
dart test packages/shared

# Run all tests in mobile app
flutter test apps/mobile

# Run all tests in web app
flutter test apps/web

# Run integration tests (requires local Supabase running)
dart test tests/e2e

# Run with coverage
flutter test --coverage apps/mobile
```

---

## Test Data

- Use factory functions or test fixtures, not raw constructors scattered across tests.
- Keep test data realistic (use Nepali plate numbers like `BA1PA1234`, actual checkpost codes like `BNP-A`).
- Clean up test state between tests. No test should depend on another test's side effects.
- Integration tests must start with a clean database state per test.

---

## Failing Tests

- A PR with any failing test will not be merged.
- Do not skip tests with `skip:` without a documented reason and linked issue.
- Flaky tests must be fixed immediately, not ignored.
