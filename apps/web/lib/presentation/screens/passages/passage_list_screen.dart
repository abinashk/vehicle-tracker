import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../data/repositories/passage_repository.dart';
import '../../widgets/data_table_wrapper.dart';
import '../../widgets/filter_bar.dart';

/// Screen displaying a paginated, filterable list of vehicle passages.
class PassageListScreen extends ConsumerStatefulWidget {
  const PassageListScreen({super.key});

  @override
  ConsumerState<PassageListScreen> createState() => _PassageListScreenState();
}

class _PassageListScreenState extends ConsumerState<PassageListScreen> {
  PaginatedPassages? _data;
  List<Checkpost> _checkposts = [];
  Map<String, Checkpost> _checkpostMap = {};
  PassageFilter _filter = const PassageFilter();
  int _currentPage = 1;
  bool _isLoading = true;
  String? _errorMessage;

  final _plateSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _plateSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final segmentRepo = ref.read(segmentRepositoryProvider);
      final checkposts = await segmentRepo.listCheckposts();

      if (mounted) {
        setState(() {
          _checkposts = checkposts;
          _checkpostMap = {for (final cp in checkposts) cp.id: cp};
        });
      }
    } catch (_) {
      // Checkposts are optional for filtering; continue.
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final passageRepo = ref.read(passageRepositoryProvider);
      final data = await passageRepo.listPassages(
        page: _currentPage,
        filter: _filter,
      );

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load passages: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter(PassageFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _currentPage = 1;
    });
    _loadData();
  }

  void _clearFilters() {
    _plateSearchController.clear();
    _applyFilter(const PassageFilter());
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filter.dateFrom != null && _filter.dateTo != null
          ? DateTimeRange(start: _filter.dateFrom!, end: _filter.dateTo!)
          : null,
    );

    if (picked != null) {
      _applyFilter(PassageFilter(
        dateFrom: picked.start,
        dateTo: picked.end.add(const Duration(days: 1)),
        checkpostId: _filter.checkpostId,
        vehicleType: _filter.vehicleType,
        plateSearch: _filter.plateSearch,
        source: _filter.source,
        isMatched: _filter.isMatched,
      ),);
    }
  }

  String _formatNepalTime(DateTime utcTime) {
    final nepalTime = utcTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    return DateFormat('yyyy-MM-dd HH:mm').format(nepalTime);
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DataTableWrapper(
            title: 'Vehicle Passages',
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            currentPage: _currentPage,
            totalPages: _data?.totalPages ?? 0,
            totalItems: _data?.totalCount ?? 0,
            pageSize: _data?.pageSize ?? PassageRepository.defaultPageSize,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _loadData();
            },
            filterBar: _buildFilterBar(),
            columns: const [
              DataColumn(label: Text('Plate')),
              DataColumn(label: Text('Vehicle Type')),
              DataColumn(label: Text('Checkpost')),
              DataColumn(label: Text('Recorded At')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Matched')),
            ],
            rows: items.map((passage) {
              final checkpost = _checkpostMap[passage.checkpostId];

              return DataRow(
                onSelectChanged: (_) {
                  context.go('/passages/${passage.id}');
                },
                cells: [
                  DataCell(Text(
                    passage.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),),
                  DataCell(Text(passage.vehicleType.label)),
                  DataCell(Text(
                      checkpost?.name ?? passage.checkpostId.substring(0, 8),),),
                  DataCell(Text(_formatNepalTime(passage.recordedAt))),
                  DataCell(_buildSourceBadge(passage.source)),
                  DataCell(_buildMatchedBadge(passage.isMatched)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return FilterBar(
      hasActiveFilters: _filter.hasActiveFilters,
      onClear: _clearFilters,
      filters: [
        FilterItem(
          label: 'Date Range',
          child: OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, size: 16),
            label: Text(
              _filter.dateFrom != null
                  ? '${DateFormat('MM/dd').format(_filter.dateFrom!)}'
                      ' - ${DateFormat('MM/dd').format(_filter.dateTo ?? DateTime.now())}'
                  : 'Select dates',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        FilterItem(
          label: 'Checkpost',
          child: DropdownButtonFormField<String>(
            value: _filter.checkpostId,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12)),),
              ..._checkposts.map((cp) => DropdownMenuItem(
                    value: cp.id,
                    child: Text(cp.name, style: const TextStyle(fontSize: 12)),
                  ),),
            ],
            onChanged: (value) {
              _applyFilter(PassageFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                checkpostId: value,
                vehicleType: _filter.vehicleType,
                plateSearch: _filter.plateSearch,
                source: _filter.source,
                isMatched: _filter.isMatched,
              ),);
            },
          ),
        ),
        FilterItem(
          label: 'Vehicle Type',
          child: DropdownButtonFormField<VehicleType>(
            value: _filter.vehicleType,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: [
              const DropdownMenuItem<VehicleType>(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12)),),
              ...VehicleType.values.map((vt) => DropdownMenuItem(
                    value: vt,
                    child: Text(vt.label, style: const TextStyle(fontSize: 12)),
                  ),),
            ],
            onChanged: (value) {
              _applyFilter(PassageFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                checkpostId: _filter.checkpostId,
                vehicleType: value,
                plateSearch: _filter.plateSearch,
                source: _filter.source,
                isMatched: _filter.isMatched,
              ),);
            },
          ),
        ),
        FilterItem(
          label: 'Plate Search',
          child: TextField(
            controller: _plateSearchController,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: 'Search plate...',
              hintStyle: TextStyle(fontSize: 12),
              suffixIcon: Icon(Icons.search, size: 16),
            ),
            style: const TextStyle(fontSize: 12),
            onSubmitted: (value) {
              _applyFilter(PassageFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                checkpostId: _filter.checkpostId,
                vehicleType: _filter.vehicleType,
                plateSearch: value.isEmpty ? null : value,
                source: _filter.source,
                isMatched: _filter.isMatched,
              ),);
            },
          ),
        ),
        FilterItem(
          label: 'Source',
          child: DropdownButtonFormField<String>(
            value: _filter.source,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: const [
              DropdownMenuItem(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12)),),
              DropdownMenuItem(
                  value: 'app',
                  child: Text('App', style: TextStyle(fontSize: 12)),),
              DropdownMenuItem(
                  value: 'sms',
                  child: Text('SMS', style: TextStyle(fontSize: 12)),),
            ],
            onChanged: (value) {
              _applyFilter(PassageFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                checkpostId: _filter.checkpostId,
                vehicleType: _filter.vehicleType,
                plateSearch: _filter.plateSearch,
                source: value,
                isMatched: _filter.isMatched,
              ),);
            },
          ),
        ),
        FilterItem(
          label: 'Matched',
          child: DropdownButtonFormField<bool>(
            value: _filter.isMatched,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: const [
              DropdownMenuItem<bool>(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12)),),
              DropdownMenuItem(
                  value: true,
                  child: Text('Matched', style: TextStyle(fontSize: 12)),),
              DropdownMenuItem(
                  value: false,
                  child: Text('Unmatched', style: TextStyle(fontSize: 12)),),
            ],
            onChanged: (value) {
              _applyFilter(PassageFilter(
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                checkpostId: _filter.checkpostId,
                vehicleType: _filter.vehicleType,
                plateSearch: _filter.plateSearch,
                source: _filter.source,
                isMatched: value,
              ),);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(String source) {
    final isApp = source == 'app';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isApp
            ? Colors.blue.withOpacity(0.1)
            : Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        source.toUpperCase(),
        style: TextStyle(
          color: isApp ? Colors.blue : Colors.purple,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMatchedBadge(bool isMatched) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isMatched
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isMatched ? 'Matched' : 'Unmatched',
        style: TextStyle(
          color: isMatched ? Colors.green : Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
