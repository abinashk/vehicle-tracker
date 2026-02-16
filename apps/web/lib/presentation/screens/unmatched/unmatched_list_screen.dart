import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/alert_repository.dart';

/// Screen displaying unmatched entries (vehicles that entered but never exited).
///
/// Entries are sorted by oldest first (most overdue at top).
/// Admin can resolve entries with notes.
class UnmatchedListScreen extends ConsumerStatefulWidget {
  const UnmatchedListScreen({super.key});

  @override
  ConsumerState<UnmatchedListScreen> createState() =>
      _UnmatchedListScreenState();
}

class _UnmatchedListScreenState extends ConsumerState<UnmatchedListScreen> {
  List<UnmatchedEntry> _entries = [];
  Map<String, Checkpost> _checkpostMap = {};
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
      final alertRepo = ref.read(alertRepositoryProvider);
      final segmentRepo = ref.read(segmentRepositoryProvider);

      final results = await Future.wait<Object>([
        alertRepo.getUnmatchedEntries(),
        segmentRepo.listCheckposts(),
      ]);

      final entries = results[0] as List<UnmatchedEntry>;
      final checkposts = results[1] as List<Checkpost>;

      if (mounted) {
        setState(() {
          _entries = entries;
          _checkpostMap = {for (final cp in checkposts) cp.id: cp};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load unmatched entries: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveEntry(UnmatchedEntry entry) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Unmatched Entry'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plate: ${entry.passage.plateNumber}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Vehicle: ${entry.passage.vehicleType.label}',
              ),
              Text(
                'Elapsed: ${entry.minutesElapsed.toStringAsFixed(0)} min '
                '(${entry.minutesOverThreshold.toStringAsFixed(0)} min over limit)',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Resolution Notes',
                  hintText:
                      'e.g., Vehicle parked at lodge, false plate read...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide resolution notes.'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      notesController.dispose();
      return;
    }

    try {
      final alertRepo = ref.read(alertRepositoryProvider);
      final authState = ref.read(authStateProvider);
      final adminId = authState.valueOrNull?.id ?? 'unknown';

      await alertRepo.resolveUnmatchedEntry(
        passageId: entry.passage.id,
        resolvedBy: adminId,
        notes: notesController.text.trim(),
      );

      notesController.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry resolved successfully.')),
        );
        _loadData();
      }
    } catch (e) {
      notesController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatNepalTime(DateTime utcTime) {
    final nepalTime = utcTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    return DateFormat('yyyy-MM-dd HH:mm').format(nepalTime);
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).toStringAsFixed(0);
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unmatched Entries',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vehicles that entered but never exited (past max travel time).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content.
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
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
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: AppTheme.successColor,),
            const SizedBox(height: 12),
            Text(
              'No unmatched entries!',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'All vehicles have been accounted for.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Plate')),
              DataColumn(label: Text('Vehicle Type')),
              DataColumn(label: Text('Checkpost')),
              DataColumn(label: Text('Recorded At')),
              DataColumn(label: Text('Elapsed')),
              DataColumn(label: Text('Over Limit')),
              DataColumn(label: Text('Action')),
            ],
            rows: _entries.map((entry) {
              final checkpost = _checkpostMap[entry.passage.checkpostId];

              return DataRow(
                cells: [
                  DataCell(Text(
                    entry.passage.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),),
                  DataCell(Text(entry.passage.vehicleType.label)),
                  DataCell(Text(checkpost?.name ??
                      entry.passage.checkpostId.substring(0, 8),),),
                  DataCell(Text(_formatNepalTime(entry.passage.recordedAt))),
                  DataCell(Text(_formatDuration(entry.minutesElapsed))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: entry.minutesOverThreshold > 60
                            ? AppTheme.errorColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${_formatDuration(entry.minutesOverThreshold)}',
                        style: TextStyle(
                          color: entry.minutesOverThreshold > 60
                              ? AppTheme.errorColor
                              : AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    ElevatedButton.icon(
                      onPressed: () => _resolveEntry(entry),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8,),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
