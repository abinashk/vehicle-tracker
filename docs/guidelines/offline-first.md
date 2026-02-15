# Offline-First Design Guidelines

## Core Rules

These rules are non-negotiable. Every agent writing client-side code must follow them.

### Rule 1: Every Write Goes to Local Drift DB First, Then Sync Queue

When a ranger records a vehicle passage, the data flow is:

```
User Action -> Drift local_passages (INSERT) -> Drift sync_queue (pending) -> Done
```

The user sees a success confirmation immediately. The sync to Supabase happens in the background. The user never waits for a network call to complete a write.

```dart
// Good: write locally, queue for sync
Future<void> recordPassage(PassageData data) async {
  final passage = VehiclePassage(
    id: uuid.v4(),
    clientId: data.clientId, // Generated once at capture time
    // ... other fields
  );
  await driftDb.localPassages.insertOne(passage.toCompanion());
  await driftDb.syncQueue.insertOne(SyncQueueCompanion(
    id: Value(uuid.v4()),
    entityType: const Value('passage'),
    entityId: Value(passage.id),
    status: const Value('pending'),
    createdAt: Value(DateTime.now()),
  ));
}

// Bad: calling Supabase directly from a use case or UI
Future<void> recordPassage(PassageData data) async {
  await supabaseClient.from('vehicle_passages').insert(data.toJson()); // WRONG
}
```

### Rule 2: Never Write Directly to Supabase from UI

All Supabase writes go through the **sync engine**, which runs in the background. The UI layer never calls Supabase insert/update/delete directly.

The only exception is the web dashboard (Agent 3), which operates in an always-online context. Even there, writes go through the repository layer, never raw Supabase calls from widgets.

### Rule 3: Every Read Falls Back to Local Data if Supabase is Unreachable

```dart
// Good: try remote, fall back to local
Future<List<VehiclePassage>> getUnmatchedPassages(String segmentId) async {
  try {
    final remote = await remoteDataSource.fetchUnmatched(segmentId);
    await localDataSource.cachePassages(remote); // Update local cache
    return remote;
  } on SocketException catch (_) {
    return localDataSource.getUnmatchedPassages(segmentId); // Local fallback
  } on TimeoutException catch (_) {
    return localDataSource.getUnmatchedPassages(segmentId); // Local fallback
  }
}

// Bad: letting the exception propagate to UI with no fallback
Future<List<VehiclePassage>> getUnmatchedPassages(String segmentId) async {
  return await remoteDataSource.fetchUnmatched(segmentId); // WRONG: no fallback
}
```

### Rule 4: No Loading Spinners Waiting for Network

Never show a loading spinner that blocks the UI while waiting for a network response. If local data exists, display it immediately. If a background fetch updates the data, refresh the UI reactively.

```dart
// Good: show local data, refresh in background
@riverpod
class PassageList extends _$PassageList {
  @override
  Future<List<VehiclePassage>> build() async {
    // Return local data immediately
    final local = await ref.read(passageRepositoryProvider).getLocalPassages();

    // Trigger background refresh (non-blocking)
    _refreshFromRemote();

    return local;
  }

  Future<void> _refreshFromRemote() async {
    try {
      final remote = await ref.read(passageRepositoryProvider).fetchAndCache();
      state = AsyncValue.data(remote);
    } catch (_) {
      // Keep showing local data, don't show error
    }
  }
}
```

---

## Sync Queue Pattern

### States

```
pending -> in_flight -> synced       (success path)
pending -> in_flight -> pending      (failure, retry with attempts++)
pending -> in_flight -> failed       (after 5 attempts, triggers SMS fallback)
```

### Sync Queue Table (Drift)

| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (UUID) | Primary key |
| entity_type | TEXT | `'passage'`, `'violation_outcome'`, `'photo'` |
| entity_id | TEXT (UUID) | ID of the entity to sync |
| status | TEXT | `'pending'`, `'in_flight'`, `'synced'`, `'failed'` |
| attempts | INTEGER | Number of sync attempts (starts at 0) |
| last_attempted_at | DATETIME | Last attempt timestamp |
| error_message | TEXT | Last error (nullable) |
| created_at | DATETIME | Queue insertion time |

### Processing Rules

1. **FIFO order.** Process sync queue items in `created_at` order.
2. **One at a time.** Do not process the next item until the current one completes or fails.
3. **Mark in_flight** before attempting the HTTP call. If the app crashes mid-sync, in_flight items are reset to pending on next startup.
4. **Handle 409** as success. A conflict on `client_id` means the server already has this passage.
5. **Increment attempts** on failure. After 5 failed attempts, mark as `failed`.
6. **Never regenerate client_id.** The same `client_id` must be used across all retry attempts to ensure idempotency.

