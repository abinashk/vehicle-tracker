import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/local_passages.dart';

part 'passage_dao.g.dart';

/// Data access object for local passages.
///
/// Provides CRUD operations and reactive watch queries for
/// the local_passages Drift table.
@DriftAccessor(tables: [LocalPassages])
class PassageDao extends DatabaseAccessor<AppDatabase> with _$PassageDaoMixin {
  PassageDao(super.db);

  /// Insert a new passage into the local database.
  Future<void> insertPassage(LocalPassagesCompanion passage) {
    return into(localPassages).insert(passage);
  }

  /// Get a passage by its ID.
  Future<LocalPassage?> getPassageById(String id) {
    return (select(localPassages)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a passage by its client ID.
  Future<LocalPassage?> getPassageByClientId(String clientId) {
    return (select(localPassages)..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  /// Watch all passages for a given checkpost, ordered by recorded_at descending.
  Stream<List<LocalPassage>> watchPassagesForCheckpost(String checkpostId) {
    return (select(localPassages)
          ..where((t) => t.checkpostId.equals(checkpostId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .watch();
  }

  /// Get today's passages for a checkpost.
  Future<List<LocalPassage>> getTodaysPassages(String checkpostId) {
    final todayStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );
    return (select(localPassages)
          ..where((t) =>
              t.checkpostId.equals(checkpostId) &
              t.recordedAt.isBiggerOrEqualValue(todayStart),)
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ]))
        .get();
  }

  /// Count today's passages for a checkpost.
  Future<int> countTodaysPassages(String checkpostId) async {
    final passages = await getTodaysPassages(checkpostId);
    return passages.length;
  }

  /// Search passages by plate number.
  Stream<List<LocalPassage>> watchPassagesByPlate(String plateQuery) {
    return (select(localPassages)
          ..where((t) => t.plateNumber.like('%$plateQuery%'))
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ])
          ..limit(100))
        .watch();
  }

  /// Update photo path after upload.
  Future<void> updatePhotoPath(String id, String photoPath) {
    return (update(localPassages)..where((t) => t.id.equals(id))).write(
      LocalPassagesCompanion(photoPath: Value(photoPath)),
    );
  }

  /// Update matched passage ID.
  Future<void> updateMatchedPassageId(String id, String matchedPassageId) {
    return (update(localPassages)..where((t) => t.id.equals(id))).write(
      LocalPassagesCompanion(matchedPassageId: Value(matchedPassageId)),
    );
  }

  /// Get all unmatched passages for the given segment and checkpost.
  Future<List<LocalPassage>> getUnmatchedPassages(
    String segmentId,
    String checkpostId,
  ) {
    return (select(localPassages)
          ..where((t) =>
              t.segmentId.equals(segmentId) &
              t.checkpostId.equals(checkpostId) &
              t.matchedPassageId.isNull(),))
        .get();
  }

  /// Get passages with local photos that haven't been uploaded yet.
  Future<List<LocalPassage>> getPassagesWithPendingPhotos() {
    return (select(localPassages)
          ..where(
              (t) => t.photoLocalPath.isNotNull() & t.photoPath.isNull(),)
          ..limit(20))
        .get();
  }

  /// Get recent passages (last N entries).
  Stream<List<LocalPassage>> watchRecentPassages({int limit = 50}) {
    return (select(localPassages)
          ..orderBy([
            (t) => OrderingTerm.desc(t.recordedAt),
          ])
          ..limit(limit))
        .watch();
  }
}
