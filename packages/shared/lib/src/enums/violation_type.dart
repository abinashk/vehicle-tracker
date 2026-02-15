enum ViolationType {
  speeding('speeding', 'SPEEDING'),
  overstay('overstay', 'OVERSTAY');

  const ViolationType(this.value, this.label);

  /// Database/JSON value.
  final String value;

  /// Display label for alerts.
  final String label;

  static ViolationType fromValue(String value) {
    return ViolationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ViolationType.speeding,
    );
  }
}
