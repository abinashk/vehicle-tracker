import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cached_passage_dao.dart';
import 'daos/passage_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/violation_dao.dart';
import 'tables/cached_remote_passages.dart';
import 'tables/local_passages.dart';
import 'tables/local_violations.dart';
import 'tables/sync_queue.dart';

part 'database.g.dart';

/// Main Drift database for the mobile app.
///
/// Contains all local tables for offline-first operation:
/// - [LocalPassages] - passages recorded by this device
/// - [CachedRemotePassages] - entries from the opposite checkpost
/// - [LocalViolations] - violations detected by client-side matching
/// - [SyncQueue] - outbound sync state machine
@DriftDatabase(
  tables: [
    LocalPassages,
    CachedRemotePassages,
    LocalViolations,
    SyncQueue,
  ],
  daos: [
    PassageDao,
    CachedPassageDao,
    ViolationDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with an in-memory database.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future schema migrations go here.
      },
    );
  }
}

/// Opens a native SQLite connection to the app's database file.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vehicle_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Provider for the app database singleton.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provider for the passage DAO.
final passageDaoProvider = Provider<PassageDao>((ref) {
  return ref.watch(appDatabaseProvider).passageDao;
});

/// Provider for the cached passage DAO.
final cachedPassageDaoProvider = Provider<CachedPassageDao>((ref) {
  return ref.watch(appDatabaseProvider).cachedPassageDao;
});

/// Provider for the violation DAO.
final violationDaoProvider = Provider<ViolationDao>((ref) {
  return ref.watch(appDatabaseProvider).violationDao;
});

/// Provider for the sync queue DAO.
final syncQueueDaoProvider = Provider<SyncQueueDao>((ref) {
  return ref.watch(appDatabaseProvider).syncQueueDao;
});
