import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared/shared.dart';

import 'package:vehicle_tracker_mobile/data/local/daos/cached_passage_dao.dart';
import 'package:vehicle_tracker_mobile/data/local/database.dart';
import 'package:vehicle_tracker_mobile/data/repositories/violation_repository.dart';
import 'package:vehicle_tracker_mobile/domain/services/matching_service.dart';

@GenerateNiceMocks([
  MockSpec<CachedPassageDao>(),
  MockSpec<ViolationRepository>(),
])
import 'matching_service_test.mocks.dart';

void main() {
  late MatchingService matchingService;
  late MockCachedPassageDao mockCachedPassageDao;
  late MockViolationRepository mockViolationRepository;

  final testSegment = HighwaySegment(
    id: 'segment-1',
    parkId: 'park-1',
    name: 'Test Segment',
    distanceKm: 20.0,
    maxSpeedKmh: 40.0,
    minSpeedKmh: 10.0,
    minTravelTimeMinutes: 30.0,
    maxTravelTimeMinutes: 120.0,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  final entryTime = DateTime.utc(2024, 6, 15, 10, 0, 0);
  final exitTimeSpeeding = DateTime.utc(2024, 6, 15, 10, 15, 0); // 15 min
  final exitTimeNormal = DateTime.utc(2024, 6, 15, 10, 45, 0); // 45 min
  final exitTimeOverstay = DateTime.utc(2024, 6, 15, 14, 0, 0); // 4 hours

  setUp(() {
    mockCachedPassageDao = MockCachedPassageDao();
    mockViolationRepository = MockViolationRepository();
    matchingService = MatchingService(
      cachedPassageDao: mockCachedPassageDao,
      violationRepository: mockViolationRepository,
    );
  });

  VehiclePassage createPassage({
    required String id,
    required DateTime recordedAt,
    String checkpostId = 'cp-1',
  }) {
    return VehiclePassage(
      id: id,
      clientId: 'client-$id',
      plateNumber: 'BA 1 PA 1234',
      vehicleType: VehicleType.car,
      checkpostId: checkpostId,
      segmentId: 'segment-1',
      recordedAt: recordedAt,
      rangerId: 'ranger-1',
      createdAt: recordedAt,
    );
  }

  CachedRemotePassage createCachedPassage({
    required String id,
    required DateTime recordedAt,
    String checkpostId = 'cp-2',
  }) {
    return CachedRemotePassage(
      id: id,
      clientId: 'client-$id',
      plateNumber: 'BA 1 PA 1234',
      vehicleType: 'car',
      checkpostId: checkpostId,
      segmentId: 'segment-1',
      recordedAt: recordedAt,
      rangerId: 'ranger-2',
      matchedPassageId: null,
      isEntry: null,
      createdAt: recordedAt,
      cachedAt: DateTime.now(),
    );
  }

  group('MatchingService', () {
    test('returns no match when no candidates found', () async {
      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => []);

      final passage = createPassage(
        id: 'exit-1',
        recordedAt: exitTimeNormal,
      );

      final result = await matchingService.findMatch(
        newPassage: passage,
        segment: testSegment,
      );

      expect(result.matched, isFalse);
      expect(result.violation, isNull);
    });

    test('detects speeding violation when travel time is below minimum',
        () async {
      final cachedEntry = createCachedPassage(
        id: 'entry-1',
        recordedAt: entryTime,
      );

      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => [cachedEntry]);

      when(mockCachedPassageDao.markAsMatched(any, any))
          .thenAnswer((_) async {});

      final speedingViolation = Violation(
        id: 'violation-1',
        entryPassageId: 'entry-1',
        exitPassageId: 'exit-1',
        segmentId: 'segment-1',
        violationType: ViolationType.speeding,
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        entryTime: entryTime,
        exitTime: exitTimeSpeeding,
        travelTimeMinutes: 15.0,
        thresholdMinutes: 30.0,
        calculatedSpeedKmh: 80.0,
        speedLimitKmh: 40.0,
        distanceKm: 20.0,
        createdAt: DateTime.now(),
      );

      when(mockViolationRepository.saveViolation(
        entryPassageId: anyNamed('entryPassageId'),
        exitPassageId: anyNamed('exitPassageId'),
        segmentId: anyNamed('segmentId'),
        violationType: anyNamed('violationType'),
        plateNumber: anyNamed('plateNumber'),
        vehicleType: anyNamed('vehicleType'),
        entryTime: anyNamed('entryTime'),
        exitTime: anyNamed('exitTime'),
        travelTimeMinutes: anyNamed('travelTimeMinutes'),
        thresholdMinutes: anyNamed('thresholdMinutes'),
        calculatedSpeedKmh: anyNamed('calculatedSpeedKmh'),
        speedLimitKmh: anyNamed('speedLimitKmh'),
        distanceKm: anyNamed('distanceKm'),
      ),).thenAnswer((_) async => speedingViolation);

      final exitPassage = createPassage(
        id: 'exit-1',
        recordedAt: exitTimeSpeeding,
      );

      final result = await matchingService.findMatch(
        newPassage: exitPassage,
        segment: testSegment,
      );

      expect(result.matched, isTrue);
      expect(result.violation, isNotNull);
      expect(result.violation!.violationType, ViolationType.speeding);

      verify(mockViolationRepository.saveViolation(
        entryPassageId: 'entry-1',
        exitPassageId: 'exit-1',
        segmentId: 'segment-1',
        violationType: ViolationType.speeding,
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        entryTime: entryTime,
        exitTime: exitTimeSpeeding,
        travelTimeMinutes: anyNamed('travelTimeMinutes'),
        thresholdMinutes: anyNamed('thresholdMinutes'),
        calculatedSpeedKmh: anyNamed('calculatedSpeedKmh'),
        speedLimitKmh: 40.0,
        distanceKm: 20.0,
      ),).called(1);
    });

    test('no violation when travel time is normal', () async {
      final cachedEntry = createCachedPassage(
        id: 'entry-1',
        recordedAt: entryTime,
      );

      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => [cachedEntry]);

      when(mockCachedPassageDao.markAsMatched(any, any))
          .thenAnswer((_) async {});

      final normalPassage = createPassage(
        id: 'exit-1',
        recordedAt: exitTimeNormal,
      );

      final result = await matchingService.findMatch(
        newPassage: normalPassage,
        segment: testSegment,
      );

      expect(result.matched, isTrue);
      expect(result.violation, isNull);
      verifyNever(mockViolationRepository.saveViolation(
        entryPassageId: anyNamed('entryPassageId'),
        exitPassageId: anyNamed('exitPassageId'),
        segmentId: anyNamed('segmentId'),
        violationType: anyNamed('violationType'),
        plateNumber: anyNamed('plateNumber'),
        vehicleType: anyNamed('vehicleType'),
        entryTime: anyNamed('entryTime'),
        exitTime: anyNamed('exitTime'),
        travelTimeMinutes: anyNamed('travelTimeMinutes'),
        thresholdMinutes: anyNamed('thresholdMinutes'),
        calculatedSpeedKmh: anyNamed('calculatedSpeedKmh'),
        speedLimitKmh: anyNamed('speedLimitKmh'),
        distanceKm: anyNamed('distanceKm'),
      ),);
    });

    test('detects overstay violation when travel time exceeds maximum',
        () async {
      final cachedEntry = createCachedPassage(
        id: 'entry-1',
        recordedAt: entryTime,
      );

      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => [cachedEntry]);

      when(mockCachedPassageDao.markAsMatched(any, any))
          .thenAnswer((_) async {});

      final overstayViolation = Violation(
        id: 'violation-2',
        entryPassageId: 'entry-1',
        exitPassageId: 'exit-1',
        segmentId: 'segment-1',
        violationType: ViolationType.overstay,
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        entryTime: entryTime,
        exitTime: exitTimeOverstay,
        travelTimeMinutes: 240.0,
        thresholdMinutes: 120.0,
        calculatedSpeedKmh: 5.0,
        speedLimitKmh: 40.0,
        distanceKm: 20.0,
        createdAt: DateTime.now(),
      );

      when(mockViolationRepository.saveViolation(
        entryPassageId: anyNamed('entryPassageId'),
        exitPassageId: anyNamed('exitPassageId'),
        segmentId: anyNamed('segmentId'),
        violationType: anyNamed('violationType'),
        plateNumber: anyNamed('plateNumber'),
        vehicleType: anyNamed('vehicleType'),
        entryTime: anyNamed('entryTime'),
        exitTime: anyNamed('exitTime'),
        travelTimeMinutes: anyNamed('travelTimeMinutes'),
        thresholdMinutes: anyNamed('thresholdMinutes'),
        calculatedSpeedKmh: anyNamed('calculatedSpeedKmh'),
        speedLimitKmh: anyNamed('speedLimitKmh'),
        distanceKm: anyNamed('distanceKm'),
      ),).thenAnswer((_) async => overstayViolation);

      final overstayPassage = createPassage(
        id: 'exit-1',
        recordedAt: exitTimeOverstay,
      );

      final result = await matchingService.findMatch(
        newPassage: overstayPassage,
        segment: testSegment,
      );

      expect(result.matched, isTrue);
      expect(result.violation, isNotNull);
      expect(result.violation!.violationType, ViolationType.overstay);
    });

    test('correctly determines entry/exit based on timestamps', () async {
      // The cached entry has a LATER timestamp than the new passage.
      final laterCachedEntry = createCachedPassage(
        id: 'later-1',
        recordedAt: exitTimeSpeeding,
      );

      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => [laterCachedEntry]);

      when(mockCachedPassageDao.markAsMatched(any, any))
          .thenAnswer((_) async {});

      // New passage has the earlier timestamp.
      final earlierPassage = createPassage(
        id: 'earlier-1',
        recordedAt: entryTime,
      );

      final result = await matchingService.findMatch(
        newPassage: earlierPassage,
        segment: testSegment,
      );

      // Should still match correctly with proper entry/exit assignment.
      expect(result.matched, isTrue);
    });

    test('marks cached entry as matched after finding a match', () async {
      final cachedEntry = createCachedPassage(
        id: 'entry-1',
        recordedAt: entryTime,
      );

      when(mockCachedPassageDao.findMatchCandidates(
        plateNumber: anyNamed('plateNumber'),
        segmentId: anyNamed('segmentId'),
        excludeCheckpostId: anyNamed('excludeCheckpostId'),
      ),).thenAnswer((_) async => [cachedEntry]);

      when(mockCachedPassageDao.markAsMatched(any, any))
          .thenAnswer((_) async {});

      final passage = createPassage(
        id: 'exit-1',
        recordedAt: exitTimeNormal,
      );

      await matchingService.findMatch(
        newPassage: passage,
        segment: testSegment,
      );

      verify(mockCachedPassageDao.markAsMatched('entry-1', 'exit-1')).called(1);
    });
  });
}
