import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
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

    final packages = await _catalogService.getPackagesForPart(
      partId: widget.part.id,
      lessonId: widget.lesson.id,
      subjectId: widget.subject.id,
    );

    if (mounted) {
      setState(() {
        _hasAccess = access;
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
    final theme = context.notifyTheme;

    return Scaffold(
      backgroundColor: theme.bg,
      appBar: AppBar(
        backgroundColor: theme.bgDarker,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          widget.part.title,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: NotifyTypography.serifFamily,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accentAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Breadcrumbs / Hierarchy
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.bgDarker,
                      borderRadius: NotifyRadius.sm,
                      border: Border.all(color: theme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school_outlined, color: theme.accentAmber, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.subject.title}  ›  ${widget.lesson.title}',
                            style: TextStyle(color: theme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Part Header Card
                  NotifyCard(
                    isElevated: true,
                    accentStripeColor: widget.part.isPdf ? NotifyColors.coral : theme.accentAmber,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            NotifyTagBadge(
                              label: widget.part.isPdf ? 'PDF (DRM Protected)' : 'HTML Note (Secure)',
                              color: widget.part.isPdf ? NotifyColors.coral : theme.accentTeal,
                              icon: widget.part.isPdf ? Icons.picture_as_pdf_rounded : Icons.article_rounded,
                            ),
                            const Spacer(),
                            NotifyTagBadge(
                              label: _hasAccess ? 'Access Granted' : 'Free Preview Mode',
                              color: _hasAccess ? theme.accentTeal : theme.accentAmber,
                              icon: _hasAccess ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.part.title,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: NotifyTypography.serifFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // FREE TRIMMED PREVIEW SECTION
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, color: theme.accentAmber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Free Trimmed Preview',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      NotifyTagBadge(
                        label: 'SAMPLE',
                        color: theme.accentAmber,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Preview Content Box
                  NotifyCard(
                    borderColor: theme.accentAmber.withValues(alpha: 0.35),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: theme.accentAmber.withValues(alpha: 0.12),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Reading initial section free of charge. Full content requires subscription.',
                            style: TextStyle(color: theme.accentAmber, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chapter Overview: ${widget.lesson.title}',
                                style: TextStyle(
                                  color: theme.accentAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Section 124: Contract of Indemnity',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'A contract by which one party promises to save the other from loss caused to him by the conduct of the promisor himself, or by the conduct of any other person, is called a contract of indemnity.\n\n'
                                '• Promisor = Indemnifier\n'
                                '• Promisee = Indemnity Holder / Indemnified',
                                style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Section 126: Contract of Guarantee',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'A contract to perform the promise, or discharge the liability, of a third person in case of default. Involves 3 parties: Principal Debtor, Creditor, and Surety.',
                                style: TextStyle(color: theme.textMuted, fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        // Trimmed Fade Out Bar
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.cardBg.withValues(alpha: 0.0),
                                theme.cardBg,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '————— End of Free Preview —————',
                              style: TextStyle(
                                color: theme.textSubtle,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
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
                    NotifyCard(
                      isElevated: true,
                      accentStripeColor: theme.accentTeal,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_rounded, color: theme.accentTeal, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'You Have Active Access to this Note',
                                style: TextStyle(
                                  color: theme.accentTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          NotifyButton(
                            isFullWidth: true,
                            label: 'Open Full Note Reader',
                            leadingIcon: Icons.menu_book_rounded,
                            onPressed: _openFullReader,
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
