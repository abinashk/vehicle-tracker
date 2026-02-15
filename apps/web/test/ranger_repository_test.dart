import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vehicle_tracker_web/data/repositories/ranger_repository.dart';

@GenerateMocks([
  SupabaseClient,
  SupabaseQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
  FunctionsClient,
])
import 'ranger_repository_test.mocks.dart';

void main() {
  late MockSupabaseClient mockClient;
  late RangerRepository rangerRepository;

  final sampleRangerJson = {
    'id': 'ranger-001',
    'full_name': 'Ram Sharma',
    'role': 'ranger',
    'phone_number': '+977-9841234567',
    'assigned_checkpost_id': 'cp-001',
    'assigned_park_id': 'park-001',
    'is_active': true,
    'created_at': '2025-01-01T00:00:00Z',
    'updated_at': '2025-01-01T00:00:00Z',
  };

  final sampleRangerJson2 = {
    'id': 'ranger-002',
    'full_name': 'Sita Thapa',
    'role': 'ranger',
    'phone_number': '+977-9851234567',
    'assigned_checkpost_id': 'cp-002',
    'assigned_park_id': 'park-001',
    'is_active': false,
    'created_at': '2025-01-02T00:00:00Z',
    'updated_at': '2025-01-02T00:00:00Z',
  };

  setUp(() {
    mockClient = MockSupabaseClient();
    rangerRepository = RangerRepository(mockClient);
  });

  group('RangerRepository', () {
    group('listRangers', () {
      test('should return a list of rangers ordered by name', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();
        final mockTransformBuilder = MockPostgrestTransformBuilder();

        when(mockClient.from(ApiConstants.userProfilesTable))
            .thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('role', 'ranger'))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.order('full_name', ascending: true))
            .thenAnswer((_) async => [sampleRangerJson, sampleRangerJson2]);

        // Act
        final rangers = await rangerRepository.listRangers();

        // Assert
        expect(rangers, hasLength(2));
        expect(rangers[0].fullName, 'Ram Sharma');
        expect(rangers[0].isRanger, true);
        expect(rangers[1].fullName, 'Sita Thapa');
        expect(rangers[1].isActive, false);
      });
    });

    group('getRanger', () {
      test('should return a single ranger by ID', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(mockClient.from(ApiConstants.userProfilesTable))
            .thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.select(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', 'ranger-001'))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.single())
            .thenAnswer((_) async => sampleRangerJson);

        // Act
        final ranger = await rangerRepository.getRanger('ranger-001');

        // Assert
        expect(ranger.id, 'ranger-001');
        expect(ranger.fullName, 'Ram Sharma');
        expect(ranger.phoneNumber, '+977-9841234567');
      });
    });

    group('toggleActive', () {
      test('should update ranger active status', () async {
        // Arrange
        final mockQueryBuilder = MockSupabaseQueryBuilder();
        final mockFilterBuilder = MockPostgrestFilterBuilder();

        when(mockClient.from(ApiConstants.userProfilesTable))
            .thenReturn(mockQueryBuilder);
        when(mockQueryBuilder.update(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.eq('id', 'ranger-001'))
            .thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.select(any)).thenReturn(mockFilterBuilder);
        when(mockFilterBuilder.single()).thenAnswer((_) async => {
              ...sampleRangerJson,
              'is_active': false,
            });

        // Act
        final ranger = await rangerRepository.toggleActive(
          'ranger-001',
          isActive: false,
        );

        // Assert
        expect(ranger.isActive, false);
      });
    });
  });

  group('CreateRangerRequest', () {
    test('should generate correct email from username', () {
      const request = CreateRangerRequest(
        username: 'ram.sharma',
        password: 'password123',
        fullName: 'Ram Sharma',
        phoneNumber: '+977-9841234567',
        assignedCheckpostId: 'cp-001',
        assignedParkId: 'park-001',
      );

      expect(request.email, 'ram.sharma@bnp.local');
    });

    test('should serialize to JSON correctly', () {
      const request = CreateRangerRequest(
        username: 'sita.thapa',
        password: 'securepass',
        fullName: 'Sita Thapa',
        phoneNumber: '+977-9851234567',
        assignedCheckpostId: 'cp-002',
        assignedParkId: 'park-001',
      );

      final json = request.toJson();

      expect(json['username'], 'sita.thapa');
      expect(json['password'], 'securepass');
      expect(json['full_name'], 'Sita Thapa');
      expect(json['phone_number'], '+977-9851234567');
      expect(json['assigned_checkpost_id'], 'cp-002');
      expect(json['assigned_park_id'], 'park-001');
    });
  });

  group('UpdateRangerRequest', () {
    test('should serialize to JSON with optional fields', () {
      const request = UpdateRangerRequest(
        fullName: 'Ram Sharma Updated',
        phoneNumber: '+977-9841111111',
        assignedCheckpostId: 'cp-003',
      );

      final json = request.toJson();

      expect(json['full_name'], 'Ram Sharma Updated');
      expect(json['phone_number'], '+977-9841111111');
      expect(json['assigned_checkpost_id'], 'cp-003');
      expect(json.containsKey('updated_at'), true);
    });

    test('should omit null optional fields', () {
      const request = UpdateRangerRequest(
        fullName: 'Name Only',
      );

      final json = request.toJson();

      expect(json['full_name'], 'Name Only');
      expect(json.containsKey('phone_number'), false);
      expect(json.containsKey('assigned_checkpost_id'), false);
    });
  });
}
