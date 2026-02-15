import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/segment_repository.dart';

/// Screen for editing a highway segment's distance and speed parameters.
///
/// Shows a live preview of the calculated travel time thresholds.
class SegmentEditScreen extends ConsumerStatefulWidget {
  final String segmentId;

  const SegmentEditScreen({super.key, required this.segmentId});

  @override
  ConsumerState<SegmentEditScreen> createState() => _SegmentEditScreenState();
}

class _SegmentEditScreenState extends ConsumerState<SegmentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _maxSpeedController = TextEditingController();
  final _minSpeedController = TextEditingController();

  HighwaySegment? _segment;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  // Live threshold preview values.
  double _previewMinTravelTime = 0;
  double _previewMaxTravelTime = 0;

  @override
  void initState() {
    super.initState();
    _loadSegment();

    // Add listeners for live threshold preview.
    _distanceController.addListener(_updatePreview);
    _maxSpeedController.addListener(_updatePreview);
    _minSpeedController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _maxSpeedController.dispose();
    _minSpeedController.dispose();
    super.dispose();
  }

  Future<void> _loadSegment() async {
    try {
      final segmentRepo = ref.read(segmentRepositoryProvider);
      final segment = await segmentRepo.getSegment(widget.segmentId);

      if (mounted) {
        setState(() {
          _segment = segment;
          _distanceController.text = segment.distanceKm.toString();
          _maxSpeedController.text = segment.maxSpeedKmh.toString();
          _minSpeedController.text = segment.minSpeedKmh.toString();
          _isInitialLoading = false;
        });
        _updatePreview();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load segment: $e';
          _isInitialLoading = false;
        });
      }
    }
  }

  void _updatePreview() {
    final distance = double.tryParse(_distanceController.text);
    final maxSpeed = double.tryParse(_maxSpeedController.text);
    final minSpeed = double.tryParse(_minSpeedController.text);

    if (distance != null &&
        distance > 0 &&
        maxSpeed != null &&
        maxSpeed > 0 &&
        minSpeed != null &&
        minSpeed > 0) {
      setState(() {
        _previewMinTravelTime = (distance / maxSpeed) * 60;
        _previewMaxTravelTime = (distance / minSpeed) * 60;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final segmentRepo = ref.read(segmentRepositoryProvider);

      await segmentRepo.updateSegment(
        widget.segmentId,
        UpdateSegmentRequest(
          distanceKm: double.parse(_distanceController.text),
          maxSpeedKmh: double.parse(_maxSpeedController.text),
          minSpeedKmh: double.parse(_minSpeedController.text),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segment updated successfully.')),
        );
        context.go(RoutePaths.segments);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update segment: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title.
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(RoutePaths.segments),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                'Edit Segment',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_segment != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                _segment!.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Form and preview side by side on desktop.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildForm()),
                    const SizedBox(width: 24),
                    SizedBox(width: 300, child: _buildPreviewPanel()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildForm(),
                  const SizedBox(height: 24),
                  _buildPreviewPanel(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Segment Parameters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Error banner.
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Distance.
              TextFormField(
                controller: _distanceController,
                decoration: const InputDecoration(
                  labelText: 'Distance (km)',
                  prefixIcon: Icon(Icons.straighten),
                  suffixText: 'km',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Distance is required';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Must be a positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Max speed.
              TextFormField(
                controller: _maxSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Maximum Speed (speed limit)',
                  prefixIcon: Icon(Icons.speed),
                  suffixText: 'km/h',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Maximum speed is required';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Must be a positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Min speed.
              TextFormField(
                controller: _minSpeedController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Speed (overstay threshold)',
                  prefixIcon: Icon(Icons.slow_motion_video),
                  suffixText: 'km/h',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Minimum speed is required';
                  }
                  final num = double.tryParse(value);
                  if (num == null || num <= 0) {
                    return 'Must be a positive number';
                  }
                  final maxSpeed = double.tryParse(_maxSpeedController.text);
                  if (maxSpeed != null && num >= maxSpeed) {
                    return 'Must be less than maximum speed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit button.
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primary.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Live Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Calculated Thresholds',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Min travel time (speeding threshold).
            _buildPreviewRow(
              label: 'Min Travel Time',
              value: '${_previewMinTravelTime.toStringAsFixed(1)} min',
              description: 'Faster = speeding violation',
              color: AppTheme.errorColor,
              icon: Icons.speed,
            ),
            const SizedBox(height: 16),

            // Max travel time (overstay threshold).
            _buildPreviewRow(
              label: 'Max Travel Time',
              value: '${_previewMaxTravelTime.toStringAsFixed(1)} min',
              description: 'Slower = overstay violation',
              color: AppTheme.warningColor,
              icon: Icons.timer_off,
            ),

            if (_segment != null) ...[
              const Divider(height: 32),
              Text(
                'Current Values',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Min: ${_segment!.minTravelTimeMinutes.toStringAsFixed(1)} min',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Max: ${_segment!.maxTravelTimeMinutes.toStringAsFixed(1)} min',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow({
    required String label,
    required String value,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
