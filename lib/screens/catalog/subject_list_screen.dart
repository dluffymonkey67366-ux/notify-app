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
  String _selectedLevel = 'All';

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
    if (_selectedLevel == 'All') return _subjects;
    return _subjects.where((s) => s.level.toLowerCase() == _selectedLevel.toLowerCase()).toList();
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
                          'Select your subject to browse chapters, preview notes free, or unlock comprehensive study passes.',
                          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: ['All', 'Inter', 'Final', 'Foundation'].map((lvl) {
                        final isSelected = _selectedLevel == lvl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: NotifyRadius.pill,
                            onTap: () => setState(() => _selectedLevel = lvl),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.accentAmber : theme.cardBg,
                                borderRadius: NotifyRadius.pill,
                                border: Border.all(
                                  color: isSelected ? theme.accentAmber : theme.border,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                lvl == 'All' ? 'All Subjects' : 'CA $lvl',
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark ? NotifyColors.inkDarker : Colors.white)
                                      : theme.textMuted,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
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
                                children: [
                                  NotifyTagBadge(
                                    label: '${subject.category} • ${subject.level}',
                                    color: theme.accentAmber,
                                  ),
                                  const Spacer(),
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
