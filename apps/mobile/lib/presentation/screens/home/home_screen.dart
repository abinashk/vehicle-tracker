import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/passage_repository.dart';
import '../../../data/repositories/violation_repository.dart';
import '../../widgets/connectivity_indicator.dart';
import '../../widgets/sync_status_bar.dart';

/// Provider for today's passage count.
final todaysPassageCountProvider = FutureProvider<int>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final checkpostId = authState.userProfile?.assignedCheckpostId;
  if (checkpostId == null) return 0;
  return ref.watch(passageRepositoryProvider).countTodaysPassages(checkpostId);
});

/// Provider for today's violation count.
final todaysViolationCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(violationRepositoryProvider).countTodaysViolations();
});

/// Home screen with primary "RECORD VEHICLE" action button.
///
/// Displays:
/// - Connectivity indicator (always visible)
/// - Sync status summary
/// - Today's stats (recordings, violations)
/// - Navigation to History
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final passageCount = ref.watch(todaysPassageCountProvider);
    final violationCount = ref.watch(todaysViolationCountProvider);
    final profile = authState.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Tracker'),
        actions: [
          const ConnectivityIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, size: 24),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ranger info
              if (profile != null) ...[
                Text(
                  'Welcome, ${profile.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Checkpost: ${profile.assignedCheckpostId ?? "Unassigned"}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sync status
              const SyncStatusBar(),
              const SizedBox(height: 24),

              // Today's stats
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Recordings Today',
                      value: passageCount.when(
                        data: (v) => v.toString(),
                        loading: () => '-',
                        error: (_, __) => '?',
                      ),
                      icon: Icons.camera_alt,
                      color: AppTheme.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Violations Today',
                      value: violationCount.when(
                        data: (v) => v.toString(),
                        loading: () => '-',
                        error: (_, __) => '?',
                      ),
                      icon: Icons.warning_amber,
                      color: AppTheme.red,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // History navigation
              SizedBox(
                height: AppTheme.minTouchTarget,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.history),
                  icon: const Icon(Icons.history, size: 24),
                  label: const Text(
                    'VIEW HISTORY',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Primary action: RECORD VEHICLE
              SizedBox(
                height: 72,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.capture),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 32),
                  label: const Text(
                    'RECORD VEHICLE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
