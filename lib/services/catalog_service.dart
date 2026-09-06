import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/catalog_models.dart';

class GrantAccessResult {
  final bool success;
  final String? purchaseId;
  final DateTime? expiresAt;
  final List<String> coveredPartIds;
  final String message;

  GrantAccessResult({
    required this.success,
    this.purchaseId,
    this.expiresAt,
    this.coveredPartIds = const [],
    required this.message,
  });
}

/// CatalogService manages browsing Subject → Lesson → Part,
/// retrieving packages covering content, loading trimmed previews,
/// and executing the stubbed grantAccess function.
class CatalogService {
  static final CatalogService _instance = CatalogService._internal();
  factory CatalogService() => _instance;
  CatalogService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Local cache for granted purchases (ensures immediate UI reaction and offline/dev testability)
  final Map<String, PurchaseRecord> _localPurchases = {};

  // Mock / Default catalog data for seamless offline & local testing
  final List<Subject> _mockSubjects = [
    Subject(
      id: 'ca_inter_law',
      title: 'Corporate and Other Laws',
      category: 'CA',
      level: 'Inter',
      description: 'Comprehensive notes covering Companies Act, 2013 and Other Laws for CA Intermediate.',
      order: 1,
      createdAt: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    ),
    Subject(
      id: 'ca_inter_tax',
      title: 'Taxation (Direct & Indirect)',
      category: 'CA',
      level: 'Inter',
      description: 'Income Tax Act, 1961 and Goods and Services Tax (GST) conceptual summaries.',
      order: 2,
      createdAt: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    ),
    Subject(
      id: 'ca_inter_acc',
      title: 'Advanced Accounting',
      category: 'CA',
      level: 'Inter',
      description: 'Accounting Standards (AS) and consolidated financial statements master notes.',
      order: 3,
      createdAt: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    ),
  ];

  final Map<String, List<Lesson>> _mockLessons = {
    'ca_inter_law': [
      Lesson(
        id: 'chapter_3_contract_act',
        subjectId: 'ca_inter_law',
        title: 'Chapter 3 - The Indian Contract Act, 1872',
        order: 1,
        description: 'Special contracts: Indemnity, Guarantee, Bailment, Pledge, and Agency.',
        createdAt: DateTime(2026, 9, 6),
      ),
      Lesson(
        id: 'chapter_7_mgmt_admin',
        subjectId: 'ca_inter_law',
        title: 'Chapter 7 - Management and Administration',
        order: 2,
        description: 'Annual General Meetings, Extra-Ordinary Meetings, Resolutions, and Registers.',
        createdAt: DateTime(2026, 9, 6),
      ),
    ],
    'ca_inter_tax': [
      Lesson(
        id: 'chapter_gst_basics',
        subjectId: 'ca_inter_tax',
        title: 'Chapter 1 - Supply Under GST & Charge of GST',
        order: 1,
        description: 'Section 7 Supply parameters, Composite vs Mixed, Reverse Charge Mechanism.',
        createdAt: DateTime(2026, 9, 6),
      ),
    ],
  };

  final Map<String, List<Part>> _mockParts = {
    'chapter_3_contract_act': [
      Part(
        id: 'part_3a_indemnity_guarantee',
        lessonId: 'chapter_3_contract_act',
        subjectId: 'ca_inter_law',
        title: 'Part A: Contract of Indemnity and Guarantee',
        order: 1,
        fileType: 'html',
        previewRef: 'content/preview/part_3a_indemnity_guarantee.html',
        fullRef: 'content/full/part_3a_indemnity_guarantee.html',
        createdAt: DateTime(2026, 9, 6),
      ),
      Part(
        id: 'part_3b_bailment_pledge',
        lessonId: 'chapter_3_contract_act',
        subjectId: 'ca_inter_law',
        title: 'Part B: Bailment and Pledge',
        order: 2,
        fileType: 'html',
        previewRef: 'content/preview/part_3b_bailment_pledge.html',
        fullRef: 'content/full/part_3b_bailment_pledge.html',
        createdAt: DateTime(2026, 9, 6),
      ),
      Part(
        id: 'part_3c_agency',
        lessonId: 'chapter_3_contract_act',
        subjectId: 'ca_inter_law',
        title: 'Part C: Law of Agency',
        order: 3,
        fileType: 'pdf',
        previewRef: 'content/preview/part_3c_agency.pdf',
        fullRef: 'content/full/part_3c_agency.pdf',
        createdAt: DateTime(2026, 9, 6),
      ),
    ],
    'chapter_7_mgmt_admin': [
      Part(
        id: 'part_7a_general_meetings',
        lessonId: 'chapter_7_mgmt_admin',
        subjectId: 'ca_inter_law',
        title: 'Part A: AGM & EGM Statutory Provisions',
        order: 1,
        fileType: 'html',
        previewRef: 'content/preview/part_7a_general_meetings.html',
        fullRef: 'content/full/part_7a_general_meetings.html',
        createdAt: DateTime(2026, 9, 6),
      ),
    ],
  };

