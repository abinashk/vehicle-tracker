import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/local/daos/cached_passage_dao.dart';
import '../../data/local/database.dart';
import '../../data/repositories/violation_repository.dart';

/// Result of a local matching attempt.
class MatchResult {
  final bool matched;
  final Violation? violation;
  final CachedRemotePassage? matchedEntry;

  const MatchResult({
    required this.matched,
    this.violation,
    this.matchedEntry,
  });

  const MatchResult.noMatch()
      : matched = false,
        violation = null,
        matchedEntry = null;
}

/// Client-side matching service for immediate violation detection.
///
/// Searches cached remote entries (from the opposite checkpost) to find
/// matches for newly recorded passages. When a match is found, uses
/// [SpeedCalculator] from the shared package to detect violations.
///
/// This provides immediate feedback to the ranger even when offline.
/// The server-side trigger (fn_auto_match_passage) provides the
/// authoritative match when data syncs.
class MatchingService {
  MatchingService({
    required CachedPassageDao cachedPassageDao,
    required ViolationRepository violationRepository,
  })  : _cachedPassageDao = cachedPassageDao,
        _violationRepository = violationRepository;

  final CachedPassageDao _cachedPassageDao;
  final ViolationRepository _violationRepository;

  /// Attempt to find a matching passage and detect violations.
  ///
  /// Searches cached remote entries for an unmatched entry with:
  /// - Same plate_number
  /// - Same segment_id
  /// - Different checkpost_id (opposite checkpost)
  ///
  /// If a match is found, calculates travel time and checks for violations
  /// using [SpeedCalculator.check].
  Future<MatchResult> findMatch({
    required VehiclePassage newPassage,
    required HighwaySegment segment,
  }) async {
    // Search cached remote entries for a matching plate.
    final candidates = await _cachedPassageDao.findMatchCandidates(
      plateNumber: newPassage.plateNumber,
      segmentId: newPassage.segmentId,
      excludeCheckpostId: newPassage.checkpostId,
    );

    if (candidates.isEmpty) {
      return const MatchResult.noMatch();
    }

    // Use the most recent unmatched candidate.
    final match = candidates.first;

    // Determine entry and exit based on recorded_at.
    final DateTime entryTime;
    final DateTime exitTime;
    final String entryPassageId;
    final String exitPassageId;

    if (match.recordedAt.isBefore(newPassage.recordedAt)) {
      entryTime = match.recordedAt;
      exitTime = newPassage.recordedAt;
      entryPassageId = match.id;
      exitPassageId = newPassage.id;
    } else {
      entryTime = newPassage.recordedAt;
      exitTime = match.recordedAt;
      entryPassageId = newPassage.id;
      exitPassageId = match.id;
    }

    // Calculate travel time.
    final travelTime = exitTime.difference(entryTime);

    // Check for violations using the shared SpeedCalculator.
    final check = SpeedCalculator.check(
      distanceKm: segment.distanceKm,
      travelTime: travelTime,
      maxSpeedKmh: segment.maxSpeedKmh,
      minSpeedKmh: segment.minSpeedKmh,
    );

    // Mark the cached entry as matched.
    await _cachedPassageDao.markAsMatched(match.id, newPassage.id);

    if (!check.isViolation) {
      return MatchResult(matched: true, matchedEntry: match);
    }

    // Create a local violation record.
    final violation = await _violationRepository.saveViolation(
      entryPassageId: entryPassageId,
      exitPassageId: exitPassageId,
      segmentId: segment.id,
      violationType: check.type!,
      plateNumber: newPassage.plateNumber,
      vehicleType: newPassage.vehicleType,
      entryTime: entryTime,
      exitTime: exitTime,
      travelTimeMinutes: check.travelTimeMinutes,
      thresholdMinutes: check.thresholdMinutes,
      calculatedSpeedKmh: check.calculatedSpeedKmh,
      speedLimitKmh: segment.maxSpeedKmh,
      distanceKm: segment.distanceKm,
    );

    return MatchResult(
      matched: true,
      violation: violation,
      matchedEntry: match,
    );
  }
}

/// Provider for the matching service.
final matchingServiceProvider = Provider<MatchingService>((ref) {
  return MatchingService(
    cachedPassageDao: ref.watch(cachedPassageDaoProvider),
    violationRepository: ref.watch(violationRepositoryProvider),
  );
});
