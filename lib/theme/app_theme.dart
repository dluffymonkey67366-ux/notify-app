import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// AppTheme facade providing backwards compatibility while delegating
/// to the unified Notify design system tokens.
class AppTheme {
  // Brand tokens
  static const Color ink = NotifyColors.ink; // #1A1A2E dark reading background
  static const Color inkDarker = NotifyColors.inkDarker;
  static const Color inkCard = NotifyColors.inkCard;
  static const Color paper = NotifyColors.paper; // #FAFAF7 light paper background

  // Accents & status
  static const Color accentAmber = NotifyColors.amber;
  static const Color accentTeal = NotifyColors.teal;
  static const Color accentCoral = NotifyColors.coral;
  static const Color textMuted = NotifyColors.textMuted;
  static const Color textLight = NotifyColors.textLight;
  static const Color errorRed = NotifyColors.crimson;

  static ThemeData get darkTheme => NotifyTheme.darkTheme;
  static ThemeData get lightTheme => NotifyTheme.lightTheme;
}
