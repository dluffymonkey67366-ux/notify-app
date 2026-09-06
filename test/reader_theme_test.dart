import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notify_app/design_system/notify_colors.dart';
import 'package:notify_app/design_system/reader_theme.dart';
import 'package:notify_app/design_system/components/notify_reader_controls_bar.dart';
import 'package:notify_app/screens/reader/html/html_security_scripts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderSettingsController & ReaderThemeConfig Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ReaderSettingsController().resetForTesting();
    });

    test('Initializes with default ink theme, 16px font, and serif typeface', () async {
      final controller = ReaderSettingsController();
      await controller.init();

      expect(controller.themeMode, ReaderThemeMode.ink);
      expect(controller.fontSize, 16.0);
      expect(controller.isSerif, true);
      expect(controller.themeConfig.backgroundColor, const Color(0xFF1A1A2E));
      expect(controller.themeConfig.textColor, NotifyColors.textLight);
      expect(controller.themeConfig.isDark, true);
    });

    test('Toggling theme mode updates themeConfig and persists', () async {
      final controller = ReaderSettingsController();
      await controller.init();

      bool notified = false;
      controller.addListener(() => notified = true);

      // Switch to Paper mode
      controller.setThemeMode(ReaderThemeMode.paper);
      expect(notified, true);
      expect(controller.themeMode, ReaderThemeMode.paper);
      expect(controller.themeConfig.backgroundColor, const Color(0xFFFAFAF7));
      expect(controller.themeConfig.textColor, NotifyColors.textDark);
      expect(controller.themeConfig.isDark, false);

      // Switch to Sepia mode
      notified = false;
      controller.setThemeMode(ReaderThemeMode.sepia);
      expect(notified, true);
      expect(controller.themeMode, ReaderThemeMode.sepia);
      expect(controller.themeConfig.backgroundColor, const Color(0xFFF4ECD8));
      expect(controller.themeConfig.textColor, const Color(0xFF332717));
      expect(controller.themeConfig.isDark, false);
    });

    test('Font size increments and decrements within boundaries [14, 22]', () async {
      final controller = ReaderSettingsController();
      await controller.init();

      expect(controller.fontSize, 16.0);

      // Increase
      controller.increaseFontSize();
      expect(controller.fontSize, 18.0);
      controller.increaseFontSize();
      expect(controller.fontSize, 20.0);
      controller.increaseFontSize();
      expect(controller.fontSize, 22.0);
      // Beyond max limit
      controller.increaseFontSize();
      expect(controller.fontSize, 22.0);

      // Decrease
      controller.decreaseFontSize();
      expect(controller.fontSize, 20.0);
      controller.decreaseFontSize();
      expect(controller.fontSize, 18.0);
      controller.decreaseFontSize();
      expect(controller.fontSize, 16.0);
      controller.decreaseFontSize();
      expect(controller.fontSize, 14.0);
      // Below min limit
      controller.decreaseFontSize();
      expect(controller.fontSize, 14.0);
    });

    test('Typeface toggle switches between Georgia serif and sans-serif', () async {
      final controller = ReaderSettingsController();
      await controller.init();

      expect(controller.isSerif, true);
      expect(controller.fontFamilyCss, 'Georgia, serif');

      controller.setIsSerif(false);
      expect(controller.isSerif, false);
      expect(controller.fontFamilyCss, 'system-ui, -apple-system, sans-serif');

      controller.setIsSerif(true);
      expect(controller.isSerif, true);
      expect(controller.fontFamilyCss, 'Georgia, serif');
    });

    test('HtmlSecurityScripts.buildUpdateStyleJs generates correct CSS variables', () async {
      final controller = ReaderSettingsController();
      await controller.init();

      final jsInk = HtmlSecurityScripts.buildUpdateStyleJs(
        themeConfig: controller.themeConfig,
        fontSize: controller.fontSize,
        isSerif: controller.isSerif,
      );

      expect(jsInk, contains("--reader-bg', '#1A1A2E'"));
      expect(jsInk, contains("--reader-text', '#F5F5FA'"));
      expect(jsInk, contains("--reader-font-family', 'Georgia, \"Times New Roman\", serif'"));
      expect(jsInk, contains("--reader-font-size', '16.0px'"));

      // Switch to Paper
      controller.setThemeMode(ReaderThemeMode.paper);
      controller.setFontSize(20.0);
      controller.setIsSerif(false);

      final jsPaper = HtmlSecurityScripts.buildUpdateStyleJs(
        themeConfig: controller.themeConfig,
        fontSize: controller.fontSize,
        isSerif: controller.isSerif,
      );

      expect(jsPaper, contains("--reader-bg', '#FAFAF7'"));
      expect(jsPaper, contains("--reader-text', '#1E1E28'"));
      expect(jsPaper, contains("--reader-font-family', '-apple-system"));
      expect(jsPaper, contains("--reader-font-size', '20.0px'"));
    });
  });

  group('NotifyReaderControlsBar Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ReaderSettingsController().resetForTesting();
    });

    testWidgets('Renders all controls and responds to taps', (tester) async {
      final controller = ReaderSettingsController();
      await controller.init();

      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotifyReaderControlsBar(
                settings: controller,
                onClose: () => closed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify presence of title and theme pills
      expect(find.text('READING DISPLAY'), findsOneWidget);
      expect(find.text('Ink'), findsOneWidget);
      expect(find.text('Paper'), findsOneWidget);
      expect(find.text('Sepia'), findsOneWidget);
      expect(find.text('16px'), findsOneWidget);
      expect(find.text('Serif'), findsOneWidget);
      expect(find.text('Sans'), findsOneWidget);

      // Tap Paper pill
      await tester.tap(find.text('Paper'));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ReaderThemeMode.paper);

      // Tap Sepia pill
      await tester.tap(find.text('Sepia'));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ReaderThemeMode.sepia);

      // Tap A+ button
      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();
      expect(controller.fontSize, 18.0);
      expect(find.text('18px'), findsOneWidget);

      // Tap Sans tab
      await tester.tap(find.text('Sans'));
      await tester.pumpAndSettle();
      expect(controller.isSerif, false);

      // Tap Serif tab
      await tester.tap(find.text('Serif'));
      await tester.pumpAndSettle();
      expect(controller.isSerif, true);

      // Tap Close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, true);
    });
  });
}
