import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_repository.dart';

/// Repository for managing proactive overstay alerts.
///
/// Handles fetching unresolved alerts and resolving them with admin notes.
class AlertRepository {
  final SupabaseClient _client;

  AlertRepository(this._client);

  /// Fetch all active (unresolved) proactive overstay alerts.
  ///
  /// Ordered by oldest first (most overdue at top).
  Future<List<ProactiveAlert>> getActiveAlerts() async {
    final data = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .select()
        .eq('is_resolved', false)
        .order('entry_time', ascending: true);

    return (data as List).map((e) => ProactiveAlert.fromJson(e)).toList();
  }

  /// Fetch all alerts, including resolved ones.
  Future<List<ProactiveAlert>> getAllAlerts({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => ProactiveAlert.fromJson(e)).toList();
  }

  /// Resolve a proactive alert with admin notes.
  ///
  /// Marks the alert as resolved with the given notes and the current admin's ID.
  Future<ProactiveAlert> resolveAlert({
    required String alertId,
    required String resolvedBy,
    required String notes,
  }) async {
    final data = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .update({
          'is_resolved': true,
          'resolved_by': resolvedBy,
          'resolved_notes': notes,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', alertId)
        .select()
        .single();

    return ProactiveAlert.fromJson(data);
  }

  /// Get unmatched entries: passages with no matched_passage_id
  /// that are older than the max_travel_time of their segment.
  ///
  /// This fetches passages that are likely "stuck" (entered but never exited).
  Future<List<UnmatchedEntry>> getUnmatchedEntries() async {
    // Fetch unmatched passages.
    final passageData = await _client
        .from(ApiConstants.vehiclePassagesTable)
        .select()
        .isFilter('matched_passage_id', null)
        .order('recorded_at', ascending: true);

    final passages =
        (passageData as List).map((e) => VehiclePassage.fromJson(e)).toList();

    if (passages.isEmpty) return [];

    // Fetch segments for travel time thresholds.
    final segmentIds = passages.map((p) => p.segmentId).toSet().toList();
    final segmentData = await _client
        .from(ApiConstants.highwaySegmentsTable)
        .select()
        .inFilter('id', segmentIds);

    final segments = <String, HighwaySegment>{};
    for (final item in segmentData as List) {
      final segment = HighwaySegment.fromJson(item);
      segments[segment.id] = segment;
    }

    // Filter to passages that have exceeded max travel time.
    final now = DateTime.now().toUtc();
    final unmatched = <UnmatchedEntry>[];

    for (final passage in passages) {
      final segment = segments[passage.segmentId];
      if (segment == null) continue;

      final elapsed =
          now.difference(passage.recordedAt.toUtc()).inSeconds / 60.0;

      if (elapsed > segment.maxTravelTimeMinutes) {
        unmatched.add(UnmatchedEntry(
          passage: passage,
          segment: segment,
          minutesElapsed: elapsed,
        ));
      }
    }

    return unmatched;
  }

  /// Resolve an unmatched entry by marking it with admin notes.
  ///
  /// This creates or updates a record in the proactive_overstay_alerts table
  /// for tracking purposes.
  Future<void> resolveUnmatchedEntry({
    required String passageId,
    required String resolvedBy,
    required String notes,
  }) async {
    // Check if there's an existing alert for this passage.
    final existing = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .select()
        .eq('passage_id', passageId)
        .maybeSingle();

    if (existing != null) {
      await _client.from(ApiConstants.proactiveOverstayAlertsTable).update({
        'is_resolved': true,
        'resolved_by': resolvedBy,
        'resolved_notes': notes,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('passage_id', passageId);
    } else {
      // Create a new resolved alert record for tracking.
      await _client.from(ApiConstants.proactiveOverstayAlertsTable).insert({
        'passage_id': passageId,
        'plate_number': '', // Will be filled by the passage data.
        'vehicle_type': '',
        'checkpost_id': '',
        'entry_time': DateTime.now().toUtc().toIso8601String(),
        'max_travel_time_minutes': 0,
        'is_resolved': true,
        'resolved_by': resolvedBy,
        'resolved_notes': notes,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}

/// An unmatched passage entry with segment context.
class UnmatchedEntry {
  final VehiclePassage passage;
  final HighwaySegment segment;
  final double minutesElapsed;

  const UnmatchedEntry({
    required this.passage,
    required this.segment,
    required this.minutesElapsed,
  });

  /// Minutes over the maximum travel time threshold.
  double get minutesOverThreshold =>
      minutesElapsed - segment.maxTravelTimeMinutes;
}
