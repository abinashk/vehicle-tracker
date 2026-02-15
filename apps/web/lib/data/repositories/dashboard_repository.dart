import 'dart:async';

import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Summary statistics for the dashboard.
class DashboardSummary {
  final int totalPassagesToday;
  final int speedingViolationsToday;
  final int overstayViolationsToday;
  final int unmatchedCount;
  final int activeAlertsCount;

  const DashboardSummary({
    required this.totalPassagesToday,
    required this.speedingViolationsToday,
    required this.overstayViolationsToday,
    required this.unmatchedCount,
    required this.activeAlertsCount,
  });

  int get totalViolationsToday =>
      speedingViolationsToday + overstayViolationsToday;
}

/// Daily count data for charts.
class DailyCount {
  final DateTime date;
  final int passages;
  final int violations;

  const DailyCount({
    required this.date,
    required this.passages,
    required this.violations,
  });
}

/// A proactive overstay alert for a vehicle that has exceeded max travel time.
class ProactiveAlert {
  final String id;
  final String passageId;
  final String plateNumber;
  final String vehicleType;
  final String checkpostId;
  final DateTime entryTime;
  final double maxTravelTimeMinutes;
  final bool isResolved;
  final String? resolvedBy;
  final String? resolvedNotes;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const ProactiveAlert({
    required this.id,
    required this.passageId,
    required this.plateNumber,
    required this.vehicleType,
    required this.checkpostId,
    required this.entryTime,
    required this.maxTravelTimeMinutes,
    required this.isResolved,
    this.resolvedBy,
    this.resolvedNotes,
    this.resolvedAt,
    required this.createdAt,
  });

  factory ProactiveAlert.fromJson(Map<String, dynamic> json) {
    return ProactiveAlert(
      id: json['id'] as String,
      passageId: json['passage_id'] as String,
      plateNumber: json['plate_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      checkpostId: json['checkpost_id'] as String,
      entryTime: DateTime.parse(json['entry_time'] as String),
      maxTravelTimeMinutes: (json['max_travel_time_minutes'] as num).toDouble(),
      isResolved: json['is_resolved'] as bool? ?? false,
      resolvedBy: json['resolved_by'] as String?,
      resolvedNotes: json['resolved_notes'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Minutes elapsed since entry.
  double get minutesElapsed {
    final now = DateTime.now().toUtc();
    return now.difference(entryTime.toUtc()).inSeconds / 60.0;
  }

  /// How many minutes over the threshold.
  double get minutesOverThreshold => minutesElapsed - maxTravelTimeMinutes;
}

/// Repository for dashboard aggregated data and Realtime subscriptions.
class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  /// Fetch today's summary statistics.
  Future<DashboardSummary> getTodaySummary() async {
    final todayStart = _todayStartUtc();
    final todayEnd = _todayEndUtc();

    // Fetch counts in parallel.
    final results = await Future.wait([
      _countPassagesToday(todayStart, todayEnd),
      _countViolationsToday(todayStart, todayEnd, ViolationType.speeding),
      _countViolationsToday(todayStart, todayEnd, ViolationType.overstay),
      _countUnmatched(),
      _countActiveAlerts(),
    ]);

    return DashboardSummary(
      totalPassagesToday: results[0],
      speedingViolationsToday: results[1],
      overstayViolationsToday: results[2],
      unmatchedCount: results[3],
      activeAlertsCount: results[4],
    );
  }

  /// Fetch daily passage and violation counts for the last 7 days.
  Future<List<DailyCount>> getLast7DaysCounts() async {
    final counts = <DailyCount>[];
    final now = DateTime.now().toUtc();

    for (int i = 6; i >= 0; i--) {
      final date = DateTime.utc(now.year, now.month, now.day - i);
      final dayStart = date;
      final dayEnd = date.add(const Duration(days: 1));

      final passageCount = await _client
          .from(ApiConstants.vehiclePassagesTable)
          .select(
              'id', const FetchOptions(count: CountOption.exact, head: true))
          .gte('recorded_at', dayStart.toIso8601String())
          .lt('recorded_at', dayEnd.toIso8601String())
          .count(CountOption.exact);

      final violationCount = await _client
          .from(ApiConstants.violationsTable)
          .select(
              'id', const FetchOptions(count: CountOption.exact, head: true))
          .gte('created_at', dayStart.toIso8601String())
          .lt('created_at', dayEnd.toIso8601String())
          .count(CountOption.exact);

      counts.add(DailyCount(
        date: date,
        passages: passageCount.count,
        violations: violationCount.count,
      ));
    }

    return counts;
  }

  /// Fetch active (unresolved) proactive overstay alerts.
  Future<List<ProactiveAlert>> getActiveAlerts() async {
    final data = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .select()
        .eq('is_resolved', false)
        .order('created_at', ascending: false);

    return (data as List).map((e) => ProactiveAlert.fromJson(e)).toList();
  }

  /// Subscribe to real-time changes on the violations table.
  ///
  /// Returns a RealtimeChannel that can be unsubscribed.
  RealtimeChannel subscribeToViolations({
    required void Function(Map<String, dynamic> payload) onInsert,
  }) {
    return _client
        .channel('violations-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: ApiConstants.violationsTable,
          callback: (payload) {
            onInsert(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Subscribe to real-time changes on the proactive_overstay_alerts table.
  ///
  /// Returns a RealtimeChannel that can be unsubscribed.
  RealtimeChannel subscribeToAlerts({
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    return _client
        .channel('alerts-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: ApiConstants.proactiveOverstayAlertsTable,
          callback: (payload) {
            onInsert(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: ApiConstants.proactiveOverstayAlertsTable,
          callback: (payload) {
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Unsubscribe from a realtime channel.
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  DateTime _todayStartUtc() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  DateTime _todayEndUtc() {
    return _todayStartUtc().add(const Duration(days: 1));
  }

  Future<int> _countPassagesToday(DateTime start, DateTime end) async {
    final response = await _client
        .from(ApiConstants.vehiclePassagesTable)
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .gte('recorded_at', start.toIso8601String())
        .lt('recorded_at', end.toIso8601String())
        .count(CountOption.exact);

    return response.count;
  }

  Future<int> _countViolationsToday(
    DateTime start,
    DateTime end,
    ViolationType type,
  ) async {
    final response = await _client
        .from(ApiConstants.violationsTable)
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('violation_type', type.value)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String())
        .count(CountOption.exact);

    return response.count;
  }

  Future<int> _countUnmatched() async {
    final response = await _client
        .from(ApiConstants.vehiclePassagesTable)
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .isFilter('matched_passage_id', null)
        .count(CountOption.exact);

    return response.count;
  }

  Future<int> _countActiveAlerts() async {
    final response = await _client
        .from(ApiConstants.proactiveOverstayAlertsTable)
        .select('id', const FetchOptions(count: CountOption.exact, head: true))
        .eq('is_resolved', false)
        .count(CountOption.exact);

    return response.count;
  }
}
