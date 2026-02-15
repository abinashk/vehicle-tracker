import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/providers.dart';

/// Remote data source for vehicle passages using Supabase REST API.
///
/// All calls go through the repository layer - never called directly from UI.
class PassageRemoteSource {
  PassageRemoteSource({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Push a passage to the server.
  ///
  /// Returns the status code:
  /// - 201 = created successfully
  /// - 409 = duplicate (client_id already exists, treated as success)
  /// - Other = failure
  Future<int> pushPassage(VehiclePassage passage) async {
    try {
      await _client
          .from(ApiConstants.vehiclePassagesTable)
          .insert(passage.toInsertJson());
      return 201;
    } on PostgrestException catch (e) {
      // Check for unique constraint violation (duplicate client_id).
      if (e.code == '23505') {
        return 409;
      }
      rethrow;
    }
  }

  /// Pull unmatched passages from the opposite checkpost.
  ///
  /// Fetches entries that:
  /// - Belong to the same segment
  /// - Are from a different checkpost (opposite)
  /// - Are not yet matched
  /// - Were recorded after the cutoff timestamp
  Future<List<VehiclePassage>> pullOppositeCheckpostPassages({
    required String segmentId,
    required String myCheckpostId,
    required DateTime cutoff,
    int limit = 500,
  }) async {
    final response = await _client
        .from(ApiConstants.vehiclePassagesTable)
        .select()
        .eq('segment_id', segmentId)
        .neq('checkpost_id', myCheckpostId)
        .isFilter('matched_passage_id', null)
        .gte('recorded_at', cutoff.toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => VehiclePassage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Upload a photo to Supabase Storage.
  ///
  /// Non-blocking: failure does not affect passage recording.
  /// Returns the storage path on success, null on failure.
  Future<String?> uploadPhoto({
    required String passageId,
    required String localPath,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.length > AppConstants.maxPhotoSizeBytes) return null;

      final storagePath = '$passageId.jpg';
      await _client.storage
          .from(ApiConstants.photoBucket)
          .uploadBinary(storagePath, Uint8List.fromList(bytes));

      return storagePath;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the user's assigned checkpost details.
  Future<Checkpost?> getCheckpost(String checkpostId) async {
    try {
      final response = await _client
          .from(ApiConstants.checkpostsTable)
          .select()
          .eq('id', checkpostId)
          .single();
      return Checkpost.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Fetch the highway segment details.
  Future<HighwaySegment?> getSegment(String segmentId) async {
    try {
      final response = await _client
          .from(ApiConstants.highwaySegmentsTable)
          .select()
          .eq('id', segmentId)
          .single();
      return HighwaySegment.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the passage remote source.
final passageRemoteSourceProvider = Provider<PassageRemoteSource>((ref) {
  return PassageRemoteSource(client: ref.watch(supabaseClientProvider));
});
