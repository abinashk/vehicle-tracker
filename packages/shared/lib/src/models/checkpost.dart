class Checkpost {
  final String id;
  final String segmentId;
  final String name;
  final String code;
  final int positionIndex;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final DateTime createdAt;

  const Checkpost({
    required this.id,
    required this.segmentId,
    required this.name,
    required this.code,
    required this.positionIndex,
    this.latitude,
    this.longitude,
    this.isActive = true,
    required this.createdAt,
  });

  factory Checkpost.fromJson(Map<String, dynamic> json) {
    return Checkpost(
      id: json['id'] as String,
      segmentId: json['segment_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      positionIndex: json['position_index'] as int,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'segment_id': segmentId,
      'name': name,
      'code': code,
      'position_index': positionIndex,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Checkpost copyWith({
    String? id,
    String? segmentId,
    String? name,
    String? code,
    int? positionIndex,
    double? latitude,
    double? longitude,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Checkpost(
      id: id ?? this.id,
      segmentId: segmentId ?? this.segmentId,
      name: name ?? this.name,
      code: code ?? this.code,
      positionIndex: positionIndex ?? this.positionIndex,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Checkpost && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Checkpost(id: $id, name: $name, code: $code)';
}
