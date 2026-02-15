import 'package:flutter/material.dart';

/// Professional admin dashboard theme for the Vehicle Tracker web app.
class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color _primaryColor = Color(0xFF1B5E20);
  // ignore: unused_field
  static const Color _primaryLight = Color(0xFF4C8C4A);
  // ignore: unused_field
  static const Color _primaryDark = Color(0xFF003300);
  static const Color _secondaryColor = Color(0xFF00695C);
  static const Color _errorColor = Color(0xFFD32F2F);
  static const Color _warningColor = Color(0xFFF57C00);
  static const Color _successColor = Color(0xFF388E3C);
  static const Color _surfaceColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _sidebarColor = Color(0xFF1B2A1B);
  static const Color _sidebarActiveColor = Color(0xFF2E7D32);

  /// Sidebar background color.
  static Color get sidebarBackground => _sidebarColor;

  /// Sidebar active item color.
  static Color get sidebarActive => _sidebarActiveColor;

  /// Warning color for violation badges.
  static Color get warningColor => _warningColor;

  /// Success color for resolved items.
  static Color get successColor => _successColor;

  /// Error color for alerts.
  static Color get errorColor => _errorColor;

  /// The light theme for the admin dashboard.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _surfaceColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surfaceColor,
      cardColor: _cardColor,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColor,
          side: const BorderSide(color: _primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _errorColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          fontSize: 13,
        ),
        dataTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
        ),
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: Color(0xFFE0E0E0),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Badge color for violation types.
  static Color violationColor(String type) {
    switch (type) {
      case 'speeding':
        return _errorColor;
      case 'overstay':
        return _warningColor;
      default:
        return Colors.grey;
    }
  }

  /// Badge color for outcome types.
  static Color outcomeColor(String type) {
    switch (type) {
      case 'warned':
        return _warningColor;
      case 'fined':
        return _errorColor;
      case 'let_go':
        return _successColor;
      case 'not_found':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
