import '../enums/violation_type.dart';

/// Result of a speed/overstay check.
class ViolationCheck {
  /// The type of violation detected, or null if no violation.
  final ViolationType? type;

  /// Calculated average speed in km/h.
  final double calculatedSpeedKmh;

  /// The threshold that was breached, in minutes.
  /// For speeding, this is the minimum travel time.
  /// For overstay, this is the maximum travel time.
  final double thresholdMinutes;

  /// Actual travel time in minutes.
  final double travelTimeMinutes;

  const ViolationCheck({
    required this.type,
    required this.calculatedSpeedKmh,
    required this.thresholdMinutes,
    required this.travelTimeMinutes,
  });

  bool get isViolation => type != null;
  bool get isSpeeding => type == ViolationType.speeding;
  bool get isOverstay => type == ViolationType.overstay;
}

/// Calculates whether a vehicle's travel time constitutes a violation.
class SpeedCalculator {
  SpeedCalculator._();

  /// Check if a travel time constitutes a speeding or overstay violation.
  ///
  /// [distanceKm] - the highway segment distance in kilometers.
  /// [travelTime] - the actual time the vehicle took.
  /// [maxSpeedKmh] - the maximum allowed speed (speed limit).
  /// [minSpeedKmh] - the minimum expected speed (below = overstay).
  static ViolationCheck check({
    required double distanceKm,
    required Duration travelTime,
    required double maxSpeedKmh,
    required double minSpeedKmh,
  }) {
    final travelTimeMinutes = travelTime.inSeconds / 60.0;
    final travelTimeHours = travelTimeMinutes / 60.0;

    // Avoid division by zero.
    final calculatedSpeedKmh =
        travelTimeHours > 0 ? distanceKm / travelTimeHours : double.infinity;

    final minTravelTimeMinutes = (distanceKm / maxSpeedKmh) * 60.0;
    final maxTravelTimeMinutes = (distanceKm / minSpeedKmh) * 60.0;

    if (travelTimeMinutes < minTravelTimeMinutes) {
      return ViolationCheck(
        type: ViolationType.speeding,
        calculatedSpeedKmh: calculatedSpeedKmh,
        thresholdMinutes: minTravelTimeMinutes,
        travelTimeMinutes: travelTimeMinutes,
      );
    }

    if (travelTimeMinutes > maxTravelTimeMinutes) {
      return ViolationCheck(
        type: ViolationType.overstay,
        calculatedSpeedKmh: calculatedSpeedKmh,
        thresholdMinutes: maxTravelTimeMinutes,
        travelTimeMinutes: travelTimeMinutes,
      );
    }

    return ViolationCheck(
      type: null,
      calculatedSpeedKmh: calculatedSpeedKmh,
      thresholdMinutes: minTravelTimeMinutes,
      travelTimeMinutes: travelTimeMinutes,
    );
  }
}
