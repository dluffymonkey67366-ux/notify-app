import 'package:cloud_firestore/cloud_firestore.dart';

/// Available plan duration tiers for Notify packages.
enum PlanDuration {
  monthly,
  threeMonths,
  sixMonths,
  oneYear;

  String get key {
    switch (this) {
      case PlanDuration.monthly:
        return 'monthly';
      case PlanDuration.threeMonths:
        return 'threeMonths';
      case PlanDuration.sixMonths:
        return 'sixMonths';
      case PlanDuration.oneYear:
        return 'oneYear';
    }
  }

  String get label {
    switch (this) {
      case PlanDuration.monthly:
        return '1 Month';
      case PlanDuration.threeMonths:
        return '3 Months';
      case PlanDuration.sixMonths:
        return '6 Months';
      case PlanDuration.oneYear:
        return '1 Year';
    }
  }

  static PlanDuration fromKey(String key) {
    switch (key) {
      case 'monthly':
        return PlanDuration.monthly;
      case 'threeMonths':
        return PlanDuration.threeMonths;
      case 'sixMonths':
        return PlanDuration.sixMonths;
      case 'oneYear':
        return PlanDuration.oneYear;
      default:
        throw ArgumentError('Unknown plan duration: $key');
    }
  }

  static PlanDuration? tryFromKey(String key) {
    for (final duration in PlanDuration.values) {
      if (duration.key == key) return duration;
    }
    return null;
  }
}

/// Package type categorization
enum PackageType {
  part,
  lesson,
  subject,
  bundle;

  String get key => name;

  String get label {
    switch (this) {
      case PackageType.part:
        return 'Single Part Note';
      case PackageType.lesson:
        return 'Chapter / Lesson Bundle';
      case PackageType.subject:
        return 'Complete Subject';
      case PackageType.bundle:
        return 'Special Multi-Subject Bundle';
    }
  }

  static PackageType fromKey(String key) {
    switch (key.toLowerCase()) {
      case 'part':
        return PackageType.part;
      case 'lesson':
        return PackageType.lesson;
      case 'subject':
        return PackageType.subject;
      case 'bundle':
        return PackageType.bundle;
      default:
        return PackageType.part;
    }
  }
}

DateTime? _parseDateTime(dynamic val) {
  if (val == null) return null;
  if (val is Timestamp) return val.toDate();
  if (val is DateTime) return val;
  if (val is String) return DateTime.tryParse(val);
  return null;
}

/// Subject schema: Top-level category-agnostic exam course unit
/// Firestore path: subjects/{subjectId}
class Subject {
  final String id;
  final String title;
  final String category; // "CA", "CMA", etc.
  final String level; // "Foundation", "Inter", "Final"
  final String description;
  final int order;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Subject({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.order,
    this.createdAt,
    this.updatedAt,
  });

