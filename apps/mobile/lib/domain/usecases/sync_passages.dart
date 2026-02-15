import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/passage_repository.dart';
import '../../data/repositories/sync_repository.dart';
import 'send_sms_fallback.dart';

/// Use case: Orchestrate the sync engine.
///
/// Configures and starts/stops the sync engine based on auth state.
/// The sync engine handles outbound push (30s timer), inbound pull,
/// and photo upload automatically. Also wires up SMS fallback when offline.
class SyncPassagesUseCase {
  SyncPassagesUseCase({
    required SyncRepository syncRepository,
    required AuthRepository authRepository,
    required PassageRepository passageRepository,
    required SendSmsFallbackUseCase sendSmsFallbackUseCase,
  })  : _syncRepository = syncRepository,
        _authRepository = authRepository,
        _passageRepository = passageRepository,
        _sendSmsFallbackUseCase = sendSmsFallbackUseCase;

  final SyncRepository _syncRepository;
  final AuthRepository _authRepository;
  final PassageRepository _passageRepository;
  final SendSmsFallbackUseCase _sendSmsFallbackUseCase;

  /// Start the sync engine with the current user's checkpost configuration.
  Future<void> startSync() async {
    final profile = _authRepository.currentProfile;
    if (profile == null) return;

    final checkpostId = profile.assignedCheckpostId;
    if (checkpostId == null) return;

    // Fetch the checkpost to get the segment ID and code.
    final checkpost = await _passageRepository.getCheckpost(checkpostId);
    if (checkpost != null) {
      _syncRepository.configure(
        checkpostId: checkpostId,
        segmentId: checkpost.segmentId,
      );

      // Configure SMS fallback with locally cached checkpost code
      // so it doesn't need a remote query when offline.
      _sendSmsFallbackUseCase.configure(checkpostCode: checkpost.code);
    }

    // Wire up SMS fallback: when the sync engine detects offline state
    // during a cycle, it triggers the SMS fallback use case.
    _syncRepository.onOfflineWithPendingItems = () {
      _sendSmsFallbackUseCase.execute();
    };

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
    sendSmsFallbackUseCase: ref.watch(sendSmsFallbackUseCaseProvider),
  );
});
