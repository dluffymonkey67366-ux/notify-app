import 'package:flutter/material.dart';
import 'notify_colors.dart';
import 'notify_typography.dart';
import 'notify_spacing.dart';

/// NotifyThemeExtension provides semantic design tokens that dynamically
/// adapt between the Dark Reading Theme (--ink) and Light Paper Theme (--paper).
class NotifyThemeExtension extends ThemeExtension<NotifyThemeExtension> {
  final Color bg;
  final Color bgDarker;
  final Color cardBg;
  final Color cardElevatedBg;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textMuted;
  final Color textSubtle;
  final Color accentAmber;
  final Color accentTeal;
  final Color accentCoral;
  final Color accentEmerald;
  final List<BoxShadow> cardShadows;

  const NotifyThemeExtension({
    required this.bg,
    required this.bgDarker,
    required this.cardBg,
    required this.cardElevatedBg,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textMuted,
    required this.textSubtle,
    required this.accentAmber,
    required this.accentTeal,
    required this.accentCoral,
    required this.accentEmerald,
    required this.cardShadows,
  });

  static const dark = NotifyThemeExtension(
    bg: NotifyColors.ink,
    bgDarker: NotifyColors.inkDarker,
    cardBg: NotifyColors.inkCard,
    cardElevatedBg: NotifyColors.inkCardElevated,
    border: NotifyColors.inkBorder,
    borderSubtle: NotifyColors.inkBorderSubtle,
    textPrimary: NotifyColors.textLight,
    textMuted: NotifyColors.textMuted,
    textSubtle: NotifyColors.textSubtle,
    accentAmber: NotifyColors.amber,
    accentTeal: NotifyColors.teal,
    accentCoral: NotifyColors.coral,
    accentEmerald: NotifyColors.emerald,
    cardShadows: NotifyShadows.darkCard,
  );

  static const light = NotifyThemeExtension(
    bg: NotifyColors.paper,
    bgDarker: NotifyColors.paperDarker,
    cardBg: NotifyColors.paperCard,
    cardElevatedBg: NotifyColors.paperCardElevated,
    border: NotifyColors.paperBorder,
    borderSubtle: NotifyColors.paperBorderSubtle,
    textPrimary: NotifyColors.textDark,
    textMuted: NotifyColors.textDarkMuted,
    textSubtle: NotifyColors.textDarkSubtle,
    accentAmber: NotifyColors.amber,
    accentTeal: NotifyColors.teal,
    accentCoral: NotifyColors.coral,
    accentEmerald: NotifyColors.emerald,
    cardShadows: NotifyShadows.lightCard,
  );

  @override
  NotifyThemeExtension copyWith({
    Color? bg,
    Color? bgDarker,
    Color? cardBg,
    Color? cardElevatedBg,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textMuted,
    Color? textSubtle,
    Color? accentAmber,
    Color? accentTeal,
    Color? accentCoral,
    Color? accentEmerald,
    List<BoxShadow>? cardShadows,
  }) {
    return NotifyThemeExtension(
      bg: bg ?? this.bg,
      bgDarker: bgDarker ?? this.bgDarker,
      cardBg: cardBg ?? this.cardBg,
      cardElevatedBg: cardElevatedBg ?? this.cardElevatedBg,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      accentAmber: accentAmber ?? this.accentAmber,
      accentTeal: accentTeal ?? this.accentTeal,
      accentCoral: accentCoral ?? this.accentCoral,
      accentEmerald: accentEmerald ?? this.accentEmerald,
      cardShadows: cardShadows ?? this.cardShadows,
    );
  }

