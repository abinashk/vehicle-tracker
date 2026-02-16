import 'package:drift/drift.dart';

/// Local violations detected by the client-side matching service.
///
/// These are best-effort violations detected locally for immediate
/// ranger feedback. The server-side trigger creates the authoritative
/// violation records.
class LocalViolations extends Table {
  TextColumn get id => text()();
  TextColumn get entryPassageId => text()();
  TextColumn get exitPassageId => text()();
  TextColumn get segmentId => text()();
  TextColumn get violationType => text()();
  TextColumn get plateNumber => text()();
  TextColumn get vehicleType => text()();
  DateTimeColumn get entryTime => dateTime()();
  DateTimeColumn get exitTime => dateTime()();
  RealColumn get travelTimeMinutes => real()();
  RealColumn get thresholdMinutes => real()();
  RealColumn get calculatedSpeedKmh => real()();
  RealColumn get speedLimitKmh => real()();
  RealColumn get distanceKm => real()();
  DateTimeColumn get alertDeliveredAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  // Outcome fields (recorded by ranger)
  TextColumn get outcomeType => text().nullable()();
  RealColumn get fineAmount => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get outcomeRecordedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
