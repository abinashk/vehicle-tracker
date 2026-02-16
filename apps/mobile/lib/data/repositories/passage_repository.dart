import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart';

import '../local/daos/passage_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/database.dart';
import '../remote/passage_remote_source.dart';

/// Repository mediating between local Drift storage and Supabase remote.
///
/// Implements the write-local-first pattern:
/// 1. Write to Drift first
/// 2. Create sync queue entry
/// 3. Return success to the UI immediately
/// 4. Sync engine handles pushing to server asynchronously
class PassageRepository {
  PassageRepository({
    required PassageDao passageDao,
    required SyncQueueDao syncQueueDao,
    required PassageRemoteSource remoteSource,
  })  : _passageDao = passageDao,
        _syncQueueDao = syncQueueDao,
        _remoteSource = remoteSource;

  final PassageDao _passageDao;
  final SyncQueueDao _syncQueueDao;
  final PassageRemoteSource _remoteSource;

  static const _uuid = Uuid();

  /// Record a new vehicle passage using write-local-first pattern.
  ///
  /// The [recordedAt] timestamp is the camera shutter moment, NOT submission time.
  /// The [clientId] is generated once and never regenerated on retry.
  Future<VehiclePassage> recordPassage({
    required String plateNumber,
    String? plateNumberRaw,
    required VehicleType vehicleType,
    required String checkpostId,
    required String segmentId,
    required DateTime recordedAt,
    required String rangerId,
    String? photoLocalPath,
  }) async {
    final id = _uuid.v4();
    final clientId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Create the passage model.
    final passage = VehiclePassage(
      id: id,
      clientId: clientId,
      plateNumber: plateNumber,
      plateNumberRaw: plateNumberRaw,
      vehicleType: vehicleType,
      checkpostId: checkpostId,
      segmentId: segmentId,
      recordedAt: recordedAt.toUtc(),
      rangerId: rangerId,
      photoLocalPath: photoLocalPath,
      source: 'app',
      createdAt: now,
    );

    // Step 1: Write to Drift first.
    await _passageDao.insertPassage(
      LocalPassagesCompanion.insert(
        id: id,
        clientId: clientId,
        plateNumber: plateNumber,
        plateNumberRaw: Value(plateNumberRaw),
        vehicleType: vehicleType.value,
        checkpostId: checkpostId,
        segmentId: segmentId,
        recordedAt: recordedAt.toUtc(),
        rangerId: rangerId,
        photoLocalPath: Value(photoLocalPath),
        source: const Value('app'),
        createdAt: now,
      ),
    );

    // Step 2: Create sync queue entry.
    await _syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        passageClientId: clientId,
        createdAt: now,
      ),
    );

    // Step 3: Return success immediately.
    return passage;
  }

  /// Get a passage by its ID.
  Future<VehiclePassage?> getPassageById(String id) async {
    final local = await _passageDao.getPassageById(id);
    if (local == null) return null;
    return _localToModel(local);
  }

  /// Get a passage by client ID.
  Future<VehiclePassage?> getPassageByClientId(String clientId) async {
    final local = await _passageDao.getPassageByClientId(clientId);
    if (local == null) return null;
    return _localToModel(local);
  }

  /// Watch passages for the current checkpost.
  Stream<List<VehiclePassage>> watchPassagesForCheckpost(String checkpostId) {
    return _passageDao
        .watchPassagesForCheckpost(checkpostId)
        .map((list) => list.map(_localToModel).toList());
  }

  /// Watch recent passages.
  Stream<List<VehiclePassage>> watchRecentPassages({int limit = 50}) {
    return _passageDao
        .watchRecentPassages(limit: limit)
        .map((list) => list.map(_localToModel).toList());
  }

  /// Search passages by plate number.
  Stream<List<VehiclePassage>> watchPassagesByPlate(String query) {
    return _passageDao
        .watchPassagesByPlate(query)
        .map((list) => list.map(_localToModel).toList());
  }

  /// Get today's passage count.
  Future<int> countTodaysPassages(String checkpostId) {
    return _passageDao.countTodaysPassages(checkpostId);
  }

  /// Update photo path after successful upload.
  Future<void> updatePhotoPath(String id, String photoPath) {
    return _passageDao.updatePhotoPath(id, photoPath);
  }

  /// Fetch checkpost details from the server.
  Future<Checkpost?> getCheckpost(String checkpostId) {
    return _remoteSource.getCheckpost(checkpostId);
  }

  /// Fetch segment details from the server.
  Future<HighwaySegment?> getSegment(String segmentId) {
    return _remoteSource.getSegment(segmentId);
  }

  /// Convert a Drift LocalPassage row to a VehiclePassage model.
  VehiclePassage _localToModel(LocalPassage row) {
    return VehiclePassage(
      id: row.id,
      clientId: row.clientId,
      plateNumber: row.plateNumber,
      plateNumberRaw: row.plateNumberRaw,
      vehicleType: VehicleType.fromValue(row.vehicleType),
      checkpostId: row.checkpostId,
      segmentId: row.segmentId,
      recordedAt: row.recordedAt,
      rangerId: row.rangerId,
      photoLocalPath: row.photoLocalPath,
      photoPath: row.photoPath,
      source: row.source,
      matchedPassageId: row.matchedPassageId,
      isEntry: row.isEntry,
      createdAt: row.createdAt,
    );
  }
}

/// Provider for the passage repository.
final passageRepositoryProvider = Provider<PassageRepository>((ref) {
  return PassageRepository(
    passageDao: ref.watch(passageDaoProvider),
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    remoteSource: ref.watch(passageRemoteSourceProvider),
  );
});
