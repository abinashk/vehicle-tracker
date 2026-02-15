import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/local_violations.dart';

part 'violation_dao.g.dart';

/// Data access object for locally detected violations.
///
/// Manages CRUD operations and reactive queries for violations
/// detected by the client-side matching service.
@DriftAccessor(tables: [LocalViolations])
class ViolationDao extends DatabaseAccessor<AppDatabase>
    with _$ViolationDaoMixin {
  ViolationDao(super.db);

  /// Insert a new violation.
  Future<void> insertViolation(LocalViolationsCompanion violation) {
    return into(localViolations).insert(violation);
  }

  /// Get a violation by its ID.
  Future<LocalViolation?> getViolationById(String id) {
    return (select(localViolations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch a single violation by ID.
  Stream<LocalViolation?> watchViolationById(String id) {
    return (select(localViolations)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Watch all violations ordered by creation time descending.
  Stream<List<LocalViolation>> watchAllViolations() {
    return (select(localViolations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Watch today's violations.
  Stream<List<LocalViolation>> watchTodaysViolations() {
    final todayStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );
    return (select(localViolations)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(todayStart))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Count today's violations.
  Future<int> countTodaysViolations() async {
    final todayStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
    );
    final results = await (select(localViolations)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(todayStart)))
        .get();
    return results.length;
  }

  /// Get violations without an outcome recorded.
  Stream<List<LocalViolation>> watchUnresolvedViolations() {
    return (select(localViolations)
          ..where((t) => t.outcomeType.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Record the outcome for a violation.
  Future<void> recordOutcome({
    required String violationId,
    required String outcomeType,
    double? fineAmount,
    String? notes,
  }) {
    return (update(localViolations)..where((t) => t.id.equals(violationId)))
        .write(
      LocalViolationsCompanion(
        outcomeType: Value(outcomeType),
        fineAmount: Value(fineAmount),
        notes: Value(notes),
        outcomeRecordedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Mark a violation alert as delivered.
  Future<void> markAlertDelivered(String id) {
    return (update(localViolations)..where((t) => t.id.equals(id))).write(
      LocalViolationsCompanion(
        alertDeliveredAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Find violations for a specific passage (entry or exit).
  Future<List<LocalViolation>> findViolationsForPassage(String passageId) {
    return (select(localViolations)
          ..where((t) =>
              t.entryPassageId.equals(passageId) |
              t.exitPassageId.equals(passageId)))
        .get();
  }
}
