import '../constants/sms_format.dart';
import '../enums/vehicle_type.dart';
import 'plate_normalizer.dart';

/// Data required to encode a passage into an SMS message.
class PassageSmsData {
  final String checkpostCode;
  final String plateNumber;
  final VehicleType vehicleType;
  final DateTime recordedAt;
  final String rangerPhoneSuffix;

  const PassageSmsData({
    required this.checkpostCode,
    required this.plateNumber,
    required this.vehicleType,
    required this.recordedAt,
    required this.rangerPhoneSuffix,
  });
}

/// Encodes vehicle passage data into compact SMS format.
///
/// Format: V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>
/// Example: V1|BNP-A|BA1PA1234|CAR|1709123456|9801
class SmsEncoder {
  SmsEncoder._();

  /// Encode passage data into an SMS string.
  ///
  /// Returns the encoded string, or throws [ArgumentError] if the result
  /// exceeds the 160-character SMS limit.
  static String encode(PassageSmsData data) {
    final compactPlate = PlateNormalizer.compact(data.plateNumber);
    final epochSeconds =
        data.recordedAt.toUtc().millisecondsSinceEpoch ~/ 1000;

    final parts = [
      SmsFormat.version,
      data.checkpostCode,
      compactPlate,
      data.vehicleType.smsCode,
      epochSeconds.toString(),
      data.rangerPhoneSuffix,
    ];

    final encoded = parts.join(SmsFormat.separator);

    if (encoded.length > SmsFormat.maxSmsLength) {
      throw ArgumentError(
        'Encoded SMS exceeds ${SmsFormat.maxSmsLength} characters: '
        '${encoded.length} characters',
      );
    }

    return encoded;
  }
}
