import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notify_app/design_system/design_system.dart';
import 'package:notify_app/models/study_package.dart';
import 'package:notify_app/services/progress_service.dart';
import 'package:notify_app/screens/library/widgets/hero_resume_card.dart';
import 'package:notify_app/screens/library/library_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressService & Exam Countdown Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Saves and retrieves progress accurately via local cache fallback', () async {
      final service = ProgressService();
      await service.saveProgress(
        partId: 'ca_inter_law_p1',
        pageNumber: 15,
        totalPages: 30,
        chapterTitle: 'Chapter 3: Contract of Indemnity',
        subjectTitle: 'Corporate and Other Laws',
      );

      final progress = await service.loadProgress('ca_inter_law_p1');
      expect(progress, isNotNull);
      expect(progress!.partId, 'ca_inter_law_p1');
      expect(progress.pageNumber, 15);
      expect(progress.totalPages, 30);
      expect(progress.completionPercentage, 50);
      expect(progress.chapterTitle, 'Chapter 3: Contract of Indemnity');
      expect(progress.subjectTitle, 'Corporate and Other Laws');

      final recent = await service.getRecentProgress();
      expect(recent, isNotNull);
      expect(recent!.partId, 'ca_inter_law_p1');
    });

    test('Target exam date can be set, retrieved, and computes days remaining', () async {
      final service = ProgressService();
      final targetDate = DateTime.now().add(const Duration(days: 45));
      await service.setTargetExamDate(targetDate);

      final retrieved = await service.getTargetExamDate();
      expect(retrieved.year, targetDate.year);
      expect(retrieved.month, targetDate.month);
      expect(retrieved.day, targetDate.day);

      final days = await service.getExamDaysRemaining();
      expect(days, isIn([44, 45]));
    });
  });

  group('HeroResumeCard Widget Tests', () {
    testWidgets('Renders subject, chapter, progress bar, and fires onResume', (tester) async {
      final pkg = StudyPackage.mockPurchasedPackages.first;
      bool resumed = false;

      final progress = StudyProgress(
        partId: pkg.id,
        pageNumber: 14,
        totalPages: 20,
        completionPercentage: 70,
        chapterTitle: 'Chapter 3: Contract of Indemnity',
        subjectTitle: pkg.title,
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: NotifyTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroResumeCard(
                package: pkg,
                progress: progress,
                onResume: () => resumed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check displayed content
      expect(find.text('RESUME STUDYING'), findsOneWidget);
      expect(find.text(pkg.title), findsOneWidget);
      expect(find.text('Chapter 3: Contract of Indemnity'), findsOneWidget);
      expect(find.text('Last studied 2h ago'), findsOneWidget);
      expect(find.text('70% completed'), findsOneWidget);

      // Tap action button
      await tester.tap(find.text('Continue Chapter 3 ›'));
      await tester.pumpAndSettle();
      expect(resumed, true);
    });
  });

  group('NotifyExamCountdownBadge Widget Tests', () {
    testWidgets('Renders days remaining and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: NotifyTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: NotifyExamCountdownBadge(
                daysRemaining: 58,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('58 Days Remaining'), findsOneWidget);
      await tester.tap(find.byType(NotifyExamCountdownBadge));
      await tester.pumpAndSettle();
      expect(tapped, true);
    });
  });

  group('LibraryScreen Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('LibraryScreen renders HeroResumeCard and exam countdown badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NotifyTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RESUME STUDYING'), findsOneWidget);
      expect(find.byType(HeroResumeCard), findsOneWidget);
      expect(find.byType(NotifyExamCountdownBadge), findsOneWidget);
    });
  });
}
