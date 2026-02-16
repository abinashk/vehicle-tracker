import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';

/// Detail screen for viewing a single vehicle passage record.
class PassageDetailScreen extends ConsumerStatefulWidget {
  final String passageId;

  const PassageDetailScreen({super.key, required this.passageId});

  @override
  ConsumerState<PassageDetailScreen> createState() =>
      _PassageDetailScreenState();
}

class _PassageDetailScreenState extends ConsumerState<PassageDetailScreen> {
  VehiclePassage? _passage;
  Checkpost? _checkpost;
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
      final passageRepo = ref.read(passageRepositoryProvider);
      final segmentRepo = ref.read(segmentRepositoryProvider);

      final passage = await passageRepo.getPassage(widget.passageId);

      Checkpost? checkpost;
      HighwaySegment? segment;

      try {
        checkpost = await segmentRepo.getCheckpost(passage.checkpostId);
        segment = await segmentRepo.getSegment(passage.segmentId);
      } catch (_) {
        // Non-critical; continue without checkpost/segment details.
      }

      if (mounted) {
        setState(() {
          _passage = passage;
          _checkpost = checkpost;
          _segment = segment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load passage: $e';
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
                onPressed: () => context.go(RoutePaths.passages),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                'Passage Details',
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
                      size: 48, color: theme.colorScheme.error,),
                  const SizedBox(height: 12),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _loadData, child: const Text('Retry'),),
                ],
              ),
            )
          else if (_passage != null)
            _buildDetails(),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final passage = _passage!;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Plate Number', passage.plateNumber),
              _buildDetailRow('Vehicle Type', passage.vehicleType.label),
              _buildDetailRow(
                  'Checkpost', _checkpost?.name ?? passage.checkpostId,),
              _buildDetailRow('Segment', _segment?.name ?? passage.segmentId),
              _buildDetailRow(
                  'Recorded At', _formatNepalTime(passage.recordedAt),),
              if (passage.serverReceivedAt != null)
                _buildDetailRow('Server Received',
                    _formatNepalTime(passage.serverReceivedAt!),),
              _buildDetailRow('Source', passage.source.toUpperCase()),
              _buildDetailRow('Matched', passage.isMatched ? 'Yes' : 'No'),
              if (passage.matchedPassageId != null)
                _buildDetailRow(
                    'Matched Passage ID', passage.matchedPassageId!,),
              if (passage.isEntry != null)
                _buildDetailRow(
                    'Direction', passage.isEntry! ? 'Entry' : 'Exit',),
              _buildDetailRow('Ranger ID', passage.rangerId),
              if (passage.plateNumberRaw != null)
                _buildDetailRow('Raw Plate', passage.plateNumberRaw!),
              if (passage.photoPath != null)
                _buildDetailRow('Photo', passage.photoPath!),
              _buildDetailRow('ID', passage.id),
              _buildDetailRow('Client ID', passage.clientId),
              _buildDetailRow(
                  'Created At', _formatNepalTime(passage.createdAt)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
