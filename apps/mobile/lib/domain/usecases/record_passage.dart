import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/passage_repository.dart';
import '../services/matching_service.dart';

/// Result of recording a passage, including any violation detected.
class RecordPassageResult {
  final VehiclePassage passage;
  final MatchResult matchResult;

  const RecordPassageResult({
    required this.passage,
    required this.matchResult,
  });

  bool get hasViolation => matchResult.violation != null;
  Violation? get violation => matchResult.violation;
}

/// Use case: Record a vehicle passage.
///
/// Orchestrates the full recording flow:
/// 1. Save to Drift (via repository)
/// 2. Add to sync queue (via repository)
/// 3. Trigger local matching service
///
/// The [recordedAt] timestamp is the camera shutter moment.
/// The [clientId] is generated once per passage and never regenerated.
class RecordPassageUseCase {
  RecordPassageUseCase({
    required PassageRepository passageRepository,
    required MatchingService matchingService,
    required AuthRepository authRepository,
  })  : _passageRepository = passageRepository,
        _matchingService = matchingService,
        _authRepository = authRepository;

  final PassageRepository _passageRepository;
  final MatchingService _matchingService;
  final AuthRepository _authRepository;

  /// Execute the use case.
  ///
  /// Records the passage locally and attempts local matching.
  /// Returns the recorded passage and any violation detected.
  Future<RecordPassageResult> execute({
    required String plateNumber,
    String? plateNumberRaw,
    required VehicleType vehicleType,
    required DateTime recordedAt,
    String? photoLocalPath,
  }) async {
    final profile = _authRepository.currentProfile;
    if (profile == null) {
      throw StateError('User is not authenticated');
    }

    final checkpostId = profile.assignedCheckpostId;
    if (checkpostId == null) {
      throw StateError('User has no assigned checkpost');
    }

    // Fetch segment info for the checkpost.
    final checkpost = await _passageRepository.getCheckpost(checkpostId);
    final segmentId = checkpost?.segmentId ?? '';

    // Step 1 & 2: Record passage (writes to Drift + sync queue).
    final passage = await _passageRepository.recordPassage(
      plateNumber: plateNumber,
      plateNumberRaw: plateNumberRaw,
      vehicleType: vehicleType,
      checkpostId: checkpostId,
      segmentId: segmentId,
      recordedAt: recordedAt,
      rangerId: profile.id,
      photoLocalPath: photoLocalPath,
    );

    // Step 3: Trigger local matching.
    MatchResult matchResult = const MatchResult.noMatch();

    if (segmentId.isNotEmpty) {
      final segment = await _passageRepository.getSegment(segmentId);
      if (segment != null) {
        matchResult = await _matchingService.findMatch(
          newPassage: passage,
          segment: segment,
        );
      }
    }

    return RecordPassageResult(
      passage: passage,
      matchResult: matchResult,
    );
  }
}

/// Provider for the record passage use case.
final recordPassageUseCaseProvider = Provider<RecordPassageUseCase>((ref) {
  return RecordPassageUseCase(
    passageRepository: ref.watch(passageRepositoryProvider),
    matchingService: ref.watch(matchingServiceProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});
