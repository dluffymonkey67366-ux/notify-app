import 'package:flutter/material.dart';

/// Notify Typography Scale
/// Designed for high-volume CA exam reading (statutes, accounting standards, case laws).
/// Blends editorial serif readability for titles/headings with crisp geometric sans-serif for UI.
class NotifyTypography {
  // Editorial font family for study titles & headings
  static const String serifFamily = 'Georgia';
  // UI font family
  static const String sansFamily = '.SF Pro Text';

  static TextTheme createTextTheme(Color primaryTextColor, Color mutedTextColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: primaryTextColor,
        fontFamily: serifFamily,
        height: 1.25,
      ),
      displayMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primaryTextColor,
        fontFamily: serifFamily,
        height: 1.28,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primaryTextColor,
        fontFamily: serifFamily,
        height: 1.32,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        color: primaryTextColor,
        fontFamily: serifFamily,
        height: 1.36,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryTextColor,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryTextColor,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primaryTextColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        color: primaryTextColor,
        height: 1.62, // Enhanced line height for sustained reading
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: mutedTextColor,
        height: 1.55,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: mutedTextColor,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: primaryTextColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: mutedTextColor,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: mutedTextColor,
      ),
    );
  }

  // Academic / Statutory quotation styling
  static TextStyle statutoryExcerpt(Color textColor) => TextStyle(
    fontSize: 14,
    fontStyle: FontStyle.italic,
    fontFamily: serifFamily,
    height: 1.6,
    color: textColor,
  );

  // Badge pill text style
  static TextStyle badge(Color color) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: color,
  );

  // Metric / streak numbers
  static TextStyle metricNumber(Color color) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: color,
  );
}
