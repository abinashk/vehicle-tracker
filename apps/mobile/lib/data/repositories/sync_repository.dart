import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../core/services/connectivity_service.dart';
import '../local/daos/cached_passage_dao.dart';
import '../local/daos/passage_dao.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/database.dart';
import '../remote/passage_remote_source.dart';

/// Sync state exposed to the UI.
class SyncState {
  final int pendingCount;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  const SyncState({
    this.pendingCount = 0,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  SyncState copyWith({
    int? pendingCount,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return SyncState(
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Sync engine: handles outbound push, inbound pull, and photo upload.
///
/// Outbound push runs every 30 seconds and on connectivity change.
/// Inbound pull fetches unmatched passages from the opposite checkpost.
/// Photo upload is non-blocking and runs after a passage is synced.
class SyncRepository {
  SyncRepository({
    required SyncQueueDao syncQueueDao,
    required PassageDao passageDao,
    required CachedPassageDao cachedPassageDao,
    required PassageRemoteSource remoteSource,
    required ConnectivityService connectivityService,
  })  : _syncQueueDao = syncQueueDao,
        _passageDao = passageDao,
        _cachedPassageDao = cachedPassageDao,
        _remoteSource = remoteSource,
        _connectivityService = connectivityService;

  final SyncQueueDao _syncQueueDao;
  final PassageDao _passageDao;
  final CachedPassageDao _cachedPassageDao;
  final PassageRemoteSource _remoteSource;
  final ConnectivityService _connectivityService;

  Timer? _syncTimer;
  StreamSubscription<ConnectivityState>? _connectivitySubscription;
  bool _isSyncing = false;

  String? _myCheckpostId;
  String? _mySegmentId;

  /// Configure the sync engine with the ranger's checkpost and segment.
  void configure({
    required String checkpostId,
    required String segmentId,
  }) {
    _myCheckpostId = checkpostId;
    _mySegmentId = segmentId;
  }

  /// Start the sync engine.
  ///
  /// Sets up a 30-second periodic timer and listens for connectivity changes.
  void start() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => _runSyncCycle(),
    );

    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivityService.stateStream.listen((state) {
      if (state == ConnectivityState.online) {
        _runSyncCycle();
      }
    });
  }

  /// Stop the sync engine.
  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Run a full sync cycle: outbound push then inbound pull.
  Future<void> _runSyncCycle() async {
    if (_isSyncing || !_connectivityService.isOnline) return;
    _isSyncing = true;

    try {
      await _outboundPush();
      await _inboundPull();
      await _uploadPendingPhotos();
    } finally {
      _isSyncing = false;
    }
  }

  /// Force a sync cycle (e.g., triggered manually).
  Future<void> forceSyncCycle() => _runSyncCycle();

  /// Outbound push: send pending sync queue items to the server.
  ///
  /// Processes items in FIFO order (created_at ascending).
  /// State transitions follow the sync queue state machine.
  Future<void> _outboundPush() async {
    final pendingItems = await _syncQueueDao.getPendingItems();

    for (final item in pendingItems) {
      // Mark as in_flight.
      await _syncQueueDao.markInFlight(item.passageClientId);

      try {
        // Fetch the passage data.
        final passage =
            await _passageDao.getPassageByClientId(item.passageClientId);
        if (passage == null) {
          await _syncQueueDao.markFailed(item.passageClientId);
          continue;
        }

        // Build the VehiclePassage model for the API.
        final model = VehiclePassage(
          id: passage.id,
          clientId: passage.clientId,
          plateNumber: passage.plateNumber,
          plateNumberRaw: passage.plateNumberRaw,
          vehicleType: VehicleType.fromValue(passage.vehicleType),
          checkpostId: passage.checkpostId,
          segmentId: passage.segmentId,
          recordedAt: passage.recordedAt,
          rangerId: passage.rangerId,
          source: passage.source,
          createdAt: passage.createdAt,
        );

        // Push to server.
        final statusCode = await _remoteSource.pushPassage(model);

        if (statusCode == 201 || statusCode == 409) {
          // 201 = created, 409 = duplicate (both are success).
          await _syncQueueDao.markSynced(item.passageClientId);
        } else {
          _handlePushFailure(item);
        }
      } catch (_) {
        await _handlePushFailure(item);
      }
    }
  }

  /// Handle a push failure: increment attempts or mark as failed.
  Future<void> _handlePushFailure(SyncQueueData item) async {
    final newAttempts = item.attempts + 1;
    if (newAttempts >= SyncQueueItem.maxAttempts) {
      await _syncQueueDao.markFailed(item.passageClientId);
    } else {
      await _syncQueueDao.markRetry(item.passageClientId, item.attempts);
    }
  }

  /// Inbound pull: fetch unmatched passages from the opposite checkpost.
  Future<void> _inboundPull() async {
    if (_mySegmentId == null || _myCheckpostId == null) return;

    try {
      final cutoff =
          DateTime.now().toUtc().subtract(AppConstants.matchLookbackWindow);

      final remotePassages = await _remoteSource.pullOppositeCheckpostPassages(
        segmentId: _mySegmentId!,
        myCheckpostId: _myCheckpostId!,
        cutoff: cutoff,
      );

      if (remotePassages.isEmpty) return;

      // Upsert into cached_remote_passages.
      final companions = remotePassages
          .map((p) => CachedRemotePassagesCompanion.insert(
                id: p.id,
                clientId: p.clientId,
                plateNumber: p.plateNumber,
                vehicleType: p.vehicleType.value,
                checkpostId: p.checkpostId,
                segmentId: p.segmentId,
                recordedAt: p.recordedAt,
                rangerId: p.rangerId,
                matchedPassageId: Value(p.matchedPassageId),
                isEntry: Value(p.isEntry),
                createdAt: p.createdAt,
                cachedAt: DateTime.now().toUtc(),
              ))
          .toList();

      await _cachedPassageDao.upsertPassages(companions);
    } catch (_) {
      // Inbound pull failure is not critical; will retry next cycle.
    }
  }

  /// Upload photos for synced passages.
  Future<void> _uploadPendingPhotos() async {
    // Find recently synced items that have local photos but no remote path.
    // This is simplified - in production you'd track photo upload state separately.
  }

  /// Upload a specific photo for a passage.
  Future<void> uploadPhoto({
    required String passageId,
    required String localPath,
  }) async {
    try {
      final remotePath = await _remoteSource.uploadPhoto(
        passageId: passageId,
        localPath: localPath,
      );
      if (remotePath != null) {
        await _passageDao.updatePhotoPath(passageId, remotePath);
      }
    } catch (_) {
      // Photo upload failure is non-blocking.
    }
  }

  /// Get the current sync state.
  Future<SyncState> getSyncState() async {
    final pendingItems = await _syncQueueDao.getPendingItems();
    final lastSync = await _syncQueueDao.getLastSyncTime();
    return SyncState(
      pendingCount: pendingItems.length,
      lastSyncTime: lastSync,
      isSyncing: _isSyncing,
    );
  }

  /// Watch pending count stream.
  Stream<int> watchPendingCount() {
    return _syncQueueDao.watchPendingCount();
  }

  /// Get failed items without SMS sent (for SMS fallback).
  Future<List<SyncQueueData>> getFailedWithoutSms() {
    return _syncQueueDao.getFailedWithoutSms();
  }

  /// Get pending items older than the given duration (for SMS fallback).
  Future<List<SyncQueueData>> getPendingOlderThan(Duration age) {
    return _syncQueueDao.getPendingOlderThan(age);
  }

  /// Mark SMS as sent for a sync queue item.
  Future<void> markSmsSent(String passageClientId) {
    return _syncQueueDao.markSmsSent(passageClientId);
  }

  /// Dispose resources.
  void dispose() {
    stop();
  }
}

/// Provider for the sync repository.
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final repo = SyncRepository(
    syncQueueDao: ref.watch(syncQueueDaoProvider),
    passageDao: ref.watch(passageDaoProvider),
    cachedPassageDao: ref.watch(cachedPassageDaoProvider),
    remoteSource: ref.watch(passageRemoteSourceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Provider that streams the sync state for the UI.
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final syncRepo = ref.watch(syncRepositoryProvider);
  return syncRepo.watchPendingCount().asyncMap((count) async {
    final lastSync = await ref.read(syncQueueDaoProvider).getLastSyncTime();
    return SyncState(
      pendingCount: count,
      lastSyncTime: lastSync,
    );
  });
});
