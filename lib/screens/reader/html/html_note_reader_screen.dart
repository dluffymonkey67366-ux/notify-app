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
import 'desktop_chromium_player.dart';
import 'mobile_html_player.dart';

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

  String? _decryptedHtml;
  bool _isLoading = true;
  String? _errorMessage;

  // Screen capture violation state
  bool _isContentBlanked = false;
  String? _violationWarning;
  StreamSubscription<ViolationEvent>? _violationSubscription;

  @override
  void initState() {
    super.initState();
    _initReaderAndProtection();
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

    // 3. Load decrypted HTML content strictly from AES-256 local encrypted cache
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

      if (mounted) {
        setState(() {
          _decryptedHtml = html;
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
    _violationSubscription?.cancel();
    _protectionService.stopProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final userIdentifier = user?.email ?? user?.phoneNumber ?? 'CA-STUDENT';

    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Scaffold(
      backgroundColor: AppTheme.inkDarker,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.85),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partTitle,
              style: const TextStyle(
                color: AppTheme.textLight,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.subjectTitle,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Protected HTML Content View (Mobile InAppWebView or Desktop Chromium)
            if (!_isLoading && _decryptedHtml != null && !_isContentBlanked)
              Positioned.fill(
                child: isDesktop
                    ? DesktopChromiumPlayer(
                        htmlContent: _decryptedHtml!,
                        onContentLoaded: () {},
                      )
                    : MobileHtmlPlayer(
                        htmlContent: _decryptedHtml!,
                        onContentLoaded: () {},
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
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Notes'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
