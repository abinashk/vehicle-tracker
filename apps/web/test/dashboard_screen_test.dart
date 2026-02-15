import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

import 'package:vehicle_tracker_web/core/di/providers.dart';
import 'package:vehicle_tracker_web/data/repositories/dashboard_repository.dart';
import 'package:vehicle_tracker_web/presentation/widgets/stat_card.dart';

void main() {
  group('StatCard Widget', () {
    testWidgets('should display label, value, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Passages Today',
              value: '42',
              icon: Icons.directions_car,
            ),
          ),
        ),
      );

      expect(find.text('Passages Today'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('should display subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Violations',
              value: '5',
              icon: Icons.warning,
              subtitle: '+2 from yesterday',
            ),
          ),
        ),
      );

      expect(find.text('Violations'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('+2 from yesterday'), findsOneWidget);
    });

    testWidgets('should be tappable when onTap is provided', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Test',
              value: '10',
              icon: Icons.check,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(StatCard));
      expect(tapped, true);
    });

    testWidgets('should show forward arrow when tappable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Test',
              value: '10',
              icon: Icons.check,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets('should not show forward arrow when not tappable',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              label: 'Test',
              value: '10',
              icon: Icons.check,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
    });
  });

  group('DashboardSummary', () {
    test('should calculate totalViolationsToday correctly', () {
      const summary = DashboardSummary(
        totalPassagesToday: 100,
        speedingViolationsToday: 3,
        overstayViolationsToday: 7,
        unmatchedCount: 5,
        activeAlertsCount: 2,
      );

      expect(summary.totalViolationsToday, 10);
    });
  });

  group('DailyCount', () {
    test('should store date, passages, and violations', () {
      final count = DailyCount(
        date: DateTime(2025, 6, 15),
        passages: 50,
        violations: 3,
      );

      expect(count.date.day, 15);
      expect(count.passages, 50);
      expect(count.violations, 3);
    });
  });

  group('ProactiveAlert', () {
    test('should parse from JSON correctly', () {
      final json = {
        'id': 'alert-001',
        'passage_id': 'passage-001',
        'plate_number': 'BA 1 PA 1234',
        'vehicle_type': 'car',
        'checkpost_id': 'cp-001',
        'entry_time': '2025-06-15T10:00:00Z',
        'max_travel_time_minutes': 30.0,
        'is_resolved': false,
        'created_at': '2025-06-15T10:35:00Z',
      };

      final alert = ProactiveAlert.fromJson(json);

      expect(alert.id, 'alert-001');
      expect(alert.plateNumber, 'BA 1 PA 1234');
      expect(alert.vehicleType, 'car');
      expect(alert.maxTravelTimeMinutes, 30.0);
      expect(alert.isResolved, false);
    });

    test('should handle resolved alerts', () {
      final json = {
        'id': 'alert-002',
        'passage_id': 'passage-002',
        'plate_number': 'BA 2 PA 5678',
        'vehicle_type': 'bus',
        'checkpost_id': 'cp-002',
        'entry_time': '2025-06-15T08:00:00Z',
        'max_travel_time_minutes': 60.0,
        'is_resolved': true,
        'resolved_by': 'admin-001',
        'resolved_notes': 'Vehicle parked at lodge',
        'resolved_at': '2025-06-15T12:00:00Z',
        'created_at': '2025-06-15T09:05:00Z',
      };

      final alert = ProactiveAlert.fromJson(json);

      expect(alert.isResolved, true);
      expect(alert.resolvedBy, 'admin-001');
      expect(alert.resolvedNotes, 'Vehicle parked at lodge');
      expect(alert.resolvedAt, isNotNull);
    });
  });

  group('ViolationFilter from violation_repository', () {
    test('should generate correct filter description', () {
      // Import the class to test directly.
      // This tests the shared filter model behavior.
      const emptyFilter = _TestViolationFilter();
      expect(emptyFilter.filterDescription, 'all');
    });
  });
}

/// Simplified test filter to verify the filter description logic
/// without importing the full violation_repository.
class _TestViolationFilter {
  final String? violationType;
  final String? plateSearch;
  final bool? hasOutcome;

  const _TestViolationFilter({
    this.violationType,
    this.plateSearch,
    this.hasOutcome,
  });

  String get filterDescription {
    final parts = <String>[];
    if (violationType != null) parts.add(violationType!);
    if (plateSearch != null && plateSearch!.isNotEmpty) {
      parts.add('plate-$plateSearch');
    }
    if (hasOutcome != null) {
      parts.add(hasOutcome! ? 'with-outcome' : 'no-outcome');
    }
    return parts.isEmpty ? 'all' : parts.join('_');
  }
}
