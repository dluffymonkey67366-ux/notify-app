import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_session.dart';

/// SessionManager enforces single active session per account across all platforms.
/// Any new login on another device writes to `users/{uid}/session/current` and
/// causes this instance to immediately detect the conflict and force logout.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _storageKeyDeviceId = 'notify_device_id';
  static const String _storageKeyLoginAt = 'notify_session_login_at';

  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  final StreamController<String> _conflictController = StreamController<String>.broadcast();

  /// Stream of force-logout reasons emitted when a session conflict occurs
  Stream<String> get onSessionConflict => _conflictController.stream;

  String? _cachedDeviceId;
  DateTime? _cachedLoginAt;

  String? get currentDeviceId => _cachedDeviceId;
  DateTime? get currentLoginAt => _cachedLoginAt;

  /// Retrieves or generates a persistent hardware-bound device ID
  Future<String> getOrCreateDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    String? deviceId = await _secureStorage.read(key: _storageKeyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (100000 + (DateTime.now().microsecond % 900000));
      deviceId = 'device_${Platform.operatingSystem}_${timestamp}_$random';
      await _secureStorage.write(key: _storageKeyDeviceId, value: deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Registers a new active session in Firestore upon verified login.
  /// Overwrites `users/{uid}/session/current`, which forces out any other active device.
  Future<UserSession> registerNewSession(String userId) async {
    final deviceId = await getOrCreateDeviceId();
    final now = DateTime.now();
    _cachedLoginAt = now;

    await _secureStorage.write(
      key: _storageKeyLoginAt,
      value: now.toIso8601String(),
    );

    final session = UserSession(
      deviceId: deviceId,
      loginAt: now,
      lastActiveAt: now,
      platform: Platform.operatingSystem,
      invalidated: false,
    );

    await _firestore
      .collection('users')
      .doc(userId)
      .collection('session')
      .doc('current')
      .set(session.toMap());

    // Begin real-time observation of this session
    startSessionObserver(userId);

    return session;
  }

  /// Starts real-time Firestore listener on `users/{uid}/session/current`.
  /// Immediately notifies when another device overwrites the session or if flagged invalidated.
  void startSessionObserver(String userId) {
    _sessionSubscription?.cancel();

    final sessionDocRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('session')
        .doc('current');

    _sessionSubscription = sessionDocRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists || snapshot.data() == null) return;

        final sessionData = snapshot.data() as Map<String, dynamic>;
        final remoteSession = UserSession.fromMap(sessionData);

        final localDeviceId = await getOrCreateDeviceId();
        final localLoginAt = _cachedLoginAt;

        if (localLoginAt == null) return;

        // Check if remote session has been replaced by a newer device login
        if (remoteSession.isConflict(localDeviceId, localLoginAt)) {
          final reason = remoteSession.invalidationReason ??
              "Your account was accessed from another device. Notify allows only one active session per account.";
          await forceSignOut(reason);
        }
      },
      onError: (error) {
        // Handle permissions or network errors
        if (error is FirebaseException && error.code == 'permission-denied') {
          forceSignOut("Session access revoked: permission denied.");
        }
      },
    );
  }

  /// Explicit validation called on app resume (didChangeAppLifecycleState -> resumed)
  Future<bool> validateSessionOnResume(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('session')
          .doc('current')
          .get();

      if (!doc.exists || doc.data() == null) return true;

      final remoteSession = UserSession.fromMap(doc.data()!);
      final localDeviceId = await getOrCreateDeviceId();
      final localLoginAt = _cachedLoginAt;

      if (localLoginAt != null && remoteSession.isConflict(localDeviceId, localLoginAt)) {
        final reason = remoteSession.invalidationReason ??
            "Your account was accessed from another device while the app was in the background.";
        await forceSignOut(reason);
        return false;
      }
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        await forceSignOut("Session access revoked: permission denied.");
        return false;
      }
      return true;
    }
  }

  /// Forces immediate sign-out and notifies UI
  Future<void> forceSignOut(String reason) async {
    stopSessionObserver();
    _cachedLoginAt = null;
    await _secureStorage.delete(key: _storageKeyLoginAt);

    try {
      await _auth.signOut();
    } catch (_) {}

    _conflictController.add(reason);
  }

  /// Cancels active listener
  void stopSessionObserver() {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
  }

  void dispose() {
    stopSessionObserver();
    _conflictController.close();
  }
}
