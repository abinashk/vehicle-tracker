import 'package:test/test.dart';
import 'package:shared/shared.dart';

void main() {
  group('SpeedCalculator', () {
    // Segment: 50 km, max speed 40 km/h, min speed 10 km/h
    // Min travel time: 50/40 * 60 = 75 minutes
    // Max travel time: 50/10 * 60 = 300 minutes

    test('should detect no violation when travel time is within bounds', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(minutes: 100),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isViolation, isFalse);
      expect(result.type, isNull);
      expect(result.travelTimeMinutes, closeTo(100, 0.1));
    });

    test('should detect speeding when travel time is below minimum', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(minutes: 45),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isViolation, isTrue);
      expect(result.isSpeeding, isTrue);
      expect(result.type, equals(ViolationType.speeding));
      expect(result.thresholdMinutes, closeTo(75, 0.1));
      expect(result.calculatedSpeedKmh, closeTo(66.67, 0.1));
    });

    test('should detect overstay when travel time exceeds maximum', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(minutes: 350),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isViolation, isTrue);
      expect(result.isOverstay, isTrue);
      expect(result.type, equals(ViolationType.overstay));
      expect(result.thresholdMinutes, closeTo(300, 0.1));
    });

    test('should detect no violation at exact minimum threshold', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(minutes: 75),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isViolation, isFalse);
    });

    test('should detect no violation at exact maximum threshold', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(minutes: 300),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isViolation, isFalse);
    });

    test('should handle Banke pilot segment (45km, 40/10 km/h)', () {
      // Min time: 45/40*60 = 67.5 min
      // Max time: 45/10*60 = 270 min
      final speedingResult = SpeedCalculator.check(
        distanceKm: 45,
        travelTime: const Duration(minutes: 50),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(speedingResult.isSpeeding, isTrue);
      expect(speedingResult.thresholdMinutes, closeTo(67.5, 0.1));

      final normalResult = SpeedCalculator.check(
        distanceKm: 45,
        travelTime: const Duration(minutes: 120),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(normalResult.isViolation, isFalse);
    });

    test('should handle zero travel time as speeding', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: Duration.zero,
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.isSpeeding, isTrue);
      expect(result.calculatedSpeedKmh, equals(double.infinity));
    });

    test('should calculate correct speed', () {
      final result = SpeedCalculator.check(
        distanceKm: 50,
        travelTime: const Duration(hours: 1),
        maxSpeedKmh: 40,
        minSpeedKmh: 10,
      );

      expect(result.calculatedSpeedKmh, closeTo(50, 0.1));
    });
  });
}
