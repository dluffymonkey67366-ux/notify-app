import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
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
    final theme = context.notifyTheme;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bgDarker,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          widget.lesson.title,
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
              onRefresh: _loadParts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Lesson Overview Header
                  NotifyCard(
                    isElevated: true,
                    accentStripeColor: theme.accentAmber,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.title,
                          style: TextStyle(
                            color: theme.accentAmber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.lesson.title,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            fontFamily: NotifyTypography.serifFamily,
                          ),
                        ),
                        if (widget.lesson.description != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.lesson.description!,
                            style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lesson Parts & Notes',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_parts.length} parts',
                        style: TextStyle(color: theme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_parts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No parts available in this lesson yet.',
                          style: TextStyle(color: theme.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._parts.map((part) {
                      final hasAccess = _accessMap[part.id] ?? false;
                      final typeColor = part.isPdf ? NotifyColors.coral : theme.accentAmber;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NotifyCard(
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
                          accentStripeColor: hasAccess ? theme.accentTeal : null,
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.14),
                                  borderRadius: NotifyRadius.md,
                                  border: Border.all(
                                    color: typeColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  part.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                                  color: typeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      part.title,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        NotifyTagBadge(
                                          label: part.isPdf ? 'PDF DRM' : 'HTML Note',
                                          color: typeColor,
                                        ),
                                        NotifyTagBadge(
                                          label: hasAccess ? 'UNLOCKED' : 'FREE PREVIEW',
                                          color: hasAccess ? theme.accentTeal : theme.accentAmber,
                                          icon: hasAccess ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                                        ),
                                      ],
                                    ),
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
