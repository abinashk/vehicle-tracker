import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/confirm_dialog.dart';

/// Screen displaying a list of all rangers with CRUD actions.
class RangerListScreen extends ConsumerStatefulWidget {
  const RangerListScreen({super.key});

  @override
  ConsumerState<RangerListScreen> createState() => _RangerListScreenState();
}

class _RangerListScreenState extends ConsumerState<RangerListScreen> {
  List<UserProfile> _rangers = [];
  Map<String, Checkpost> _checkposts = {};
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
      final rangerRepo = ref.read(rangerRepositoryProvider);
      final segmentRepo = ref.read(segmentRepositoryProvider);

      final results = await Future.wait<Object>([
        rangerRepo.listRangers(),
        segmentRepo.listCheckposts(),
      ]);

      final rangers = results[0] as List<UserProfile>;
      final checkposts = results[1] as List<Checkpost>;

      if (mounted) {
        setState(() {
          _rangers = rangers;
          _checkposts = {for (final cp in checkposts) cp.id: cp};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load rangers: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleActive(UserProfile ranger) async {
    final newStatus = !ranger.isActive;
    final action = newStatus ? 'activate' : 'deactivate';

    final confirmed = await ConfirmDialog.show(
      context: context,
      title: '${newStatus ? "Activate" : "Deactivate"} Ranger',
      message: 'Are you sure you want to $action ${ranger.fullName}?',
      confirmLabel: newStatus ? 'Activate' : 'Deactivate',
      confirmColor: newStatus ? AppTheme.successColor : AppTheme.errorColor,
      icon: newStatus ? Icons.check_circle : Icons.block,
    );

    if (confirmed != true) return;

    try {
      final rangerRepo = ref.read(rangerRepositoryProvider);
      await rangerRepo.toggleActive(ranger.id, isActive: newStatus);
      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${ranger.fullName} has been ${newStatus ? "activated" : "deactivated"}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rangers',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage ranger accounts and assignments.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.rangerCreate),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Ranger'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content.
        Expanded(
          child: _buildContent(),
        ),
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

    if (_rangers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No rangers found.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.rangerCreate),
              icon: const Icon(Icons.add),
              label: const Text('Create First Ranger'),
            ),
          ],
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Checkpost')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _rangers.map((ranger) => _buildRow(ranger)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(UserProfile ranger) {
    final checkpost = ranger.assignedCheckpostId != null
        ? _checkposts[ranger.assignedCheckpostId]
        : null;

    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ranger.fullName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                ranger.id.substring(0, 8),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(ranger.phoneNumber ?? '-')),
        DataCell(Text(checkpost?.name ?? 'Unassigned')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ranger.isActive
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ranger.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: ranger.isActive
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => context.go('/rangers/${ranger.id}/edit'),
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _toggleActive(ranger),
                icon: Icon(
                  ranger.isActive ? Icons.block : Icons.check_circle,
                  size: 18,
                  color: ranger.isActive
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
                tooltip: ranger.isActive ? 'Deactivate' : 'Activate',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
