import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../widgets/stat_card.dart';

/// Main dashboard screen showing today's summary, 7-day chart,
/// and live proactive alerts.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardSummary? _summary;
  List<DailyCount> _dailyCounts = [];
  List<ProactiveAlert> _activeAlerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  RealtimeChannel? _violationsChannel;
  RealtimeChannel? _alertsChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscriptions();
    // Refresh summary every 60 seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshSummary(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Remove channels directly — cannot use ref.read() during dispose.
    final client = Supabase.instance.client;
    if (_violationsChannel != null) {
      client.removeChannel(_violationsChannel!);
    }
    if (_alertsChannel != null) {
      client.removeChannel(_alertsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dashboardRepo = ref.read(dashboardRepositoryProvider);

      final results = await Future.wait<Object>([
        dashboardRepo.getTodaySummary(),
        dashboardRepo.getLast7DaysCounts(),
        dashboardRepo.getActiveAlerts(),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as DashboardSummary;
          _dailyCounts = results[1] as List<DailyCount>;
          _activeAlerts = results[2] as List<ProactiveAlert>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dashboard data: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSummary() async {
    try {
      final dashboardRepo = ref.read(dashboardRepositoryProvider);
      final summary = await dashboardRepo.getTodaySummary();
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (_) {
      // Silent refresh failure.
    }
  }

  void _setupRealtimeSubscriptions() {
    final dashboardRepo = ref.read(dashboardRepositoryProvider);

    _violationsChannel = dashboardRepo.subscribeToViolations(
      onInsert: (payload) {
        // Refresh summary when a new violation comes in.
        _refreshSummary();
      },
    );

    _alertsChannel = dashboardRepo.subscribeToAlerts(
      onInsert: (payload) {
        final alert = ProactiveAlert.fromJson(payload);
        if (mounted) {
          setState(() {
            _activeAlerts.insert(0, alert);
          });
          _refreshSummary();
        }
      },
      onUpdate: (payload) {
        final updated = ProactiveAlert.fromJson(payload);
        if (mounted) {
          setState(() {
            if (updated.isResolved) {
              _activeAlerts.removeWhere((a) => a.id == updated.id);
            } else {
              final index = _activeAlerts.indexWhere((a) => a.id == updated.id);
              if (index >= 0) {
                _activeAlerts[index] = updated;
              }
            }
          });
          _refreshSummary();
        }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title.
            Text(
              'Dashboard',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Overview of today\'s activity and system status.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Summary cards.
            _buildSummaryCards(),
            const SizedBox(height: 24),

            // Chart and alerts side by side.
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildChart()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildAlertsPanel()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildChart(),
                    const SizedBox(height: 24),
                    _buildAlertsPanel(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();

    final cards = [
      StatCard(
        key: const ValueKey('passages'),
        label: 'Passages Today',
        value: summary.totalPassagesToday.toString(),
        icon: Icons.directions_car,
        iconColor: Colors.blue,
        onTap: () => context.go(RoutePaths.passages),
      ),
      StatCard(
        key: const ValueKey('speeding'),
        label: 'Speeding',
        value: summary.speedingViolationsToday.toString(),
        icon: Icons.speed,
        iconColor: AppTheme.errorColor,
        onTap: () => context.go(RoutePaths.violations),
      ),
      StatCard(
        key: const ValueKey('overstay'),
        label: 'Overstay',
        value: summary.overstayViolationsToday.toString(),
        icon: Icons.timer_off,
        iconColor: AppTheme.warningColor,
        onTap: () => context.go(RoutePaths.violations),
      ),
      StatCard(
        key: const ValueKey('unmatched'),
        label: 'Unmatched',
        value: summary.unmatchedCount.toString(),
        icon: Icons.help_outline,
        iconColor: Colors.orange,
        onTap: () => context.go(RoutePaths.unmatched),
      ),
      StatCard(
        key: const ValueKey('alerts'),
        label: 'Active Alerts',
        value: summary.activeAlertsCount.toString(),
        icon: Icons.notifications_active,
        iconColor: AppTheme.errorColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 1000
            ? (constraints.maxWidth - 64) / 5
            : constraints.maxWidth > 700
                ? (constraints.maxWidth - 32) / 3
                : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) {
            return SizedBox(
              width: cardWidth,
              height: cardWidth / 1.4,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChart() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 Days',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Daily passages and violations',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: _dailyCounts.isEmpty
                  ? const Center(child: Text('No data available'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _calculateMaxY(),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = _dailyCounts[groupIndex];
                              final label = rodIndex == 0
                                  ? 'Passages: ${day.passages}'
                                  : 'Violations: ${day.violations}';
                              return BarTooltipItem(
                                label,
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= _dailyCounts.length) {
                                  return const SizedBox.shrink();
                                }
                                final date = _dailyCounts[index].date;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat('E').format(date),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _calculateMaxY() / 5,
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _dailyCounts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: data.passages.toDouble(),
                                color: theme.colorScheme.primary,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              BarChartRodData(
                                toY: data.violations.toDouble(),
                                color: AppTheme.errorColor,
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Legend.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Passages', theme.colorScheme.primary),
                const SizedBox(width: 24),
                _buildLegendItem('Violations', AppTheme.errorColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _calculateMaxY() {
    if (_dailyCounts.isEmpty) return 10;
    final maxPassages =
        _dailyCounts.map((d) => d.passages).reduce((a, b) => a > b ? a : b);
    final maxViolations =
        _dailyCounts.map((d) => d.violations).reduce((a, b) => a > b ? a : b);
    final max = maxPassages > maxViolations ? maxPassages : maxViolations;
    return (max * 1.2).ceilToDouble().clamp(10, double.infinity);
  }

  Widget _buildAlertsPanel() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _activeAlerts.isEmpty
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeAlerts.length}',
                    style: TextStyle(
                      color: _activeAlerts.isEmpty
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Vehicles exceeding max travel time',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            if (_activeAlerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 40,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active alerts',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount:
                    _activeAlerts.length > 10 ? 10 : _activeAlerts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final alert = _activeAlerts[index];
                  return _buildAlertTile(alert);
                },
              ),
            if (_activeAlerts.length > 10) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go(RoutePaths.unmatched),
                  child: Text('View all ${_activeAlerts.length} alerts'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(ProactiveAlert alert) {
    final theme = Theme.of(context);
    final overMinutes = alert.minutesOverThreshold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: overMinutes > 60
                  ? AppTheme.errorColor
                  : AppTheme.warningColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.plateNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${VehicleType.fromValue(alert.vehicleType).label}'
                  ' - ${overMinutes.toStringAsFixed(0)} min over limit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatNepalTime(alert.entryTime),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNepalTime(DateTime utcTime) {
    final nepalTime = utcTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    return DateFormat('HH:mm').format(nepalTime);
  }
}
