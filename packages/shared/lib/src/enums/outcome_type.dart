enum OutcomeType {
  warned('warned', 'Warned'),
  fined('fined', 'Fined'),
  letGo('let_go', 'Let Go'),
  notFound('not_found', 'Not Found'),
  other('other', 'Other');

  const OutcomeType(this.value, this.label);

  final String value;
  final String label;

  static OutcomeType fromValue(String value) {
    return OutcomeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OutcomeType.other,
    );
  }
}
