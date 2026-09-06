import 'package:flutter/material.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../notify_typography.dart';
import '../reader_theme.dart';

/// Floating reader controls bar for adjusting reading ergonomics:
/// - Theme mode: Ink (--ink dark) / Paper (--paper light) / Sepia (#F4ECD8)
/// - Font size stepper: 14 / 16 / 18 / 20 / 22 px
/// - Typeface toggle: Georgia serif / Clean sans-serif
class NotifyReaderControlsBar extends StatelessWidget {
  final ReaderSettingsController settings;
  final VoidCallback? onClose;

  const NotifyReaderControlsBar({
    super.key,
    required this.settings,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final currentConfig = settings.themeConfig;
        final isDark = settings.themeMode == ReaderThemeMode.ink;
        final isMobile = MediaQuery.sizeOf(context).width < NotifyBreakpoints.medium;

        return Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: 12,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: currentConfig.cardColor.withValues(alpha: 0.96),
              borderRadius: NotifyRadius.xl,
              border: Border.all(
                color: currentConfig.borderColor.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Section title & close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: currentConfig.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'READING DISPLAY',
                          style: TextStyle(
                            color: currentConfig.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (onClose != null)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: currentConfig.textMutedColor,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: onClose,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Theme Mode Selector
                Row(
                  children: [
                    _buildThemePill(
                      context: context,
                      label: 'Ink',
                      mode: ReaderThemeMode.ink,
                      swatchColor: NotifyColors.ink,
                      textColor: NotifyColors.textLight,
                      isSelected: settings.themeMode == ReaderThemeMode.ink,
                    ),
                    const SizedBox(width: 8),
                    _buildThemePill(
                      context: context,
                      label: 'Paper',
                      mode: ReaderThemeMode.paper,
                      swatchColor: NotifyColors.paper,
                      textColor: NotifyColors.textDark,
                      isSelected: settings.themeMode == ReaderThemeMode.paper,
                    ),
                    const SizedBox(width: 8),
                    _buildThemePill(
                      context: context,
                      label: 'Sepia',
                      mode: ReaderThemeMode.sepia,
                      swatchColor: const Color(0xFFF4ECD8),
                      textColor: const Color(0xFF332717),
                      isSelected: settings.themeMode == ReaderThemeMode.sepia,
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(
                  color: currentConfig.borderColor.withValues(alpha: 0.5),
                  height: 1,
                  thickness: 1,
                ),
                const SizedBox(height: 14),

                // Bottom row: Font-size stepper and Typeface toggle
                Row(
                  children: [
                    // Font Size Stepper
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentConfig.backgroundColor.withValues(alpha: 0.7),
                          borderRadius: NotifyRadius.md,
                          border: Border.all(
                            color: currentConfig.borderColor.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Text(
                                'A-',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              color: settings.fontSize > 14
                                  ? currentConfig.textColor
                                  : currentConfig.textMutedColor.withValues(alpha: 0.3),
                              onPressed: settings.fontSize > 14
                                  ? () => settings.decreaseFontSize()
                                  : null,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            Text(
                              '${settings.fontSize.toInt()}px',
                              style: TextStyle(
                                color: currentConfig.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Text(
                                'A+',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              color: settings.fontSize < 22
                                  ? currentConfig.textColor
                                  : currentConfig.textMutedColor.withValues(alpha: 0.3),
                              onPressed: settings.fontSize < 22
                                  ? () => settings.increaseFontSize()
                                  : null,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Typeface toggle (Serif vs Sans)
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: currentConfig.backgroundColor.withValues(alpha: 0.7),
                          borderRadius: NotifyRadius.md,
                          border: Border.all(
                            color: currentConfig.borderColor.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTypefaceTab(
                                label: 'Serif',
                                isSelected: settings.isSerif,
                                currentConfig: currentConfig,
                                fontFamily: 'Georgia',
                                onTap: () => settings.setIsSerif(true),
                              ),
                            ),
                            Expanded(
                              child: _buildTypefaceTab(
                                label: 'Sans',
                                isSelected: !settings.isSerif,
                                currentConfig: currentConfig,
                                fontFamily: NotifyTypography.sansFamily,
                                onTap: () => settings.setIsSerif(false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemePill({
    required BuildContext context,
    required String label,
    required ReaderThemeMode mode,
    required Color swatchColor,
    required Color textColor,
    required bool isSelected,
  }) {
    final currentConfig = settings.themeConfig;

    return Expanded(
      child: Material(
        color: isSelected
            ? currentConfig.accentColor.withValues(alpha: 0.18)
            : currentConfig.backgroundColor.withValues(alpha: 0.6),
        borderRadius: NotifyRadius.md,
        child: InkWell(
          onTap: () => settings.setThemeMode(mode),
          borderRadius: NotifyRadius.md,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: NotifyRadius.md,
              border: Border.all(
                color: isSelected
                    ? currentConfig.accentColor
                    : currentConfig.borderColor.withValues(alpha: 0.6),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black26,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? currentConfig.textColor : currentConfig.textMutedColor,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypefaceTab({
    required String label,
    required bool isSelected,
    required ReaderThemeConfig currentConfig,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? currentConfig.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? currentConfig.textColor : currentConfig.textMutedColor,
              fontSize: 12,
              fontFamily: fontFamily,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