---

## Sync Engine

The sync engine is a background service that runs continuously while the app is open.

### Triggers

1. **Timer:** Every 30 seconds, check for pending sync items.
2. **Connectivity change:** When connectivity transitions from offline to online, immediately trigger a sync cycle.
3. **Manual:** User can pull-to-refresh on the home screen to trigger sync.

### Sync Cycle

A single sync cycle does three things in order:

1. **Outbound push:** Process pending sync queue items (passages, outcomes).
2. **Inbound pull:** Fetch unmatched passages from the opposite checkpost and cache locally.
3. **Photo upload:** Upload any pending photos (non-blocking, lower priority).

### Connectivity Detection

Use `connectivity_plus` to monitor network state. The sync engine should:
- Pause when offline (no wasted attempts).
- Resume immediately when connectivity returns.
- Not rely solely on `connectivity_plus` -- also handle HTTP timeouts as implicit offline signals.

---

## SMS Fallback

### When SMS Triggers

SMS fallback activates when ALL of these conditions are true:

1. No data connectivity for 5 minutes or more.
2. Sync queue has items in `pending` or `failed` status.
3. SMS has not already been sent for those specific items.

### What SMS Contains

Each SMS contains one passage record in V1 compact format:

```
V1|BNP-A|BA1PA1234|CAR|1709123456|9801
```

See `api-contracts.md` for the full format specification.

### SMS Flow

```
Sync queue item pending + no connectivity for 5 min
    |
    v
SmsService.sendFallback(passage)
    |
    v
SmsEncoder.encode(passage) -> "V1|BNP-A|BA1PA1234|CAR|1709123456|9801"
    |
    v
Send SMS to Twilio number
    |
    v
Mark sync queue item with sms_sent = true
    |
    v
Server receives SMS via webhook -> inserts passage with source='sms'
```

### Rules

- **Do not send SMS too eagerly.** 5 minutes is the minimum wait. This prevents unnecessary SMS costs during brief connectivity drops.
- **Do not send duplicate SMS.** Track which items have had SMS sent.
- **SMS is a last resort.** The sync engine should continue trying HTTP sync even after SMS is sent. If HTTP sync eventually succeeds, both the app record and the SMS record will have the same `client_id`, so the server deduplicates automatically.

---

## Client ID (Idempotency Key)

### Generation

The `client_id` is a UUID generated **once** at the moment the ranger taps the camera shutter. It is assigned to the passage record and never changes.

```dart
// Good: generate once at capture time
final clientId = uuid.v4(); // Generated here, stored forever

// Bad: regenerating on retry
Future<void> syncPassage(Passage p) async {
  p.clientId = uuid.v4(); // WRONG: breaks idempotency
  await supabase.from('vehicle_passages').insert(p.toJson());
}
```

### Purpose

The `client_id` ensures that:
- Retried HTTP requests do not create duplicate passages.
- SMS-originated passages and later HTTP-synced passages are recognized as the same record.
- The server can safely use `ON CONFLICT (client_id) DO NOTHING`.

---

## Photo Upload

Photo upload is **non-blocking**. It runs independently from the passage sync.

### Flow

1. Passage is recorded and synced (or queued for sync).
2. Photo is added to a separate upload queue.
3. Photo uploads happen in the background, after passage sync.
4. If upload succeeds, the `photo_path` field on the passage is updated (both locally and remotely).
5. If upload fails, the passage remains valid without the photo. The photo can be retried later.

### Rules

- Never block passage recording on photo upload.
- Never block the UI on photo upload.
- Photos are compressed to JPEG before upload (2MB max).
- If the photo fails to upload after 3 attempts, log the failure but do not trigger SMS for photos.

---

## Graceful Degradation

The app operates in three tiers:

| Tier | Connectivity | Available Features |
|------|-------------|-------------------|
| **Full Online** | Data connectivity available | All features: sync, remote matching, photo upload, realtime alerts |
| **Core Offline** | No data connectivity | Record passages, local matching against cached data, local violation alerts, queue for sync |
| **SMS Last Resort** | No data, SMS only | Record passages, send via SMS for server-side processing |

The UI must always show the current connectivity state via a persistent indicator. The user should never be surprised by which tier they are operating in.