  /// Packages covering single parts, single lessons, whole subjects, or bundles.
  /// Each package configures a distinct subset of durations:
  /// - pkg_part_3a: only monthly (₹49)
  /// - pkg_law_ch3_all: monthly (₹79) & 3 months (₹189)
  /// - pkg_law_full_subject: 3 months (₹299), 6 months (₹499), 1 year (₹799)
  /// - pkg_ca_inter_all_bundle: only 1 year (₹1999)
  final List<Package> _mockPackages = [
    Package(
      id: 'pkg_part_3a',
      title: 'Part A Only — Contract of Indemnity & Guarantee',
      description: 'Single note access covering Section 124 to Section 147.',
      packageType: PackageType.part,
      category: 'CA',
      level: 'Inter',
      subjectId: 'ca_inter_law',
      refs: ['part_3a_indemnity_guarantee'],
      pricing: {
        PlanDuration.monthly: 49, // ONLY monthly configured!
      },
      isActive: true,
      createdAt: DateTime(2026, 9, 6),
    ),
    Package(
      id: 'pkg_law_ch3_all',
      title: 'Contract Act — Complete Chapter 3 Bundle',
      description: 'Unlocks all parts of Chapter 3 (Indemnity, Bailment, Pledge, Agency).',
      packageType: PackageType.lesson,
      category: 'CA',
      level: 'Inter',
      subjectId: 'ca_inter_law',
      refs: ['chapter_3_contract_act', 'part_3a_indemnity_guarantee', 'part_3b_bailment_pledge', 'part_3c_agency'],
      pricing: {
        PlanDuration.monthly: 79,
        PlanDuration.threeMonths: 189,
        // sixMonths and oneYear are NOT offered!
      },
      isActive: true,
      createdAt: DateTime(2026, 9, 6),
    ),
    Package(
      id: 'pkg_law_full_subject',
      title: 'Corporate and Other Laws — Full Subject Pass',
      description: 'Unlocks all chapters and parts of CA Inter Corporate and Other Laws.',
      packageType: PackageType.subject,
      category: 'CA',
      level: 'Inter',
      subjectId: 'ca_inter_law',
      refs: ['ca_inter_law'],
      pricing: {
        // monthly is NOT offered!
        PlanDuration.threeMonths: 299,
        PlanDuration.sixMonths: 499,
        PlanDuration.oneYear: 799,
      },
      isActive: true,
      createdAt: DateTime(2026, 9, 6),
    ),
    Package(
      id: 'pkg_ca_inter_all_bundle',
      title: 'CA Intermediate All-Subjects Combo Bundle',
      description: 'Unrestricted access to Law, Taxation, and Advanced Accounting.',
      packageType: PackageType.bundle,
      category: 'CA',
      level: 'Inter',
      refs: ['ca_inter_law', 'ca_inter_tax', 'ca_inter_acc', 'part_3a_indemnity_guarantee', 'part_3b_bailment_pledge', 'part_3c_agency'],
      pricing: {
        // Only oneYear is offered!
        PlanDuration.oneYear: 1999,
      },
      isActive: true,
      createdAt: DateTime(2026, 9, 6),
    ),
  ];

  // -------------------------------------------------------------
  // CATALOG BROWSING: Subject → Lesson → Part
  // -------------------------------------------------------------

