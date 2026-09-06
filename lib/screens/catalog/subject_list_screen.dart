import 'package:flutter/material.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: const Text('Notify Course Catalog'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : RefreshIndicator(
              color: AppTheme.accentAmber,
              onRefresh: _loadSubjects,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentAmber.withOpacity(0.18),
                          AppTheme.inkCard,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_stories, color: AppTheme.accentAmber, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'CA / CMA Exam Notes',
                              style: TextStyle(
                                color: AppTheme.accentAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select your subject to browse chapters, preview notes free, or unlock comprehensive study passes.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Inter', 'Final', 'Foundation'].map((lvl) {
                        final isSelected = _selectedLevel == lvl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(lvl == 'All' ? 'All Subjects' : 'CA $lvl'),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _selectedLevel = lvl);
                            },
                            selectedColor: AppTheme.accentAmber,
                            backgroundColor: AppTheme.inkCard,
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.inkDarker : AppTheme.textMuted,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subject Cards List
                  if (_filteredSubjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No subjects found in this category.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._filteredSubjects.map((subject) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.inkCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LessonListScreen(subject: subject),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentAmber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${subject.category} • ${subject.level}',
                                        style: const TextStyle(
                                          color: AppTheme.accentAmber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 14),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  subject.title,
                                  style: const TextStyle(
                                    color: AppTheme.textLight,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subject.description,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.menu_book, color: AppTheme.accentTeal, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Browse Lessons & Chapters',
                                      style: TextStyle(
                                        color: AppTheme.accentTeal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Free Previews Inside',
                                        style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
