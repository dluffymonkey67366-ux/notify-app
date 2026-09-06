import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyProgress {
  final String partId;
  final int pageNumber;
  final int totalPages;
  final int completionPercentage;
  final String? chapterTitle;
  final String? subjectTitle;
  final DateTime updatedAt;

  const StudyProgress({
    required this.partId,
    required this.pageNumber,
    required this.totalPages,
    required this.completionPercentage,
    this.chapterTitle,
    this.subjectTitle,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'partId': partId,
    'pageNumber': pageNumber,
    'totalPages': totalPages,
    'completionPercentage': completionPercentage,
    'chapterTitle': chapterTitle,
    'subjectTitle': subjectTitle,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StudyProgress.fromMap(Map<String, dynamic> map) {
    DateTime dt;
    final rawDt = map['updatedAt'];
    if (rawDt is Timestamp) {
      dt = rawDt.toDate();
    } else if (rawDt is String) {
      dt = DateTime.tryParse(rawDt) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    return StudyProgress(
      partId: map['partId'] as String? ?? '',
      pageNumber: (map['pageNumber'] as num?)?.toInt() ?? 1,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      completionPercentage: (map['completionPercentage'] as num?)?.toInt() ?? 0,
      chapterTitle: map['chapterTitle'] as String?,
      subjectTitle: map['subjectTitle'] as String?,
      updatedAt: dt,
    );
  }
}

/// Service managing CA student study progress across Firestore (`users/{uid}/progress/{partId}`)
/// and local SharedPreferences fallback.
class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const String _prefExamDateKey = 'notify_target_exam_date';
  static const String _prefRecentProgressKey = 'notify_recent_progress_cache';

  /// Saves student reading progress to Firestore and local cache
  Future<void> saveProgress({
    required String partId,
    required int pageNumber,
    required int totalPages,
    String? chapterTitle,
    String? subjectTitle,
  }) async {
    final completionPercentage = totalPages > 0
        ? ((pageNumber / totalPages) * 100).round()
        : 0;

    final progress = StudyProgress(
      partId: partId,
      pageNumber: pageNumber,
      totalPages: totalPages,
      completionPercentage: completionPercentage,
      chapterTitle: chapterTitle,
      subjectTitle: subjectTitle,
      updatedAt: DateTime.now(),
    );

    // Save to local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('notify_progress_$partId', jsonEncode(progress.toMap()));
      await prefs.setString(_prefRecentProgressKey, jsonEncode(progress.toMap()));
    } catch (_) {}

    // Save to Firestore if authenticated
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .doc(partId)
            .set({
          'partId': partId,
          'pageNumber': pageNumber,
          'totalPages': totalPages,
          'completionPercentage': completionPercentage,
          'chapterTitle': chapterTitle,
          'subjectTitle': subjectTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
    }
  }

  /// Loads reading progress for a specific part
  Future<StudyProgress?> loadProgress(String partId) async {
    // Check Firestore first if authenticated
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .doc(partId)
            .get();

        if (doc.exists && doc.data() != null) {
          return StudyProgress.fromMap(doc.data()!);
        }
      }
    } catch (_) {}

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('notify_progress_$partId');
      if (str != null) {
        return StudyProgress.fromMap(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}

    return null;
  }

  /// Returns the most recent study progress
  Future<StudyProgress?> getRecentProgress() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final query = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          return StudyProgress.fromMap(query.docs.first.data());
        }
      }
    } catch (_) {}

    // Local fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefRecentProgressKey);
      if (str != null) {
        return StudyProgress.fromMap(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}

    return null;
  }

  /// Target exam date management
  Future<DateTime> getTargetExamDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefExamDateKey);
      if (str != null) {
        final dt = DateTime.tryParse(str);
        if (dt != null) return dt;
      }
    } catch (_) {}

    // Default: May 2, 2026 (Upcoming CA Exam session)
    return DateTime(2026, 5, 2);
  }

  Future<void> setTargetExamDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefExamDateKey, date.toIso8601String());
    } catch (_) {}
  }

  Future<int> getExamDaysRemaining() async {
    final target = await getTargetExamDate();
    final now = DateTime.now();
    final diff = target.difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff > 0 ? diff : 0;
  }
}
