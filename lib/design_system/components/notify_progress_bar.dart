import 'package:flutter/material.dart';
import '../notify_spacing.dart';
import '../notify_theme.dart';

/// Notify Progress Bar: Elegant progress indicator for CA chapter and syllabus completion
class NotifyProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String? label;
  final String? trailingText;
  final Color? color;
  final double height;
  final bool showPercentage;

  const NotifyProgressBar({
    super.key,
    required this.value,
    this.label,
    this.trailingText,
    this.color,
    this.height = 6.0,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final clampedValue = value.clamp(0.0, 1.0);
    final percentageInt = (clampedValue * 100).toInt();
    final barColor = color ?? theme.accentAmber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || trailingText != null || showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Expanded(
                  child: Text(
                    label!,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                trailingText ?? '$percentageInt% completed',
                style: TextStyle(
                  color: showPercentage && clampedValue > 0 ? barColor : theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Stack(
          children: [
            // Background track
            Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.border.withOpacity(0.4),
                borderRadius: NotifyRadius.pill,
              ),
            ),
            // Filled bar
            FractionallySizedBox(
              widthFactor: clampedValue,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      barColor.withOpacity(0.85),
                      barColor,
                    ],
                  ),
                  borderRadius: NotifyRadius.pill,
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
