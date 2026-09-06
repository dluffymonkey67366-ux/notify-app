import 'package:flutter/material.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../reader/html/html_note_reader_screen.dart';
import '../reader/pdf/drm_pdf_reader_screen.dart';
import 'package_selection_sheet.dart';

/// Screen displaying Part details, free trimmed preview, and package purchase picker.
class PartDetailScreen extends StatefulWidget {
  final Subject subject;
  final Lesson lesson;
  final Part part;

  const PartDetailScreen({
    super.key,
    required this.subject,
    required this.lesson,
    required this.part,
  });

  @override
  State<PartDetailScreen> createState() => _PartDetailScreenState();
}

class _PartDetailScreenState extends State<PartDetailScreen> {
  final CatalogService _catalogService = CatalogService();

  bool _isLoading = true;
  bool _hasAccess = false;
  String _previewContent = '';
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadPartData();
  }

  Future<void> _loadPartData() async {
    setState(() => _isLoading = true);

    final access = await _catalogService.hasActiveAccess(
      widget.part.id,
      lessonId: widget.lesson.id,
      subjectId: widget.subject.id,
    );

    final preview = await _catalogService.getTrimmedPreviewHtml(widget.part);

    final packages = await _catalogService.getPackagesForPart(
      partId: widget.part.id,
      lessonId: widget.lesson.id,
      subjectId: widget.subject.id,
    );

    if (mounted) {
      setState(() {
        _hasAccess = access;
        _previewContent = preview;
        _packages = packages;
        _isLoading = false;
      });
    }
  }

  void _openFullReader() {
    if (widget.part.isPdf) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DrmPdfReaderScreen(
            partId: widget.part.id,
            partTitle: widget.part.title,
            subjectTitle: widget.subject.title,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HtmlNoteReaderScreen(
            partId: widget.part.id,
            partTitle: widget.part.title,
            subjectTitle: widget.subject.title,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        title: Text(widget.part.title),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumbs / Hierarchy
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.inkDarker,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined, color: AppTheme.accentAmber, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.subject.title}  ›  ${widget.lesson.title}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Part Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.inkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.part.isPdf
                                    ? AppTheme.accentCoral.withOpacity(0.2)
                                    : AppTheme.accentTeal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.part.isPdf ? 'PDF (DRM Protected)' : 'HTML Note (Secure)',
                                style: TextStyle(
                                  color: widget.part.isPdf ? AppTheme.accentCoral : AppTheme.accentTeal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _hasAccess
                                    ? AppTheme.accentTeal.withOpacity(0.2)
                                    : AppTheme.accentAmber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _hasAccess ? Icons.check_circle : Icons.lock_outline,
                                    color: _hasAccess ? AppTheme.accentTeal : AppTheme.accentAmber,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _hasAccess ? 'Access Granted' : 'Free Preview Mode',
                                    style: TextStyle(
                                      color: _hasAccess ? AppTheme.accentTeal : AppTheme.accentAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.part.title,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // FREE TRIMMED PREVIEW SECTION
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined, color: AppTheme.accentAmber, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Free Trimmed Preview',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SAMPLE',
                          style: TextStyle(
                            color: AppTheme.accentAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Preview Content Box
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.inkDarker,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Reading initial section free of charge. Full content requires subscription.',
                            style: TextStyle(color: AppTheme.accentAmber, fontSize: 11),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chapter Overview: ${widget.lesson.title}',
                                style: const TextStyle(
                                  color: AppTheme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Section 124: Contract of Indemnity',
                                style: TextStyle(
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A contract by which one party promises to save the other from loss caused to him by the conduct of the promisor himself, or by the conduct of any other person, is called a contract of indemnity.\n\n'
                                '• Promisor = Indemnifier\n'
                                '• Promisee = Indemnity Holder / Indemnified',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Section 126: Contract of Guarantee',
                                style: TextStyle(
                                  color: AppTheme.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A contract to perform the promise, or discharge the liability, of a third person in case of default. Involves 3 parties: Principal Debtor, Creditor, and Surety.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        // Trimmed Fade Out Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.inkDarker.withOpacity(0.0),
                                AppTheme.inkDarker,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '————— End of Free Preview —————',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ACCESS ACTIONS
                  if (_hasAccess) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.accentTeal),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified, color: AppTheme.accentTeal, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'You Have Active Access to this Note',
                                style: TextStyle(
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _openFullReader,
                            icon: const Icon(Icons.menu_book),
                            label: const Text('Open Full Note Reader'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // PACKAGE SELECTION SHEET WITH ACCURATE DURATION FILTERING
                    PackageSelectionSheet(
                      packages: _packages,
                      onPurchaseSuccess: () {
                        _loadPartData();
                      },
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
