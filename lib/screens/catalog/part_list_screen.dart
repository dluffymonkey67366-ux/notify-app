import 'package:flutter/material.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import 'part_detail_screen.dart';

/// Screen displaying parts belonging to a selected lesson.
/// Users browse Subject → Lesson → Part.
class PartListScreen extends StatefulWidget {
  final Subject subject;
  final Lesson lesson;

  const PartListScreen({
    super.key,
    required this.subject,
    required this.lesson,
  });

  @override
  State<PartListScreen> createState() => _PartListScreenState();
}

class _PartListScreenState extends State<PartListScreen> {
  final CatalogService _catalogService = CatalogService();
  List<Part> _parts = [];
  bool _isLoading = true;
  final Map<String, bool> _accessMap = {};

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  Future<void> _loadParts() async {
    setState(() => _isLoading = true);
    final parts = await _catalogService.getParts(widget.subject.id, widget.lesson.id);

    // Check access for each part
    for (final part in parts) {
      final hasAccess = await _catalogService.hasActiveAccess(
        part.id,
        lessonId: widget.lesson.id,
        subjectId: widget.subject.id,
      );
      _accessMap[part.id] = hasAccess;
    }

    if (mounted) {
      setState(() {
        _parts = parts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: Text(widget.lesson.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : RefreshIndicator(
              color: AppTheme.accentAmber,
              onRefresh: _loadParts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Lesson Overview Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.inkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.title,
                          style: const TextStyle(color: AppTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.lesson.title,
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (widget.lesson.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.lesson.description!,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lesson Parts & Notes',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_parts.length} parts',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_parts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No parts available in this lesson yet.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._parts.map((part) {
                      final hasAccess = _accessMap[part.id] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.inkCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: hasAccess
                                ? AppTheme.accentTeal.withValues(alpha: 0.4)
                                : Colors.white12,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: part.isPdf
                                  ? AppTheme.accentCoral.withValues(alpha: 0.15)
                                  : AppTheme.accentAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              part.isPdf ? Icons.picture_as_pdf : Icons.article,
                              color: part.isPdf ? AppTheme.accentCoral : AppTheme.accentAmber,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            part.title,
                            style: const TextStyle(
                              color: AppTheme.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    part.isPdf ? 'PDF DRM' : 'HTML Note',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hasAccess
                                        ? AppTheme.accentTeal.withValues(alpha: 0.2)
                                        : AppTheme.accentAmber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    hasAccess ? 'UNLOCKED' : 'FREE PREVIEW',
                                    style: TextStyle(
                                      color: hasAccess ? AppTheme.accentTeal : AppTheme.accentAmber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PartDetailScreen(
                                  subject: widget.subject,
                                  lesson: widget.lesson,
                                  part: part,
                                ),
                              ),
                            );
                            _loadParts();
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
