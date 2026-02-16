import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data class for updating highway segment parameters.
class UpdateSegmentRequest {
  final double distanceKm;
  final double maxSpeedKmh;
  final double minSpeedKmh;

  const UpdateSegmentRequest({
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.minSpeedKmh,
  });

  /// Calculate the minimum travel time (at max speed) in minutes.
  double get minTravelTimeMinutes => (distanceKm / maxSpeedKmh) * 60;

  /// Calculate the maximum travel time (at min speed) in minutes.
  double get maxTravelTimeMinutes => (distanceKm / minSpeedKmh) * 60;

  Map<String, dynamic> toJson() => {
        'distance_km': distanceKm,
        'max_speed_kmh': maxSpeedKmh,
        'min_speed_kmh': minSpeedKmh,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

/// Repository for highway segments and checkpost data access.
class SegmentRepository {
  final SupabaseClient _client;

  SegmentRepository(this._client);

  /// Fetch all highway segments ordered by name.
  Future<List<HighwaySegment>> listSegments() async {
    final data = await _client
        .from(ApiConstants.highwaySegmentsTable)
        .select()
        .order('name', ascending: true);

    return (data as List).map((e) => HighwaySegment.fromJson(e)).toList();
  }

  /// Fetch a single segment by ID.
  Future<HighwaySegment> getSegment(String id) async {
    final data = await _client
        .from(ApiConstants.highwaySegmentsTable)
        .select()
        .eq('id', id)
        .single();

    return HighwaySegment.fromJson(data);
  }

  /// Update segment distance and speed parameters.
  ///
  /// The database recalculates min_travel_time_minutes and
  /// max_travel_time_minutes via PostgreSQL generated columns.
  Future<HighwaySegment> updateSegment(
      String id, UpdateSegmentRequest request,) async {
    final data = await _client
        .from(ApiConstants.highwaySegmentsTable)
        .update(request.toJson())
        .eq('id', id)
        .select()
        .single();

    return HighwaySegment.fromJson(data);
  }

  /// Fetch all checkposts, optionally filtered by segment.
  Future<List<Checkpost>> listCheckposts({String? segmentId}) async {
    var query = _client.from(ApiConstants.checkpostsTable).select();

    if (segmentId != null) {
      query = query.eq('segment_id', segmentId);
    }

    final data = await query.order('position_index', ascending: true);

    return (data as List).map((e) => Checkpost.fromJson(e)).toList();
  }

  /// Fetch a single checkpost by ID.
  Future<Checkpost> getCheckpost(String id) async {
    final data = await _client
        .from(ApiConstants.checkpostsTable)
        .select()
        .eq('id', id)
        .single();

    return Checkpost.fromJson(data);
  }

  /// Fetch all parks.
  Future<List<Park>> listParks() async {
    final data = await _client
        .from(ApiConstants.parksTable)
        .select()
        .order('name', ascending: true);

    return (data as List).map((e) => Park.fromJson(e)).toList();
  }
}
