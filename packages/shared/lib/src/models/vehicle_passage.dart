import '../enums/vehicle_type.dart';

class VehiclePassage {
  final String id;
  final String clientId;
  final String plateNumber;
  final String? plateNumberRaw;
  final VehicleType vehicleType;
  final String checkpostId;
  final String segmentId;
  final DateTime recordedAt;
  final DateTime? serverReceivedAt;
  final String rangerId;
  final String? photoPath;
  final String? photoLocalPath;
  final String source;
  final String? matchedPassageId;
  final bool? isEntry;
  final DateTime createdAt;

  const VehiclePassage({
    required this.id,
    required this.clientId,
    required this.plateNumber,
    this.plateNumberRaw,
    required this.vehicleType,
    required this.checkpostId,
    required this.segmentId,
    required this.recordedAt,
    this.serverReceivedAt,
    required this.rangerId,
    this.photoPath,
    this.photoLocalPath,
    this.source = 'app',
    this.matchedPassageId,
    this.isEntry,
    required this.createdAt,
  });

  factory VehiclePassage.fromJson(Map<String, dynamic> json) {
    return VehiclePassage(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      plateNumber: json['plate_number'] as String,
      plateNumberRaw: json['plate_number_raw'] as String?,
      vehicleType: VehicleType.fromValue(json['vehicle_type'] as String),
      checkpostId: json['checkpost_id'] as String,
      segmentId: json['segment_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      serverReceivedAt: json['server_received_at'] != null
          ? DateTime.parse(json['server_received_at'] as String)
          : null,
      rangerId: json['ranger_id'] as String,
      photoPath: json['photo_path'] as String?,
      photoLocalPath: json['photo_local_path'] as String?,
      source: json['source'] as String? ?? 'app',
      matchedPassageId: json['matched_passage_id'] as String?,
      isEntry: json['is_entry'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'plate_number': plateNumber,
      if (plateNumberRaw != null) 'plate_number_raw': plateNumberRaw,
      'vehicle_type': vehicleType.value,
      'checkpost_id': checkpostId,
      'segment_id': segmentId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'ranger_id': rangerId,
      if (photoPath != null) 'photo_path': photoPath,
      'source': source,
      if (matchedPassageId != null) 'matched_passage_id': matchedPassageId,
      if (isEntry != null) 'is_entry': isEntry,
    };
  }

  /// JSON for inserting to Supabase (excludes server-generated fields).
  Map<String, dynamic> toInsertJson() {
    return {
      'client_id': clientId,
      'plate_number': plateNumber,
      if (plateNumberRaw != null) 'plate_number_raw': plateNumberRaw,
      'vehicle_type': vehicleType.value,
      'checkpost_id': checkpostId,
      'segment_id': segmentId,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'ranger_id': rangerId,
      'source': source,
    };
  }

  bool get isMatched => matchedPassageId != null;

  VehiclePassage copyWith({
    String? id,
    String? clientId,
    String? plateNumber,
    String? plateNumberRaw,
    VehicleType? vehicleType,
    String? checkpostId,
    String? segmentId,
    DateTime? recordedAt,
    DateTime? serverReceivedAt,
    String? rangerId,
    String? photoPath,
    String? photoLocalPath,
    String? source,
    String? matchedPassageId,
    bool? isEntry,
    DateTime? createdAt,
  }) {
    return VehiclePassage(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      plateNumber: plateNumber ?? this.plateNumber,
      plateNumberRaw: plateNumberRaw ?? this.plateNumberRaw,
      vehicleType: vehicleType ?? this.vehicleType,
      checkpostId: checkpostId ?? this.checkpostId,
      segmentId: segmentId ?? this.segmentId,
      recordedAt: recordedAt ?? this.recordedAt,
      serverReceivedAt: serverReceivedAt ?? this.serverReceivedAt,
      rangerId: rangerId ?? this.rangerId,
      photoPath: photoPath ?? this.photoPath,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      source: source ?? this.source,
      matchedPassageId: matchedPassageId ?? this.matchedPassageId,
      isEntry: isEntry ?? this.isEntry,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehiclePassage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VehiclePassage(id: $id, plate: $plateNumber, type: ${vehicleType.value})';
}
