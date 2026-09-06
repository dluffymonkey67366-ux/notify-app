import 'package:flutter/material.dart';
import '../notify_colors.dart';
import '../notify_spacing.dart';
import '../reader_theme.dart';

/// Represents an individual readable section within a chapter
class TocSection {
  final String id;
  final String title;
  final int pageNumber;
  final String anchorId;
  final bool isCompleted;

  const TocSection({
    required this.id,
    required this.title,
    required this.pageNumber,
    required this.anchorId,
    this.isCompleted = false,
  });
}

/// Represents a syllabus chapter containing multiple sections
class TocChapter {
  final String id;
  final String title;
  final int chapterNumber;
  final List<TocSection> sections;

  const TocChapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.sections,
  });

  /// Default CA exam prep Table of Contents data for standard notes & DRM streams
  static List<TocChapter> defaultChaptersForPart(String partId, String partTitle) {
    return [
      TocChapter(
        id: 'ch_overview',
        title: 'Module Introduction & Statutory Framework',
        chapterNumber: 1,
        sections: [
          const TocSection(
            id: 'sec_syllabus',
            title: 'Syllabus Weightage & Exam Blueprint',
            pageNumber: 1,
            anchorId: 'section-syllabus',
            isCompleted: true,
          ),
          const TocSection(
            id: 'sec_definitions',
            title: 'Foundational Definitions & Scope',
            pageNumber: 3,
            anchorId: 'section-definitions',
            isCompleted: true,
          ),
        ],
      ),
      TocChapter(
        id: 'ch_core',
        title: partTitle.isNotEmpty ? partTitle : 'Core Statutory Provisions',
        chapterNumber: 2,
        sections: [
          const TocSection(
            id: 'sec_indemnity_124',
            title: 'Section 124: Contract of Indemnity',
            pageNumber: 5,
            anchorId: 'section-124',
            isCompleted: true,
          ),
          const TocSection(
            id: 'sec_guarantee_126',
            title: 'Section 126: Contract of Guarantee',
            pageNumber: 10,
            anchorId: 'section-126',
            isCompleted: false,
          ),
          const TocSection(
            id: 'sec_liability_128',
            title: 'Section 128: Co-extensive Liability',
            pageNumber: 16,
            anchorId: 'section-128',
            isCompleted: false,
          ),
          const TocSection(
            id: 'sec_discharge_133',
            title: 'Section 133: Discharge by Variance',
            pageNumber: 22,
            anchorId: 'section-133',
            isCompleted: false,
          ),
          const TocSection(
            id: 'sec_rights_140',
            title: 'Section 140: Subrogation & Surety Rights',
            pageNumber: 28,
            anchorId: 'section-140',
            isCompleted: false,
          ),
        ],
      ),
      const TocChapter(
        id: 'ch_practice',
        title: 'Past Exam Case Studies & MCQs',
        chapterNumber: 3,
        sections: [
          TocSection(
            id: 'sec_case_scenarios',
            title: 'Practical Integrated Case Scenarios',
            pageNumber: 34,
            anchorId: 'section-case-studies',
            isCompleted: false,
          ),
          TocSection(
            id: 'sec_mcq_bank',
            title: 'ICAI Question Bank & Past Papers',
            pageNumber: 40,
            anchorId: 'section-mcqs',
            isCompleted: false,
          ),
        ],
      ),
    ];
  }
}

/// NotifyReaderDrawer: Table of Contents & Section Navigator.
/// Can be presented as:
/// 1. A slide-over drawer or bottom sheet for mobile reading
/// 2. A docked 280px left rail for desktop reading (Rank 6)
class NotifyReaderDrawer extends StatelessWidget {
  final List<TocChapter> chapters;
  final String? activeSectionId;
  final int? currentPage;
  final ValueChanged<TocSection> onSectionSelected;
  final VoidCallback? onClose;
  final ReaderThemeConfig themeConfig;
  final bool isDockedRail;

  const NotifyReaderDrawer({
    super.key,
    required this.chapters,
    this.activeSectionId,
    this.currentPage,
    required this.onSectionSelected,
    this.onClose,
    required this.themeConfig,
    this.isDockedRail = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isDockedRail ? 280 : null,
      decoration: BoxDecoration(
        color: themeConfig.cardColor,
        border: isDockedRail
            ? Border(
                right: Border.all(
                  color: themeConfig.borderColor.withValues(alpha: 0.6),
                  width: 1,
                ).top,
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 18,
                        color: themeConfig.accentColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TABLE OF CONTENTS',
                        style: TextStyle(
                          color: themeConfig.accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  if (onClose != null && !isDockedRail)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: themeConfig.textMutedColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onClose,
                    ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: themeConfig.borderColor.withValues(alpha: 0.5),
            ),

            // Chapters & Sections Tree
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
                itemBuilder: (context, chapterIndex) {
                  final chapter = chapters[chapterIndex];
                  return _buildChapterSection(chapter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterSection(TocChapter chapter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chapter Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'CHAPTER ${chapter.chapterNumber}: ${chapter.title.toUpperCase()}',
            style: TextStyle(
              color: themeConfig.textMutedColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Section Rows
        ...chapter.sections.map((section) {
          final isSelected = activeSectionId == section.id ||
              (currentPage != null &&
                  currentPage! >= section.pageNumber &&
                  (section == chapter.sections.last ||
                      currentPage! <
                          chapter.sections[chapter.sections.indexOf(section) + 1].pageNumber));

          final isCompleted = section.isCompleted ||
              (currentPage != null && currentPage! > section.pageNumber);

          return Material(
            color: isSelected
                ? themeConfig.accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            child: InkWell(
              onTap: () {
                onSectionSelected(section);
                if (onClose != null && !isDockedRail) {
                  onClose!();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    // Completion status checkmark / bullet
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? NotifyColors.emerald.withValues(alpha: 0.2)
                            : (isSelected
                                ? themeConfig.accentColor.withValues(alpha: 0.2)
                                : themeConfig.borderColor.withValues(alpha: 0.4)),
                        border: Border.all(
                          color: isCompleted
                              ? NotifyColors.emerald
                              : (isSelected
                                  ? themeConfig.accentColor
                                  : themeConfig.borderColor),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 11,
                                color: NotifyColors.emerald,
                              )
                            : (isSelected
                                ? Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: themeConfig.accentColor,
                                    ),
                                  )
                                : null),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Section Title
                    Expanded(
                      child: Text(
                        section.title,
                        style: TextStyle(
                          color: isSelected
                              ? themeConfig.accentColor
                              : themeConfig.textColor,
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Page number badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: themeConfig.backgroundColor.withValues(alpha: 0.6),
                        borderRadius: NotifyRadius.xs,
                        border: Border.all(
                          color: themeConfig.borderColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'p. ${section.pageNumber}',
                        style: TextStyle(
                          color: isSelected
                              ? themeConfig.accentColor
                              : themeConfig.textMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 6),
      ],
    );
  }
}
