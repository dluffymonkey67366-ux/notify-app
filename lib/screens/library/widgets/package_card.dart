import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../models/study_package.dart';

/// Highly polished Study Package Card for CA students
class PackageCard extends StatelessWidget {
  final StudyPackage package;
  final VoidCallback? onOpenReader;
  final VoidCallback? onToggleOffline;

  const PackageCard({
    super.key,
    required this.package,
    this.onOpenReader,
    this.onToggleOffline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;

    return NotifyCard(
      onTap: onOpenReader,
      accentStripeColor: package.accentColor,
      isElevated: true,
      padding: const EdgeInsets.all(15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top metadata row: Tags (left) + Expiry Badge (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: NotifyTagBadge(
                  label: '${package.paperCode} • ${package.groupName}',
                  color: theme.accentAmber,
                ),
              ),
              const SizedBox(width: 8),
              // "X days remaining" expiry badge
              NotifyExpiryBadge(
                daysRemaining: package.daysRemaining,
                isCompact: true,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Course Title with Subject Icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: package.accentColor.withValues(alpha: 0.15),
                  borderRadius: NotifyRadius.sm,
                  border: Border.all(
                    color: package.accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  package.icon,
                  size: 17,
                  color: package.accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  package.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Faculty & Scheme
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 13, color: theme.textSubtle),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${package.instructorName} • ${package.syllabusScheme}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Offline Available Indicator + Chapter count
          Row(
            children: [
              // Offline Available Indicator
              Expanded(
                child: NotifyOfflineIndicator(
                  isAvailable: package.isOfflineAvailable,
                  sizeBytes: package.isOfflineAvailable ? package.offlineSizeBytes : null,
                  isCompact: true,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${package.completedChapters}/${package.totalChapters} Ch',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar
          NotifyProgressBar(
            value: package.progressPercentage,
            color: package.accentColor,
            label: 'Syllabus Progress',
          ),

          const SizedBox(height: 10),

          // Last Read Snippet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.bgDarker.withValues(alpha: 0.6),
              borderRadius: NotifyRadius.sm,
              border: Border.all(color: theme.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 15,
                  color: theme.accentAmber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    package.lastReadChapterTitle,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: NotifyButton(
                  label: 'Resume Reading',
                  leadingIcon: Icons.auto_stories_rounded,
                  isCompact: true,
                  onPressed: onOpenReader,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: package.isOfflineAvailable ? 'Offline Ready' : 'Download for Offline',
                child: IconButton(
                  icon: Icon(
                    package.isOfflineAvailable
                        ? Icons.download_done_rounded
                        : Icons.cloud_download_outlined,
                    color: package.isOfflineAvailable ? NotifyColors.teal : theme.textMuted,
                    size: 20,
                  ),
                  onPressed: onToggleOffline,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.cardElevatedBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: NotifyRadius.md,
                      side: BorderSide(color: theme.border, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
