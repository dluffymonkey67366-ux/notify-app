import 'package:flutter/material.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import 'part_list_screen.dart';

/// Screen displaying lessons/chapters for a selected subject.
/// Users browse Subject → Lesson → Part.
class LessonListScreen extends StatefulWidget {
  final Subject subject;

  const LessonListScreen({
    super.key,
    required this.subject,
  });

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final CatalogService _catalogService = CatalogService();
  List<Lesson> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    final lessons = await _catalogService.getLessons(widget.subject.id);
    if (mounted) {
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: Text(widget.subject.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : RefreshIndicator(
              color: AppTheme.accentAmber,
              onRefresh: _loadLessons,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Subject Overview Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.inkCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentAmber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.subject.category} • ${widget.subject.level}',
                                style: const TextStyle(
                                  color: AppTheme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.subject.title,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subject.description,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chapters / Modules',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_lessons.length} chapters',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_lessons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No lessons found for this subject.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._lessons.map((lesson) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.inkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${lesson.order}',
                                style: const TextStyle(
                                  color: AppTheme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            lesson.title,
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: lesson.description != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    lesson.description!,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              : null,
                          trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PartListScreen(
                                  subject: widget.subject,
                                  lesson: lesson,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
