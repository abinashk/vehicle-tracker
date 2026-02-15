import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';

/// Screen displaying a list of highway segments with their configurations.
class SegmentListScreen extends ConsumerStatefulWidget {
  const SegmentListScreen({super.key});

  @override
  ConsumerState<SegmentListScreen> createState() => _SegmentListScreenState();
}

class _SegmentListScreenState extends ConsumerState<SegmentListScreen> {
  List<HighwaySegment> _segments = [];
  Map<String, List<Checkpost>> _checkpostsBySegment = {};
  String? _expandedSegmentId;
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
      final segmentRepo = ref.read(segmentRepositoryProvider);

      final results = await Future.wait([
        segmentRepo.listSegments(),
        segmentRepo.listCheckposts(),
      ]);

      final segments = results[0] as List<HighwaySegment>;
      final checkposts = results[1] as List<Checkpost>;

      final checkpostsBySegment = <String, List<Checkpost>>{};
      for (final cp in checkposts) {
        checkpostsBySegment.putIfAbsent(cp.segmentId, () => []).add(cp);
      }

      if (mounted) {
        setState(() {
          _segments = segments;
          _checkpostsBySegment = checkpostsBySegment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load segments: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header.
        Text(
          'Highway Segments',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure segment distances, speeds, and view checkposts.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

    if (_segments.isEmpty) {
      return const Center(child: Text('No segments configured.'));
    }

    return SingleChildScrollView(
      child: Column(
        children: _segments.map((segment) {
          final checkposts = _checkpostsBySegment[segment.id] ?? [];
          final isExpanded = _expandedSegmentId == segment.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                // Segment row.
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedSegmentId = isExpanded ? null : segment.id;
                    });
                  },
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.route,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                segment.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${segment.distanceKm.toStringAsFixed(1)} km'
                                ' | Speed: ${segment.minSpeedKmh.toStringAsFixed(0)}'
                                '-${segment.maxSpeedKmh.toStringAsFixed(0)} km/h',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Threshold info.
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Min: ${segment.minTravelTimeMinutes.toStringAsFixed(1)} min',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Max: ${segment.maxTravelTimeMinutes.toStringAsFixed(1)} min',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () =>
                              context.go('/segments/${segment.id}/edit'),
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit',
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded checkpost list.
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkposts (${checkposts.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (checkposts.isEmpty)
                          const Text('No checkposts configured.')
                        else
                          ...checkposts.map((cp) => _buildCheckpostTile(cp)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCheckpostTile(Checkpost cp) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${cp.positionIndex}',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cp.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Code: ${cp.code}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (cp.latitude != null && cp.longitude != null)
            Text(
              '${cp.latitude!.toStringAsFixed(4)}, ${cp.longitude!.toStringAsFixed(4)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cp.isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              cp.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: cp.isActive ? Colors.green : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
