import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/violation_repository.dart';

/// Outcome screen for recording the result of a violation encounter.
///
/// Features:
/// - Outcome type selector (warned, fined, let_go, not_found, other)
/// - Conditional fine amount field (appears when "fined" selected)
/// - Notes text field
/// - "SAVE" button
class OutcomeScreen extends ConsumerStatefulWidget {
  const OutcomeScreen({
    super.key,
    required this.violationId,
  });

  final String violationId;

  @override
  ConsumerState<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends ConsumerState<OutcomeScreen> {
  OutcomeType _selectedOutcome = OutcomeType.warned;
  final _fineController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _fineController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      double? fineAmount;
      if (_selectedOutcome == OutcomeType.fined) {
        final fineText = _fineController.text.trim();
        if (fineText.isNotEmpty) {
          fineAmount = double.tryParse(fineText);
          if (fineAmount == null || fineAmount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a valid fine amount'),
                backgroundColor: AppTheme.red,
              ),
            );
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final notes = _notesController.text.trim();

      await ref.read(violationRepositoryProvider).recordOutcome(
            violationId: widget.violationId,
            outcomeType: _selectedOutcome,
            fineAmount: fineAmount,
            notes: notes.isNotEmpty ? notes : null,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Outcome recorded: ${_selectedOutcome.label}'),
          backgroundColor: AppTheme.green,
        ),
      );
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving outcome: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Outcome'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Outcome type selector
              const Text(
                'Outcome',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...OutcomeType.values.map((type) {
                final isSelected = type == _selectedOutcome;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedOutcome = type),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: AppTheme.minTouchTarget,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.amber.withOpacity(0.15)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppTheme.amber, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _outcomeIcon(type),
                            color: isSelected
                                ? AppTheme.amber
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppTheme.amber
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppTheme.amber, size: 24),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Conditional fine amount field
              if (_selectedOutcome == OutcomeType.fined) ...[
                const SizedBox(height: 16),
                const Text(
                  'Fine Amount (NPR)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fineController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    hintText: 'Enter fine amount',
                    prefixIcon: Icon(Icons.attach_money, size: 24),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Notes field
              const Text(
                'Notes (optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Additional notes...',
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 24),
                  label: const Text(
                    'SAVE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _outcomeIcon(OutcomeType type) {
    switch (type) {
      case OutcomeType.warned:
        return Icons.warning_amber;
      case OutcomeType.fined:
        return Icons.receipt_long;
      case OutcomeType.letGo:
        return Icons.directions_car;
      case OutcomeType.notFound:
        return Icons.search_off;
      case OutcomeType.other:
        return Icons.more_horiz;
    }
  }
}
