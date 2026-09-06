import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notify_colors.dart';

enum ReaderThemeMode { ink, paper, sepia }

class ReaderThemeConfig {
  final ReaderThemeMode mode;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color textMutedColor;
  final Color cardColor;
  final Color borderColor;
  final Color accentColor;
  final String bgHex;
  final String textHex;
  final String textMutedHex;
  final String cardBgHex;
  final String borderHex;
  final String accentHex;

  bool get isDark => mode == ReaderThemeMode.ink;

  const ReaderThemeConfig({
    required this.mode,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.textMutedColor,
    required this.cardColor,
    required this.borderColor,
    required this.accentColor,
    required this.bgHex,
    required this.textHex,
    required this.textMutedHex,
    required this.cardBgHex,
    required this.borderHex,
    required this.accentHex,
  });

  static const ink = ReaderThemeConfig(
    mode: ReaderThemeMode.ink,
    label: 'Ink',
    backgroundColor: NotifyColors.ink,
    textColor: NotifyColors.textLight,
    textMutedColor: NotifyColors.textMuted,
    cardColor: NotifyColors.inkCard,
    borderColor: NotifyColors.inkBorder,
    accentColor: NotifyColors.amber,
    bgHex: '#1A1A2E',
    textHex: '#F5F5FA',
    textMutedHex: '#9E9EB4',
    cardBgHex: '#22223B',
    borderHex: '#33334E',
    accentHex: '#E5A93B',
  );

  static const paper = ReaderThemeConfig(
    mode: ReaderThemeMode.paper,
    label: 'Paper',
    backgroundColor: NotifyColors.paper,
    textColor: NotifyColors.textDark,
    textMutedColor: NotifyColors.textDarkMuted,
    cardColor: NotifyColors.paperCard,
    borderColor: NotifyColors.paperBorder,
    accentColor: NotifyColors.amberDark,
    bgHex: '#FAFAF7',
    textHex: '#1E1E28',
    textMutedHex: '#5A5A70',
    cardBgHex: '#FFFFFF',
    borderHex: '#E2E0D8',
    accentHex: '#C78C26',
  );

  static const sepia = ReaderThemeConfig(
    mode: ReaderThemeMode.sepia,
    label: 'Sepia',
    backgroundColor: Color(0xFFF4ECD8),
    textColor: Color(0xFF332717),
    textMutedColor: Color(0xFF6B5844),
    cardColor: Color(0xFFEAE0C8),
    borderColor: Color(0xFFD9CEB2),
    accentColor: Color(0xFFA66A1E),
    bgHex: '#F4ECD8',
    textHex: '#332717',
    textMutedHex: '#6B5844',
    cardBgHex: '#EAE0C8',
    borderHex: '#D9CEB2',
    accentHex: '#A66A1E',
  );

  static ReaderThemeConfig fromMode(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.ink:
        return ink;
      case ReaderThemeMode.paper:
        return paper;
      case ReaderThemeMode.sepia:
        return sepia;
    }
  }
}

/// Controller that manages and persists reader display preferences:
/// - Theme (Ink dark / Paper light / Sepia warm)
/// - Font size (14px to 22px)
/// - Typeface (Georgia serif vs Clean sans-serif)
class ReaderSettingsController extends ChangeNotifier {
  static final ReaderSettingsController _instance = ReaderSettingsController._internal();
  factory ReaderSettingsController() => _instance;
  ReaderSettingsController._internal() {
    loadSettings();
  }

  static const String _prefThemeKey = 'notify_reader_theme_mode';
  static const String _prefFontSizeKey = 'notify_reader_font_size';
  static const String _prefIsSerifKey = 'notify_reader_is_serif';

  ReaderThemeMode _themeMode = ReaderThemeMode.ink;
  double _fontSize = 16.0;
  bool _isSerif = true;
  bool _isLoaded = false;

  ReaderThemeMode get themeMode => _themeMode;
  ReaderThemeConfig get themeConfig => ReaderThemeConfig.fromMode(_themeMode);
  double get fontSize => _fontSize;
  bool get isSerif => _isSerif;
  String get fontFamilyCss => _isSerif ? 'Georgia, serif' : 'system-ui, -apple-system, sans-serif';
  bool get isLoaded => _isLoaded;

  static const List<double> availableFontSizes = [14.0, 16.0, 18.0, 20.0, 22.0];

  @visibleForTesting
  void resetForTesting() {
    _themeMode = ReaderThemeMode.ink;
    _fontSize = 16.0;
    _isSerif = true;
    _isLoaded = true;
  }

  Future<void> init() => loadSettings();

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString(_prefThemeKey);
      if (themeStr != null) {
        if (themeStr == 'paper') {
          _themeMode = ReaderThemeMode.paper;
        } else if (themeStr == 'sepia') {
          _themeMode = ReaderThemeMode.sepia;
        } else {
          _themeMode = ReaderThemeMode.ink;
        }
      }

      final savedSize = prefs.getDouble(_prefFontSizeKey);
      if (savedSize != null && availableFontSizes.contains(savedSize)) {
        _fontSize = savedSize;
      }

      final savedIsSerif = prefs.getBool(_prefIsSerifKey);
      if (savedIsSerif != null) {
        _isSerif = savedIsSerif;
      }

      _isLoaded = true;
      notifyListeners();
    } catch (_) {
      // In-memory defaults fallback
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ReaderThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, mode.name);
    } catch (_) {}
  }

  Future<void> setFontSize(double size) async {
    if (_fontSize == size || !availableFontSizes.contains(size)) return;
    _fontSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefFontSizeKey, size);
    } catch (_) {}
  }

  Future<void> increaseFontSize() async {
    final currentIndex = availableFontSizes.indexOf(_fontSize);
    if (currentIndex < availableFontSizes.length - 1) {
      await setFontSize(availableFontSizes[currentIndex + 1]);
    }
  }

  Future<void> decreaseFontSize() async {
    final currentIndex = availableFontSizes.indexOf(_fontSize);
    if (currentIndex > 0) {
      await setFontSize(availableFontSizes[currentIndex - 1]);
    }
  }

  Future<void> setIsSerif(bool isSerif) async {
    if (_isSerif == isSerif) return;
    _isSerif = isSerif;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefIsSerifKey, isSerif);
    } catch (_) {}
  }
}