  factory Subject.fromMap(Map<String, dynamic> data, String id) {
    return Subject(
      id: id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'CA',
      level: data['level'] as String? ?? 'Inter',
      description: data['description'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'level': level,
    'description': description,
    'order': order,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Lesson schema: Chapter or topic grouping within a subject
/// Firestore path: subjects/{subjectId}/lessons/{lessonId}
class Lesson {
  final String id;
  final String subjectId;
  final String title;
  final int order;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Lesson({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.order,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Lesson.fromMap(Map<String, dynamic> data, String id) {
    return Lesson(
      id: id,
      subjectId: data['subjectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      description: data['description'] as String?,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'subjectId': subjectId,
    'title': title,
    'order': order,
    if (description != null) 'description': description,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Part schema: Smallest atomic content unit (HTML or PDF)
/// Firestore path: subjects/{subjectId}/lessons/{lessonId}/parts/{partId}
class Part {
  final String id;
  final String lessonId;
  final String subjectId;
  final String title;
  final int order;
  final String fileType; // "html" or "pdf"
  final String previewRef; // Public/trimmed preview reference
  final String fullRef; // Protected content reference
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Part({
    required this.id,
    required this.lessonId,
    required this.subjectId,
    required this.title,
    required this.order,
    required this.fileType,
    required this.previewRef,
    required this.fullRef,
    this.createdAt,
    this.updatedAt,
  });

  bool get isHtml => fileType.toLowerCase() == 'html';
  bool get isPdf => fileType.toLowerCase() == 'pdf';

  factory Part.fromMap(Map<String, dynamic> data, String id) {
    return Part(
      id: id,
      lessonId: data['lessonId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      fileType: data['fileType'] as String? ?? 'html',
      previewRef: data['previewRef'] as String? ?? '',
      fullRef: data['fullRef'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'lessonId': lessonId,
    'subjectId': subjectId,
    'title': title,
    'order': order,
    'fileType': fileType,
    'previewRef': previewRef,
    'fullRef': fullRef,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}

/// Package schema: Sellable units at any level (Part, Lesson, Subject, Bundle)
/// Firestore path: packages/{packageId}
class Package {
  final String id;
  final String title;
  final String? description;
  final PackageType packageType;
  final String category;
  final String level;
  final String? subjectId;
  final List<String> refs;
  final Map<PlanDuration, int> pricing; // Duration -> Price in INR
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Package({
    required this.id,
    required this.title,
    this.description,
    required this.packageType,
    required this.category,
    required this.level,
    this.subjectId,
    required this.refs,
    required this.pricing,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// CRITICAL REQUIREMENT:
  /// "Selecting a package (which may cover one Part, one Lesson, a whole Subject, or a bundle)
  /// shows only the durations that package actually offers (subset of monthly/3mo/6mo/1yr)
  /// with that package's own price for each."
  /// "confirm a package with only some durations configured genuinely hides the missing ones in the picker, not just visually disables them."
  List<PlanDuration> get availableDurations {
    return PlanDuration.values.where((duration) {
      final price = pricing[duration];
      return price != null && price > 0;
    }).toList();
  }

  bool offersDuration(PlanDuration duration) {
    final price = pricing[duration];
    return price != null && price > 0;
  }

  int? priceFor(PlanDuration duration) => pricing[duration];

  /// Checks if this package covers a given part directly or through lesson/subject hierarchy
  bool coversPart(String partId, {String? lessonId, String? subjectId}) {
    switch (packageType) {
      case PackageType.part:
        return refs.contains(partId);
      case PackageType.lesson:
        return (lessonId != null && refs.contains(lessonId)) || refs.contains(partId);
      case PackageType.subject:
        return (subjectId != null && refs.contains(subjectId)) ||
            (this.subjectId != null && this.subjectId == subjectId) ||
            refs.contains(partId);
      case PackageType.bundle:
        return refs.contains(partId) ||
            (lessonId != null && refs.contains(lessonId)) ||
            (subjectId != null && refs.contains(subjectId));
    }
  }

  factory Package.fromMap(Map<String, dynamic> data, String id) {
    final pricingRaw = data['pricing'] as Map<String, dynamic>? ?? {};
    final Map<PlanDuration, int> pricingMap = {};
    for (final duration in PlanDuration.values) {
      final val = pricingRaw[duration.key];
      if (val is num && val > 0) {
        pricingMap[duration] = val.toInt();
      }
    }

    return Package(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      packageType: PackageType.fromKey(data['packageType'] as String? ?? 'part'),
      category: data['category'] as String? ?? 'CA',
      level: data['level'] as String? ?? 'Inter',
      subjectId: data['subjectId'] as String?,
      refs: (data['refs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      pricing: pricingMap,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, int> pricingRaw = {};
    for (final entry in pricing.entries) {
      pricingRaw[entry.key.key] = entry.value;
    }

    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'packageType': packageType.key,
      'category': category,
      'level': level,
      if (subjectId != null) 'subjectId': subjectId,
      'refs': refs,
      'pricing': pricingRaw,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

/// Purchase record representing active access to content
class PurchaseRecord {
  final String id;
  final String userId;
  final String packageId;
  final String packageType;
  final PlanDuration planDuration;
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final String status;
  final int amount;
  final String currency;
  final List<String> coveredPartIds;
  final List<String>? coveredLessonIds;
  final List<String>? coveredSubjectIds;

  PurchaseRecord({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.packageType,
    required this.planDuration,
    required this.purchasedAt,
    required this.expiresAt,
    this.status = 'active',
    required this.amount,
    this.currency = 'INR',
    required this.coveredPartIds,
    this.coveredLessonIds,
    this.coveredSubjectIds,
  });

  bool get isActive => status == 'active' && DateTime.now().isBefore(expiresAt);

  factory PurchaseRecord.fromMap(Map<String, dynamic> data, String id) {
    return PurchaseRecord(
      id: id,
      userId: data['userId'] as String? ?? '',
      packageId: data['packageId'] as String? ?? '',
      packageType: data['packageType'] as String? ?? 'part',
      planDuration: PlanDuration.tryFromKey(data['planDuration'] as String? ?? 'monthly') ?? PlanDuration.monthly,
      purchasedAt: _parseDateTime(data['purchasedAt']) ?? DateTime.now(),
      expiresAt: _parseDateTime(data['expiresAt']) ?? DateTime.now().add(const Duration(days: 30)),
      status: data['status'] as String? ?? 'active',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'INR',
      coveredPartIds: (data['coveredPartIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coveredLessonIds: (data['coveredLessonIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      coveredSubjectIds: (data['coveredSubjectIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'packageId': packageId,
    'packageType': packageType,
    'planDuration': planDuration.key,
    'purchasedAt': purchasedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'status': status,
    'amount': amount,
    'currency': currency,
    'coveredPartIds': coveredPartIds,
    if (coveredLessonIds != null) 'coveredLessonIds': coveredLessonIds,
    if (coveredSubjectIds != null) 'coveredSubjectIds': coveredSubjectIds,
  };
}
