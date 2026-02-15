import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/violation_repository.dart';
import '../../widgets/data_table_wrapper.dart';
import '../../widgets/filter_bar.dart';

/// Screen displaying a paginated, filterable list of violations with CSV export.
class ViolationListScreen extends ConsumerStatefulWidget {
  const ViolationListScreen({super.key});

  @override
  ConsumerState<ViolationListScreen> createState() =>
      _ViolationListScreenState();
}

class _ViolationListScreenState extends ConsumerState<ViolationListScreen> {
  PaginatedViolations? _data;
  ViolationFilter _filter = const ViolationFilter();
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  final _plateSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _plateSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final violationRepo = ref.read(violationRepositoryProvider);
      final data = await violationRepo.listViolations(
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
          _errorMessage = 'Failed to load violations: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter(ViolationFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _currentPage = 1;
    });
    _loadData();
  }

  void _clearFilters() {
    _plateSearchController.clear();
    _applyFilter(const ViolationFilter());
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);

    try {
      final violationRepo = ref.read(violationRepositoryProvider);
      final allData = await violationRepo.listAllForExport(filter: _filter);
      final csvContent = violationRepo.generateCsvContent(allData);
      final filename = violationRepo.getCsvFilename(_filter);

      // Trigger browser download.
      final blob = html.Blob([csvContent], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement()
        ..href = url
        ..download = filename;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${allData.length} violations to $filename'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
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
      _applyFilter(ViolationFilter(
        violationType: _filter.violationType,
        dateFrom: picked.start,
        dateTo: picked.end.add(const Duration(days: 1)),
        plateSearch: _filter.plateSearch,
        hasOutcome: _filter.hasOutcome,
      ));
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
            title: 'Violations',
            isLoading: _isLoading,
            errorMessage: _errorMessage,
            currentPage: _currentPage,
            totalPages: _data?.totalPages ?? 0,
            totalItems: _data?.totalCount ?? 0,
            pageSize: _data?.pageSize ?? ViolationRepository.defaultPageSize,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _loadData();
            },
            actions: [
              OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportCsv,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
              ),
            ],
            filterBar: _buildFilterBar(),
            columns: const [
              DataColumn(label: Text('Plate')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Vehicle')),
              DataColumn(label: Text('Travel Time')),
              DataColumn(label: Text('Speed')),
              DataColumn(label: Text('Entry')),
              DataColumn(label: Text('Exit')),
              DataColumn(label: Text('Outcome')),
            ],
            rows: items.map((item) {
              final v = item.violation;
              return DataRow(
                onSelectChanged: (_) {
                  context.go('/violations/${v.id}');
                },
                cells: [
                  DataCell(Text(
                    v.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  )),
                  DataCell(_buildViolationTypeBadge(v.violationType)),
                  DataCell(Text(v.vehicleType.label)),
                  DataCell(
                      Text('${v.travelTimeMinutes.toStringAsFixed(1)} min')),
                  DataCell(
                      Text('${v.calculatedSpeedKmh.toStringAsFixed(1)} km/h')),
                  DataCell(Text(_formatNepalTime(v.entryTime))),
                  DataCell(Text(_formatNepalTime(v.exitTime))),
                  DataCell(_buildOutcomeBadge(item.outcome)),
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
          label: 'Violation Type',
          child: DropdownButtonFormField<ViolationType>(
            value: _filter.violationType,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: const [
              DropdownMenuItem<ViolationType>(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(
                  value: ViolationType.speeding,
                  child: Text('Speeding', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(
                  value: ViolationType.overstay,
                  child: Text('Overstay', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (value) {
              _applyFilter(ViolationFilter(
                violationType: value,
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                plateSearch: _filter.plateSearch,
                hasOutcome: _filter.hasOutcome,
              ));
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
              _applyFilter(ViolationFilter(
                violationType: _filter.violationType,
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                plateSearch: value.isEmpty ? null : value,
                hasOutcome: _filter.hasOutcome,
              ));
            },
          ),
        ),
        FilterItem(
          label: 'Outcome',
          child: DropdownButtonFormField<bool>(
            value: _filter.hasOutcome,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            isExpanded: true,
            hint: const Text('All', style: TextStyle(fontSize: 12)),
            items: const [
              DropdownMenuItem<bool>(
                  value: null,
                  child: Text('All', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(
                  value: true,
                  child: Text('Has Outcome', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(
                  value: false,
                  child: Text('No Outcome', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (value) {
              _applyFilter(ViolationFilter(
                violationType: _filter.violationType,
                dateFrom: _filter.dateFrom,
                dateTo: _filter.dateTo,
                plateSearch: _filter.plateSearch,
                hasOutcome: value,
              ));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViolationTypeBadge(ViolationType type) {
    final color = AppTheme.violationColor(type.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(ViolationOutcome? outcome) {
    if (outcome == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final color = AppTheme.outcomeColor(outcome.outcomeType.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        outcome.outcomeType.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
