import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/violation_repository.dart';

/// Detail screen showing full violation information including entry/exit passages.
class ViolationDetailScreen extends ConsumerStatefulWidget {
  final String violationId;

  const ViolationDetailScreen({super.key, required this.violationId});

  @override
  ConsumerState<ViolationDetailScreen> createState() =>
      _ViolationDetailScreenState();
}

class _ViolationDetailScreenState extends ConsumerState<ViolationDetailScreen> {
  ViolationWithOutcome? _data;
  VehiclePassage? _entryPassage;
  VehiclePassage? _exitPassage;
  HighwaySegment? _segment;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final violationRepo = ref.read(violationRepositoryProvider);
      final passageRepo = ref.read(passageRepositoryProvider);
      final segmentRepo = ref.read(segmentRepositoryProvider);

      final data = await violationRepo.getViolation(widget.violationId);

      VehiclePassage? entryPassage;
      VehiclePassage? exitPassage;
      HighwaySegment? segment;

      try {
        entryPassage =
            await passageRepo.getPassage(data.violation.entryPassageId);
        exitPassage =
            await passageRepo.getPassage(data.violation.exitPassageId);
        segment = await segmentRepo.getSegment(data.violation.segmentId);
      } catch (_) {
        // Non-critical; continue without passage/segment details.
      }

      if (mounted) {
        setState(() {
          _data = data;
          _entryPassage = entryPassage;
          _exitPassage = exitPassage;
          _segment = segment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load violation: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatNepalTime(DateTime utcTime) {
    final nepalTime = utcTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(nepalTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title.
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(RoutePaths.violations),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                'Violation Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _loadData, child: const Text('Retry')),
                ],
              ),
            )
          else if (_data != null)
            _buildDetails(),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final theme = Theme.of(context);
    final v = _data!.violation;
    final outcome = _data!.outcome;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Violation summary card.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildViolationTypeBadge(v.violationType),
                      const SizedBox(width: 12),
                      Text(
                        v.plateNumber,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        v.vehicleType.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildDetailRow('Segment', _segment?.name ?? v.segmentId),
                  _buildDetailRow(
                      'Distance', '${v.distanceKm.toStringAsFixed(2)} km'),
                  _buildDetailRow('Travel Time',
                      '${v.travelTimeMinutes.toStringAsFixed(1)} min'),
                  _buildDetailRow('Threshold',
                      '${v.thresholdMinutes.toStringAsFixed(1)} min'),
                  _buildDetailRow('Calculated Speed',
                      '${v.calculatedSpeedKmh.toStringAsFixed(1)} km/h'),
                  _buildDetailRow('Speed Limit',
                      '${v.speedLimitKmh.toStringAsFixed(1)} km/h'),
                  _buildDetailRow('Entry Time', _formatNepalTime(v.entryTime)),
                  _buildDetailRow('Exit Time', _formatNepalTime(v.exitTime)),
                  _buildDetailRow(
                      'Difference',
                      '${v.thresholdDifferenceMinutes.toStringAsFixed(1)} min '
                          '${v.isSpeeding ? "under" : "over"} threshold'),
                  _buildDetailRow('Created At', _formatNepalTime(v.createdAt)),
                  _buildDetailRow('Violation ID', v.id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Entry/Exit passage info.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child:
                            _buildPassageCard('Entry Passage', _entryPassage)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildPassageCard('Exit Passage', _exitPassage)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildPassageCard('Entry Passage', _entryPassage),
                  const SizedBox(height: 16),
                  _buildPassageCard('Exit Passage', _exitPassage),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Outcome card.
          _buildOutcomeCard(outcome),
        ],
      ),
    );
  }

  Widget _buildPassageCard(String title, VehiclePassage? passage) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (passage == null)
              Text(
                'Passage details not available.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else ...[
              _buildDetailRow('Plate', passage.plateNumber),
              _buildDetailRow('Time', _formatNepalTime(passage.recordedAt)),
              _buildDetailRow('Source', passage.source.toUpperCase()),
              _buildDetailRow('Ranger', passage.rangerId.substring(0, 8)),
              _buildDetailRow('ID', passage.id.substring(0, 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeCard(ViolationOutcome? outcome) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Outcome',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (outcome != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.outcomeColor(outcome.outcomeType.value)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      outcome.outcomeType.label,
                      style: TextStyle(
                        color: AppTheme.outcomeColor(outcome.outcomeType.value),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (outcome == null)
              Text(
                'No outcome recorded yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else ...[
              _buildDetailRow('Type', outcome.outcomeType.label),
              if (outcome.fineAmount != null)
                _buildDetailRow('Fine Amount',
                    'Rs. ${outcome.fineAmount!.toStringAsFixed(2)}'),
              if (outcome.notes != null)
                _buildDetailRow('Notes', outcome.notes!),
              _buildDetailRow(
                  'Recorded At', _formatNepalTime(outcome.recordedAt)),
              _buildDetailRow('Recorded By', outcome.recordedBy),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViolationTypeBadge(ViolationType type) {
    final color = AppTheme.violationColor(type.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
