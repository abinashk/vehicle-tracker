class Park {
  final String id;
  final String name;
  final String code;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Park({
    required this.id,
    required this.name,
    required this.code,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Park.fromJson(Map<String, dynamic> json) {
    return Park(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Park copyWith({
    String? id,
    String? name,
    String? code,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Park(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Park && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Park(id: $id, name: $name, code: $code)';
}
