import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/violation_repository.dart';

/// Alert screen that auto-appears when a violation is detected.
///
/// Displays:
/// - Large violation type indicator (SPEEDING / OVERSTAY)
/// - Vehicle details (plate, type)
/// - Calculated speed and threshold comparison
/// - Travel time details
/// - "RECORD OUTCOME" and "DISMISS" buttons
class AlertScreen extends ConsumerStatefulWidget {
  const AlertScreen({
    super.key,
    required this.violationId,
  });

  final String violationId;

  @override
  ConsumerState<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends ConsumerState<AlertScreen> {
  @override
  void initState() {
    super.initState();
    // Mark alert as delivered.
    ref
        .read(violationRepositoryProvider)
        .markAlertDelivered(widget.violationId);
  }

  @override
  void dispose() {
    // Stop any playing audio when leaving the screen.
    ref.read(audioAlertServiceProvider).stopAlert();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final violationStream = ref
        .watch(violationRepositoryProvider)
        .watchViolationById(widget.violationId);

    return Scaffold(
      body: StreamBuilder<Violation?>(
        stream: violationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.amber),
            );
          }

          final violation = snapshot.data!;
          return _buildAlertContent(violation);
        },
      ),
    );
  }

  Widget _buildAlertContent(Violation violation) {
    final isSpeeding = violation.isSpeeding;
    final alertColor = isSpeeding ? AppTheme.red : AppTheme.amber;
    final alertLabel = isSpeeding ? 'SPEEDING' : 'OVERSTAY';
    final alertIcon = isSpeeding ? Icons.speed : Icons.timer_off;

    // Display times in Nepal Time.
    final entryNpt =
        violation.entryTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    final exitNpt =
        violation.exitTime.toUtc().add(AppConstants.nepalTimezoneOffset);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Violation type banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: alertColor, width: 2),
              ),
              child: Column(
                children: [
                  Icon(alertIcon, size: 64, color: alertColor),
                  const SizedBox(height: 12),
                  Text(
                    alertLabel,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: alertColor,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Vehicle details
            _DetailRow(
              label: 'Plate Number',
              value: violation.plateNumber,
              valueStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Vehicle Type',
              value: violation.vehicleType.label,
            ),
            const Divider(height: 32, color: AppTheme.divider),

            // Speed comparison
            if (isSpeeding) ...[
              _DetailRow(
                label: 'Calculated Speed',
                value:
                    '${violation.calculatedSpeedKmh.toStringAsFixed(1)} km/h',
                valueColor: AppTheme.red,
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: 'Speed Limit',
                value: '${violation.speedLimitKmh.toStringAsFixed(0)} km/h',
              ),
            ],

            // Travel time details
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Travel Time',
              value: '${violation.travelTimeMinutes.toStringAsFixed(1)} min',
              valueColor: alertColor,
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: isSpeeding ? 'Minimum Expected' : 'Maximum Allowed',
              value: '${violation.thresholdMinutes.toStringAsFixed(1)} min',
            ),
            const Divider(height: 32, color: AppTheme.divider),

            // Entry and exit times
            _DetailRow(
              label: 'Entry Time',
              value: _formatTime(entryNpt),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Exit Time',
              value: _formatTime(exitNpt),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Distance',
              value: '${violation.distanceKm.toStringAsFixed(1)} km',
            ),

            const Spacer(),

            // Record outcome button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(audioAlertServiceProvider).stopAlert();
                  context.push(
                    AppRoutes.outcome,
                    extra: {'violationId': violation.id},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: alertColor,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.edit_note, size: 24),
                label: const Text(
                  'RECORD OUTCOME',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Dismiss button
            SizedBox(
              height: AppTheme.minTouchTarget,
              child: TextButton(
                onPressed: () {
                  ref.read(audioAlertServiceProvider).stopAlert();
                  context.go(AppRoutes.home);
                },
                child: const Text(
                  'DISMISS',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')} NPT';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: valueStyle ??
                TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimary,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
