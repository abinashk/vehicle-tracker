import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Filter parameters for passage queries.
class PassageFilter {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? checkpostId;
  final VehicleType? vehicleType;
  final String? plateSearch;
  final String? source;
  final bool? isMatched;

  const PassageFilter({
    this.dateFrom,
    this.dateTo,
    this.checkpostId,
    this.vehicleType,
    this.plateSearch,
    this.source,
    this.isMatched,
  });

  PassageFilter copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? checkpostId,
    VehicleType? vehicleType,
    String? plateSearch,
    String? source,
    bool? isMatched,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearCheckpostId = false,
    bool clearVehicleType = false,
    bool clearPlateSearch = false,
    bool clearSource = false,
    bool clearIsMatched = false,
  }) {
    return PassageFilter(
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      checkpostId: clearCheckpostId ? null : (checkpostId ?? this.checkpostId),
      vehicleType: clearVehicleType ? null : (vehicleType ?? this.vehicleType),
      plateSearch: clearPlateSearch ? null : (plateSearch ?? this.plateSearch),
      source: clearSource ? null : (source ?? this.source),
      isMatched: clearIsMatched ? null : (isMatched ?? this.isMatched),
    );
  }

  bool get hasActiveFilters =>
      dateFrom != null ||
      dateTo != null ||
      checkpostId != null ||
      vehicleType != null ||
      (plateSearch != null && plateSearch!.isNotEmpty) ||
      source != null ||
      isMatched != null;
}

/// Result of a paginated passage query.
class PaginatedPassages {
  final List<VehiclePassage> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PaginatedPassages({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;
}

/// Repository for vehicle passage data access with pagination and filtering.
class PassageRepository {
  final SupabaseClient _client;

  static const int defaultPageSize = 25;

  PassageRepository(this._client);

  /// Fetch paginated passages with optional filters.
  ///
  /// Uses Supabase range headers for efficient pagination.
  Future<PaginatedPassages> listPassages({
    int page = 1,
    int pageSize = defaultPageSize,
    PassageFilter filter = const PassageFilter(),
    bool ascending = false,
  }) async {
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;

    var query = _client
        .from(ApiConstants.vehiclePassagesTable)
        .select('*', const FetchOptions(count: CountOption.exact));

    // Apply filters.
    if (filter.dateFrom != null) {
      query =
          query.gte('recorded_at', filter.dateFrom!.toUtc().toIso8601String());
    }
    if (filter.dateTo != null) {
      query =
          query.lte('recorded_at', filter.dateTo!.toUtc().toIso8601String());
    }
    if (filter.checkpostId != null) {
      query = query.eq('checkpost_id', filter.checkpostId!);
    }
    if (filter.vehicleType != null) {
      query = query.eq('vehicle_type', filter.vehicleType!.value);
    }
    if (filter.plateSearch != null && filter.plateSearch!.isNotEmpty) {
      query = query.ilike('plate_number', '%${filter.plateSearch}%');
    }
    if (filter.source != null) {
      query = query.eq('source', filter.source!);
    }
    if (filter.isMatched != null) {
      if (filter.isMatched!) {
        query = query.not('matched_passage_id', 'is', null);
      } else {
        query = query.isFilter('matched_passage_id', null);
      }
    }

    final response =
        await query.order('recorded_at', ascending: ascending).range(from, to);

    // Extract count from the response.
    // The count is available when using FetchOptions with count.
    final items =
        (response as List).map((e) => VehiclePassage.fromJson(e)).toList();

    // For count, we need a separate count query since the main query
    // returns data. We approximate by checking if we got a full page.
    final totalCount = await _getFilteredCount(
      ApiConstants.vehiclePassagesTable,
      filter,
    );

    return PaginatedPassages(
      items: items,
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Get a single passage by ID.
  Future<VehiclePassage> getPassage(String id) async {
    final data = await _client
        .from(ApiConstants.vehiclePassagesTable)
        .select()
        .eq('id', id)
        .single();

    return VehiclePassage.fromJson(data);
  }

  /// Get count of filtered passages for pagination.
  Future<int> _getFilteredCount(String table, PassageFilter filter) async {
    var query = _client
        .from(table)
        .select('id', const FetchOptions(count: CountOption.exact, head: true));

    if (filter.dateFrom != null) {
      query =
          query.gte('recorded_at', filter.dateFrom!.toUtc().toIso8601String());
    }
    if (filter.dateTo != null) {
      query =
          query.lte('recorded_at', filter.dateTo!.toUtc().toIso8601String());
    }
    if (filter.checkpostId != null) {
      query = query.eq('checkpost_id', filter.checkpostId!);
    }
    if (filter.vehicleType != null) {
      query = query.eq('vehicle_type', filter.vehicleType!.value);
    }
    if (filter.plateSearch != null && filter.plateSearch!.isNotEmpty) {
      query = query.ilike('plate_number', '%${filter.plateSearch}%');
    }
    if (filter.source != null) {
      query = query.eq('source', filter.source!);
    }
    if (filter.isMatched != null) {
      if (filter.isMatched!) {
        query = query.not('matched_passage_id', 'is', null);
      } else {
        query = query.isFilter('matched_passage_id', null);
      }
    }

    final response = await query.count(CountOption.exact);
    return response.count;
  }
}
