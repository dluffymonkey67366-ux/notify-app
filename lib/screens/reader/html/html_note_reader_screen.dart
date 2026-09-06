import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/encrypted_cache_service.dart';
import '../../../services/screen_protection_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/drifting_watermark.dart';
import '../../../design_system/design_system.dart';
import 'desktop_chromium_player.dart';
import 'html_security_scripts.dart';
import 'mobile_html_player.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Full-featured, secure HTML Note Reader for CA/CMA notes.
///
/// Security Features:
/// 1. Offline AES-256 encrypted cache (hardware-bound key via FlutterSecureStorage).
/// 2. Android: OS-level FLAG_SECURE (genuine screenshot + recording block).
/// 3. iOS & Desktop: Detect-and-react telemetry:
///    - iOS: NSNotification screenshot + UIScreen.main.isCaptured screen recording.
///    - Desktop: Active process scanner for known capture software.
/// 4. Detection response:
///    - Content immediately blanked.
///    - In-app warning dialog: "Screenshots and recording aren't allowed here — repeated attempts will log you out."
///    - Firestore telemetry written to `violations/{violationId}`.
///    - 4th violation triggers Cloud Function force-logout invalidation.
/// 5. Drifting low-opacity (~0.15) forensic watermark repositioning every 20-40s.
class HtmlNoteReaderScreen extends StatefulWidget {
  final String partId;
  final String partTitle;
  final String subjectTitle;
  final String? initialRawHtml; // For seeding/preview

  const HtmlNoteReaderScreen({
    super.key,
    required this.partId,
    required this.partTitle,
    required this.subjectTitle,
    this.initialRawHtml,
  });

  @override
  State<HtmlNoteReaderScreen> createState() => _HtmlNoteReaderScreenState();
}

class _HtmlNoteReaderScreenState extends State<HtmlNoteReaderScreen> {
  final EncryptedCacheService _cacheService = EncryptedCacheService();
  final ScreenProtectionService _protectionService = ScreenProtectionService();
  final ReaderSettingsController _readerSettings = ReaderSettingsController();

  InAppWebViewController? _webViewController;
  String? _decryptedHtml;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  late List<TocChapter> _tocChapters;
  String? _activeSectionId;

  // Annotations state (Rank 7)
  NoteAnnotationsBundle _annotations = const NoteAnnotationsBundle(partId: '');
  String? _selectedText;
  bool _showHighlightToolbar = false;

  // Screen capture violation state
  bool _isContentBlanked = false;
  String? _violationWarning;
  StreamSubscription<ViolationEvent>? _violationSubscription;

  bool get _isCurrentSectionBookmarked {
    final currentSectionId = _activeSectionId ?? 'section_default';
    return _annotations.bookmarks.any((b) => b.sectionId == currentSectionId);
  }

  @override
  void initState() {
    super.initState();
    _annotations = NoteAnnotationsBundle(partId: widget.partId);
    _tocChapters = TocChapter.defaultChaptersForPart(widget.partId, widget.partTitle);
    _readerSettings.addListener(_onReaderSettingsChanged);
    _initReaderAndProtection();
  }

  void _onContentLoaded() {
    if (_annotations.highlights.isNotEmpty) {
      final js = HtmlSecurityScripts.buildRestoreHighlightsJs(_annotations.highlights);
      _webViewController?.evaluateJavascript(source: js);
    }
  }

