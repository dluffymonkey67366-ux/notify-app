import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../models/study_package.dart';
import '../../../services/progress_service.dart';

/// Hero Resume Card on Library Screen:
/// High-priority elevated card allowing CA students to resume studying immediately
/// with a single tap, displaying subject, active chapter, completion progress, and time elapsed.
class HeroResumeCard extends StatelessWidget {
  final StudyPackage package;
  final StudyProgress? progress;
  final VoidCallback onResume;

  const HeroResumeCard({
    super.key,
    required this.package,
    this.progress,
    required this.onResume,
  });

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Last studied recently';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Last studied just now';
    } else if (diff.inMinutes < 60) {
      return 'Last studied ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Last studied ${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Last studied yesterday';
    } else {
      return 'Last studied ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= NotifyBreakpoints.medium;

    final chapterName = progress?.chapterTitle ?? package.lastReadChapterTitle;
    final lastStudiedText = _formatTimeAgo(progress?.updatedAt);
    final completionPct = progress != null
        ? (progress!.completionPercentage / 100.0).clamp(0.0, 1.0)
        : package.progressPercentage;

    // Short section name for the button label
    String buttonSection = 'Chapter ${package.lastReadChapterNumber}';
    if (chapterName.contains(':')) {
      buttonSection = chapterName.split(':').first.trim();
    }

    return NotifyCard(
      isElevated: true,
      accentStripeColor: package.accentColor,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 14,
        vertical: isDesktop ? 20 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Chip + Last studied label
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: package.accentColor.withValues(alpha: 0.16),
                    borderRadius: NotifyRadius.sm,
                    border: Border.all(
                      color: package.accentColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, size: 12, color: package.accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'RESUME STUDYING',
                        style: TextStyle(
                          color: package.accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                NotifyTagBadge(
                  label: package.paperCode,
                  color: theme.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  lastStudiedText,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Subject Title
          Text(
            package.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: theme.textPrimary,
              fontSize: isDesktop ? 20 : 17,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Active Chapter Name
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 14, color: package.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  chapterName,
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress Bar
          NotifyProgressBar(
            value: completionPct,
            label: 'Module Completion',
            color: package.accentColor,
            trailingText: '${(completionPct * 100).toInt()}% completed',
          ),

          const SizedBox(height: 16),

          // Action Button
          NotifyButton(
            label: 'Continue $buttonSection ›',
            onPressed: onResume,
            isFullWidth: true,
            leadingIcon: Icons.auto_stories_rounded,
          ),
        ],
      ),
    );
  }
}
