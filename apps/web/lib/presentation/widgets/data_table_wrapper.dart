import 'package:flutter/material.dart';

/// A reusable paginated data table wrapper with filter support.
///
/// Wraps a DataTable with pagination controls and an optional filter bar.
class DataTableWrapper extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<int>? onPageChanged;
  final Widget? filterBar;
  final List<Widget>? actions;
  final String title;

  const DataTableWrapper({
    super.key,
    required this.columns,
    required this.rows,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    this.isLoading = false,
    this.errorMessage,
    this.onPageChanged,
    this.filterBar,
    this.actions,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title bar with actions.
        if (title.isNotEmpty || (actions != null && actions!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
          ),

        // Filter bar.
        if (filterBar != null) ...[
          filterBar!,
          const SizedBox(height: 16),
        ],

        // Error message.
        if (errorMessage != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Data table.
        if (errorMessage == null)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isLoading)
                  const LinearProgressIndicator()
                else
                  const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns,
                    rows: rows,
                    showCheckboxColumn: false,
                    headingRowHeight: 48,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 56,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                  ),
                ),
                if (rows.isEmpty && !isLoading)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No data found',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Pagination controls.
                if (totalPages > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${((currentPage - 1) * pageSize) + 1}'
                          '-${_min(currentPage * pageSize, totalItems)}'
                          ' of $totalItems',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: currentPage > 1
                                  ? () => onPageChanged?.call(currentPage - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'Previous page',
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Page $currentPage of $totalPages',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              onPressed: currentPage < totalPages
                                  ? () => onPageChanged?.call(currentPage + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                              tooltip: 'Next page',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  int _min(int a, int b) => a < b ? a : b;
}
