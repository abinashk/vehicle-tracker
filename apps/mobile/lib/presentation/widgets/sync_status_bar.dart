import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/sync_repository.dart';

/// Sync status summary showing pending count and last sync time.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStateAsync = ref.watch(syncStateProvider);

    return syncStateAsync.when(
      data: (state) => _buildBar(state),
      loading: () => _buildBar(const SyncState()),
      error: (_, __) => _buildBar(const SyncState()),
    );
  }

  Widget _buildBar(SyncState state) {
    final hasPending = state.pendingCount > 0;
    final lastSyncText = state.lastSyncTime != null
        ? _formatLastSync(state.lastSyncTime!)
        : 'Never synced';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasPending ? Icons.sync : Icons.cloud_done,
            color: hasPending ? AppTheme.amber : AppTheme.green,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasPending
                      ? '${state.pendingCount} pending sync'
                      : 'All synced',
                  style: TextStyle(
                    color: hasPending ? AppTheme.amber : AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  lastSyncText,
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    // Display in Nepal Time (UTC+5:45).
    final nepalTime = lastSync.toUtc().add(AppConstants.nepalTimezoneOffset);
    final now = DateTime.now().toUtc().add(AppConstants.nepalTimezoneOffset);
    final diff = now.difference(nepalTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${nepalTime.hour.toString().padLeft(2, '0')}:${nepalTime.minute.toString().padLeft(2, '0')}';
  }
}
