import 'dart:convert';

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class for creating a new ranger via the Edge Function.
class CreateRangerRequest {
  final String username;
  final String password;
  final String fullName;
  final String phoneNumber;
  final String assignedCheckpostId;
  final String assignedParkId;

  const CreateRangerRequest({
    required this.username,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.assignedCheckpostId,
    required this.assignedParkId,
  });

  /// The email used for authentication (username@bnp.local).
  String get email => '$username${AppConstants.authDomainSuffix}';

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'assigned_checkpost_id': assignedCheckpostId,
        'assigned_park_id': assignedParkId,
      };
}

/// Data class for updating an existing ranger's profile.
class UpdateRangerRequest {
  final String fullName;
  final String? phoneNumber;
  final String? assignedCheckpostId;

  const UpdateRangerRequest({
    required this.fullName,
    this.phoneNumber,
    this.assignedCheckpostId,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (assignedCheckpostId != null)
          'assigned_checkpost_id': assignedCheckpostId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

/// Repository for managing ranger user profiles.
///
/// Uses the Supabase REST API for list/edit/toggle and the
/// create-ranger Edge Function for creating new ranger accounts.
class RangerRepository {
  final SupabaseClient _client;

  RangerRepository(this._client);

  /// Fetch all rangers (user profiles with role = 'ranger').
  Future<List<UserProfile>> listRangers() async {
    final data = await _client
        .from(ApiConstants.userProfilesTable)
        .select()
        .eq('role', UserRole.ranger.value)
        .order('full_name', ascending: true);

    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  /// Fetch a single ranger by ID.
  Future<UserProfile> getRanger(String id) async {
    final data = await _client
        .from(ApiConstants.userProfilesTable)
        .select()
        .eq('id', id)
        .single();

    return UserProfile.fromJson(data);
  }

  /// Create a new ranger via the create-ranger Edge Function.
  ///
  /// This calls POST /functions/v1/create-ranger which creates
  /// both the auth user and the user_profile record.
  Future<UserProfile> createRanger(CreateRangerRequest request) async {
    final response = await _client.functions.invoke(
      ApiConstants.createRangerFunction,
      body: request.toJson(),
    );

    if (response.status != 200 && response.status != 201) {
      final body = response.data;
      final message = body is Map
          ? body['error'] ?? 'Unknown error'
          : 'Failed to create ranger';
      throw Exception('Failed to create ranger: $message');
    }

    final body = response.data;
    if (body is Map<String, dynamic>) {
      return UserProfile.fromJson(body);
    }

    // If the response is a string, try to parse it.
    if (body is String) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return UserProfile.fromJson(decoded);
    }

    throw Exception('Unexpected response format from create-ranger function.');
  }

  /// Update a ranger's profile fields.
  Future<UserProfile> updateRanger(
      String id, UpdateRangerRequest request,) async {
    final data = await _client
        .from(ApiConstants.userProfilesTable)
        .update(request.toJson())
        .eq('id', id)
        .select()
        .single();

    return UserProfile.fromJson(data);
  }

  /// Toggle a ranger's active status.
  Future<UserProfile> toggleActive(String id, {required bool isActive}) async {
    final data = await _client
        .from(ApiConstants.userProfilesTable)
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return UserProfile.fromJson(data);
  }
}
