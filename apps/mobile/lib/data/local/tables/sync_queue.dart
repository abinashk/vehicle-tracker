import 'package:drift/drift.dart';

/// Sync queue table tracking outbound sync state per passage.
///
/// State machine: pending -> in_flight -> synced (or failed after 5 attempts).
/// See /docs/architecture/offline-sync.md for the full state machine diagram.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get passageClientId => text().unique()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  BoolColumn get smsSent => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}
