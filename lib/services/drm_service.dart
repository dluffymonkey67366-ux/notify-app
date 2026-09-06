import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/drm_pdf_manifest.dart';

class DrmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String licenseServerEndpoint =
      'https://us-central1-notify-app.cloudfunctions.net/requestDrmLicense';

  /// Fetches the DRM stream manifest for a purchased part.
  /// Verifies client has valid purchase before returning video stream manifest.
  Future<DrmPdfManifest> getStreamManifest(String partId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Authentication required to view DRM content.");
    }

    // Check user's active purchase in Firestore
    final purchaseDoc = await _firestore
        .collection('purchases')
        .doc('${user.uid}_$partId')
        .get();

    if (!purchaseDoc.exists) {
      throw Exception("Purchase record not found for this part.");
    }

    final data = purchaseDoc.data();
    final expiresAt = (data?['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      throw Exception("Subscription plan for this note has expired. Repurchase to continue.");
    }

    // Return DRM stream manifest for video-frame playback
    const totalPages = 45;
    const pageDuration = 2.0;
    final timestamps = List<double>.generate(totalPages, (i) => i * pageDuration);

    return DrmPdfManifest(
      partId: partId,
      totalPages: totalPages,
      pageDurationSeconds: pageDuration,
      pageTimestamps: timestamps,
      dashStreamUrl: 'https://stream.notifyapp.in/drm/dash/$partId/manifest.mpd',
      hlsStreamUrl: 'https://stream.notifyapp.in/drm/hls/$partId/master.m3u8',
      licenseServerUrl: licenseServerEndpoint,
      drmKeyId: 'key_$partId',
      protectionType: 'widevine',
    );
  }

  /// Exchanges CDM challenge for DRM license from license server
  Future<Map<String, dynamic>> requestDrmLicense({
    required String partId,
    String? challengeBase64,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User unauthenticated.");

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse(licenseServerEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Notify-Part-Id': partId,
      },
      body: jsonEncode({
        'partId': partId,
        'challenge': challengeBase64,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? "DRM license request refused (Code ${response.statusCode})");
    }
  }

  /// Persists reading progress (page number) to Firestore
  Future<void> saveProgress({
    required String partId,
    required int pageNumber,
    required int totalPages,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc(partId)
          .set({
        'partId': partId,
        'pageNumber': pageNumber,
        'totalPages': totalPages,
        'completionPercentage': ((pageNumber / totalPages) * 100).round(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Loads last saved reading progress
  Future<int> loadProgress(String partId) async {
    final user = _auth.currentUser;
    if (user == null) return 1;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc(partId)
          .get();

      if (doc.exists && doc.data() != null) {
        return (doc.data()!['pageNumber'] as int?) ?? 1;
      }
    } catch (_) {}
    return 1;
  }
}