  void _onTextSelected(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _selectedText = text.trim();
      _showHighlightToolbar = true;
    });
  }

  void _onSelectionCleared() {
    if (_showHighlightToolbar) {
      setState(() {
        _showHighlightToolbar = false;
        _selectedText = null;
      });
    }
  }

  Future<void> _applyHighlight(HighlightColor color) async {
    final text = _selectedText;
    if (text == null || text.isEmpty) return;

    final highlight = ReaderHighlight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      partId: widget.partId,
      text: text,
      color: color,
    );

    final updatedHighlights = [..._annotations.highlights, highlight];
    final updatedBundle = _annotations.copyWith(highlights: updatedHighlights);

    setState(() {
      _annotations = updatedBundle;
      _showHighlightToolbar = false;
      _selectedText = null;
    });

    final js = HtmlSecurityScripts.buildApplyHighlightJs(highlight);
    await _webViewController?.evaluateJavascript(source: js);

    await _cacheService.saveEncryptedAnnotations(widget.partId, updatedBundle);
  }

  Future<void> _toggleBookmark() async {
    final currentSectionId = _activeSectionId ?? 'section_default';
    final isAlreadyBookmarked =
        _annotations.bookmarks.any((b) => b.sectionId == currentSectionId);

    List<ReaderBookmark> updatedBookmarks;
    if (isAlreadyBookmarked) {
      updatedBookmarks = _annotations.bookmarks
          .where((b) => b.sectionId != currentSectionId)
          .toList();
    } else {
      final bookmark = ReaderBookmark(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        partId: widget.partId,
        title: widget.partTitle,
        sectionId: currentSectionId,
      );
      updatedBookmarks = [..._annotations.bookmarks, bookmark];
    }

    final updatedBundle = _annotations.copyWith(bookmarks: updatedBookmarks);
    setState(() {
      _annotations = updatedBundle;
    });

    await _cacheService.saveEncryptedAnnotations(widget.partId, updatedBundle);
  }

  void _onSectionSelected(TocSection section) {
    setState(() {
      _activeSectionId = section.id;
    });
    final js = HtmlSecurityScripts.buildScrollToSectionJs(section.anchorId);
    _webViewController?.evaluateJavascript(source: js);
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
          activeSectionId: _activeSectionId,
          themeConfig: themeConfig,
          onClose: () => Navigator.of(ctx).pop(),
          onSectionSelected: _onSectionSelected,
        ),
      ),
    );
  }

  void _onReaderSettingsChanged() {
    if (!mounted) return;
    setState(() {});
    final js = HtmlSecurityScripts.buildUpdateStyleJs(
      themeConfig: _readerSettings.themeConfig,
      fontSize: _readerSettings.fontSize,
      isSerif: _readerSettings.isSerif,
    );
    _webViewController?.evaluateJavascript(source: js);
  }

  Future<void> _initReaderAndProtection() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? 'anonymous_user';

    // 1. Start OS screen defense and background capture detection
    await _protectionService.startProtection(
      userId: userId,
      partId: widget.partId,
    );

    // 2. Listen for detection events (iOS screenshot/recording or Desktop capture tools)
    _violationSubscription = _protectionService.onViolationDetected.listen((event) {
      _triggerViolationReaction(event);
    });

    // 3. Ensure offline encrypted cache schema is migrated (v1 -> v2)
    await _cacheService.ensureCacheVersionMigrated();

    // 4. Load decrypted HTML content strictly from AES-256 local encrypted cache
    await _loadDecryptedNoteContent();
  }

  Future<void> _loadDecryptedNoteContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if already in encrypted cache
      var html = await _cacheService.readDecryptedContent(widget.partId);

      // If not yet cached, seed from initial content or remote securely
      if (html == null) {
        final contentToCache = widget.initialRawHtml ??
            '<h1>${widget.partTitle}</h1><p>Comprehensive study material for ${widget.subjectTitle}.</p>';
        await _cacheService.saveEncryptedContent(widget.partId, contentToCache);
        // Read back strictly decrypted from disk cache
        html = await _cacheService.readDecryptedContent(widget.partId);
      }

      // Load saved annotations from encrypted cache
      NoteAnnotationsBundle loadedAnnotations = NoteAnnotationsBundle(partId: widget.partId);
      try {
        final saved = await _cacheService.readDecryptedAnnotations(widget.partId);
        if (saved != null) {
          loadedAnnotations = saved;
        }
      } catch (e) {
        debugPrint('Notify Annotations: Error reading encrypted annotations: $e');
      }

      if (mounted) {
        setState(() {
          _decryptedHtml = html;
          _annotations = loadedAnnotations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load protected content: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// On any capture detection event:
  /// (1) Blank content immediately
  /// (2) Show warning "Screenshots and recording aren't allowed here — repeated attempts will log you out."
  /// (3) Violation record is written to Firestore violations/{violationId} by ScreenProtectionService
  void _triggerViolationReaction(ViolationEvent event) {
    if (!mounted) return;

    setState(() {
      _isContentBlanked = true;
      _violationWarning =
          "Screenshots and recording aren't allowed here — repeated attempts will log you out.";
    });

    // Show prominent modal warning
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.inkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Text(
              'Security Alert',
              style: TextStyle(
                color: AppTheme.textLight,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          _violationWarning!,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: AppTheme.inkDarker,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) {
                // Resume viewing once dialog acknowledged
                setState(() {
                  _isContentBlanked = false;
                });
              }
            },
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _readerSettings.removeListener(_onReaderSettingsChanged);
    _violationSubscription?.cancel();
    _protectionService.stopProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final userIdentifier = user?.email ?? user?.phoneNumber ?? 'CA-STUDENT';
    final themeConfig = _readerSettings.themeConfig;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktopMeasure = screenWidth >= 900;

    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    // Reading content column with webview/player and overlays
    Widget contentColumn = Stack(
      children: [
        // 1. Protected HTML Content View (Mobile InAppWebView or Desktop Chromium)
        if (!_isLoading && _decryptedHtml != null && !_isContentBlanked)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _showControls = !_showControls),
              child: isDesktop
                  ? DesktopChromiumPlayer(
                      htmlContent: _decryptedHtml!,
                      themeConfig: themeConfig,
                      fontSize: _readerSettings.fontSize,
                      isSerif: _readerSettings.isSerif,
                      onControllerCreated: (controller) => _webViewController = controller,
                      onCanvasTap: () => setState(() => _showControls = !_showControls),
                      onContentLoaded: _onContentLoaded,
                      onTextSelected: _onTextSelected,
                      onSelectionCleared: _onSelectionCleared,
                    )
                  : MobileHtmlPlayer(
                      htmlContent: _decryptedHtml!,
                      themeConfig: themeConfig,
                      fontSize: _readerSettings.fontSize,
                      isSerif: _readerSettings.isSerif,
                      onControllerCreated: (controller) => _webViewController = controller,
                      onCanvasTap: () => setState(() => _showControls = !_showControls),
                      onContentLoaded: _onContentLoaded,
                      onTextSelected: _onTextSelected,
                      onSelectionCleared: _onSelectionCleared,
                    ),
            ),
          ),

        // 2. Blanked Content State (Triggered on Capture Detection)
        if (_isContentBlanked)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gpp_bad_rounded,
                        color: AppTheme.errorRed,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Protected Content Blanked',
                        style: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _violationWarning ??
                            "Screenshots and recording aren't allowed here — repeated attempts will log you out.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 3. Drifting Forensic Watermark (Email or Phone, low opacity ~0.15, 20-40s repositioning)
        DriftingWatermark(
          identifier: userIdentifier,
          minSeconds: 20,
          maxSeconds: 40,
          opacity: 0.15,
        ),

        // 4. Loading State
        if (_isLoading)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                ),
                SizedBox(height: 16),
                Text(
                  'Decrypting Cached Study Material (AES-256)...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

        // 5. Error State
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
                  const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: themeConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: themeConfig.cardColor.withValues(alpha: 0.95),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partTitle,
              style: TextStyle(
                color: themeConfig.textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.subjectTitle,
              style: TextStyle(
                color: themeConfig.textMutedColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: themeConfig.textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isCurrentSectionBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: _isCurrentSectionBookmarked
                  ? NotifyColors.amber
                  : themeConfig.textColor,
              size: 20,
            ),
            tooltip: _isCurrentSectionBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
            onPressed: _toggleBookmark,
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
              _showControls ? Icons.text_fields_rounded : Icons.tune_rounded,
              color: _showControls ? themeConfig.accentColor : themeConfig.textMutedColor,
              size: 20,
            ),
            tooltip: 'Reading Controls',
            onPressed: () => setState(() => _showControls = !_showControls),
          ),
        ],
      ),
      drawer: isDesktopMeasure
          ? null
          : Drawer(
              backgroundColor: themeConfig.cardColor,
              child: NotifyReaderDrawer(
                chapters: _tocChapters,
                activeSectionId: _activeSectionId,
                themeConfig: themeConfig,
                onClose: () => Navigator.of(context).pop(),
                onSectionSelected: _onSectionSelected,
              ),
            ),
      body: SafeArea(
        child: isDesktopMeasure
            ? Row(
                children: [
                  // Stationary 280px left rail
                  NotifyReaderDrawer(
                    chapters: _tocChapters,
                    activeSectionId: _activeSectionId,
                    themeConfig: themeConfig,
                    isDockedRail: true,
                    onSectionSelected: _onSectionSelected,
                  ),
                  // Reading Measure Column (max width 760px, centered with 32px padding)
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: contentColumn,
                            ),
                          ),
                        ),
                        // Desktop floating highlight toolbar (Rank 7)
                        if (_showHighlightToolbar && _selectedText != null && !_isContentBlanked)
                          Positioned(
                            bottom: _showControls ? 96 : 32,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: NotifyHighlightToolbar(
                                themeConfig: themeConfig,
                                isBookmarked: _isCurrentSectionBookmarked,
                                onColorSelected: _applyHighlight,
                                onBookmark: _toggleBookmark,
                                onDismiss: () => setState(() {
                                  _showHighlightToolbar = false;
                                  _selectedText = null;
                                }),
                              ),
                            ),
                          ),
                        // Desktop reader controls bar
                        if (_showControls && !_isLoading && _errorMessage == null && !_isContentBlanked)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 760),
                                child: SafeArea(
                                  top: false,
                                  child: NotifyReaderControlsBar(
                                    settings: _readerSettings,
                                    onClose: () => setState(() => _showControls = false),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  contentColumn,
                  // Mobile floating highlight toolbar (Rank 7)
                  if (_showHighlightToolbar && _selectedText != null && !_isContentBlanked)
                    Positioned(
                      bottom: _showControls ? 96 : 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: NotifyHighlightToolbar(
                          themeConfig: themeConfig,
                          isBookmarked: _isCurrentSectionBookmarked,
                          onColorSelected: _applyHighlight,
                          onBookmark: _toggleBookmark,
                          onDismiss: () => setState(() {
                            _showHighlightToolbar = false;
                            _selectedText = null;
                          }),
                        ),
                      ),
                    ),
                  // Mobile reader controls bar
                  if (_showControls && !_isLoading && _errorMessage == null && !_isContentBlanked)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: NotifyReaderControlsBar(
                          settings: _readerSettings,
                          onClose: () => setState(() => _showControls = false),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

