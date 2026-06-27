import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppTheme {
  AppTheme._();

  static const Color primary      = Color(0xFF0D7377);
  static const Color primaryLight = Color(0xFF14A1A6);
  static const Color primaryDark  = Color(0xFF095A5E);
  static const Color accent       = Color(0xFFF5A623);
  static const Color accentDark   = Color(0xFFD4891A);
  static const Color success      = Color(0xFF18A463);
  static const Color successBg    = Color(0xFFE4F7EC);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningBg    = Color(0xFFFEF3E2);
  static const Color error        = Color(0xFFE5484D);
  static const Color errorBg      = Color(0xFFFDECEC);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoBg       = Color(0xFFEAF2FE);
  static const Color background     = Color(0xFFF4F7F9);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F5);
  static const Color textPrimary    = Color(0xFF14181F);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color textTertiary   = Color(0xFF9AA1AC);
  static const Color border         = Color(0xFFE0E7EC);
  static const Color divider        = Color(0xFFEDEFF2);
  static const Color shadow         = Color(0x14101828);
  static const Color driverColor    = Color(0xFF0D7377);
  static const Color passengerColor = Color(0xFFF5A623);
  static const Color adminColor     = Color(0xFFB7791F);

  static const double space4  = 4;
  static const double space8  = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;

  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusXl   = 24;
  static const double radiusPill = 999;

  static List<BoxShadow> get cardShadow => [
    const BoxShadow(color: Color(0x0A101828), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> get elevatedShadow => [
    const BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: error,
      onError: Colors.white,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: defaultTargetPlatform == TargetPlatform.iOS ? '.SF Pro Text' : 'Roboto',
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusPill), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusPill), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusPill), borderSide: const BorderSide(color: primary, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusPill), borderSide: const BorderSide(color: error, width: 1.4)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusPill), borderSide: const BorderSide(color: error, width: 1.8)),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 15),
        prefixIconColor: primary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLg), side: const BorderSide(color: border, width: 1)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      colorScheme: colorScheme,
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
      headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
      headlineSmall: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary, height: 1.4),
      bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary, height: 1.4),
      bodySmall: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: textTertiary, height: 1.3),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
      labelMedium: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary),
      labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textTertiary),
    );
  }
}