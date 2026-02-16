import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:vehicle_tracker_web/data/repositories/ranger_repository.dart';

void main() {
  group('UserProfile model parsing', () {
    test('should parse ranger from JSON', () {
      final json = {
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

      final ranger = UserProfile.fromJson(json);

      expect(ranger.id, 'ranger-001');
      expect(ranger.fullName, 'Ram Sharma');
      expect(ranger.role, UserRole.ranger);
      expect(ranger.isRanger, true);
      expect(ranger.phoneNumber, '+977-9841234567');
      expect(ranger.isActive, true);
    });

    test('should parse inactive ranger', () {
      final json = {
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

      final ranger = UserProfile.fromJson(json);

      expect(ranger.fullName, 'Sita Thapa');
      expect(ranger.isActive, false);
    });

    test('should parse admin from JSON', () {
      final json = {
        'id': 'admin-001',
        'full_name': 'Admin User',
        'role': 'admin',
        'is_active': true,
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-01T00:00:00Z',
      };

      final admin = UserProfile.fromJson(json);

      expect(admin.role, UserRole.admin);
      expect(admin.isRanger, false);
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
