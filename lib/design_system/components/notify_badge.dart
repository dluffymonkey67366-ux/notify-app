import 'package:flutter/material.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../notify_theme.dart';

/// Expiry Badge: Shows "X days remaining" with color shifts based on urgency
class NotifyExpiryBadge extends StatelessWidget {
  final int daysRemaining;
  final bool isCompact;

  const NotifyExpiryBadge({
    super.key,
    required this.daysRemaining,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final Color badgeBg;
    final IconData badgeIcon;
    final String label;

    if (daysRemaining <= 0) {
      badgeColor = NotifyColors.crimson;
      badgeBg = NotifyColors.crimson.withValues(alpha: 0.15);
      badgeIcon = Icons.error_outline_rounded;
      label = 'Access Expired';
    } else if (daysRemaining <= 7) {
      badgeColor = NotifyColors.coral;
      badgeBg = NotifyColors.coral.withValues(alpha: 0.18);
      badgeIcon = Icons.timer_outlined;
      label = '$daysRemaining days remaining';
    } else if (daysRemaining <= 30) {
      badgeColor = NotifyColors.warningAmber;
      badgeBg = NotifyColors.warningAmber.withValues(alpha: 0.16);
      badgeIcon = Icons.hourglass_top_rounded;
      label = '$daysRemaining days remaining';
    } else {
      badgeColor = NotifyColors.emerald;
      badgeBg = NotifyColors.emerald.withValues(alpha: 0.14);
      badgeIcon = Icons.event_available_rounded;
      label = '$daysRemaining days remaining';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7.0 : 9.0,
        vertical: isCompact ? 3.5 : 5.0,
      ),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: NotifyRadius.pill,
        border: Border.all(color: badgeColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: isCompact ? 12 : 13, color: badgeColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: badgeColor,
                fontSize: isCompact ? 10.5 : 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Offline Available Indicator
class NotifyOfflineIndicator extends StatelessWidget {
  final bool isAvailable;
  final int? sizeBytes;
  final bool isCompact;

  const NotifyOfflineIndicator({
    super.key,
    required this.isAvailable,
    this.sizeBytes,
    this.isCompact = false,
  });

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;

    if (isAvailable) {
      final sizeStr = sizeBytes != null ? ' • ${_formatSize(sizeBytes!)}' : '';
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 7.0 : 9.0,
          vertical: isCompact ? 3.5 : 5.0,
        ),
        decoration: BoxDecoration(
          color: NotifyColors.teal.withValues(alpha: 0.14),
          borderRadius: NotifyRadius.pill,
          border: Border.all(color: NotifyColors.teal.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: NotifyColors.teal,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.offline_pin_rounded, size: isCompact ? 12 : 13, color: NotifyColors.teal),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Offline available$sizeStr',
                style: TextStyle(
                  color: NotifyColors.teal,
                  fontSize: isCompact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 7.0 : 9.0,
          vertical: isCompact ? 3.5 : 5.0,
        ),
        decoration: BoxDecoration(
          color: theme.borderSubtle,
          borderRadius: NotifyRadius.pill,
          border: Border.all(color: theme.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue_rounded, size: isCompact ? 12 : 13, color: theme.textSubtle),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Online only',
                style: TextStyle(
                  color: theme.textSubtle,
                  fontSize: isCompact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Generic Tag Badge for CA levels, group, or paper numbers
class NotifyTagBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const NotifyTagBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final effectiveColor = color ?? theme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: NotifyRadius.sm,
        border: Border.all(color: effectiveColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
