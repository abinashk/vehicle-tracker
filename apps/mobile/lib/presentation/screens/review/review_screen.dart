import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/audio_alert_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/ocr_service.dart';
import '../../../domain/usecases/record_passage.dart';

/// Review screen showing captured photo and OCR-prefilled plate number.
///
/// Features:
/// - Photo display
/// - OCR pre-filled plate field (editable)
/// - Vehicle type selector (defaults to Car)
/// - "SUBMIT" button (56dp, green)
/// - "RETAKE" option
/// - Timestamp display
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.imagePath,
    required this.capturedAt,
  });

  final String imagePath;
  final DateTime capturedAt;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _plateController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.car;
  bool _isProcessingOcr = true;
  bool _isSubmitting = false;
  String? _rawOcrText;

  @override
  void initState() {
    super.initState();
    _runOcr();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _runOcr() async {
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final result = await ocrService.extractPlateNumber(widget.imagePath);

      if (result != null && mounted) {
        setState(() {
          _plateController.text = result.normalizedPlate;
          _rawOcrText = result.rawText;
          _isProcessingOcr = false;
        });
      } else {
        setState(() => _isProcessingOcr = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final plateText = _plateController.text.trim();
    if (plateText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plate number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final normalizedPlate = PlateNormalizer.normalize(plateText);

      final recordUseCase = ref.read(recordPassageUseCaseProvider);
      final result = await recordUseCase.execute(
        plateNumber: normalizedPlate,
        plateNumberRaw: _rawOcrText ?? plateText,
        vehicleType: _selectedVehicleType,
        recordedAt: widget.capturedAt,
        photoLocalPath: widget.imagePath,
      );

      if (!mounted) return;

      if (result.hasViolation) {
        // Play violation alert audio.
        final audioService = ref.read(audioAlertServiceProvider);
        await audioService.playViolationAlert(result.violation!.violationType);

        // Navigate to alert screen.
        context.go(
          AppRoutes.alert,
          extra: {'violationId': result.violation!.id},
        );
      } else {
        // Success - return to home.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded: $normalizedPlate (${_selectedVehicleType.label})',
            ),
            backgroundColor: AppTheme.green,
          ),
        );
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording passage: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display timestamp in Nepal Time (UTC+5:45).
    final nepalTime =
        widget.capturedAt.toUtc().add(AppConstants.nepalTimezoneOffset);
    final timeStr = '${nepalTime.hour.toString().padLeft(2, '0')}:'
        '${nepalTime.minute.toString().padLeft(2, '0')}:'
        '${nepalTime.second.toString().padLeft(2, '0')} NPT';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Captured photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.surface,
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: AppTheme.textHint),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Timestamp display
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Captured at $timeStr',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Plate number field
                Row(
                  children: [
                    const Text(
                      'Plate Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (_isProcessingOcr) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.amber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Reading plate...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'BA 1 PA 1234',
                    prefixIcon: Icon(Icons.directions_car, size: 24),
                  ),
                ),
                const SizedBox(height: 20),

                // Vehicle type selector
                const Text(
                  'Vehicle Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: VehicleType.values.map((type) {
                    final isSelected = type == _selectedVehicleType;
                    return ChoiceChip(
                      label: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isSelected ? Colors.black : AppTheme.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.amber,
                      backgroundColor: AppTheme.surfaceVariant,
                      onSelected: (_) {
                        setState(() => _selectedVehicleType = type);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    // Retake button
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : () => context.pop(),
                          icon: const Icon(Icons.camera_alt, size: 24),
                          label: const Text(
                            'RETAKE',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Submit button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 24),
                          label: const Text(
                            'SUBMIT',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
