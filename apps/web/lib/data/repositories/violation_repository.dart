import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Escape special characters for Postgres ILIKE patterns.
String _sanitizeLikePattern(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Filter parameters for violation queries.
class ViolationFilter {
  final ViolationType? violationType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? plateSearch;
  final bool? hasOutcome;

  const ViolationFilter({
    this.violationType,
    this.dateFrom,
    this.dateTo,
    this.plateSearch,
    this.hasOutcome,
  });

  ViolationFilter copyWith({
    ViolationType? violationType,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? plateSearch,
    bool? hasOutcome,
    bool clearViolationType = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearPlateSearch = false,
    bool clearHasOutcome = false,
  }) {
    return ViolationFilter(
      violationType:
          clearViolationType ? null : (violationType ?? this.violationType),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      plateSearch: clearPlateSearch ? null : (plateSearch ?? this.plateSearch),
      hasOutcome: clearHasOutcome ? null : (hasOutcome ?? this.hasOutcome),
    );
  }

  bool get hasActiveFilters =>
      violationType != null ||
      dateFrom != null ||
      dateTo != null ||
      (plateSearch != null && plateSearch!.isNotEmpty) ||
      hasOutcome != null;

  /// Description of the active filters for CSV filename.
  String get filterDescription {
    final parts = <String>[];
    if (violationType != null) parts.add(violationType!.value);
    if (plateSearch != null && plateSearch!.isNotEmpty) {
      parts.add('plate-$plateSearch');
    }
    if (hasOutcome != null) {
      parts.add(hasOutcome! ? 'with-outcome' : 'no-outcome');
    }
    return parts.isEmpty ? 'all' : parts.join('_');
  }
}

/// Result of a paginated violation query.
class PaginatedViolations {
  final List<ViolationWithOutcome> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PaginatedViolations({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;
}

/// A violation combined with its optional outcome record.
class ViolationWithOutcome {
  final Violation violation;
  final ViolationOutcome? outcome;

  const ViolationWithOutcome({
    required this.violation,
    this.outcome,
  });

  bool get hasOutcome => outcome != null;
}

/// Repository for violation data access with pagination, filtering, and CSV export.
class ViolationRepository {
  final SupabaseClient _client;

  static const int defaultPageSize = 25;

  ViolationRepository(this._client);

  /// Fetch paginated violations with optional filters.
  Future<PaginatedViolations> listViolations({
    int page = 1,
    int pageSize = defaultPageSize,
    ViolationFilter filter = const ViolationFilter(),
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    // Fetch violations.
    var query = _client.from(ApiConstants.violationsTable).select();

    query = _applyViolationFilters(query, filter);

    final data =
        await query.order('created_at', ascending: false).range(from, to);

    final violations =
        (data as List).map((e) => Violation.fromJson(e)).toList();

    // Fetch outcomes for these violations.
    final violationIds = violations.map((v) => v.id).toList();
    final outcomes = await _fetchOutcomes(violationIds);

    // Combine violations with outcomes.
    final items = violations.map((v) {
      return ViolationWithOutcome(
        violation: v,
        outcome: outcomes[v.id],
      );
    }).toList();

    // Apply outcome filter if specified.
    List<ViolationWithOutcome> filtered = items;
    if (filter.hasOutcome != null) {
      filtered =
          items.where((item) => item.hasOutcome == filter.hasOutcome).toList();
    }

    final totalCount = await _getViolationCount(filter);

    return PaginatedViolations(
      items: filtered,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Fetch a single violation with its outcome by ID.
  Future<ViolationWithOutcome> getViolation(String id) async {
    final data = await _client
        .from(ApiConstants.violationsTable)
        .select()
        .eq('id', id)
        .single();

    final violation = Violation.fromJson(data);
    final outcomes = await _fetchOutcomes([id]);

    return ViolationWithOutcome(
      violation: violation,
      outcome: outcomes[id],
    );
  }

  /// Fetch all violations matching the filter for CSV export.
  ///
  /// Returns all matching records (not paginated).
  Future<List<ViolationWithOutcome>> listAllForExport({
    ViolationFilter filter = const ViolationFilter(),
  }) async {
    var query = _client.from(ApiConstants.violationsTable).select();

    query = _applyViolationFilters(query, filter);

    final data = await query.order('created_at', ascending: false);

    final violations =
        (data as List).map((e) => Violation.fromJson(e)).toList();

    // Fetch all outcomes.
    final violationIds = violations.map((v) => v.id).toList();
    final outcomes = await _fetchOutcomes(violationIds);

    var items = violations.map((v) {
      return ViolationWithOutcome(
        violation: v,
        outcome: outcomes[v.id],
      );
    }).toList();

    if (filter.hasOutcome != null) {
      items =
          items.where((item) => item.hasOutcome == filter.hasOutcome).toList();
    }

    return items;
  }

  /// Generate CSV content from violation data.
  ///
  /// Returns a string containing the CSV data with headers.
  String generateCsvContent(List<ViolationWithOutcome> violations) {
    final buffer = StringBuffer();

    // CSV headers.
    buffer.writeln(
      'ID,Plate Number,Vehicle Type,Violation Type,'
      'Entry Time,Exit Time,Travel Time (min),Threshold (min),'
      'Calculated Speed (km/h),Speed Limit (km/h),Distance (km),'
      'Segment ID,Outcome Type,Fine Amount,Outcome Notes,Outcome Date',
    );

    // CSV rows.
    for (final item in violations) {
      final v = item.violation;
      final o = item.outcome;

      buffer.writeln(
        '${_csvEscape(v.id)},'
        '${_csvEscape(v.plateNumber)},'
        '${_csvEscape(v.vehicleType.label)},'
        '${_csvEscape(v.violationType.label)},'
        '${_csvEscape(_formatUtcToNepal(v.entryTime))},'
        '${_csvEscape(_formatUtcToNepal(v.exitTime))},'
        '${v.travelTimeMinutes.toStringAsFixed(1)},'
        '${v.thresholdMinutes.toStringAsFixed(1)},'
        '${v.calculatedSpeedKmh.toStringAsFixed(1)},'
        '${v.speedLimitKmh.toStringAsFixed(1)},'
        '${v.distanceKm.toStringAsFixed(2)},'
        '${_csvEscape(v.segmentId)},'
        '${o != null ? _csvEscape(o.outcomeType.label) : ""},'
        '${o?.fineAmount?.toStringAsFixed(2) ?? ""},'
        '${o?.notes != null ? _csvEscape(o!.notes!) : ""},'
        '${o != null ? _csvEscape(_formatUtcToNepal(o.recordedAt)) : ""}',
      );
    }

    return buffer.toString();
  }

  /// Get the filename for a CSV export based on the filter.
  String getCsvFilename(ViolationFilter filter) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'violations_${filter.filterDescription}_$dateStr.csv';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyViolationFilters(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    ViolationFilter filter,
  ) {
    if (filter.violationType != null) {
      query = query.eq('violation_type', filter.violationType!.value);
    }
    if (filter.dateFrom != null) {
      query =
          query.gte('created_at', filter.dateFrom!.toUtc().toIso8601String());
    }
    if (filter.dateTo != null) {
      query = query.lte('created_at', filter.dateTo!.toUtc().toIso8601String());
    }
    if (filter.plateSearch != null && filter.plateSearch!.isNotEmpty) {
      query = query.ilike('plate_number', '%${_sanitizeLikePattern(filter.plateSearch!)}%');
    }
    return query;
  }

  Future<Map<String, ViolationOutcome>> _fetchOutcomes(
      List<String> violationIds) async {
    if (violationIds.isEmpty) return {};

    final data = await _client
        .from(ApiConstants.violationOutcomesTable)
        .select()
        .inFilter('violation_id', violationIds);

    final outcomes = <String, ViolationOutcome>{};
    for (final item in data as List) {
      final outcome = ViolationOutcome.fromJson(item);
      outcomes[outcome.violationId] = outcome;
    }
    return outcomes;
  }

  Future<int> _getViolationCount(ViolationFilter filter) async {
    var query = _client
        .from(ApiConstants.violationsTable)
        .select('id');

    if (filter.violationType != null) {
      query = query.eq('violation_type', filter.violationType!.value);
    }
    if (filter.dateFrom != null) {
      query =
          query.gte('created_at', filter.dateFrom!.toUtc().toIso8601String());
    }
    if (filter.dateTo != null) {
      query = query.lte('created_at', filter.dateTo!.toUtc().toIso8601String());
    }
    if (filter.plateSearch != null && filter.plateSearch!.isNotEmpty) {
      query = query.ilike('plate_number', '%${_sanitizeLikePattern(filter.plateSearch!)}%');
    }

    final response = await query.count(CountOption.exact);
    return response.count;
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatUtcToNepal(DateTime utcTime) {
    final nepalTime = utcTime.toUtc().add(AppConstants.nepalTimezoneOffset);
    return '${nepalTime.year}-'
        '${nepalTime.month.toString().padLeft(2, '0')}-'
        '${nepalTime.day.toString().padLeft(2, '0')} '
        '${nepalTime.hour.toString().padLeft(2, '0')}:'
        '${nepalTime.minute.toString().padLeft(2, '0')}:'
        '${nepalTime.second.toString().padLeft(2, '0')}';
  }
}
