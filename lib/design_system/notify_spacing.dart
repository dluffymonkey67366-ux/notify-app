import 'package:flutter/material.dart';

/// Notify Spacing, Radius, Shadows, and Breakpoint Tokens
class NotifySpacing {
  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;
  static const double monumental = 64.0;

  // Inset presets
  static const EdgeInsets paddingCard = EdgeInsets.all(16.0);
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);
  static const EdgeInsets paddingScreenWide = EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0);
  static const EdgeInsets paddingBadge = EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0);
  static const EdgeInsets paddingChip = EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);
}

class NotifyRadius {
  static const double xsVal = 4.0;
  static const double smVal = 8.0;
  static const double mdVal = 12.0;
  static const double lgVal = 16.0;
  static const double xlVal = 20.0;
  static const double xxlVal = 24.0;
  static const double pillVal = 999.0;

  static const BorderRadius xs = BorderRadius.all(Radius.circular(xsVal));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(smVal));
  static const BorderRadius md = BorderRadius.all(Radius.circular(mdVal));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(lgVal));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(xlVal));
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(xxlVal));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(pillVal));
}

class NotifyShadows {
  // Dark mode soft glow
  static const List<BoxShadow> darkCard = [
    BoxShadow(
      color: Color(0x28000000),
      offset: Offset(0, 4),
      blurRadius: 14,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> darkElevated = [
    BoxShadow(
      color: Color(0x40000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1AE5A93B), // Subtle gold ambient halo
      offset: Offset(0, 0),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  // Light mode soft paper elevation
  static const List<BoxShadow> lightCard = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 2),
      blurRadius: 10,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x08000000),
      offset: Offset(0, 6),
      blurRadius: 18,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> lightElevated = [
    BoxShadow(
      color: Color(0x12000000),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];
}

class NotifyBreakpoints {
  static const double compact = 600.0; // Phone
  static const double medium = 840.0; // Tablet / Foldable
  static const double expanded = 1200.0; // Desktop

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMediumOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= compact;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;
}
