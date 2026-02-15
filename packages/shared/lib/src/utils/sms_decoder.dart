import '../constants/sms_format.dart';
import '../enums/vehicle_type.dart';

/// Decoded SMS passage data.
class DecodedPassageSms {
  final String checkpostCode;
  final String plateNumber;
  final VehicleType vehicleType;
  final DateTime recordedAt;
  final String rangerPhoneSuffix;

  const DecodedPassageSms({
    required this.checkpostCode,
    required this.plateNumber,
    required this.vehicleType,
    required this.recordedAt,
    required this.rangerPhoneSuffix,
  });
}

/// Decodes compact SMS format back into passage data.
class SmsDecoder {
  SmsDecoder._();

  /// Decode an SMS string into passage data.
  ///
  /// Throws [FormatException] if the SMS format is invalid.
  static DecodedPassageSms decode(String sms) {
    final parts = sms.trim().split(SmsFormat.separator);

    if (parts.length != SmsFormat.fieldCount) {
      throw FormatException(
        'Invalid SMS format: expected ${SmsFormat.fieldCount} fields, '
        'got ${parts.length}',
        sms,
      );
    }

    final version = parts[SmsFormat.versionIndex];
    if (version != SmsFormat.version) {
      throw FormatException(
        'Unsupported SMS version: $version (expected ${SmsFormat.version})',
        sms,
      );
    }

    final checkpostCode = parts[SmsFormat.checkpostCodeIndex];
    final plateNumber = parts[SmsFormat.plateNumberIndex];
    final vehicleTypeCode = parts[SmsFormat.vehicleTypeCodeIndex];
    final timestampEpochStr = parts[SmsFormat.timestampEpochIndex];
    final rangerPhoneSuffix = parts[SmsFormat.rangerPhoneSuffixIndex];

    final epochSeconds = int.tryParse(timestampEpochStr);
    if (epochSeconds == null) {
      throw FormatException(
        'Invalid timestamp in SMS: $timestampEpochStr',
        sms,
      );
    }

    return DecodedPassageSms(
      checkpostCode: checkpostCode,
      plateNumber: plateNumber,
      vehicleType: VehicleType.fromSmsCode(vehicleTypeCode),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      ),
      rangerPhoneSuffix: rangerPhoneSuffix,
    );
  }
}
