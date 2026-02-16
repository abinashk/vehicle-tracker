import 'package:drift/drift.dart';

/// Cached remote passages from the opposite checkpost.
///
/// These entries are pulled from the server during inbound sync
/// and used by the local matching service to detect violations
/// even when offline.
class CachedRemotePassages extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text()();
  TextColumn get plateNumber => text()();
  TextColumn get vehicleType => text()();
  TextColumn get checkpostId => text()();
  TextColumn get segmentId => text()();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get rangerId => text()();
  TextColumn get matchedPassageId => text().nullable()();
  BoolColumn get isEntry => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
