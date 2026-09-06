import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ViolationEvent {
  final String type; // 'screenshot' or 'screen_recording'
  final String platform;
  final DateTime timestamp;
  final String? processName;

  ViolationEvent({
    required this.type,
    required this.platform,
    required this.timestamp,
    this.processName,
  });
}

/// ScreenProtectionService manages hardware and software DRM screen capture defenses
/// across Android, iOS, and Desktop (Windows / macOS / Linux).
class ScreenProtectionService {
  static final ScreenProtectionService _instance = ScreenProtectionService._internal();
  factory ScreenProtectionService() => _instance;
  ScreenProtectionService._internal() {
    _initNativeChannel();
  }

  static const MethodChannel _channel = MethodChannel('com.notify.app/security');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final StreamController<ViolationEvent> _violationController =
      StreamController<ViolationEvent>.broadcast();
  Stream<ViolationEvent> get onViolationDetected => _violationController.stream;

  Timer? _desktopScanTimer;
  Timer? _iosCaptureCheckTimer;
  String? _activeUserId;
  String? _activePartId;
  bool _isProtecting = false;

  // Known desktop screen recorders
  static const Set<String> _windowsRecorders = {
    'obs64', 'obs32', 'obs', 'camtasia', 'camtasiastudio', 'snagit32', 'snagit64',
    'snagit', 'bandicam', 'fraps', 'captura', 'sharex', 'screentogif', 'action',
    'xsplit', 'gamebarft', 'gamebar', 'flashback', 'loom', 'activepresenter',
    'icecreamscreenrecorder', 'tinytake', 'debut'
  };

  static const Set<String> _macRecorders = {
    'OBS', 'Camtasia', 'ScreenFlow', 'Snagit', 'CleanShot X', 'Kap', 'Loom',
    'QuickTime Player', 'Screenflick', 'Monosnap'
  };

  static const Set<String> _linuxRecorders = {
    'obs', 'simplescreenrecorder', 'kazam', 'recordmydesktop', 'vokoscreen',
    'peek', 'green-recorder', 'kooha'
  };

  void _initNativeChannel() {
    if (kIsWeb) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onScreenshotDetected':
          _handleDetectionEvent(
            type: 'screenshot',
            platform: 'ios',
          );
          break;
        case 'onScreenRecordingDetected':
          _handleDetectionEvent(
            type: 'screen_recording',
            platform: 'ios',
          );
          break;
      }
    });
  }

  String _currentPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Begins active protection for the currently open note part
  Future<void> startProtection({
    required String userId,
    required String partId,
  }) async {
    _activeUserId = userId;
    _activePartId = partId;
    _isProtecting = true;

    if (kIsWeb) return;

    // 1. Android: Apply FLAG_SECURE (hardware-level screen/record block)
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('enableSecureFlag');
      } catch (e) {
        debugPrint('Android FLAG_SECURE enable error: $e');
      }
    }

    // 2. iOS: Polling check for active screen capture (UIScreen.main.isCaptured)
    if (Platform.isIOS) {
      _iosCaptureCheckTimer?.cancel();
      _iosCaptureCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!_isProtecting) return;
        try {
          final isCaptured = await _channel.invokeMethod<bool>('isScreenCaptured');
          if (isCaptured == true) {
            _handleDetectionEvent(type: 'screen_recording', platform: 'ios');
          }
        } catch (_) {}
      });
    }

    // 3. Desktop: Best-effort periodic scan for known screen recording processes
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      _desktopScanTimer?.cancel();
      // Scan immediately on open
      _scanDesktopProcesses();
      // And then scan every 3 seconds while note is viewed
      _desktopScanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_isProtecting) {
          _scanDesktopProcesses();
        }
      });
    }
  }

  /// Stops protection when exiting the note reader
  Future<void> stopProtection() async {
    _isProtecting = false;
    _desktopScanTimer?.cancel();
    _desktopScanTimer = null;
    _iosCaptureCheckTimer?.cancel();
    _iosCaptureCheckTimer = null;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('disableSecureFlag');
      } catch (_) {}
    }

    _activeUserId = null;
    _activePartId = null;
  }

  /// Scans running desktop processes for known capture software
  Future<void> _scanDesktopProcesses() async {
    try {
      final detected = await detectRunningRecorder();
      if (detected != null && _isProtecting) {
        _handleDetectionEvent(
          type: 'screen_recording',
          platform: _currentPlatformString(),
          processName: detected,
        );
      }
    } catch (e) {
      // Best-effort detection
    }
  }

  /// Checks running processes and returns the name of detected recording software, or null
  Future<String?> detectRunningRecorder() async {
    if (kIsWeb) return null;

    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
        if (result.exitCode == 0) {
          final output = (result.stdout as String).toLowerCase();
          for (final proc in _windowsRecorders) {
            if (output.contains('"$proc.exe"') || output.contains('$proc.exe')) {
              return proc;
            }
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('ps', ['-A', '-c', '-o', 'comm']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (_macRecorders.contains(trimmed)) {
              return trimmed;
            }
          }
        }
      } else if (Platform.isLinux) {
        final result = await Process.run('ps', ['-A', '-c', '-o', 'comm']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          for (final line in lines) {
            final trimmed = line.trim().toLowerCase();
            if (_linuxRecorders.contains(trimmed)) {
              return trimmed;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _handleDetectionEvent({
    required String type,
    required String platform,
    String? processName,
  }) {
    final event = ViolationEvent(
      type: type,
      platform: platform,
      timestamp: DateTime.now(),
      processName: processName,
    );

    _violationController.add(event);

    final userId = _activeUserId;
    final partId = _activePartId;
    if (userId != null && partId != null) {
      recordViolation(
        userId: userId,
        partId: partId,
        type: type,
        platform: platform,
      );
    }
  }

  /// Writes Firestore violation record:
  /// violations/{violationId} -> {userId, partId, type, platform, timestamp}
  Future<String> recordViolation({
    required String userId,
    required String partId,
    required String type,
    String? platform,
  }) async {
    final effectivePlatform = platform ?? _currentPlatformString();
    final violationId = 'viol_${DateTime.now().millisecondsSinceEpoch}_${100000 + Random().nextInt(900000)}';

    try {
      await _firestore.collection('violations').doc(violationId).set({
        'id': violationId,
        'userId': userId,
        'partId': partId,
        'type': type,
        'platform': effectivePlatform,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error writing violation record: $e');
    }

    return violationId;
  }

  void dispose() {
    stopProtection();
    _violationController.close();
  }
}
