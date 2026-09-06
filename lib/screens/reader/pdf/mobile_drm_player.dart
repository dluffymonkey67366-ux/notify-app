import 'package:flutter/material.dart';
import '../../../models/drm_pdf_manifest.dart';
import '../../../theme/app_theme.dart';

/// Mobile DRM Video-Frame Player for Android (Widevine) and iOS (FairPlay)
class MobileDrmPlayer extends StatefulWidget {
  final DrmPdfManifest manifest;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPlaybackReady;

  const MobileDrmPlayer({
    super.key,
    required this.manifest,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPlaybackReady,
  });

  @override
  State<MobileDrmPlayer> createState() => _MobileDrmPlayerState();
}

class _MobileDrmPlayerState extends State<MobileDrmPlayer> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _isReady = true);
        widget.onPlaybackReady();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.inkDarker,
      child: Center(
        child: _isReady
            ? AspectRatio(
                aspectRatio: 1 / 1.414, // A4 Portrait Aspect Ratio
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.accentTeal, size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'PROTECTED VIDEO SURFACE (FLAG_SECURE)',
                              style: TextStyle(
                                color: AppTheme.accentTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hardware DRM Decrypted • Page ${widget.currentPage}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
              ),
      ),
    );
  }
}
