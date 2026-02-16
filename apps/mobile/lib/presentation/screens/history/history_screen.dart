import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/passage_repository.dart';

/// Provider for the search query state.
final historySearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider that switches between all passages and filtered-by-plate passages.
final historyPassagesProvider = StreamProvider<List<VehiclePassage>>((ref) {
  final query = ref.watch(historySearchQueryProvider);
  final repo = ref.watch(passageRepositoryProvider);

  if (query.isEmpty) {
    return repo.watchRecentPassages(limit: 100);
  }
  return repo.watchPassagesByPlate(query);
});

/// History screen showing recent recordings with search/filter.
///
/// Features:
/// - List of recent recordings at this checkpost
/// - Filter/search by plate number
/// - Shows matched/unmatched status
/// - Shows violation status if applicable
/// - Tap to view details
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passagesAsync = ref.watch(historyPassagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search by plate number...',
                  prefixIcon: const Icon(Icons.search, size: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 24),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(historySearchQueryProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  ref.read(historySearchQueryProvider.notifier).state =
                      value.trim();
                },
              ),
            ),

            // Results list
            Expanded(
              child: passagesAsync.when(
                data: (passages) {
                  if (passages.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: AppTheme.textHint,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No recordings found',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: passages.length,
                    itemBuilder: (context, index) {
                      final passage = passages[index];
                      return _PassageListItem(passage: passage);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.amber),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading history: $e',
                    style: const TextStyle(
                      color: AppTheme.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassageListItem extends StatelessWidget {
  const _PassageListItem({required this.passage});

  final VehiclePassage passage;

  @override
  Widget build(BuildContext context) {
    final isMatched = passage.isMatched;
    final statusColor = isMatched ? AppTheme.green : AppTheme.textHint;
    final statusText = isMatched ? 'Matched' : 'Unmatched';

    // Display in Nepal Time.
    final nepalTime =
        passage.recordedAt.toUtc().add(AppConstants.nepalTimezoneOffset);
    final timeStr = '${nepalTime.hour.toString().padLeft(2, '0')}:'
        '${nepalTime.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${nepalTime.year}-${nepalTime.month.toString().padLeft(2, '0')}-'
        '${nepalTime.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to details or alert if violation exists.
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Vehicle type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.directions_car,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Passage details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passage.plateNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          passage.vehicleType.label,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dateStr $timeStr',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
