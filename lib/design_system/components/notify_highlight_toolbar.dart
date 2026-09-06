import 'package:flutter/material.dart';
import '../../models/reader_annotation_models.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../reader_theme.dart';

/// Floating toolbar displayed when note text is selected in the reader.
/// Enables DRM-safe highlighting in Amber, Emerald, and Coral,
/// plus one-tap encrypted bookmarking.
class NotifyHighlightToolbar extends StatelessWidget {
  final ValueChanged<HighlightColor> onColorSelected;
  final VoidCallback onBookmark;
  final VoidCallback onDismiss;
  final ReaderThemeConfig themeConfig;
  final bool isBookmarked;

  const NotifyHighlightToolbar({
    super.key,
    required this.onColorSelected,
    required this.onBookmark,
    required this.onDismiss,
    required this.themeConfig,
    this.isBookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: themeConfig.cardColor,
          borderRadius: NotifyRadius.pill,
          border: Border.all(
            color: themeConfig.borderColor.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color options: Amber, Emerald, Coral
            ...HighlightColor.values.map((color) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: NotifyRadius.pill,
                  onTap: () => onColorSelected(color),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.color.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: 8),
            Container(
              height: 20,
              width: 1,
              color: themeConfig.borderColor,
            ),
            const SizedBox(width: 4),

            // Bookmark button
            IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                color: isBookmarked ? NotifyColors.amber : themeConfig.textColor,
                size: 20,
              ),
              tooltip: isBookmarked ? 'Bookmarked' : 'Add Bookmark',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: onBookmark,
            ),

            // Dismiss button
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: themeConfig.textMutedColor,
                size: 18,
              ),
              tooltip: 'Dismiss',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
