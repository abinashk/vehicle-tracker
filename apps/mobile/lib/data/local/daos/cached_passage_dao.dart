import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/cached_remote_passages.dart';

part 'cached_passage_dao.g.dart';

/// Data access object for cached remote passages.
///
/// Manages the local cache of entries from the opposite checkpost,
/// used by the matching service for offline violation detection.
@DriftAccessor(tables: [CachedRemotePassages])
class CachedPassageDao extends DatabaseAccessor<AppDatabase>
    with _$CachedPassageDaoMixin {
  CachedPassageDao(super.db);

  /// Upsert a batch of remote passages into the cache.
  ///
  /// Uses insertOnConflictUpdate to handle duplicates gracefully.
  Future<void> upsertPassages(
      List<CachedRemotePassagesCompanion> passages) async {
    await batch((b) {
      for (final passage in passages) {
        b.insert(cachedRemotePassages, passage,
            onConflict: DoUpdate((_) => passage));
      }
    });
  }

  /// Find unmatched cached entries for a specific plate, segment, and
  /// different checkpost (opposite checkpost matching).
  Future<List<CachedRemotePassage>> findMatchCandidates({
    required String plateNumber,
    required String segmentId,
    required String excludeCheckpostId,
  }) {
    return (select(cachedRemotePassages)
          ..where((t) =>
              t.plateNumber.equals(plateNumber) &
              t.segmentId.equals(segmentId) &
              t.checkpostId.isNotValue(excludeCheckpostId) &
              t.matchedPassageId.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .get();
  }

  /// Mark a cached passage as matched.
  Future<void> markAsMatched(String id, String matchedPassageId) {
    return (update(cachedRemotePassages)..where((t) => t.id.equals(id))).write(
      CachedRemotePassagesCompanion(matchedPassageId: Value(matchedPassageId)),
    );
  }

  /// Delete cached entries older than the given cutoff.
  Future<int> deleteOlderThan(DateTime cutoff) {
    return (delete(cachedRemotePassages)
          ..where((t) => t.recordedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Get all cached entries for a segment.
  Future<List<CachedRemotePassage>> getCachedForSegment(String segmentId) {
    return (select(cachedRemotePassages)
          ..where((t) => t.segmentId.equals(segmentId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .get();
  }
}
