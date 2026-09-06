import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/drm_pdf_manifest.dart';
import '../../../services/auth_service.dart';
import '../../../services/drm_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/drifting_watermark.dart';
import '../../../design_system/design_system.dart';
import 'desktop_drm_player.dart';
import 'mobile_drm_player.dart';

class DrmPdfReaderScreen extends StatefulWidget {
  final String partId;
  final String partTitle;
  final String subjectTitle;

  const DrmPdfReaderScreen({
    super.key,
    required this.partId,
    required this.partTitle,
    required this.subjectTitle,
  });

  @override
  State<DrmPdfReaderScreen> createState() => _DrmPdfReaderScreenState();
}

class _DrmPdfReaderScreenState extends State<DrmPdfReaderScreen> {
  final DrmService _drmService = DrmService();
  final TransformationController _zoomController = TransformationController();
  final ReaderSettingsController _readerSettings = ReaderSettingsController();

  DrmPdfManifest? _manifest;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  bool _showControls = true;
  Timer? _progressDebounceTimer;
  late List<TocChapter> _tocChapters;

  @override
  void initState() {
    super.initState();
    _tocChapters = TocChapter.defaultChaptersForPart(widget.partId, widget.partTitle);
    _readerSettings.addListener(_onReaderSettingsChanged);
    _initializeReader();
  }

