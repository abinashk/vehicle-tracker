import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared/shared.dart';

import 'package:vehicle_tracker_mobile/data/local/database.dart';
import 'package:vehicle_tracker_mobile/data/local/daos/passage_dao.dart';
import 'package:vehicle_tracker_mobile/data/local/daos/sync_queue_dao.dart';
import 'package:vehicle_tracker_mobile/data/remote/passage_remote_source.dart';
import 'package:vehicle_tracker_mobile/data/repositories/passage_repository.dart';

@GenerateNiceMocks([
  MockSpec<PassageDao>(),
  MockSpec<SyncQueueDao>(),
  MockSpec<PassageRemoteSource>(),
])
import 'passage_repository_test.mocks.dart';

void main() {
  late PassageRepository passageRepository;
  late MockPassageDao mockPassageDao;
  late MockSyncQueueDao mockSyncQueueDao;
  late MockPassageRemoteSource mockRemoteSource;

  setUp(() {
    mockPassageDao = MockPassageDao();
    mockSyncQueueDao = MockSyncQueueDao();
    mockRemoteSource = MockPassageRemoteSource();

    passageRepository = PassageRepository(
      passageDao: mockPassageDao,
      syncQueueDao: mockSyncQueueDao,
      remoteSource: mockRemoteSource,
    );
  });

  group('PassageRepository - Write-Local-First Pattern', () {
    test('recordPassage writes to local DB and creates sync queue entry',
        () async {
      when(mockPassageDao.insertPassage(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((_) async {});

      final result = await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        plateNumberRaw: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 0, 0),
        rangerId: 'ranger-1',
        photoLocalPath: '/photos/test.jpg',
      );

      // Step 1: Should write to local DB.
      verify(mockPassageDao.insertPassage(any)).called(1);

      // Step 2: Should create sync queue entry.
      verify(mockSyncQueueDao.enqueue(any)).called(1);

      // Step 3: Should return a valid passage model.
      expect(result, isNotNull);
      expect(result.plateNumber, 'BA 1 PA 1234');
      expect(result.vehicleType, VehicleType.car);
      expect(result.checkpostId, 'cp-1');
      expect(result.segmentId, 'segment-1');
      expect(result.rangerId, 'ranger-1');
      expect(result.source, 'app');
    });

    test('recordPassage generates unique id and clientId', () async {
      when(mockPassageDao.insertPassage(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((_) async {});

      final result1 = await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 0, 0),
        rangerId: 'ranger-1',
      );

      final result2 = await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 5678',
        vehicleType: VehicleType.bus,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 1, 0),
        rangerId: 'ranger-1',
      );

      expect(result1.id, isNot(result2.id));
      expect(result1.clientId, isNot(result2.clientId));
    });

    test('recordPassage preserves the exact recordedAt timestamp', () async {
      when(mockPassageDao.insertPassage(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((_) async {});

      final capturedAt = DateTime.utc(2024, 6, 15, 10, 30, 45);

      final result = await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: capturedAt,
        rangerId: 'ranger-1',
      );

      expect(result.recordedAt, capturedAt);
    });

    test('recordPassage creates sync queue entry with correct clientId',
        () async {
      when(mockPassageDao.insertPassage(any)).thenAnswer((_) async {});

      SyncQueueCompanion? capturedEnqueue;
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((invocation) async {
        capturedEnqueue =
            invocation.positionalArguments[0] as SyncQueueCompanion;
      });

      final result = await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 0, 0),
        rangerId: 'ranger-1',
      );

      expect(capturedEnqueue, isNotNull);
      expect(
        capturedEnqueue!.passageClientId.value,
        result.clientId,
      );
    });

    test('recordPassage does not call remote source', () async {
      when(mockPassageDao.insertPassage(any)).thenAnswer((_) async {});
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((_) async {});

      await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 0, 0),
        rangerId: 'ranger-1',
      );

      verifyNever(mockRemoteSource.pushPassage(any));
    });

    test('recordPassage includes photoLocalPath when provided', () async {
      LocalPassagesCompanion? capturedPassage;
      when(mockPassageDao.insertPassage(any)).thenAnswer((invocation) async {
        capturedPassage =
            invocation.positionalArguments[0] as LocalPassagesCompanion;
      });
      when(mockSyncQueueDao.enqueue(any)).thenAnswer((_) async {});

      await passageRepository.recordPassage(
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        checkpostId: 'cp-1',
        segmentId: 'segment-1',
        recordedAt: DateTime.utc(2024, 6, 15, 10, 0, 0),
        rangerId: 'ranger-1',
        photoLocalPath: '/photos/capture_123.jpg',
      );

      expect(capturedPassage, isNotNull);
      expect(
        capturedPassage!.photoLocalPath.value,
        '/photos/capture_123.jpg',
      );
    });
  });
}
