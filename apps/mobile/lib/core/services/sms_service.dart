import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// Sends SMS messages via platform channel using the device's native SMS capability.
///
/// Uses [SmsEncoder] from the shared package to format passage data
/// into the V1 compact format before sending.
class SmsService {
  SmsService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.bnp.vehicletracker/sms');

  final MethodChannel _channel;

  /// The configured SMS gateway phone number.
  /// In production, this would come from remote config or environment.
  static const String gatewayNumber = '+9779800000000';

  /// Send a raw SMS message to the specified number.
  ///
  /// Returns true if the SMS was sent successfully via the platform.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Encode and send a passage as an SMS fallback message.
  ///
  /// Uses [SmsEncoder.encode] to format the data, then sends it
  /// to the configured gateway number.
  Future<bool> sendPassageSms({
    required String checkpostCode,
    required String plateNumber,
    required VehicleType vehicleType,
    required DateTime recordedAt,
    required String rangerPhoneSuffix,
  }) async {
    final smsData = PassageSmsData(
      checkpostCode: checkpostCode,
      plateNumber: plateNumber,
      vehicleType: vehicleType,
      recordedAt: recordedAt,
      rangerPhoneSuffix: rangerPhoneSuffix,
    );

    try {
      final encoded = SmsEncoder.encode(smsData);
      return sendSms(phoneNumber: gatewayNumber, message: encoded);
    } on ArgumentError {
      return false;
    }
  }
}

/// Provider for the SMS service.
final smsServiceProvider = Provider<SmsService>((ref) {
  return SmsService();
});
