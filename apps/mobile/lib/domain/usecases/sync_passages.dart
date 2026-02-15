import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/passage_repository.dart';
import '../../data/repositories/sync_repository.dart';

/// Use case: Orchestrate the sync engine.
///
/// Configures and starts/stops the sync engine based on auth state.
/// The sync engine handles outbound push (30s timer), inbound pull,
/// and photo upload automatically.
class SyncPassagesUseCase {
  SyncPassagesUseCase({
    required SyncRepository syncRepository,
    required AuthRepository authRepository,
    required PassageRepository passageRepository,
  })  : _syncRepository = syncRepository,
        _authRepository = authRepository,
        _passageRepository = passageRepository;

  final SyncRepository _syncRepository;
  final AuthRepository _authRepository;
  final PassageRepository _passageRepository;

  /// Start the sync engine with the current user's checkpost configuration.
  Future<void> startSync() async {
    final profile = _authRepository.currentProfile;
    if (profile == null) return;

    final checkpostId = profile.assignedCheckpostId;
    if (checkpostId == null) return;

    // Fetch the checkpost to get the segment ID.
    final checkpost = await _passageRepository.getCheckpost(checkpostId);
    if (checkpost != null) {
      _syncRepository.configure(
        checkpostId: checkpostId,
        segmentId: checkpost.segmentId,
      );
    }

    _syncRepository.start();
  }

  /// Stop the sync engine.
  void stopSync() {
    _syncRepository.stop();
  }

  /// Force an immediate sync cycle.
  Future<void> forceSync() {
    return _syncRepository.forceSyncCycle();
  }

  /// Get the current sync state.
  Future<SyncState> getSyncState() {
    return _syncRepository.getSyncState();
  }
}

/// Provider for the sync passages use case.
final syncPassagesUseCaseProvider = Provider<SyncPassagesUseCase>((ref) {
  return SyncPassagesUseCase(
    syncRepository: ref.watch(syncRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    passageRepository: ref.watch(passageRepositoryProvider),
  );
});
