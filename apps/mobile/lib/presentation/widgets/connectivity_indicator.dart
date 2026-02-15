import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';

/// Always-visible connectivity status indicator.
///
/// Shows a colored dot and label indicating online/offline status.
/// Designed for high visibility in outdoor conditions.
class ConnectivityIndicator extends ConsumerWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityStateProvider);

    return connectivityAsync.when(
      data: (state) => _buildIndicator(state),
      loading: () => _buildIndicator(ConnectivityState.offline),
      error: (_, __) => _buildIndicator(ConnectivityState.offline),
    );
  }

  Widget _buildIndicator(ConnectivityState state) {
    final isOnline = state == ConnectivityState.online;
    final color = isOnline ? AppTheme.green : AppTheme.red;
    final label = isOnline ? 'ONLINE' : 'OFFLINE';
    final icon = isOnline ? Icons.wifi : Icons.wifi_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
