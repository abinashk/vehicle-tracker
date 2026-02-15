import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../local/daos/violation_dao.dart';
import '../local/database.dart';

/// Repository for violation access, mediating local Drift storage.
///
/// Violations are created locally by the matching service and stored
/// in the local_violations Drift table for immediate ranger feedback.
class ViolationRepository {
  ViolationRepository({required ViolationDao violationDao})
      : _violationDao = violationDao;

  final ViolationDao _violationDao;
  static const _uuid = Uuid();

  /// Save a locally detected violation.
  Future<Violation> saveViolation({
    required String entryPassageId,
    required String exitPassageId,
    required String segmentId,
    required ViolationType violationType,
    required String plateNumber,
    required VehicleType vehicleType,
    required DateTime entryTime,
    required DateTime exitTime,
    required double travelTimeMinutes,
    required double thresholdMinutes,
    required double calculatedSpeedKmh,
    required double speedLimitKmh,
    required double distanceKm,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    final violation = Violation(
      id: id,
      entryPassageId: entryPassageId,
      exitPassageId: exitPassageId,
      segmentId: segmentId,
      violationType: violationType,
      plateNumber: plateNumber,
      vehicleType: vehicleType,
      entryTime: entryTime,
      exitTime: exitTime,
      travelTimeMinutes: travelTimeMinutes,
      thresholdMinutes: thresholdMinutes,
      calculatedSpeedKmh: calculatedSpeedKmh,
      speedLimitKmh: speedLimitKmh,
      distanceKm: distanceKm,
      createdAt: now,
    );

    await _violationDao.insertViolation(
      LocalViolationsCompanion.insert(
        id: id,
        entryPassageId: entryPassageId,
        exitPassageId: exitPassageId,
        segmentId: segmentId,
        violationType: violationType.value,
        plateNumber: plateNumber,
        vehicleType: vehicleType.value,
        entryTime: entryTime,
        exitTime: exitTime,
        travelTimeMinutes: travelTimeMinutes,
        thresholdMinutes: thresholdMinutes,
        calculatedSpeedKmh: calculatedSpeedKmh,
        speedLimitKmh: speedLimitKmh,
        distanceKm: distanceKm,
        createdAt: now,
      ),
    );

    return violation;
  }

  /// Get a violation by ID.
  Future<Violation?> getViolationById(String id) async {
    final local = await _violationDao.getViolationById(id);
    if (local == null) return null;
    return _localToModel(local);
  }

  /// Watch a violation by ID.
  Stream<Violation?> watchViolationById(String id) {
    return _violationDao.watchViolationById(id).map((local) {
      if (local == null) return null;
      return _localToModel(local);
    });
  }

  /// Watch all violations.
  Stream<List<Violation>> watchAllViolations() {
    return _violationDao
        .watchAllViolations()
        .map((list) => list.map(_localToModel).toList());
  }

  /// Watch today's violations.
  Stream<List<Violation>> watchTodaysViolations() {
    return _violationDao
        .watchTodaysViolations()
        .map((list) => list.map(_localToModel).toList());
  }

  /// Count today's violations.
  Future<int> countTodaysViolations() {
    return _violationDao.countTodaysViolations();
  }

  /// Record an outcome for a violation.
  Future<void> recordOutcome({
    required String violationId,
    required OutcomeType outcomeType,
    double? fineAmount,
    String? notes,
  }) {
    return _violationDao.recordOutcome(
      violationId: violationId,
      outcomeType: outcomeType.value,
      fineAmount: fineAmount,
      notes: notes,
    );
  }

  /// Mark a violation alert as delivered.
  Future<void> markAlertDelivered(String id) {
    return _violationDao.markAlertDelivered(id);
  }

  /// Find violations for a specific passage.
  Future<List<Violation>> findViolationsForPassage(String passageId) async {
    final locals = await _violationDao.findViolationsForPassage(passageId);
    return locals.map(_localToModel).toList();
  }

  /// Convert a Drift LocalViolation row to a Violation model.
  Violation _localToModel(LocalViolation row) {
    return Violation(
      id: row.id,
      entryPassageId: row.entryPassageId,
      exitPassageId: row.exitPassageId,
      segmentId: row.segmentId,
      violationType: ViolationType.fromValue(row.violationType),
      plateNumber: row.plateNumber,
      vehicleType: VehicleType.fromValue(row.vehicleType),
      entryTime: row.entryTime,
      exitTime: row.exitTime,
      travelTimeMinutes: row.travelTimeMinutes,
      thresholdMinutes: row.thresholdMinutes,
      calculatedSpeedKmh: row.calculatedSpeedKmh,
      speedLimitKmh: row.speedLimitKmh,
      distanceKm: row.distanceKm,
      alertDeliveredAt: row.alertDeliveredAt,
      createdAt: row.createdAt,
    );
  }
}

/// Provider for the violation repository.
final violationRepositoryProvider = Provider<ViolationRepository>((ref) {
  return ViolationRepository(violationDao: ref.watch(violationDaoProvider));
});
