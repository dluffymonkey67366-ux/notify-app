# Notify App — Manual QA Security & DRM Verification Checklist

This checklist documents mandatory manual verification procedures for hardware-level and visual security features that cannot be verified by automated unit or Firestore emulator tests.

---

## Prerequisites & Test Devices

- **Physical Android Test Device**: Android 10+ (API 29+) with physical hardware buttons (e.g. Samsung Galaxy, Google Pixel, or OnePlus).
- **Physical iOS Test Device (Optional / Secondary)**: iOS 15+.
- **Secondary Device / External Camera**: To capture physical evidence of screens (since device screenshots will be blocked).
- **Screen Recording Apps**:
  - Android native screen recorder (Quick Settings tile).
  - Third-party recording app (e.g., AZ Screen Recorder or Mobizen).
  - Desktop: OBS Studio / Windows Game Bar (if testing Windows build).

---

## Checklist Summary

| Test ID | Test Scenario | Platform | Expected Result | Pass / Fail |
|---------|---------------|----------|-----------------|-------------|
| **MQA-01** | Hardware Screenshot Blocking (`FLAG_SECURE`) | Android Physical | Toast message: *"Can't take screenshot due to security policy"* or capture is blocked | [ ] |
| **MQA-02** | System Screen Recorder Blackout | Android Physical | Recorded video shows pitch-black content area while viewing protected notes | [ ] |
| **MQA-03** | Third-Party Screen Recorder Detection & Blackout | Android Physical | Third-party app captures black screen and violation alert is logged | [ ] |
| **MQA-04** | App Switcher / Recent Apps Thumbnail Obfuscation | Android / iOS | In task switcher, Notify card is blank/white/obscured with no note text visible | [ ] |
| **MQA-05** | DRM Video Playback Recording Black Screen | Android Physical | DRM protected video frames (ExoPlayer/Widevine) render as solid black in video capture | [ ] |
| **MQA-06** | Dynamic Drifting Watermark Animation | All Platforms | User identifier (email/phone/UID) and timestamp visibly drift diagonally across the screen | [ ] |
| **MQA-07** | Watermark Readability & Non-Obtrusiveness | All Platforms | Watermark is legible when photographed externally, but does not block note text | [ ] |

---

## Step-by-Step Test Procedures

### MQA-01: Hardware Screenshot Blocking (`FLAG_SECURE`)
1. Open the Notify app on a **physical Android device**.
2. Log in with a valid student account with active access.
3. Open any protected note (HTML reader or PDF viewer).
4. Press the hardware key combination: **Power + Volume Down** (or trigger screenshot gesture).
5. **Expected Result**:
   - System displays a toast: *"Can't take screenshot due to security policy"* or *"Taking screenshots isn't allowed by the app or your organization"*.
   - No screenshot is saved to the Android Gallery/Photos folder.
   - Screen protection service maintains reader view without crashing.

### MQA-02: Native Android Screen Recorder Blackout
1. Pull down Android Quick Settings and tap **Screen Recorder**.
2. Start recording the screen (with audio/mic optional).
3. Switch into the Notify app and open a protected note part.
4. Scroll through the note content for 10-15 seconds.
5. Stop the screen recording and open the recorded MP4 file in Gallery/Photos.
6. **Expected Result**:
   - The recorded video renders the Notify note content area as **pitch-black** (blank screen).
   - Navigation bars or system status bar may be visible, but protected note content is 100% blacked out.

### MQA-03: Third-Party Screen Recorder Detection & Blackout
1. Install a third-party screen recording tool (e.g. AZ Screen Recorder from Google Play Store).
2. Start recording using the floating widget.
3. Open Notify and navigate to a protected note.
4. **Expected Result**:
   - The resulting recording produces a solid black screen for the protected viewport.
   - A violation telemetry event is logged to Firestore `violations` collection.

### MQA-04: App Switcher / Recents Screen Obfuscation
1. Open any protected note in Notify.
2. Swipe up from the bottom of the screen (or press Recents/App Switcher button) to view open apps.
3. Inspect the Notify app preview card.
4. **Expected Result**:
   - The preview card thumbnail is blank, white, or showing the splash screen.
   - No readable note content is visible in the task switcher preview.

### MQA-05: DRM Video Playback Recording Black Screen
1. Open a PDF note rendered via the DRM video-frame pipeline (`drmPipeline`).
2. Verify video frames stream smoothly while turning pages.
3. Start any screen recording software.
4. Turn pages and play back the video-frame note.
5. Inspect the captured video file.
6. **Expected Result**:
   - Hardware DRM (Widevine Modular L1/L3) prevents video frame buffers from being composited into the screen grabber.
   - The video player canvas in the captured video is completely black.

### MQA-06: Dynamic Drifting Watermark Movement
1. Open any HTML note or PDF note in Notify.
2. Observe the overlay watermark containing the user's registered details (e.g. `student@email.com • 9876543210 • 2026-09-06`).
3. Watch the watermark position over 30-60 seconds.
4. **Expected Result**:
   - The watermark smoothly and visibly drifts across different regions of the screen (e.g., floating diagonally, bouncing off viewport bounds, or changing coordinate offsets every few seconds).
   - The watermark does not remain static at a single coordinate, preventing cropping or masking attacks.

### MQA-07: Watermark Legibility Under External Photography
1. With the protected note open, use a secondary smartphone camera to take a photo of the physical test device's screen.
2. Inspect the captured photograph.
3. **Expected Result**:
   - The user identifier (email, phone number, UID) and timestamp on the drifting watermark are clearly legible in the photograph.
   - The watermark opacity (e.g., 15-20%) strikes a balance: clearly traceable in a photo, but does not obscure text or diagrams during normal studying.

---

## QA Sign-Off

- **Tester Name**: __________________________
- **Device Model / OS**: __________________________
- **App Version Tested**: __________________________
- **Date Tested**: __________________________
- **Overall Result**: [ ] PASS  [ ] FAIL
