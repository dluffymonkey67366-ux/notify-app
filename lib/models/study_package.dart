import 'package:flutter/material.dart';

/// Represents a purchased CA study package (e.g., CA Inter Corporate Law, Advanced Accounting)
class StudyPackage {
  final String id;
  final String title;
  final String paperCode;
  final String courseLevel;
  final String groupName;
  final String syllabusScheme;
  final int daysRemaining;
  final bool isOfflineAvailable;
  final int offlineSizeBytes;
  final int totalChapters;
  final int completedChapters;
  final String lastReadChapterTitle;
  final int lastReadChapterNumber;
  final String instructorName;
  final double totalHours;
  final Color accentColor;
  final IconData icon;

  const StudyPackage({
    required this.id,
    required this.title,
    required this.paperCode,
    required this.courseLevel,
    required this.groupName,
    this.syllabusScheme = 'ICAI New Scheme',
    required this.daysRemaining,
    required this.isOfflineAvailable,
    this.offlineSizeBytes = 0,
    required this.totalChapters,
    required this.completedChapters,
    required this.lastReadChapterTitle,
    required this.lastReadChapterNumber,
    required this.instructorName,
    required this.totalHours,
    required this.accentColor,
    required this.icon,
  });

  double get progressPercentage =>
      totalChapters > 0 ? (completedChapters / totalChapters).clamp(0.0, 1.0) : 0.0;

  bool get isExpiringSoon => daysRemaining <= 7;
  bool get isExpired => daysRemaining <= 0;

  /// Curated mock data representing real ICAI CA student courses
  static List<StudyPackage> get mockPurchasedPackages => [
    const StudyPackage(
      id: 'ca_inter_law',
      title: 'Corporate and Other Laws',
      paperCode: 'Paper 2',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 1',
      daysRemaining: 42,
      isOfflineAvailable: true,
      offlineSizeBytes: 398458880, // ~380 MB
      totalChapters: 20,
      completedChapters: 14,
      lastReadChapterTitle: 'Chapter 3: Contract of Indemnity and Guarantee',
      lastReadChapterNumber: 3,
      instructorName: 'CA Darshan Khare',
      totalHours: 110,
      accentColor: Color(0xFFE5A93B), // Amber
      icon: Icons.gavel_rounded,
    ),
    const StudyPackage(
      id: 'ca_inter_acc',
      title: 'Advanced Accounting',
      paperCode: 'Paper 1',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 1',
      daysRemaining: 185,
      isOfflineAvailable: true,
      offlineSizeBytes: 545259520, // ~520 MB
      totalChapters: 25,
      completedChapters: 18,
      lastReadChapterTitle: 'AS 14: Accounting for Amalgamations',
      lastReadChapterNumber: 9,
      instructorName: 'CA Praveen Sharma',
      totalHours: 160,
      accentColor: Color(0xFF2A9D8F), // Teal
      icon: Icons.account_balance_rounded,
    ),
    const StudyPackage(
      id: 'ca_inter_tax',
      title: 'Taxation: Direct & Indirect (GST)',
      paperCode: 'Paper 3',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 1',
      daysRemaining: 6, // Urgent expiry badge demonstration
      isOfflineAvailable: false,
      offlineSizeBytes: 0,
      totalChapters: 24,
      completedChapters: 11,
      lastReadChapterTitle: 'Sec 54 Capital Gains Exemptions & GST ITC Rules',
      lastReadChapterNumber: 7,
      instructorName: 'CA Vijay Sarda & CA Rajkumar',
      totalHours: 145,
      accentColor: Color(0xFFE76F51), // Coral
      icon: Icons.receipt_long_rounded,
    ),
    const StudyPackage(
      id: 'ca_inter_audit',
      title: 'Auditing and Ethics',
      paperCode: 'Paper 5',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 2',
      daysRemaining: 24,
      isOfflineAvailable: false,
      offlineSizeBytes: 0,
      totalChapters: 15,
      completedChapters: 5,
      lastReadChapterTitle: 'SA 315: Identifying Risks of Material Misstatement',
      lastReadChapterNumber: 4,
      instructorName: 'CA Shubham Keswani',
      totalHours: 85,
      accentColor: Color(0xFFC5A880), // Bronze
      icon: Icons.policy_rounded,
    ),
    const StudyPackage(
      id: 'ca_inter_cost',
      title: 'Cost and Management Accounting',
      paperCode: 'Paper 4',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 2',
      daysRemaining: 120,
      isOfflineAvailable: true,
      offlineSizeBytes: 304087040, // ~290 MB
      totalChapters: 16,
      completedChapters: 10,
      lastReadChapterTitle: 'Standard Costing & Variance Analysis',
      lastReadChapterNumber: 11,
      instructorName: 'CA Purushottam Aggarwal',
      totalHours: 120,
      accentColor: Color(0xFF3D5A80), // Indigo slate
      icon: Icons.calculate_rounded,
    ),
    const StudyPackage(
      id: 'ca_inter_fmsm',
      title: 'Financial Management & Strategic Management',
      paperCode: 'Paper 6',
      courseLevel: 'CA Intermediate',
      groupName: 'Group 2',
      daysRemaining: 95,
      isOfflineAvailable: true,
      offlineSizeBytes: 325058560, // ~310 MB
      totalChapters: 18,
      completedChapters: 13,
      lastReadChapterTitle: 'Cost of Capital & WACC Calculation',
      lastReadChapterNumber: 6,
      instructorName: 'CA Rahul Garg',
      totalHours: 95,
      accentColor: Color(0xFF9D4EDD), // Royal Violet
      icon: Icons.trending_up_rounded,
    ),
  ];
}
