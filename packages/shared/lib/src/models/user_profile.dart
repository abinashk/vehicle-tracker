import '../enums/user_role.dart';

class UserProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final String? phoneNumber;
  final String? assignedCheckpostId;
  final String? assignedParkId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.phoneNumber,
    this.assignedCheckpostId,
    this.assignedParkId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.fromValue(json['role'] as String),
      phoneNumber: json['phone_number'] as String?,
      assignedCheckpostId: json['assigned_checkpost_id'] as String?,
      assignedParkId: json['assigned_park_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role.value,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (assignedCheckpostId != null)
        'assigned_checkpost_id': assignedCheckpostId,
      if (assignedParkId != null) 'assigned_park_id': assignedParkId,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  bool get isRanger => role == UserRole.ranger;
  bool get isAdmin => role == UserRole.admin;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserProfile(id: $id, name: $fullName, role: ${role.value})';
}
