import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/sms_service.dart';
import '../../data/local/daos/passage_dao.dart';
import '../../data/local/database.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/passage_repository.dart';
import '../../data/repositories/sync_repository.dart';

/// Use case: Send SMS fallback for passages that cannot be synced.
///
/// Triggers when:
/// 1. No connectivity detected
/// 2. Sync queue has pending items older than 5 minutes
/// 3. SMS has not already been sent for that item
///
/// Uses [SmsEncoder.encode] from the shared package to format the message.
class SendSmsFallbackUseCase {
  SendSmsFallbackUseCase({
    required SyncRepository syncRepository,
    required PassageRepository passageRepository,
    required PassageDao passageDao,
    required SmsService smsService,
    required ConnectivityService connectivityService,
    required AuthRepository authRepository,
  })  : _syncRepository = syncRepository,
        _passageRepository = passageRepository,
        _passageDao = passageDao,
        _smsService = smsService,
        _connectivityService = connectivityService,
        _authRepository = authRepository;

  final SyncRepository _syncRepository;
  final PassageRepository _passageRepository;
  final PassageDao _passageDao;
  final SmsService _smsService;
  final ConnectivityService _connectivityService;
  final AuthRepository _authRepository;

  /// Check and send SMS fallback for eligible items.
  ///
  /// Returns the number of SMS messages sent.
  Future<int> execute() async {
    // Only trigger when offline.
    if (_connectivityService.isOnline) return 0;

    final profile = _authRepository.currentProfile;
    if (profile == null) return 0;

    final checkpostId = profile.assignedCheckpostId;
    if (checkpostId == null) return 0;

    // Get the checkpost code for SMS encoding.
    final checkpost = await _passageRepository.getCheckpost(checkpostId);
    if (checkpost == null) return 0;

    // Get the ranger's phone suffix (last 4 digits).
    final phoneSuffix = _extractPhoneSuffix(profile.phoneNumber);

    // Find pending items older than 5 minutes without SMS sent.
    final eligibleItems = await _syncRepository.getPendingOlderThan(
      SyncQueueItem.smsFallbackDelay,
    );

    // Also get failed items without SMS.
    final failedItems = await _syncRepository.getFailedWithoutSms();

    final allItems = [...eligibleItems, ...failedItems];
    if (allItems.isEmpty) return 0;

    int sentCount = 0;

    for (final item in allItems) {
      // Fetch the passage data.
      final passage =
          await _passageDao.getPassageByClientId(item.passageClientId);
      if (passage == null) continue;

      // Send the SMS.
      final success = await _smsService.sendPassageSms(
        checkpostCode: checkpost.code,
        plateNumber: passage.plateNumber,
        vehicleType: VehicleType.fromValue(passage.vehicleType),
        recordedAt: passage.recordedAt,
        rangerPhoneSuffix: phoneSuffix,
      );

      if (success) {
        await _syncRepository.markSmsSent(item.passageClientId);
        sentCount++;
      }
    }

    return sentCount;
  }

  /// Extract the last 4 digits of a phone number.
  String _extractPhoneSuffix(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return '0000';
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return digits.padLeft(4, '0');
    return digits.substring(digits.length - 4);
  }
}

/// Provider for the send SMS fallback use case.
final sendSmsFallbackUseCaseProvider = Provider<SendSmsFallbackUseCase>((ref) {
  return SendSmsFallbackUseCase(
    syncRepository: ref.watch(syncRepositoryProvider),
    passageRepository: ref.watch(passageRepositoryProvider),
    passageDao: ref.watch(passageDaoProvider),
    smsService: ref.watch(smsServiceProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});
