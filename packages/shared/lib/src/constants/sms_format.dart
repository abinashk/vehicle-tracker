/// SMS compact format specification for vehicle passage data.
///
/// Format: V1|<checkpost_code>|<plate_number>|<vehicle_type_code>|<timestamp_epoch>|<ranger_phone_suffix>
/// Example: V1|BNP-A|BA1PA1234|CAR|1709123456|9801
///
/// Must fit within 160 characters (SMS limit).
class SmsFormat {
  SmsFormat._();

  /// Current format version.
  static const String version = 'V1';

  /// Field separator.
  static const String separator = '|';

  /// Number of fields in a valid V1 message.
  static const int fieldCount = 6;

  /// Field indexes in the parsed SMS.
  static const int versionIndex = 0;
  static const int checkpostCodeIndex = 1;
  static const int plateNumberIndex = 2;
  static const int vehicleTypeCodeIndex = 3;
  static const int timestampEpochIndex = 4;
  static const int rangerPhoneSuffixIndex = 5;

  /// SMS character limit.
  static const int maxSmsLength = 160;
}
