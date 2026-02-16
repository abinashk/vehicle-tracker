import 'package:drift/drift.dart';

/// Local passages table - mirrors the server's vehicle_passages table.
///
/// Every passage is written here first (write-local-first pattern).
/// The sync engine later pushes to the server.
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
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('app'))();
  TextColumn get matchedPassageId => text().nullable()();
  BoolColumn get isEntry => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
