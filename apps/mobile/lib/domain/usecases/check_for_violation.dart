import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/repositories/passage_repository.dart';
import '../services/matching_service.dart';

/// Use case: Check a recorded passage for violations.
///
/// Uses [SpeedCalculator] from the shared package via the [MatchingService].
/// Called after a passage is recorded to detect speeding or overstay violations.
class CheckForViolationUseCase {
  CheckForViolationUseCase({
    required MatchingService matchingService,
    required PassageRepository passageRepository,
  })  : _matchingService = matchingService,
        _passageRepository = passageRepository;

  final MatchingService _matchingService;
  final PassageRepository _passageRepository;

  /// Execute the violation check for a given passage.
  ///
  /// Returns a [MatchResult] indicating whether a match was found
  /// and whether a violation was detected.
  Future<MatchResult> execute({
    required VehiclePassage passage,
  }) async {
    // Fetch segment data to get speed limits and distance.
    final segment = await _passageRepository.getSegment(passage.segmentId);
    if (segment == null) {
      return const MatchResult.noMatch();
    }

    return _matchingService.findMatch(
      newPassage: passage,
      segment: segment,
    );
  }
}

/// Provider for the check for violation use case.
final checkForViolationUseCaseProvider =
    Provider<CheckForViolationUseCase>((ref) {
  return CheckForViolationUseCase(
    matchingService: ref.watch(matchingServiceProvider),
    passageRepository: ref.watch(passageRepositoryProvider),
  );
});
