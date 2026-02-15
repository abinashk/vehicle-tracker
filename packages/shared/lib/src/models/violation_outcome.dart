import '../enums/outcome_type.dart';

class ViolationOutcome {
  final String id;
  final String violationId;
  final OutcomeType outcomeType;
  final double? fineAmount;
  final String? notes;
  final String recordedBy;
  final DateTime recordedAt;
  final DateTime createdAt;

  const ViolationOutcome({
    required this.id,
    required this.violationId,
    required this.outcomeType,
    this.fineAmount,
    this.notes,
    required this.recordedBy,
    required this.recordedAt,
    required this.createdAt,
  });

  factory ViolationOutcome.fromJson(Map<String, dynamic> json) {
    return ViolationOutcome(
      id: json['id'] as String,
      violationId: json['violation_id'] as String,
      outcomeType: OutcomeType.fromValue(json['outcome_type'] as String),
      fineAmount: (json['fine_amount'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'violation_id': violationId,
      'outcome_type': outcomeType.value,
      if (fineAmount != null) 'fine_amount': fineAmount,
      if (notes != null) 'notes': notes,
      'recorded_by': recordedBy,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'violation_id': violationId,
      'outcome_type': outcomeType.value,
      if (fineAmount != null) 'fine_amount': fineAmount,
      if (notes != null) 'notes': notes,
      'recorded_by': recordedBy,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViolationOutcome &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ViolationOutcome(id: $id, type: ${outcomeType.value})';
}
