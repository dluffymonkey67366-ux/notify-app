import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notify_app/models/catalog_models.dart';
import 'package:notify_app/screens/catalog/subject_list_screen.dart';
import 'package:notify_app/services/catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rank 5: Catalog 2-tier Navigation and Scheme Badge Tests', () {
    test('Subject model supports group and scheme in constructor and serialization', () {
      final subject = Subject(
        id: 'test_sub',
        title: 'Test Subject',
        category: 'CA',
        level: 'Inter',
        group: 'Group 1',
        scheme: 'New Scheme 2024+',
        description: 'Test description',
        order: 1,
      );

      expect(subject.group, equals('Group 1'));
      expect(subject.scheme, equals('New Scheme 2024+'));

      final map = subject.toMap();
      expect(map['group'], equals('Group 1'));
      expect(map['scheme'], equals('New Scheme 2024+'));

      final fromMap = Subject.fromMap(map, 'test_sub');
      expect(fromMap.group, equals('Group 1'));
      expect(fromMap.scheme, equals('New Scheme 2024+'));
    });

    test('CatalogService mockSubjects contain Foundation, Inter (Group 1 & 2), and Final', () async {
      final service = CatalogService();
      final subjects = await service.getSubjects();

      expect(subjects.any((s) => s.level == 'Foundation'), isTrue);
      expect(subjects.any((s) => s.level == 'Inter' && s.group == 'Group 1'), isTrue);
      expect(subjects.any((s) => s.level == 'Inter' && s.group == 'Group 2'), isTrue);
      expect(subjects.any((s) => s.level == 'Final' && s.group == 'Group 1'), isTrue);
      expect(subjects.any((s) => s.level == 'Final' && s.group == 'Group 2'), isTrue);
      expect(subjects.any((s) => s.scheme == 'New Scheme 2024+'), isTrue);
    });

    testWidgets('SubjectListScreen displays 2-tier navigation and filters properly', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const SubjectListScreen(),
        ),
      );

      // Allow async _loadSubjects to complete
      await tester.pumpAndSettle();

      // Tier 1 controls should be visible
      expect(find.text('Foundation'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Final'), findsOneWidget);

      // Intermediate is default level -> group filters are visible
      expect(find.text('All Papers'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Group 1'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Group 2'), findsOneWidget);

      // Intermediate subjects should be displayed
      expect(find.text('Advanced Accounting'), findsOneWidget);
      expect(find.text('Corporate and Other Laws'), findsOneWidget);
      expect(find.text('Auditing and Ethics'), findsOneWidget);
      expect(find.text('New Scheme 2024+'), findsWidgets);

      // Filter by Group 2
      await tester.tap(find.widgetWithText(InkWell, 'Group 2'));
      await tester.pumpAndSettle();

      // Group 2 subjects should remain, Group 1 should be gone
      expect(find.text('Auditing and Ethics'), findsOneWidget);
      expect(find.text('Cost and Management Accounting'), findsOneWidget);
      expect(find.text('Advanced Accounting'), findsNothing);
      expect(find.text('Corporate and Other Laws'), findsNothing);

      // Switch to Foundation tier
      await tester.tap(find.widgetWithText(InkWell, 'Foundation'));
      await tester.pumpAndSettle();

      // Foundation subjects visible
      expect(find.text('Business Laws'), findsOneWidget);
      expect(find.text('Accounting'), findsOneWidget);
      // Group sub-tabs should not appear for Foundation
      expect(find.widgetWithText(InkWell, 'Group 1'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Group 2'), findsNothing);
    });
  });
}
