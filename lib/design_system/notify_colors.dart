import 'package:flutter/material.dart';

/// Notify Color Tokens for CA Study App
/// Featuring Dark Reading Theme (--ink: #1A1A2E) and Light Paper Theme (--paper: #FAFAF7)
class NotifyColors {
  // Core Brand Tokens requested by user
  static const Color ink = Color(0xFF1A1A2E); // Dark reading mode background
  static const Color paper = Color(0xFFFAFAF7); // Light mode soft paper background

  // Dark Theme Palette (--ink ecosystem)
  static const Color inkDarker = Color(0xFF121220); // Deep background / app bar / nav rail
  static const Color inkCard = Color(0xFF22223B); // Elevated card & container surface
  static const Color inkCardElevated = Color(0xFF2B2B48); // Hover or highlighted card
  static const Color inkBorder = Color(0xFF33334E); // Card & divider borders
  static const Color inkBorderSubtle = Color(0x1FFFFFFF); // 12% white subtle borders

  // Light Theme Palette (--paper ecosystem)
  static const Color paperDarker = Color(0xFFF0EFEA); // Light contrast background
  static const Color paperCard = Color(0xFFFFFFFF); // Elevated light card surface
  static const Color paperCardElevated = Color(0xFFF7F7F4); // Hover card surface
  static const Color paperBorder = Color(0xFFE2E0D8); // Card & divider borders
  static const Color paperBorderSubtle = Color(0x14000000); // 8% black subtle borders

  // Accents & Brand Gold
  static const Color amber = Color(0xFFE5A93B); // Premium CA Gold / Amber
  static const Color amberLight = Color(0xFFFAD785); // Highlight gold
  static const Color amberDark = Color(0xFFC78C26); // Pressed gold
  static const Color goldSheen = Color(0xFFD4AF37); // Trophy / premium ribbon gold

  // Semantic & Status Colors
  static const Color teal = Color(0xFF2A9D8F); // Offline available / verified
  static const Color tealLight = Color(0xFF48CAE4);
  static const Color emerald = Color(0xFF2EAA55); // Healthy expiry (> 30 days)
  static const Color warningAmber = Color(0xFFF59E0B); // Expiring soon (8 - 30 days)
  static const Color coral = Color(0xFFE76F51); // Urgent expiry (<= 7 days)
  static const Color crimson = Color(0xFFE63946); // Expired / critical alert

  // Editorial & Academic Accents
  static const Color bronze = Color(0xFFC5A880); // Academic notes & chapters
  static const Color navy = Color(0xFF3D5A80); // Case study tag
  static const Color slate = Color(0xFF4A4E69); // ICAI reference badge

  // Dark Mode Text
  static const Color textLight = Color(0xFFF5F5FA); // High contrast text
  static const Color textMuted = Color(0xFF9E9EB4); // Medium contrast body/meta
  static const Color textSubtle = Color(0xFF6E6E88); // Low contrast hints/disabled

  // Light Mode Text
  static const Color textDark = Color(0xFF1E1E28); // High contrast text
  static const Color textDarkMuted = Color(0xFF5A5A70); // Medium contrast
  static const Color textDarkSubtle = Color(0xFF8A8A9E); // Low contrast hints

  // Subtle Shimmer / Gradients
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFE5A93B), Color(0xFFF5C563)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient inkCardGradient = LinearGradient(
    colors: [Color(0xFF24243E), Color(0xFF1E1E34)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient paperCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAF9F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
