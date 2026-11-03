/// Parses a positive or negative decimal amount into minor units without using
/// floating-point arithmetic. A period is the only accepted decimal separator.
int? parseMinorUnits(String raw) {
  final String input = raw.trim();
  if (!RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(input)) return null;

  final bool negative = input.startsWith('-');
  final String unsigned = negative ? input.substring(1) : input;
  final List<String> parts = unsigned.split('.');
  final int? whole = int.tryParse(parts.first);
  if (whole == null) return null;

  final String fractional = parts.length == 1
      ? '00'
      : parts.last.padRight(2, '0');
  final int? cents = int.tryParse(fractional);
  if (cents == null) return null;

  final int amount = whole * 100 + cents;
  return negative ? -amount : amount;
}

String? validateRequired(String? value, {String label = 'This field'}) {
  if (value == null || value.trim().isEmpty) return '$label is required.';
  return null;
}

String? validatePositiveAmount(String? value) {
  final int? minorUnits = value == null ? null : parseMinorUnits(value);
  if (minorUnits == null || minorUnits <= 0) {
    return 'Enter an amount greater than zero with up to two decimal places.';
  }
  return null;
}
