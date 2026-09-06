import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:notify_app/design_system/design_system.dart';
import 'package:notify_app/screens/app_shell.dart';
import 'package:notify_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

Widget createTestApp({
  ThemeMode mode = ThemeMode.dark,
  Widget? home,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>(create: (_) => FakeAuthService()),
      ChangeNotifierProvider(create: (_) => ThemeController()..setThemeMode(mode)),
    ],
    child: Builder(
      builder: (context) {
        final themeController = Provider.of<ThemeController>(context);
        return MaterialApp(
          title: 'Notify Test',
          theme: NotifyTheme.lightTheme,
          darkTheme: NotifyTheme.darkTheme,
          themeMode: themeController.themeMode,
          home: home ?? const AppShell(),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notify App Shell & Library Screen Tests', () {
    testWidgets('Renders AppShell on small screen (390x844 - Mobile) without overflow', (tester) async {
      // 1. Set screen size to mobile
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify no layout overflow exception
      expect(tester.takeException(), isNull, reason: 'Layout should render without exceptions on mobile');

      // Check Bottom Navigation Bar is present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Check Library Screen elements
      expect(find.text('My CA Library'), findsOneWidget);
      expect(find.text('Purchased Packages'), findsOneWidget);

      // Check Expiry Badges ("X days remaining")
      expect(find.textContaining('days remaining'), findsWidgets);

      // Check "Offline available" indicator
      expect(find.textContaining('Offline available'), findsWidgets);

      // Check Progress Bar
      expect(find.byType(NotifyProgressBar), findsWidgets);

      // Check Search & Filter Bar
      expect(find.byType(NotifySearchBar), findsOneWidget);
    });

    testWidgets('Renders AppShell on large screen (1200x800 - Desktop/Tablet) with Side Navigation without overflow', (tester) async {
      // 1. Set screen size to large desktop/tablet
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify no layout overflow exception
      expect(tester.takeException(), isNull, reason: 'Layout should render without exceptions on desktop');

      // Check Bottom Navigation is NOT present
      expect(find.byType(NavigationBar), findsNothing);

      // Check Side Navigation Rail is present
      expect(find.text('My Library'), findsOneWidget);
      expect(find.text('Reading Desk'), findsOneWidget);
      expect(find.text('ICAI Catalog'), findsOneWidget);
      expect(find.text('Student Account'), findsOneWidget);

      // Check Library Grid renders packages
      expect(find.text('My CA Library'), findsOneWidget);
      expect(find.textContaining('days remaining'), findsWidgets);
      expect(find.textContaining('Offline available'), findsWidgets);
    });

    testWidgets('Renders in Light Mode (--paper: #FAFAF7) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp(mode: ThemeMode.light));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My CA Library'), findsOneWidget);
      expect(find.textContaining('days remaining'), findsWidgets);
      expect(find.textContaining('Offline available'), findsWidgets);
    });

    testWidgets('Filter chips filter packages correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap "Group 2" filter chip
      await tester.tap(find.text('Group 2'));
      await tester.pumpAndSettle();

      // Only Group 2 packages should be displayed (Cost and Management Accounting, etc.)
      expect(find.text('Cost and Management Accounting'), findsOneWidget);
      expect(find.text('Corporate and Other Laws'), findsNothing);

      // Tap "Offline Ready" filter chip
      await tester.tap(find.text('Offline Ready'));
      await tester.pumpAndSettle();

      // All displayed items should be offline available
      expect(find.textContaining('Offline available'), findsWidgets);
    });
  });
}