  /// 1. Fetch Subjects list
  Future<List<Subject>> getSubjects() async {
    try {
      final snap = await _firestore.collection('subjects').orderBy('order').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) => Subject.fromMap(doc.data(), doc.id)).toList();
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Using local subjects catalog fallback: $e");
    }
    return List.unmodifiable(_mockSubjects);
  }

  /// 2. Fetch Lessons for a given Subject
  Future<List<Lesson>> getLessons(String subjectId) async {
    try {
      final snap = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .orderBy('order')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) => Lesson.fromMap(doc.data(), doc.id)).toList();
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Using local lessons catalog fallback: $e");
    }
    return List.unmodifiable(_mockLessons[subjectId] ?? []);
  }

  /// 3. Fetch Parts for a given Lesson (Public catalog metadata)
  Future<List<Part>> getParts(String subjectId, String lessonId) async {
    try {
      final snap = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .doc(lessonId)
          .collection('parts')
          .orderBy('order')
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) => Part.fromMap(doc.data(), doc.id)).toList();
      }
    } catch (e) {
      // Re-throw permission-denied errors so rule violations are never silently swallowed
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Using local parts catalog fallback: $e");
    }
    return List.unmodifiable(_mockParts[lessonId] ?? []);
  }

  /// Fetches the protected content subdocument for a part once access is verified.
  /// Path: subjects/{subjectId}/lessons/{lessonId}/parts/{partId}/protected/content
  /// Requires hasActivePurchase(subjectId, lessonId, partId) under Firestore rules.
  Future<String?> getPartFullRef({
    required String subjectId,
    required String lessonId,
    required String partId,
  }) async {
    try {
      final doc = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('lessons')
          .doc(lessonId)
          .collection('parts')
          .doc(partId)
          .collection('protected')
          .doc('content')
          .get();
      if (doc.exists) {
        return doc.data()?['fullRef'] as String?;
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Error fetching protected fullRef: $e");
    }
    // Fallback to local mock if available (for offline testing)
    final parts = _mockParts[lessonId] ?? [];
    for (final p in parts) {
      if (p.id == partId) return p.fullRef;
    }
    return null;
  }

  /// 4. Fetch Packages covering a specific Part, Lesson, Subject, or Bundle
  Future<List<Package>> getPackagesForPart({
    required String partId,
    required String lessonId,
    required String subjectId,
  }) async {
    List<Package> allPackages = [];
    try {
      final snap = await _firestore.collection('packages').where('isActive', isEqualTo: true).get();
      if (snap.docs.isNotEmpty) {
        allPackages = snap.docs.map((doc) => Package.fromMap(doc.data(), doc.id)).toList();
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Using local packages fallback: $e");
    }

    if (allPackages.isEmpty) {
      allPackages = List.of(_mockPackages);
    }

    // Filter packages that cover this part
    return allPackages.where((pkg) {
      return pkg.coversPart(partId, lessonId: lessonId, subjectId: subjectId);
    }).toList();
  }

  /// Fetch all active packages for a subject
  Future<List<Package>> getPackagesForSubject(String subjectId) async {
    List<Package> allPackages = [];
    try {
      final snap = await _firestore.collection('packages').where('isActive', isEqualTo: true).get();
      if (snap.docs.isNotEmpty) {
        allPackages = snap.docs.map((doc) => Package.fromMap(doc.data(), doc.id)).toList();
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Using local packages fallback: $e");
    }

    if (allPackages.isEmpty) {
      allPackages = List.of(_mockPackages);
    }

    return allPackages.where((pkg) {
      return pkg.subjectId == subjectId ||
          pkg.refs.contains(subjectId) ||
          pkg.packageType == PackageType.bundle;
    }).toList();
  }

  // -------------------------------------------------------------
  // ACCESS & PURCHASE CHECKING
  // -------------------------------------------------------------

  /// Checks whether user has active, unexpired purchase for this part
  Future<bool> hasActiveAccess(String partId, {String? lessonId, String? subjectId}) async {
    final uid = _auth.currentUser?.uid ?? 'local_user';

    // 1. Check local session cache
    final localKey = '${uid}_$partId';
    if (_localPurchases.containsKey(localKey)) {
      final purchase = _localPurchases[localKey]!;
      if (purchase.isActive) return true;
    }

    // Also check lesson-level or subject-level local purchase
    if (lessonId != null && _localPurchases.containsKey('${uid}_$lessonId')) {
      final p = _localPurchases['${uid}_$lessonId']!;
      if (p.isActive) return true;
    }
    if (subjectId != null && _localPurchases.containsKey('${uid}_$subjectId')) {
      final p = _localPurchases['${uid}_$subjectId']!;
      if (p.isActive) return true;
    }

    // 2. Check Firestore purchases/{userId}_{partId}
    try {
      final doc = await _firestore.collection('purchases').doc('${uid}_$partId').get();
      if (doc.exists) {
        final purchase = PurchaseRecord.fromMap(doc.data()!, doc.id);
        if (purchase.isActive) {
          _localPurchases[localKey] = purchase;
          return true;
        }
      }

      // Check lesson purchase doc
      if (lessonId != null) {
        final lessonDoc = await _firestore.collection('purchases').doc('${uid}_$lessonId').get();
        if (lessonDoc.exists) {
          final p = PurchaseRecord.fromMap(lessonDoc.data()!, lessonDoc.id);
          if (p.isActive) return true;
        }
      }

      // Check subject purchase doc
      if (subjectId != null) {
        final subDoc = await _firestore.collection('purchases').doc('${uid}_$subjectId').get();
        if (subDoc.exists) {
          final p = PurchaseRecord.fromMap(subDoc.data()!, subDoc.id);
          if (p.isActive) return true;
        }
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      debugPrint("Firestore access check info: $e");
    }

    return false;
  }

  // -------------------------------------------------------------
  // FREE TRIMMED PREVIEW
  // -------------------------------------------------------------

  /// Returns the free trimmed preview content for a given part before purchase.
  /// Complies with security rules: only the public previewRef / trimmed sample is shown.
  Future<String> getTrimmedPreviewHtml(Part part) async {
    // In production, this can fetch from Firebase Storage previewRef or public endpoint.
    // Here we provide high-yield trimmed preview content for CA/CMA notes.
    return '''
<div class="note-preview-wrapper">
  <div class="preview-header">
    <span class="preview-badge">FREE TRIMMED PREVIEW (FIRST 25%)</span>
    <h2 style="color: #E5A93B; margin-top: 8px;">${part.title}</h2>
  </div>

  <div class="preview-content">
    <p><strong>1. Introduction and Statutory Background</strong></p>
    <p>The concepts of Indemnity and Guarantee form the bedrock of commercial surety relationships under the Indian Contract Act, 1872.</p>
    
    <div style="background: rgba(229, 169, 59, 0.1); border-left: 4px solid #E5A93B; padding: 12px; margin: 12px 0;">
      <strong>Section 124 — Contract of Indemnity Defined:</strong><br/>
      <em>"A contract by which one party promises to save the other from loss caused to him by the conduct of the promisor himself, or by the conduct of any other person, is called a contract of indemnity."</em>
    </div>

    <p><strong>Key Elements of Indemnity:</strong></p>
    <ul>
      <li><strong>Two Parties:</strong> Indemnifier (promisor who promises to make good loss) and Indemnity-holder / Indemnified (promisee protected from loss).</li>
      <li><strong>Anticipated Loss:</strong> The loss must arise from human agency, not natural catastrophe (force majeure).</li>
      <li><strong>Enforceability:</strong> Governed by general principles of valid contracts (offer, acceptance, lawful consideration).</li>
    </ul>

    <p><strong>Section 126 — Contract of Guarantee Defined:</strong></p>
    <p>A contract of guarantee is a contract to perform the promise, or discharge the liability, of a third person in case of his default. It involves tripartite relationships:</p>
    <ol>
      <li><strong>Surety:</strong> Person giving the guarantee</li>
      <li><strong>Principal Debtor:</strong> Person in respect of whose default guarantee is given</li>
      <li><strong>Creditor:</strong> Person to whom the guarantee is given</li>
    </ol>
  </div>
</div>
''';
  }

  // -------------------------------------------------------------
  // STUBBED grantAccess(packageId, planDuration)
  // -------------------------------------------------------------

  /// Calculates expiration date matching server calculation in grantAccess.ts
  DateTime calculateExpiration(DateTime startDate, PlanDuration duration) {
    final d = DateTime(startDate.year, startDate.month, startDate.day, startDate.hour, startDate.minute);
    switch (duration) {
      case PlanDuration.monthly:
        return DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
      case PlanDuration.threeMonths:
        return DateTime(d.year, d.month + 3, d.day, d.hour, d.minute);
      case PlanDuration.sixMonths:
        return DateTime(d.year, d.month + 6, d.day, d.hour, d.minute);
      case PlanDuration.oneYear:
        return DateTime(d.year + 1, d.month, d.day, d.hour, d.minute);
    }
  }

  /// STUBBED FUNCTION: grantAccess(packageId, planDuration)
  ///
  /// Requirement:
  /// "On 'Purchase', call a stubbed grantAccess(packageId, planDuration) function
  /// (Razorpay integration comes later — do not build real payment yet, just the call site
  /// and a mocked success path)."
  Future<GrantAccessResult> grantAccess({
    required String packageId,
    required PlanDuration planDuration,
  }) async {
    // 1. Resolve package definition
    Package? targetPackage;
    try {
      final doc = await _firestore.collection('packages').doc(packageId).get();
      if (doc.exists) {
        targetPackage = Package.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}

    targetPackage ??= _mockPackages.firstWhere(
      (p) => p.id == packageId,
      orElse: () => throw ArgumentError("Package not found: $packageId"),
    );

    // 2. Validate that the package actually offers the selected plan duration
    if (!targetPackage.offersDuration(planDuration)) {
      throw StateError(
        "Duration '${planDuration.label}' is not offered by package '${targetPackage.title}'.",
      );
    }

    final price = targetPackage.priceFor(planDuration) ?? 0;
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'local_student_session';
    final now = DateTime.now();
    final expiresAt = calculateExpiration(now, planDuration);
    final purchaseId = 'purch_${userId}_${packageId}_${now.millisecondsSinceEpoch}';

    // 3. Resolve covered parts
    final List<String> coveredPartIds = [];
    if (targetPackage.packageType == PackageType.part) {
      coveredPartIds.addAll(targetPackage.refs);
    } else if (targetPackage.packageType == PackageType.lesson) {
      for (final ref in targetPackage.refs) {
        if (_mockParts.containsKey(ref)) {
          coveredPartIds.addAll(_mockParts[ref]!.map((p) => p.id));
        } else {
          coveredPartIds.add(ref);
        }
      }
    } else if (targetPackage.packageType == PackageType.subject) {
      final subjectId = targetPackage.subjectId ?? (targetPackage.refs.isNotEmpty ? targetPackage.refs.first : '');
      final lessons = _mockLessons[subjectId] ?? [];
      for (final l in lessons) {
        final parts = _mockParts[l.id] ?? [];
        coveredPartIds.addAll(parts.map((p) => p.id));
      }
      if (coveredPartIds.isEmpty) {
        coveredPartIds.addAll(targetPackage.refs);
      }
    } else {
      // Bundle
      for (final ref in targetPackage.refs) {
        if (_mockParts.containsKey(ref)) {
          coveredPartIds.addAll(_mockParts[ref]!.map((p) => p.id));
        } else {
          coveredPartIds.add(ref);
        }
      }
    }

    // 4. Mocked Success Path: Record purchase
    final masterPurchase = PurchaseRecord(
      id: purchaseId,
      userId: userId,
      packageId: packageId,
      packageType: targetPackage.packageType.key,
      planDuration: planDuration,
      purchasedAt: now,
      expiresAt: expiresAt,
      status: 'active',
      amount: price,
      currency: 'INR',
      coveredPartIds: coveredPartIds,
      coveredSubjectIds: targetPackage.subjectId != null ? [targetPackage.subjectId!] : null,
    );

    // Save into local memory cache for immediate access
    _localPurchases['${userId}_$packageId'] = masterPurchase;
    for (final partId in coveredPartIds) {
      _localPurchases['${userId}_$partId'] = masterPurchase;
    }

    // Also persist to Firestore if connected
    try {
      final batch = _firestore.batch();
      final pRef = _firestore.collection('purchases').doc(purchaseId);
      batch.set(pRef, masterPurchase.toMap());

      for (final partId in coveredPartIds) {
        final partAccessRef = _firestore.collection('purchases').doc('${userId}_$partId');
        batch.set(partAccessRef, {
          'userId': userId,
          'packageId': packageId,
          'partId': partId,
          'packageType': targetPackage.packageType.key,
          'planDuration': planDuration.key,
          'purchasedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'status': 'active',
          'masterPurchaseId': purchaseId,
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Firestore mock purchase save info (offline/rules handled): $e");
    }

    return GrantAccessResult(
      success: true,
      purchaseId: purchaseId,
      expiresAt: expiresAt,
      coveredPartIds: coveredPartIds,
      message: "Access granted for ${planDuration.label}! Full notes unlocked.",
    );
  }

  /// For testing/debugging: resets purchase state
  void clearLocalPurchases() {
    _localPurchases.clear();
  }
}