  void _openTocDrawer(BuildContext context, ReaderThemeConfig themeConfig) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.sizeOf(context).height * 0.75,
        decoration: BoxDecoration(
          color: themeConfig.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: NotifyReaderDrawer(
          chapters: _tocChapters,
          currentPage: _currentPage,
          themeConfig: themeConfig,
          onClose: () => Navigator.of(ctx).pop(),
          onSectionSelected: (section) {
            _onPageChanged(section.pageNumber);
          },
        ),
      ),
    );
  }

  void _onReaderSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeReader() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch DRM Stream Manifest (server verifies purchase validity)
      final manifest = await _drmService.getStreamManifest(widget.partId);

      // 2. Load last saved progress
      final savedPage = await _drmService.loadProgress(widget.partId);

      if (mounted) {
        setState(() {
          _manifest = manifest;
          _totalPages = manifest.totalPages;
          _currentPage = savedPage.clamp(1, manifest.totalPages);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(int newPage) {
    if (newPage < 1 || newPage > _totalPages) return;

    setState(() {
      _currentPage = newPage;
      // Reset zoom on page flip for clean reading
      _zoomController.value = Matrix4.identity();
    });

    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = Timer(const Duration(seconds: 3), () {
      _drmService.saveProgress(
        partId: widget.partId,
        pageNumber: _currentPage,
        totalPages: _totalPages,
      );
    });
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: _currentPage.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.inkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Jump to Page', style: TextStyle(color: AppTheme.textLight, fontSize: 18)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "1 - $_totalPages",
            suffixText: "of $_totalPages",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: AppTheme.inkDarker),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1 && val <= _totalPages) {
                Navigator.of(ctx).pop();
                _onPageChanged(val);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  bool _showReaderControls = false;

  @override
  void dispose() {
    _readerSettings.removeListener(_onReaderSettingsChanged);
    _progressDebounceTimer?.cancel();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final userIdentifier = user?.email ?? user?.phoneNumber ?? "CA-STUDENT";
    final themeConfig = _readerSettings.themeConfig;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopMeasure = screenWidth >= 900;

    // Determine platform for player dispatch
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    Widget? drmCanvas = (_manifest != null)
        ? GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: InteractiveViewer(
              transformationController: _zoomController,
              minScale: 1.0,
              maxScale: 3.5, // Crisp 3.5x zoom for tables & flowcharts
              child: Center(
                child: isDesktop
                    ? DesktopDrmPlayer(
                        manifest: _manifest!,
                        currentPage: _currentPage,
                        onPageChanged: _onPageChanged,
                        onPlaybackReady: () {},
                      )
                    : MobileDrmPlayer(
                        manifest: _manifest!,
                        currentPage: _currentPage,
                        onPageChanged: _onPageChanged,
                        onPlaybackReady: () {},
                      ),
              ),
            ),
          )
        : null;

    Widget mainContentStack = Stack(
      children: [
        // 1. DRM Video Frame Canvas with Zoom and Pan (Desktop reading measure or mobile fill)
        if (!_isLoading && drmCanvas != null)
          isDesktopMeasure
              ? Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: drmCanvas,
                      ),
                    ),
                  ),
                )
              : Positioned.fill(child: drmCanvas),

        // 2. Drifting Forensic Watermark (Always Overlaid)
        DriftingWatermark(
          identifier: userIdentifier,
          minSeconds: 20,
          maxSeconds: 40,
          opacity: 0.16,
        ),

        // 3. Loading State
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber)),
                SizedBox(height: 16),
                Text(
                  'Acquiring Hardware DRM License...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

        // 4. Error State (License Denied / Expired)
        if (_errorMessage != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.inkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gpp_bad_outlined, color: AppTheme.errorRed, size: 48),
                  const SizedBox(height: 14),
                  const Text(
                    'Content Access Restricted',
                    style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Library'),
                  ),
                ],
              ),
            ),
          ),

        // 5. Header Overlay (Back Button, Title, Page Indicator, Display Controls)
        if (_showControls && !_isLoading && _errorMessage == null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktopMeasure ? 760 : double.infinity),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        themeConfig.cardColor.withValues(alpha: 0.95),
                        themeConfig.cardColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: themeConfig.textColor, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.partTitle,
                              style: TextStyle(color: themeConfig.textColor, fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.subjectTitle,
                              style: TextStyle(color: themeConfig.textMutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!isDesktopMeasure)
                        IconButton(
                          icon: Icon(
                            Icons.format_list_bulleted_rounded,
                            color: themeConfig.textColor,
                            size: 20,
                          ),
                          tooltip: 'Table of Contents',
                          onPressed: () => _openTocDrawer(context, themeConfig),
                        ),
                      IconButton(
                        icon: Icon(
                          _showReaderControls ? Icons.text_fields_rounded : Icons.tune_rounded,
                          color: _showReaderControls ? themeConfig.accentColor : themeConfig.textMutedColor,
                          size: 20,
                        ),
                        tooltip: 'Display Controls',
                        onPressed: () => setState(() => _showReaderControls = !_showReaderControls),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _showJumpToPageDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: themeConfig.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: themeConfig.accentColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '$_currentPage / $_totalPages',
                            style: TextStyle(color: themeConfig.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 6. Floating Reader Controls Bar (Theme switcher, font stepper, typeface toggle)
        if (_showControls && _showReaderControls && !_isLoading && _errorMessage == null)
          Positioned(
            bottom: 74,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktopMeasure ? 760 : double.infinity),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: NotifyReaderControlsBar(
                    settings: _readerSettings,
                    onClose: () => setState(() => _showReaderControls = false),
                  ),
                ),
              ),
            ),
          ),

        // 7. Bottom Navigation Controls (Scrubber, Prev, Next)
        if (_showControls && !_isLoading && _errorMessage == null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktopMeasure ? 760 : double.infinity),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        themeConfig.cardColor.withValues(alpha: 0.95),
                        themeConfig.cardColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, size: 30, color: themeConfig.textColor),
                        onPressed: _currentPage > 1 ? () => _onPageChanged(_currentPage - 1) : null,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: themeConfig.accentColor,
                            inactiveTrackColor: themeConfig.borderColor.withValues(alpha: 0.5),
                            thumbColor: themeConfig.accentColor,
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _currentPage.toDouble(),
                            min: 1,
                            max: _totalPages.toDouble(),
                            divisions: _totalPages > 1 ? _totalPages - 1 : 1,
                            onChanged: (val) => _onPageChanged(val.round()),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, size: 30, color: themeConfig.textColor),
                        onPressed: _currentPage < _totalPages ? () => _onPageChanged(_currentPage + 1) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: themeConfig.backgroundColor,
      drawer: isDesktopMeasure
          ? null
          : Drawer(
              backgroundColor: themeConfig.cardColor,
              child: NotifyReaderDrawer(
                chapters: _tocChapters,
                currentPage: _currentPage,
                themeConfig: themeConfig,
                onClose: () => Navigator.of(context).pop(),
                onSectionSelected: (section) {
                  _onPageChanged(section.pageNumber);
                },
              ),
            ),
      body: SafeArea(
        child: isDesktopMeasure
            ? Row(
                children: [
                  NotifyReaderDrawer(
                    chapters: _tocChapters,
                    currentPage: _currentPage,
                    themeConfig: themeConfig,
                    isDockedRail: true,
                    onSectionSelected: (section) {
                      _onPageChanged(section.pageNumber);
                    },
                  ),
                  Expanded(child: mainContentStack),
                ],
              )
            : mainContentStack,
      ),
    );
  }
}
