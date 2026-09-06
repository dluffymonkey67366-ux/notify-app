import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notify_app/design_system/components/notify_reader_drawer.dart';
import 'package:notify_app/screens/reader/html/html_note_reader_screen.dart';
import 'package:notify_app/screens/reader/pdf/drm_pdf_reader_screen.dart';
import 'package:notify_app/services/auth_service.dart';

class FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  bool get isAuthenticated => true;

  @override
  User? get currentUser => null;

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  String? get pendingTarget => null;

  @override
  AuthFlowType? get currentFlow => null;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget createTestReader(Widget reader) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => FakeAuthService()),
    ],
    child: MaterialApp(
      home: reader,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rank 6: Desktop Reading Measure Container & Docked Rail Tests', () {
    testWidgets('HtmlNoteReaderScreen on mobile (<900px) has Drawer and TOC AppBar button', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestReader(
          const HtmlNoteReaderScreen(
            partId: 'part_1',
            partTitle: 'Contract Act Intro',
            subjectTitle: 'Corporate Law',
            initialRawHtml: '<h1>Intro</h1>',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNotNull);

      // TOC icon button is visible in AppBar
      expect(find.byTooltip('Table of Contents'), findsOneWidget);

      // Docked rail is NOT present in body
      final dockedRailFinder = find.byWidgetPredicate(
        (widget) => widget is NotifyReaderDrawer && widget.isDockedRail == true,
      );
      expect(dockedRailFinder, findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('HtmlNoteReaderScreen on desktop (>=900px) docks 280px left rail and constrains reading width to 760px', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestReader(
          const HtmlNoteReaderScreen(
            partId: 'part_1',
            partTitle: 'Contract Act Intro',
            subjectTitle: 'Corporate Law',
            initialRawHtml: '<h1>Intro</h1>',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);

      // TOC button in AppBar is hidden on desktop (rail already docked)
      expect(find.byTooltip('Table of Contents'), findsNothing);

      // Stationary docked 280px rail is present
      final dockedRailFinder = find.byWidgetPredicate(
        (widget) => widget is NotifyReaderDrawer && widget.isDockedRail == true,
      );
      expect(dockedRailFinder, findsOneWidget);

      // Reading Measure Container: ConstrainedBox with maxWidth: 760 and 32px padding
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final measureBox = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 760);
      expect(measureBox.isNotEmpty, isTrue);

      final paddings = tester.widgetList<Padding>(find.byType(Padding));
      final readingPadding = paddings.where(
        (p) => p.padding == const EdgeInsets.symmetric(horizontal: 32),
      );
      expect(readingPadding.isNotEmpty, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('DrmPdfReaderScreen on desktop (>=900px) docks rail and constrains canvas', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestReader(
          const DrmPdfReaderScreen(
            partId: 'part_pdf_1',
            partTitle: 'Taxation Notes',
            subjectTitle: 'Direct Tax',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);

      // Stationary docked 280px rail is present
      final dockedRailFinder = find.byWidgetPredicate(
        (widget) => widget is NotifyReaderDrawer && widget.isDockedRail == true,
      );
      expect(dockedRailFinder, findsOneWidget);

      // ConstrainedBox with maxWidth: 760 is present
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final measureBox = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 760);
      expect(measureBox.isNotEmpty, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
