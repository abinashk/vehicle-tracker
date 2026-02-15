import 'package:test/test.dart';
import 'package:shared/shared.dart';

void main() {
  group('SmsEncoder', () {
    test('should encode passage data into compact SMS format', () {
      final data = PassageSmsData(
        checkpostCode: 'BNP-A',
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.car,
        recordedAt: DateTime.utc(2026, 1, 15, 10, 30, 0),
        rangerPhoneSuffix: '9801',
      );

      final encoded = SmsEncoder.encode(data);
      final epochSeconds =
          DateTime.utc(2026, 1, 15, 10, 30, 0).millisecondsSinceEpoch ~/ 1000;

      expect(encoded, equals('V1|BNP-A|BA1PA1234|CAR|$epochSeconds|9801'));
    });

    test('should strip spaces from plate number', () {
      final data = PassageSmsData(
        checkpostCode: 'BNP-B',
        plateNumber: 'NA 1 JA 5678',
        vehicleType: VehicleType.truck,
        recordedAt: DateTime.utc(2026, 2, 1, 8, 0, 0),
        rangerPhoneSuffix: '1234',
      );

      final encoded = SmsEncoder.encode(data);
      expect(encoded, contains('NA1JA5678'));
      expect(encoded, contains('TRK'));
    });

    test('should produce output within 160 character limit', () {
      final data = PassageSmsData(
        checkpostCode: 'BNP-A',
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.autoRickshaw,
        recordedAt: DateTime.utc(2026, 12, 31, 23, 59, 59),
        rangerPhoneSuffix: '9876',
      );

      final encoded = SmsEncoder.encode(data);
      expect(encoded.length, lessThanOrEqualTo(160));
    });

    test('should use correct vehicle type SMS codes', () {
      for (final type in VehicleType.values) {
        final data = PassageSmsData(
          checkpostCode: 'X',
          plateNumber: 'A1B2',
          vehicleType: type,
          recordedAt: DateTime.utc(2026),
          rangerPhoneSuffix: '0',
        );

        final encoded = SmsEncoder.encode(data);
        expect(encoded, contains(type.smsCode));
      }
    });
  });

  group('SmsDecoder', () {
    test('should decode a valid V1 SMS', () {
      final epochSeconds =
          DateTime.utc(2026, 1, 15, 10, 30, 0).millisecondsSinceEpoch ~/ 1000;

      final decoded =
          SmsDecoder.decode('V1|BNP-A|BA1PA1234|CAR|$epochSeconds|9801');

      expect(decoded.checkpostCode, equals('BNP-A'));
      expect(decoded.plateNumber, equals('BA1PA1234'));
      expect(decoded.vehicleType, equals(VehicleType.car));
      expect(decoded.recordedAt, equals(DateTime.utc(2026, 1, 15, 10, 30, 0)));
      expect(decoded.rangerPhoneSuffix, equals('9801'));
    });

    test('should throw FormatException for invalid field count', () {
      expect(
        () => SmsDecoder.decode('V1|BNP-A|BA1PA1234'),
        throwsFormatException,
      );
    });

    test('should throw FormatException for wrong version', () {
      expect(
        () => SmsDecoder.decode('V2|BNP-A|BA1PA1234|CAR|123456|9801'),
        throwsFormatException,
      );
    });

    test('should throw FormatException for invalid timestamp', () {
      expect(
        () => SmsDecoder.decode('V1|BNP-A|BA1PA1234|CAR|notanumber|9801'),
        throwsFormatException,
      );
    });

    test('should decode all vehicle type codes', () {
      for (final type in VehicleType.values) {
        final encoded = 'V1|X|A1B2|${type.smsCode}|1000000|0';
        final decoded = SmsDecoder.decode(encoded);
        expect(decoded.vehicleType, equals(type));
      }
    });
  });

  group('SmsEncoder + SmsDecoder roundtrip', () {
    test('should encode and decode back to same data', () {
      final original = PassageSmsData(
        checkpostCode: 'BNP-A',
        plateNumber: 'BA 1 PA 1234',
        vehicleType: VehicleType.bus,
        recordedAt: DateTime.utc(2026, 6, 15, 14, 0, 0),
        rangerPhoneSuffix: '5555',
      );

      final encoded = SmsEncoder.encode(original);
      final decoded = SmsDecoder.decode(encoded);

      expect(decoded.checkpostCode, equals(original.checkpostCode));
      expect(decoded.plateNumber, equals('BA1PA1234'));
      expect(decoded.vehicleType, equals(original.vehicleType));
      expect(decoded.recordedAt, equals(original.recordedAt));
      expect(decoded.rangerPhoneSuffix, equals(original.rangerPhoneSuffix));
    });
  });
}
