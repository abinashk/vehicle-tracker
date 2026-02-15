import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:vehicle_tracker_mobile/core/services/connectivity_service.dart';
import 'package:vehicle_tracker_mobile/data/local/daos/cached_passage_dao.dart';
import 'package:vehicle_tracker_mobile/data/local/daos/passage_dao.dart';
import 'package:vehicle_tracker_mobile/data/local/daos/sync_queue_dao.dart';
import 'package:vehicle_tracker_mobile/data/local/database.dart';
import 'package:vehicle_tracker_mobile/data/remote/passage_remote_source.dart';
import 'package:vehicle_tracker_mobile/data/repositories/sync_repository.dart';

@GenerateNiceMocks([
  MockSpec<SyncQueueDao>(),
  MockSpec<PassageDao>(),
  MockSpec<CachedPassageDao>(),
  MockSpec<PassageRemoteSource>(),
  MockSpec<ConnectivityService>(),
])
import 'sync_repository_test.mocks.dart';

void main() {
  late SyncRepository syncRepository;
  late MockSyncQueueDao mockSyncQueueDao;
  late MockPassageDao mockPassageDao;
  late MockCachedPassageDao mockCachedPassageDao;
  late MockPassageRemoteSource mockRemoteSource;
  late MockConnectivityService mockConnectivityService;

  setUp(() {
    mockSyncQueueDao = MockSyncQueueDao();
    mockPassageDao = MockPassageDao();
    mockCachedPassageDao = MockCachedPassageDao();
    mockRemoteSource = MockPassageRemoteSource();
    mockConnectivityService = MockConnectivityService();

    syncRepository = SyncRepository(
      syncQueueDao: mockSyncQueueDao,
      passageDao: mockPassageDao,
      cachedPassageDao: mockCachedPassageDao,
      remoteSource: mockRemoteSource,
      connectivityService: mockConnectivityService,
    );
  });

  SyncQueueData createSyncItem({
    int id = 1,
    String passageClientId = 'client-1',
    String status = 'pending',
    int attempts = 0,
    bool smsSent = false,
  }) {
    return SyncQueueData(
      id: id,
      passageClientId: passageClientId,
      status: status,
      attempts: attempts,
      lastAttemptAt: null,
      smsSent: smsSent,
      createdAt: DateTime.now().toUtc(),
    );
  }

  LocalPassage createLocalPassage({
    String id = 'passage-1',
    String clientId = 'client-1',
  }) {
    return LocalPassage(
      id: id,
      clientId: clientId,
      plateNumber: 'BA 1 PA 1234',
      plateNumberRaw: null,
      vehicleType: 'car',
      checkpostId: 'cp-1',
      segmentId: 'segment-1',
      recordedAt: DateTime.now().toUtc(),
      rangerId: 'ranger-1',
      photoLocalPath: null,
      photoPath: null,
      source: 'app',
      matchedPassageId: null,
      isEntry: null,
      createdAt: DateTime.now().toUtc(),
    );
  }

  group('SyncRepository - Sync State Machine', () {
    test('pending items are transitioned to in_flight then synced on 201',
        () async {
      final item = createSyncItem();
      final passage = createLocalPassage();

      when(mockConnectivityService.isOnline).thenReturn(true);
      when(mockSyncQueueDao.getPendingItems()).thenAnswer((_) async => [item]);
      when(mockSyncQueueDao.markInFlight(any)).thenAnswer((_) async {});
      when(mockPassageDao.getPassageByClientId(any))
          .thenAnswer((_) async => passage);
      when(mockRemoteSource.pushPassage(any)).thenAnswer((_) async => 201);
      when(mockSyncQueueDao.markSynced(any)).thenAnswer((_) async {});

      syncRepository.configure(checkpostId: 'cp-1', segmentId: 'segment-1');
      await syncRepository.forceSyncCycle();

      verify(mockSyncQueueDao.markInFlight('client-1')).called(1);
      verify(mockSyncQueueDao.markSynced('client-1')).called(1);
    });

    test('409 (duplicate) is treated as success', () async {
      final item = createSyncItem();
      final passage = createLocalPassage();

      when(mockConnectivityService.isOnline).thenReturn(true);
      when(mockSyncQueueDao.getPendingItems()).thenAnswer((_) async => [item]);
      when(mockSyncQueueDao.markInFlight(any)).thenAnswer((_) async {});
      when(mockPassageDao.getPassageByClientId(any))
          .thenAnswer((_) async => passage);
      when(mockRemoteSource.pushPassage(any)).thenAnswer((_) async => 409);
      when(mockSyncQueueDao.markSynced(any)).thenAnswer((_) async {});

      syncRepository.configure(checkpostId: 'cp-1', segmentId: 'segment-1');
      await syncRepository.forceSyncCycle();

      verify(mockSyncQueueDao.markSynced('client-1')).called(1);
    });

    test('failure increments attempts and returns to pending', () async {
      final item = createSyncItem(attempts: 2);
      final passage = createLocalPassage();

      when(mockConnectivityService.isOnline).thenReturn(true);
      when(mockSyncQueueDao.getPendingItems()).thenAnswer((_) async => [item]);
      when(mockSyncQueueDao.markInFlight(any)).thenAnswer((_) async {});
      when(mockPassageDao.getPassageByClientId(any))
          .thenAnswer((_) async => passage);
      when(mockRemoteSource.pushPassage(any))
          .thenThrow(Exception('Network error'));
      when(mockSyncQueueDao.markRetry(any, any)).thenAnswer((_) async {});

      syncRepository.configure(checkpostId: 'cp-1', segmentId: 'segment-1');
      await syncRepository.forceSyncCycle();

      verify(mockSyncQueueDao.markRetry('client-1', 2)).called(1);
      verifyNever(mockSyncQueueDao.markFailed(any));
    });

    test('marks as failed after 5 attempts', () async {
      final item = createSyncItem(attempts: 4); // 4 + 1 = 5 >= maxAttempts
      final passage = createLocalPassage();

      when(mockConnectivityService.isOnline).thenReturn(true);
      when(mockSyncQueueDao.getPendingItems()).thenAnswer((_) async => [item]);
      when(mockSyncQueueDao.markInFlight(any)).thenAnswer((_) async {});
      when(mockPassageDao.getPassageByClientId(any))
          .thenAnswer((_) async => passage);
      when(mockRemoteSource.pushPassage(any))
          .thenThrow(Exception('Network error'));
      when(mockSyncQueueDao.markFailed(any)).thenAnswer((_) async {});

      syncRepository.configure(checkpostId: 'cp-1', segmentId: 'segment-1');
      await syncRepository.forceSyncCycle();

      verify(mockSyncQueueDao.markFailed('client-1')).called(1);
      verifyNever(mockSyncQueueDao.markRetry(any, any));
    });

    test('does not sync when offline', () async {
      when(mockConnectivityService.isOnline).thenReturn(false);

      await syncRepository.forceSyncCycle();

      verifyNever(mockSyncQueueDao.getPendingItems());
    });

    test('marks SMS as sent for a specific item', () async {
      when(mockSyncQueueDao.markSmsSent(any)).thenAnswer((_) async {});

      await syncRepository.markSmsSent('client-1');

      verify(mockSyncQueueDao.markSmsSent('client-1')).called(1);
    });

    test('returns correct sync state', () async {
      when(mockSyncQueueDao.getPendingItems())
          .thenAnswer((_) async => [createSyncItem(), createSyncItem(id: 2)]);
      when(mockSyncQueueDao.getLastSyncTime())
          .thenAnswer((_) async => DateTime(2024, 6, 15));

      final state = await syncRepository.getSyncState();

      expect(state.pendingCount, 2);
      expect(state.lastSyncTime, DateTime(2024, 6, 15));
    });

    test('handles missing passage gracefully during push', () async {
      final item = createSyncItem();

      when(mockConnectivityService.isOnline).thenReturn(true);
      when(mockSyncQueueDao.getPendingItems()).thenAnswer((_) async => [item]);
      when(mockSyncQueueDao.markInFlight(any)).thenAnswer((_) async {});
      when(mockPassageDao.getPassageByClientId(any))
          .thenAnswer((_) async => null);
      when(mockSyncQueueDao.markFailed(any)).thenAnswer((_) async {});

      syncRepository.configure(checkpostId: 'cp-1', segmentId: 'segment-1');
      await syncRepository.forceSyncCycle();

      verify(mockSyncQueueDao.markFailed('client-1')).called(1);
    });
  });
}
