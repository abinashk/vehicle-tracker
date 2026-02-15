enum VehicleType {
  car('car', 'Car', 'CAR'),
  jeepSuv('jeep_suv', 'Jeep/SUV', 'JSV'),
  minibus('minibus', 'Minibus', 'MNB'),
  bus('bus', 'Bus', 'BUS'),
  truck('truck', 'Truck', 'TRK'),
  tanker('tanker', 'Tanker', 'TNK'),
  motorcycle('motorcycle', 'Motorcycle', 'MCY'),
  autoRickshaw('auto_rickshaw', 'Auto-rickshaw', 'ARK'),
  tractor('tractor', 'Tractor', 'TRC'),
  other('other', 'Other', 'OTH');

  const VehicleType(this.value, this.label, this.smsCode);

  /// Database/JSON value (snake_case).
  final String value;

  /// Human-readable display label.
  final String label;

  /// 3-character code used in SMS compact format.
  final String smsCode;

  static VehicleType fromValue(String value) {
    return VehicleType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VehicleType.other,
    );
  }

  static VehicleType fromSmsCode(String code) {
    return VehicleType.values.firstWhere(
      (e) => e.smsCode == code,
      orElse: () => VehicleType.other,
    );
  }
}
