# Notify — PDF DRM Video-Frame Pipeline Specification

This document details the architecture, encoding pipeline, DRM packaging, license exchange protocol, and player implementations for Notify's DRM-protected PDF notes across Android, iOS, and Desktop (Windows/macOS/Linux).

---

## 1. Why Video DRM Instead of Native PDF Viewers?

Standard mobile and desktop PDF renderers (PDF.js, Pdfium, CoreGraphics, Skia) render pages directly to the OS graphics framebuffer. On Desktop and non-FLAG_SECURE environments, screen capture utilities, OBS, Discord screen sharing, and window capture APIs can easily intercept the rendered graphics.

By converting PDF pages into discrete video frames and packaging them as a **hardware-protected DRM video stream**:
1. **Decryption occurs strictly inside a Hardware Secure Enclave / Trusted Execution Environment (TEE)**:
   - Android: Widevine L1 / L3
   - iOS: FairPlay Streaming via AVFoundation
   - Desktop: Widevine Content Decryption Module (CDM) via Embedded Chromium
2. **OS Compositor Capture Block**:
   - The OS window manager is bypassed during video overlay composition.
   - Any screen capture or recording tool captures only a black rectangle.
3. **No Native Export/Share**:
   - The original PDF file is never delivered to the client; the client receives only encrypted video segments.
   - Printing, exporting, copying text, or "open in other app" is architecturally impossible.

---

## 2. Server-Side Page-to-Frame Pipeline

```
Raw PDF (Uploaded by Creator)
        ↓
1. High-Resolution Frame Rendering (pdftoppm / poppler)
   - 300 DPI, 2160 x 3840 (4K crisp text/tables)
   - Output: page_0001.png, page_0002.png, ...
        ↓
2. Keyframe-Aligned Video Encoding (FFmpeg)
   - 1 page per 2.0s duration
   - Forced IDR keyframe at every page boundary for instantaneous seeking
   - Command:
     ffmpeg -framerate 0.5 -i page_%04d.png \
       -c:v libx264 -preset slow -crf 18 \
       -pix_fmt yuv420p -tune stillimage \
       -g 1 -keyint_min 1 -force_key_frames "expr:gte(t,n_forced*2)" \
       notes_master.mp4
        ↓
3. Shaka Packager DRM Encryption & Manifest Generation
   - Common Encryption (CENC AES-128 CTR / CBCS)
   - Widevine PSSH for Android & Desktop Chromium
   - FairPlay key metadata for iOS
   - Command:
     packager \
       input=notes_master.mp4,stream=video,output=encrypted_video.mp4 \
       --enable_raw_key_encryption \
       --keys label=:key_id=${KEY_ID}:key=${KEY_HEX} \
       --protection_scheme cenc \
       --mpd_output manifest.mpd \
       --hls_master_playlist_output master.m3u8
        ↓
4. Cloud Storage Deployment
   - Encrypted segments uploaded to Firebase Storage / Cloud CDN
```

---

## 3. DRM License Exchange Protocol

```
Student opens PDF Part in Notify
        ↓
App checks Firestore purchase record (must be active & non-expired)
        ↓
Player requests DRM license:
  POST /requestDrmLicense
  Headers:
    Authorization: Bearer <firebase_id_token>
    X-Notify-Part-Id: <part_id>
  Body: { challenge: <CDM_challenge_base64> }
        ↓
Cloud Function validates:
  1. Token verification (UID identified)
  2. Firestore query: purchases/{uid}_{partId}
     - status == 'active'
     - expiresAt > now
  3. If check fails → HTTP 403 Forbidden (Playback Denied)
  4. If check passes → Generates and signs DRM license payload with CEK
        ↓
Player feeds license to Hardware CDM
        ↓
Hardware decodes and displays page frame
```

---

## 4. Platform-Specific Player Architecture

### Android & iOS
- **Android**: Uses Google ExoPlayer with MediaDrm configured for Widevine modular DRM (`com.widevine.alpha`). Hardware-protected surface (`SurfaceView` with `FLAG_SECURE`).
- **iOS**: Uses `AVPlayer` with `AVContentKeySession` configured for FairPlay Streaming (FPS).

### Desktop (Windows, macOS, Linux)
- Flutter's native desktop DRM plugins are currently immature and lack hardware-level Widevine CDM integration.
- **Solution**: Embed an instance of Chromium (via WebView2 on Windows, WKWebView on macOS with FairPlay, or embedded CEF) hosting an HTML5 Shaka Player with native Encrypted Media Extensions (EME).
- This provides hardware-level capture protection and seamless Widevine CDM license acquisition on desktop.

---

## 5. UI/UX & Forensic Protections

1. **Drifting Forensic Watermark**:
   - Low-opacity (0.12 - 0.18) overlay displaying the student's email or phone number.
   - Automatically repositions every 30 seconds across screen corners/margins to defeat camera photography.
2. **Page Navigation**:
   - Next/Previous page buttons, scrubber, and jump-to-page input.
   - Seeking translates directly to `(pageNumber - 1) * pageDurationSeconds`.
3. **Reading Progress**:
   - Exact `pageNumber` persisted to `users/{uid}/progress/{partId}`.
4. **Zero Share Affordances**:
   - No context menu, no export button, no printing dialog.
