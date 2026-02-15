class HighwaySegment {
  final String id;
  final String parkId;
  final String name;
  final double distanceKm;
  final double maxSpeedKmh;
  final double minSpeedKmh;
  final double minTravelTimeMinutes;
  final double maxTravelTimeMinutes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HighwaySegment({
    required this.id,
    required this.parkId,
    required this.name,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.minSpeedKmh,
    required this.minTravelTimeMinutes,
    required this.maxTravelTimeMinutes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HighwaySegment.fromJson(Map<String, dynamic> json) {
    final distanceKm = (json['distance_km'] as num).toDouble();
    final maxSpeedKmh = (json['max_speed_kmh'] as num).toDouble();
    final minSpeedKmh = (json['min_speed_kmh'] as num).toDouble();

    return HighwaySegment(
      id: json['id'] as String,
      parkId: json['park_id'] as String,
      name: json['name'] as String,
      distanceKm: distanceKm,
      maxSpeedKmh: maxSpeedKmh,
      minSpeedKmh: minSpeedKmh,
      minTravelTimeMinutes: json['min_travel_time_minutes'] != null
          ? (json['min_travel_time_minutes'] as num).toDouble()
          : (distanceKm / maxSpeedKmh) * 60,
      maxTravelTimeMinutes: json['max_travel_time_minutes'] != null
          ? (json['max_travel_time_minutes'] as num).toDouble()
          : (distanceKm / minSpeedKmh) * 60,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'park_id': parkId,
      'name': name,
      'distance_km': distanceKm,
      'max_speed_kmh': maxSpeedKmh,
      'min_speed_kmh': minSpeedKmh,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  HighwaySegment copyWith({
    String? id,
    String? parkId,
    String? name,
    double? distanceKm,
    double? maxSpeedKmh,
    double? minSpeedKmh,
    double? minTravelTimeMinutes,
    double? maxTravelTimeMinutes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HighwaySegment(
      id: id ?? this.id,
      parkId: parkId ?? this.parkId,
      name: name ?? this.name,
      distanceKm: distanceKm ?? this.distanceKm,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      minSpeedKmh: minSpeedKmh ?? this.minSpeedKmh,
      minTravelTimeMinutes: minTravelTimeMinutes ?? this.minTravelTimeMinutes,
      maxTravelTimeMinutes: maxTravelTimeMinutes ?? this.maxTravelTimeMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighwaySegment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'HighwaySegment(id: $id, name: $name, distance: ${distanceKm}km)';
}
