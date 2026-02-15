import '../enums/violation_type.dart';
import '../enums/vehicle_type.dart';

class Violation {
  final String id;
  final String entryPassageId;
  final String exitPassageId;
  final String segmentId;
  final ViolationType violationType;
  final String plateNumber;
  final VehicleType vehicleType;
  final DateTime entryTime;
  final DateTime exitTime;
  final double travelTimeMinutes;
  final double thresholdMinutes;
  final double calculatedSpeedKmh;
  final double speedLimitKmh;
  final double distanceKm;
  final DateTime? alertDeliveredAt;
  final DateTime createdAt;

  const Violation({
    required this.id,
    required this.entryPassageId,
    required this.exitPassageId,
    required this.segmentId,
    required this.violationType,
    required this.plateNumber,
    required this.vehicleType,
    required this.entryTime,
    required this.exitTime,
    required this.travelTimeMinutes,
    required this.thresholdMinutes,
    required this.calculatedSpeedKmh,
    required this.speedLimitKmh,
    required this.distanceKm,
    this.alertDeliveredAt,
    required this.createdAt,
  });

  factory Violation.fromJson(Map<String, dynamic> json) {
    return Violation(
      id: json['id'] as String,
      entryPassageId: json['entry_passage_id'] as String,
      exitPassageId: json['exit_passage_id'] as String,
      segmentId: json['segment_id'] as String,
      violationType:
          ViolationType.fromValue(json['violation_type'] as String),
      plateNumber: json['plate_number'] as String,
      vehicleType: VehicleType.fromValue(json['vehicle_type'] as String),
      entryTime: DateTime.parse(json['entry_time'] as String),
      exitTime: DateTime.parse(json['exit_time'] as String),
      travelTimeMinutes:
          (json['travel_time_minutes'] as num).toDouble(),
      thresholdMinutes:
          (json['threshold_minutes'] as num).toDouble(),
      calculatedSpeedKmh:
          (json['calculated_speed_kmh'] as num).toDouble(),
      speedLimitKmh: (json['speed_limit_kmh'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      alertDeliveredAt: json['alert_delivered_at'] != null
          ? DateTime.parse(json['alert_delivered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_passage_id': entryPassageId,
      'exit_passage_id': exitPassageId,
      'segment_id': segmentId,
      'violation_type': violationType.value,
      'plate_number': plateNumber,
      'vehicle_type': vehicleType.value,
      'entry_time': entryTime.toUtc().toIso8601String(),
      'exit_time': exitTime.toUtc().toIso8601String(),
      'travel_time_minutes': travelTimeMinutes,
      'threshold_minutes': thresholdMinutes,
      'calculated_speed_kmh': calculatedSpeedKmh,
      'speed_limit_kmh': speedLimitKmh,
      'distance_km': distanceKm,
      if (alertDeliveredAt != null)
        'alert_delivered_at': alertDeliveredAt!.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  bool get isSpeeding => violationType == ViolationType.speeding;
  bool get isOverstay => violationType == ViolationType.overstay;

  /// How many minutes the vehicle was over/under the threshold.
  double get thresholdDifferenceMinutes =>
      (travelTimeMinutes - thresholdMinutes).abs();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Violation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Violation(id: $id, type: ${violationType.label}, plate: $plateNumber)';
}