  @override
  NotifyThemeExtension lerp(ThemeExtension<NotifyThemeExtension>? other, double t) {
    if (other is! NotifyThemeExtension) return this;
    return NotifyThemeExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      bgDarker: Color.lerp(bgDarker, other.bgDarker, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardElevatedBg: Color.lerp(cardElevatedBg, other.cardElevatedBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      accentAmber: Color.lerp(accentAmber, other.accentAmber, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentCoral: Color.lerp(accentCoral, other.accentCoral, t)!,
      accentEmerald: Color.lerp(accentEmerald, other.accentEmerald, t)!,
      cardShadows: cardShadows,
    );
  }
}

/// Helper extension for BuildContext to quickly access tokens
extension NotifyThemeContext on BuildContext {
  NotifyThemeExtension get notifyTheme {
    return Theme.of(this).extension<NotifyThemeExtension>() ?? NotifyThemeExtension.dark;
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Main Theme Factory for Notify App
class NotifyTheme {
  static NotifyThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<NotifyThemeExtension>() ?? NotifyThemeExtension.dark;
  }

  /// Dark Reading Theme (--ink: #1A1A2E background)
  static ThemeData get darkTheme {
    final textTheme = NotifyTypography.createTextTheme(
      NotifyColors.textLight,
      NotifyColors.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NotifyColors.ink,
      fontFamily: NotifyTypography.sansFamily,
      textTheme: textTheme,
      extensions: const [NotifyThemeExtension.dark],
      colorScheme: const ColorScheme.dark(
        primary: NotifyColors.amber,
        onPrimary: NotifyColors.inkDarker,
        secondary: NotifyColors.teal,
        surface: NotifyColors.inkCard,
        error: NotifyColors.crimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NotifyColors.inkDarker,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: NotifyColors.textLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: NotifyTypography.serifFamily,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: NotifyColors.textLight),
      ),
      cardTheme: CardThemeData(
        color: NotifyColors.inkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: NotifyRadius.lg,
          side: const BorderSide(color: NotifyColors.inkBorderSubtle, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NotifyColors.inkDarker,
        indicatorColor: NotifyColors.amber.withOpacity(0.18),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: NotifyColors.amber,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: NotifyColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: NotifyColors.amber, size: 24);
          }
          return const IconThemeData(color: NotifyColors.textMuted, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: NotifyColors.inkDarker,
        selectedIconTheme: const IconThemeData(color: NotifyColors.amber, size: 26),
        unselectedIconTheme: const IconThemeData(color: NotifyColors.textMuted, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: NotifyColors.amber,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: NotifyColors.textMuted,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        indicatorColor: NotifyColors.amber.withOpacity(0.18),
      ),
      dividerTheme: const DividerThemeData(
        color: NotifyColors.inkBorder,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NotifyColors.amber,
          foregroundColor: NotifyColors.inkDarker,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: NotifyRadius.md),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NotifyColors.amber,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: NotifyColors.amber, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: NotifyRadius.md),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Light Mode Theme (--paper: #FAFAF7 background)
  static ThemeData get lightTheme {
    final textTheme = NotifyTypography.createTextTheme(
      NotifyColors.textDark,
      NotifyColors.textDarkMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NotifyColors.paper,
      fontFamily: NotifyTypography.sansFamily,
      textTheme: textTheme,
      extensions: const [NotifyThemeExtension.light],
      colorScheme: const ColorScheme.light(
        primary: NotifyColors.amberDark,
        onPrimary: Colors.white,
        secondary: NotifyColors.teal,
        surface: NotifyColors.paperCard,
        error: NotifyColors.crimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NotifyColors.paperDarker,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: NotifyColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: NotifyTypography.serifFamily,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: NotifyColors.textDark),
      ),
      cardTheme: CardThemeData(
        color: NotifyColors.paperCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: NotifyRadius.lg,
          side: const BorderSide(color: NotifyColors.paperBorderSubtle, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NotifyColors.paperDarker,
        indicatorColor: NotifyColors.amberDark.withOpacity(0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: NotifyColors.amberDark,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: NotifyColors.textDarkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: NotifyColors.amberDark, size: 24);
          }
          return const IconThemeData(color: NotifyColors.textDarkMuted, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: NotifyColors.paperDarker,
        selectedIconTheme: const IconThemeData(color: NotifyColors.amberDark, size: 26),
        unselectedIconTheme: const IconThemeData(color: NotifyColors.textDarkMuted, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: NotifyColors.amberDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: NotifyColors.textDarkMuted,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        indicatorColor: NotifyColors.amberDark.withOpacity(0.12),
      ),
      dividerTheme: const DividerThemeData(
        color: NotifyColors.paperBorder,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NotifyColors.amberDark,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: NotifyRadius.md),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NotifyColors.amberDark,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: NotifyColors.amberDark, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: NotifyRadius.md),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Theme Controller for toggling between Ink Dark & Paper Light reading modes
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}
