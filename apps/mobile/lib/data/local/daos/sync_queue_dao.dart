import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_queue.dart';

part 'sync_queue_dao.g.dart';

/// Data access object for the sync queue.
///
/// Implements the sync state machine transitions:
/// pending -> in_flight -> synced (or failed after 5 attempts).
@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Insert a new sync queue item with pending status.
  Future<void> enqueue(SyncQueueCompanion item) {
    return into(syncQueue).insert(item);
  }

  /// Get all pending items ordered by creation time (FIFO).
  Future<List<SyncQueueData>> getPendingItems() {
    return (select(syncQueue)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// Watch the count of pending items.
  Stream<int> watchPendingCount() {
    final query = selectOnly(syncQueue)
      ..addColumns([syncQueue.id.count()])
      ..where(syncQueue.status.equals('pending'));
    return query
        .map((row) => row.read(syncQueue.id.count()) ?? 0)
        .watchSingle();
  }

  /// Transition an item to in_flight status.
  Future<void> markInFlight(String passageClientId) {
    return (update(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .write(
      SyncQueueCompanion(
        status: const Value('in_flight'),
        lastAttemptAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Transition an item to synced status (success).
  Future<void> markSynced(String passageClientId) {
    return (update(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .write(
      const SyncQueueCompanion(
        status: Value('synced'),
      ),
    );
  }

  /// Transition back to pending with incremented attempt count.
  Future<void> markRetry(String passageClientId, int currentAttempts) {
    return (update(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .write(
      SyncQueueCompanion(
        status: const Value('pending'),
        attempts: Value(currentAttempts + 1),
        lastAttemptAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Transition to failed status (after max attempts).
  Future<void> markFailed(String passageClientId) {
    return (update(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .write(
      const SyncQueueCompanion(
        status: Value('failed'),
      ),
    );
  }

  /// Mark SMS as sent for an item.
  Future<void> markSmsSent(String passageClientId) {
    return (update(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .write(
      const SyncQueueCompanion(
        smsSent: Value(true),
      ),
    );
  }

  /// Get failed items that have not had SMS sent.
  Future<List<SyncQueueData>> getFailedWithoutSms() {
    return (select(syncQueue)
          ..where((t) => t.status.equals('failed') & t.smsSent.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// Get pending items older than the given duration that have not had SMS sent.
  ///
  /// Used by the SMS fallback to find items eligible for SMS transmission.
  Future<List<SyncQueueData>> getPendingOlderThan(Duration age) {
    final cutoff = DateTime.now().toUtc().subtract(age);
    return (select(syncQueue)
          ..where((t) =>
              t.status.equals('pending') &
              t.smsSent.equals(false) &
              t.createdAt.isSmallerThanValue(cutoff))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// Get a sync queue item by passage client ID.
  Future<SyncQueueData?> getByPassageClientId(String passageClientId) {
    return (select(syncQueue)
          ..where((t) => t.passageClientId.equals(passageClientId)))
        .getSingleOrNull();
  }

  /// Watch all queue items.
  Stream<List<SyncQueueData>> watchAll() {
    return (select(syncQueue)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Get last successful sync time.
  Future<DateTime?> getLastSyncTime() async {
    final result = await (select(syncQueue)
          ..where((t) => t.status.equals('synced'))
          ..orderBy([
            (t) => OrderingTerm.desc(t.lastAttemptAt),
          ])
          ..limit(1))
        .getSingleOrNull();
    return result?.lastAttemptAt;
  }
}
