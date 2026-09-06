import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
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
    final theme = context.notifyTheme;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bgDarker,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          widget.subject.title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: NotifyTypography.serifFamily,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentAmber))
          : RefreshIndicator(
              color: theme.accentAmber,
              onRefresh: _loadLessons,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Subject Overview Header
                  NotifyCard(
                    isElevated: true,
                    accentStripeColor: theme.accentAmber,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NotifyTagBadge(
                          label: '${widget.subject.category} • ${widget.subject.level}',
                          color: theme.accentAmber,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.subject.title,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: NotifyTypography.serifFamily,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subject.description,
                          style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chapters / Modules',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_lessons.length} chapters',
                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_lessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No lessons found for this subject.',
                          style: TextStyle(color: theme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._lessons.map((lesson) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NotifyCard(
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
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: theme.accentAmber.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.accentAmber.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${lesson.order}',
                                    style: TextStyle(
                                      color: theme.accentAmber,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lesson.title,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    if (lesson.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        lesson.description!,
                                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios_rounded, color: theme.textMuted, size: 14),
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
