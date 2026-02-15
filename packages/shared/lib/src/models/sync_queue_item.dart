import '../enums/sync_status.dart';

class SyncQueueItem {
  final String id;
  final String tableName;
  final String operation;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int attempts;
  final DateTime createdAt;
  final DateTime? lastAttemptedAt;
  final String? errorMessage;
  final DateTime? smsSentAt;

  const SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.operation,
    required this.payload,
    this.status = SyncStatus.pending,
    this.attempts = 0,
    required this.createdAt,
    this.lastAttemptedAt,
    this.errorMessage,
    this.smsSentAt,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      tableName: json['table_name'] as String,
      operation: json['operation'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      status: SyncStatus.fromValue(json['status'] as String),
      attempts: json['attempts'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastAttemptedAt: json['last_attempted_at'] != null
          ? DateTime.parse(json['last_attempted_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      smsSentAt: json['sms_sent_at'] != null
          ? DateTime.parse(json['sms_sent_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_name': tableName,
      'operation': operation,
      'payload': payload,
      'status': status.value,
      'attempts': attempts,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (lastAttemptedAt != null)
        'last_attempted_at': lastAttemptedAt!.toUtc().toIso8601String(),
      if (errorMessage != null) 'error_message': errorMessage,
      if (smsSentAt != null)
        'sms_sent_at': smsSentAt!.toUtc().toIso8601String(),
    };
  }

  bool get isPending => status == SyncStatus.pending;
  bool get isFailed => status == SyncStatus.failed;
  bool get isSynced => status == SyncStatus.synced;
  bool get hasSmsSent => smsSentAt != null;

  /// Max retry attempts before marking as failed.
  static const int maxAttempts = 5;

  /// Duration after which SMS fallback is triggered for pending items.
  static const Duration smsFallbackDelay = Duration(minutes: 5);

  bool get shouldTriggerSmsFallback =>
      isPending &&
      !hasSmsSent &&
      DateTime.now().difference(createdAt) > smsFallbackDelay;

  SyncQueueItem copyWith({
    String? id,
    String? tableName,
    String? operation,
    Map<String, dynamic>? payload,
    SyncStatus? status,
    int? attempts,
    DateTime? createdAt,
    DateTime? lastAttemptedAt,
    String? errorMessage,
    DateTime? smsSentAt,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      smsSentAt: smsSentAt ?? this.smsSentAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncQueueItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SyncQueueItem(id: $id, table: $tableName, status: ${status.value})';
}
