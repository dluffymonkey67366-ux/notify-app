import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import 'lesson_list_screen.dart';

/// Top-level screen for exploring the course catalog.
/// Users browse Subject → Lesson → Part.
class SubjectListScreen extends StatefulWidget {
  const SubjectListScreen({super.key});

  @override
  State<SubjectListScreen> createState() => _SubjectListScreenState();
}

class _SubjectListScreenState extends State<SubjectListScreen> {
  final CatalogService _catalogService = CatalogService();
  List<Subject> _subjects = [];
  bool _isLoading = true;
  String _selectedLevel = 'Intermediate';
  String _selectedGroup = 'All Papers';

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    final subjects = await _catalogService.getSubjects();
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    }
  }

  List<Subject> get _filteredSubjects {
    return _subjects.where((s) {
      // 1. Level match
      final bool matchesLevel;
      if (_selectedLevel == 'Intermediate') {
        matchesLevel = s.level.toLowerCase() == 'intermediate' || s.level.toLowerCase() == 'inter';
      } else {
        matchesLevel = s.level.toLowerCase() == _selectedLevel.toLowerCase();
      }
      if (!matchesLevel) return false;

      // 2. Group match
      if (_selectedGroup == 'Group 1') {
        return s.group == 'Group 1';
      } else if (_selectedGroup == 'Group 2') {
        return s.group == 'Group 2';
      }
      return true; // 'All Papers'
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.notifyTheme;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bgDarker,
        title: Text(
          'Notify Course Catalog',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: NotifyTypography.serifFamily,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentAmber))
          : RefreshIndicator(
              color: theme.accentAmber,
              onRefresh: _loadSubjects,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Card
                  NotifyCard(
                    isElevated: true,
                    accentStripeColor: theme.accentAmber,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_stories_rounded, color: theme.accentAmber, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'CA / CMA Exam Notes',
                              style: TextStyle(
                                color: theme.accentAmber,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select your curriculum level and group to browse chapters, preview notes free, or unlock comprehensive study passes.',
                          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tier 1: Course Level Segmented Control
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: NotifyRadius.md,
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Row(
                      children: ['Foundation', 'Intermediate', 'Final'].map((lvl) {
                        final isSelected = _selectedLevel == lvl;
                        return Expanded(
                          child: InkWell(
                            borderRadius: NotifyRadius.sm,
                            onTap: () {
                              setState(() {
                                _selectedLevel = lvl;
                                if (lvl == 'Foundation') {
                                  _selectedGroup = 'All Papers';
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? theme.accentAmber : Colors.transparent,
                                borderRadius: NotifyRadius.sm,
                              ),
                              child: Text(
                                lvl,
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark ? NotifyColors.inkDarker : Colors.white)
                                      : theme.textMuted,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Tier 2: Group Sub-tabs (Intermediate & Final)
                  if (_selectedLevel != 'Foundation') ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: ['All Papers', 'Group 1', 'Group 2'].map((grp) {
                          final isSelected = _selectedGroup == grp;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: NotifyRadius.pill,
                              onTap: () => setState(() => _selectedGroup = grp),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.accentAmber.withValues(alpha: 0.16)
                                      : theme.cardBg,
                                  borderRadius: NotifyRadius.pill,
                                  border: Border.all(
                                    color: isSelected ? theme.accentAmber : theme.border,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  grp,
                                  style: TextStyle(
                                    color: isSelected ? theme.accentAmber : theme.textMuted,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Subject Cards List
                  if (_filteredSubjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: theme.textSubtle),
                            const SizedBox(height: 10),
                            Text(
                              'No subjects found in this category.',
                              style: TextStyle(color: theme.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filteredSubjects.map((subject) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: NotifyCard(
                          isElevated: true,
                          accentStripeColor: theme.accentAmber,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LessonListScreen(subject: subject),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        NotifyTagBadge(
                                          label: '${subject.category} • ${subject.level == "Inter" ? "Intermediate" : subject.level}',
                                          color: theme.accentAmber,
                                        ),
                                        if (subject.group != null)
                                          NotifyTagBadge(
                                            label: subject.group!,
                                            color: theme.accentAmber,
                                          ),
                                        if (subject.scheme != null)
                                          NotifyTagBadge(
                                            label: subject.scheme!,
                                            color: theme.accentTeal,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_ios_rounded, color: theme.textMuted, size: 14),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                subject.title,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subject.description,
                                style: TextStyle(
                                  color: theme.textMuted,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(Icons.menu_book_rounded, color: theme.accentTeal, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Browse Lessons & Chapters',
                                    style: TextStyle(
                                      color: theme.accentTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  NotifyTagBadge(
                                    label: 'Free Previews Inside',
                                    color: theme.textSubtle,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
