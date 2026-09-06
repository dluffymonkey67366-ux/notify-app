import 'package:flutter/material.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../notify_theme.dart';

enum NotifyButtonVariant { primary, secondary, ghost }

/// Premium Styled Button for Notify App
class NotifyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final NotifyButtonVariant variant;
  final bool isFullWidth;
  final bool isCompact;
  final bool isLoading;

  const NotifyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.variant = NotifyButtonVariant.primary,
    this.isFullWidth = false,
    this.isCompact = false,
    this.isLoading = false,
  });

  const NotifyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = false,
    this.isCompact = false,
    this.isLoading = false,
  }) : variant = NotifyButtonVariant.secondary;

  const NotifyButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = false,
    this.isCompact = false,
    this.isLoading = false,
  }) : variant = NotifyButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final isDark = context.isDarkMode;

    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case NotifyButtonVariant.primary:
        bgColor = theme.accentAmber;
        fgColor = isDark ? NotifyColors.inkDarker : Colors.white;
        break;
      case NotifyButtonVariant.secondary:
        bgColor = Colors.transparent;
        fgColor = theme.accentAmber;
        borderSide = BorderSide(color: theme.accentAmber.withOpacity(0.6), width: 1.2);
        break;
      case NotifyButtonVariant.ghost:
        bgColor = Colors.transparent;
        fgColor = theme.textMuted;
        break;
    }

    final height = isCompact ? 38.0 : 46.0;
    final fontSize = isCompact ? 13.0 : 14.5;
    final paddingH = isCompact ? 14.0 : 20.0;

    Widget child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: isCompact ? 16 : 18, color: fgColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: fgColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: isCompact ? 16 : 18, color: fgColor),
        ],
      ],
    );

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: NotifyRadius.md,
        side: borderSide,
      ),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: NotifyRadius.md,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: paddingH),
          child: child,
        ),
      ),
    );
  }
}
