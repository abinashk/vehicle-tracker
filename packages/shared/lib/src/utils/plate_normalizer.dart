import '../constants/plate_regex.dart';

/// Normalizes Nepali license plate numbers to a canonical Latin format.
///
/// Converts Devanagari script to Latin equivalents, strips extra whitespace,
/// and uppercases the result for consistent matching.
class PlateNormalizer {
  PlateNormalizer._();

  /// Normalize a raw plate string to canonical Latin format.
  ///
  /// Examples:
  ///   'बा १ पा १२३४' → 'BA 1 PA 1234'
  ///   'ba 1 pa 1234'  → 'BA 1 PA 1234'
  ///   'BA1PA1234'      → 'BA 1 PA 1234'
  static String normalize(String raw) {
    var result = raw.trim();

    // Replace Devanagari digits with Latin digits.
    for (final entry in PlateRegex.devanagariToLatinDigits.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // Replace Devanagari zone/category codes with Latin equivalents.
    // Sort by length descending so longer codes match first.
    final sortedCodes = PlateRegex.devanagariToLatinCodes.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedCodes) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // Uppercase.
    result = result.toUpperCase();

    // Collapse multiple spaces to single space.
    result = result.replaceAll(RegExp(r'\s+'), ' ');

    // Remove any characters that aren't alphanumeric or space.
    result = result.replaceAll(RegExp(r'[^A-Z0-9 ]'), '');

    // Try to format into standard pattern: XX 0 XX 0000
    // by inserting spaces between letter groups and digit groups.
    result = _insertSpaces(result);

    return result.trim();
  }

  /// Insert spaces between letter and digit groups for readability.
  /// 'BA1PA1234' → 'BA 1 PA 1234'
  static String _insertSpaces(String input) {
    final buffer = StringBuffer();
    var prevIsDigit = false;
    var prevIsLetter = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      final isLetter = char.codeUnitAt(0) >= 65 && char.codeUnitAt(0) <= 90;
      final isSpace = char == ' ';

      if (isSpace) {
        buffer.write(' ');
        prevIsDigit = false;
        prevIsLetter = false;
        continue;
      }

      // Insert space at transitions between letters and digits.
      if ((prevIsDigit && isLetter) || (prevIsLetter && isDigit)) {
        buffer.write(' ');
      }

      buffer.write(char);
      prevIsDigit = isDigit;
      prevIsLetter = isLetter;
    }

    // Collapse multiple spaces.
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Strip all spaces from a normalized plate for compact matching.
  static String compact(String normalized) {
    return normalized.replaceAll(' ', '');
  }
}
