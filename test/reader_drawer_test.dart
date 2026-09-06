import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notify_app/design_system/design_system.dart';
import 'package:notify_app/screens/reader/html/html_security_scripts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Table of Contents Model & Script Tests', () {
    test('defaultChaptersForPart generates structured chapters and sections', () {
      final chapters = TocChapter.defaultChaptersForPart('part_law_1', 'Contract of Indemnity');

      expect(chapters.length, greaterThanOrEqualTo(2));
      expect(chapters.first.title, contains('Module Introduction'));
      expect(chapters.first.sections.first.anchorId, 'section-syllabus');
      expect(chapters.first.sections.first.pageNumber, 1);

      final coreChapter = chapters[1];
      expect(coreChapter.sections.any((s) => s.anchorId == 'section-124'), true);
      final sec124 = coreChapter.sections.firstWhere((s) => s.anchorId == 'section-124');
      expect(sec124.pageNumber, 5);
      expect(sec124.title, contains('Section 124'));
    });

    test('buildScrollToSectionJs creates smooth scrollIntoView JavaScript', () {
      final js = HtmlSecurityScripts.buildScrollToSectionJs('section-124');

      expect(js, contains("document.getElementById('section-124')"));
      expect(js, contains("scrollIntoView({ behavior: 'smooth', block: 'start' })"));
    });
  });

  group('NotifyReaderDrawer Widget Tests', () {
    testWidgets('Renders chapters, sections, completion checkmarks and handles selection', (tester) async {
      final chapters = TocChapter.defaultChaptersForPart('part_test', 'Test Module');
      TocSection? selectedSection;
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotifyReaderDrawer(
              chapters: chapters,
              activeSectionId: 'sec_syllabus',
              currentPage: 5,
              themeConfig: ReaderThemeConfig.ink,
              onClose: () => closed = true,
              onSectionSelected: (s) => selectedSection = s,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('TABLE OF CONTENTS'), findsOneWidget);

      // Verify Chapter headers
      expect(find.textContaining('CHAPTER 1:'), findsOneWidget);
      expect(find.textContaining('CHAPTER 2:'), findsOneWidget);

      // Verify Sections
      expect(find.text('Section 124: Contract of Indemnity'), findsOneWidget);
      expect(find.text('p. 5'), findsOneWidget);

      // Tap a section row
      await tester.tap(find.text('Section 124: Contract of Indemnity'));
      await tester.pumpAndSettle();

      expect(selectedSection, isNotNull);
      expect(selectedSection!.id, 'sec_indemnity_124');
      expect(selectedSection!.pageNumber, 5);
      expect(selectedSection!.anchorId, 'section-124');

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, true);
    });

    testWidgets('Renders in docked rail mode without close button', (tester) async {
      final chapters = TocChapter.defaultChaptersForPart('part_test', 'Test Module');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotifyReaderDrawer(
              chapters: chapters,
              themeConfig: ReaderThemeConfig.paper,
              isDockedRail: true,
              onSectionSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TABLE OF CONTENTS'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
