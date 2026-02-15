/// Regular expressions for Nepali license plate number formats.
class PlateRegex {
  PlateRegex._();

  /// Devanagari digits mapped to Latin digits.
  static const Map<String, String> devanagariToLatinDigits = {
    '\u0966': '0', // ०
    '\u0967': '1', // १
    '\u0968': '2', // २
    '\u0969': '3', // ३
    '\u096A': '4', // ४
    '\u096B': '5', // ५
    '\u096C': '6', // ६
    '\u096D': '7', // ७
    '\u096E': '8', // ८
    '\u096F': '9', // ९
  };

  /// Common Devanagari zone/province codes mapped to Latin equivalents.
  static const Map<String, String> devanagariToLatinCodes = {
    '\u092C\u093E': 'BA', // बा (Bagmati/Province)
    '\u0928\u093E': 'NA', // ना (Narayani)
    '\u091C': 'JA', // ज (Janakpur)
    '\u0915\u094B': 'KO', // को (Koshi)
    '\u0938\u093E': 'SA', // सा (Sagarmatha)
    '\u092E\u0947': 'ME', // मे (Mechi)
    '\u0932\u0941': 'LU', // लु (Lumbini)
    '\u0927': 'DHA', // ध (Dhaulagiri)
    '\u0930\u093E': 'RA', // रा (Rapti)
    '\u092D\u0947': 'BHE', // भे (Bheri)
    '\u0938\u0947': 'SE', // से (Seti)
    '\u092E': 'MA', // म (Mahakali)
    '\u092A\u093E': 'PA', // पा (category code)
    '\u091A': 'CHA', // च (category code)
    '\u091D': 'JHA', // झ (category code)
    '\u0917': 'GA', // ग (category code)
  };

  /// Pattern matching a normalized plate number (Latin script).
  /// Matches formats like: BA 1 PA 1234, NA 1 JA 1234
  static final RegExp normalizedPlatePattern = RegExp(
    r'^[A-Z]{2,3}\s?\d\s?[A-Z]{1,3}\s?\d{1,4}$',
    caseSensitive: false,
  );
}
