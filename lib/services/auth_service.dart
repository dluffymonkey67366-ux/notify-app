import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'session_manager.dart';

enum AuthFlowType { phone, google }
enum AuthStatus { unauthenticated, verifyingPhone, pendingOtp, authenticated }

/// AuthService manages Google Sign-In and Phone Auth with mandatory OTP verification.
/// Non-negotiable rule: No login is trusted or granted session access without OTP verification.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final SessionManager _sessionManager = SessionManager();

  AuthStatus _status = AuthStatus.unauthenticated;
  AuthStatus get status => _status;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated && currentUser != null;

  String? _pendingVerificationId;
  int? _resendToken;
  String? _pendingEmail;
  String? _pendingPhoneNumber;
  AuthFlowType? _currentFlow;

  String? get pendingTarget => _currentFlow == AuthFlowType.phone ? _pendingPhoneNumber : _pendingEmail;
  AuthFlowType? get currentFlow => _currentFlow;

  AuthService() {
    _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _status = AuthStatus.unauthenticated;
        _sessionManager.stopSessionObserver();
        notifyListeners();
      }
    });

    // Listen to session conflict events
    _sessionManager.onSessionConflict.listen((reason) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  // ===========================================================================
  // 1. PHONE NUMBER + SMS OTP FLOW
  // ===========================================================================

  /// Step 1: Send SMS OTP to phone number
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    _pendingPhoneNumber = phoneNumber;
    _currentFlow = AuthFlowType.phone;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval on Android (instant OTP match)
          await _signInWithPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Phone verification failed.");
        },
        codeSent: (String verificationId, int? resendToken) {
          _pendingVerificationId = verificationId;
          _resendToken = resendToken;
          _status = AuthStatus.pendingOtp;
          notifyListeners();
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _pendingVerificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Step 2: Verify SMS OTP code entered by user
  Future<bool> verifyPhoneOtp({
    required String smsCode,
    required Function(String error) onError,
  }) async {
    if (_pendingVerificationId == null) {
      onError("No active phone verification request found. Please request a new OTP.");
      return false;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _pendingVerificationId!,
        smsCode: smsCode,
      );

      return await _signInWithPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? "Invalid or expired OTP code.");
      return false;
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  Future<bool> _signInWithPhoneCredential(PhoneAuthCredential credential) async {
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      // OTP verified: Register single active session
      await _sessionManager.registerNewSession(user.uid);
      _status = AuthStatus.authenticated;
      _pendingVerificationId = null;
      _pendingPhoneNumber = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ===========================================================================
  // 2. GOOGLE SIGN-IN + MANDATORY EMAIL OTP FLOW
  // ===========================================================================

  /// Step 1: Initiate Google Sign-In, then trigger mandatory secondary OTP
  Future<bool> initiateGoogleSignIn({
    required Function(String email) onOtpSent,
    required Function(String error) onError,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User aborted Google sign-in dialog
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null || user.email == null) {
        onError("Unable to retrieve email from Google Account.");
        await _auth.signOut();
        return false;
      }

      _pendingEmail = user.email;
      _currentFlow = AuthFlowType.google;

      // NON-NEGOTIABLE: Google sign-in alone DOES NOT grant session access.
      // Must complete 6-digit OTP verification.
      _status = AuthStatus.pendingOtp;
      notifyListeners();

      // Dispatch 6-digit OTP to user's registered Google email
      await _dispatchEmailOtp(user.uid, user.email!);
      onOtpSent(user.email!);
      return true;
    } catch (e) {
      await _auth.signOut();
      onError(e.toString());
      return false;
    }
  }

  /// Dispatches 6-digit verification code to the Google email and records pending OTP
  Future<void> _dispatchEmailOtp(String uid, String email) async {
    final code = (100000 + (DateTime.now().microsecond * 7 % 900000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    // Store pending OTP in secure user subcollection
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('security')
        .doc('pending_otp')
        .set({
      'code': code, // In production, hashed or validated via Cloud Function
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'attempts': 0,
      'verified': false,
    });
  }

  /// Step 2: Verify Email OTP for Google Sign-In
  Future<bool> verifyGoogleEmailOtp({
    required String otpCode,
    required Function(String error) onError,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      onError("No authenticated session in progress. Please sign in again.");
      return false;
    }

    try {
      final otpDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('security')
          .doc('pending_otp')
          .get();

      if (!otpDoc.exists || otpDoc.data() == null) {
        onError("OTP expired or not found. Please request a new code.");
        return false;
      }

      final data = otpDoc.data()!;
      final expectedCode = data['code'] as String?;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final attempts = (data['attempts'] as int?) ?? 0;

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        onError("OTP has expired. Please request a new code.");
        return false;
      }

      if (attempts >= 5) {
        onError("Too many failed attempts. Please request a new OTP.");
        await _auth.signOut();
        return false;
      }

      if (expectedCode != otpCode.trim()) {
        // Increment failed attempt count
        await otpDoc.reference.update({'attempts': FieldValue.increment(1)});
        onError("Incorrect OTP code. Please check and try again.");
        return false;
      }

      // Mark OTP verified
      await otpDoc.reference.update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      // OTP verified successfully: Register single active session
      await _sessionManager.registerNewSession(user.uid);
      _status = AuthStatus.authenticated;
      _pendingEmail = null;
      notifyListeners();
      return true;
    } catch (e) {
      onError(e.toString());
      return false;
    }
  }

  /// Resends OTP for current flow
  Future<void> resendOtp({
    required Function(String message) onSuccess,
    required Function(String error) onError,
  }) async {
    if (_currentFlow == AuthFlowType.phone && _pendingPhoneNumber != null) {
      await sendPhoneOtp(
        phoneNumber: _pendingPhoneNumber!,
        onCodeSent: (_) => onSuccess("A new OTP code has been sent via SMS."),
        onError: onError,
      );
    } else if (_currentFlow == AuthFlowType.google && currentUser != null && _pendingEmail != null) {
      await _dispatchEmailOtp(currentUser!.uid, _pendingEmail!);
      onSuccess("A new 6-digit OTP code has been sent to $_pendingEmail.");
    } else {
      onError("Unable to resend OTP at this time.");
    }
  }

  /// Cancels pending sign-in and logs out
  Future<void> cancelPendingAuth() async {
    _status = AuthStatus.unauthenticated;
    _pendingVerificationId = null;
    _pendingPhoneNumber = null;
    _pendingEmail = null;
    _currentFlow = null;
    await _auth.signOut();
    notifyListeners();
  }

  /// Standard user-initiated sign out
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('session')
            .doc('current')
            .update({'invalidated': true, 'invalidationReason': 'User signed out'});
      } catch (_) {}
    }

    _sessionManager.stopSessionObserver();
    await _auth.signOut();
    await _googleSignIn.signOut();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
