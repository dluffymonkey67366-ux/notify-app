import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an active user session for single-device enforcement
class UserSession {
  final String deviceId;
  final DateTime loginAt;
  final DateTime? lastActiveAt;
  final String? platform;
  final bool invalidated;
  final String? invalidationReason;

  const UserSession({
    required this.deviceId,
    required this.loginAt,
    this.lastActiveAt,
    this.platform,
    this.invalidated = false,
    this.invalidationReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'loginAt': Timestamp.fromDate(loginAt),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : FieldValue.serverTimestamp(),
      'platform': platform,
      'invalidated': invalidated,
      'invalidationReason': invalidationReason,
    };
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    DateTime parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserSession(
      deviceId: map['deviceId'] as String? ?? '',
      loginAt: parseTimestamp(map['loginAt']),
      lastActiveAt: map['lastActiveAt'] != null ? parseTimestamp(map['lastActiveAt']) : null,
      platform: map['platform'] as String?,
      invalidated: map['invalidated'] as bool? ?? false,
      invalidationReason: map['invalidationReason'] as String?,
    );
  }

  /// Returns true if this session has been superseded or invalidated by another device
  bool isConflict(String currentDeviceId, DateTime currentLoginAt) {
    if (invalidated) return true;
    if (deviceId != currentDeviceId) return true;
    if (loginAt.isAfter(currentLoginAt)) return true;
    return false;
  }
}
