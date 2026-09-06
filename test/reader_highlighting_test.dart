import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notify_app/design_system/design_system.dart';
import 'package:notify_app/screens/reader/html/html_security_scripts.dart';
import 'package:notify_app/services/encrypted_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rank 7: Reader Annotation Models Serialization Tests', () {
    test('HighlightColor enum provides correct hex, rgba, and Flutter Color', () {
      expect(HighlightColor.amber.hex, '#F59E0B');
      expect(HighlightColor.emerald.hex, '#10B981');
      expect(HighlightColor.coral.hex, '#F43F5E');

      expect(HighlightColor.amber.rgba, contains('rgba(245, 158, 11'));
      expect(HighlightColor.emerald.rgba, contains('rgba(16, 185, 129'));
      expect(HighlightColor.coral.rgba, contains('rgba(244, 63, 94'));

      expect(HighlightColor.amber.color, const Color(0xFFF59E0B));
      expect(HighlightColor.emerald.color, const Color(0xFF10B981));
      expect(HighlightColor.coral.color, const Color(0xFFF43F5E));
    });

    test('ReaderHighlight serializes to Map/JSON and deserializes accurately', () {
      final now = DateTime(2026, 9, 6, 12, 0, 0);
      final highlight = ReaderHighlight(
        id: 'hl_001',
        partId: 'part_tax_01',
        text: 'Section 44AB tax audit requirement threshold',
        color: HighlightColor.emerald,
        startOffset: 120,
        endOffset: 165,
        anchorNodeId: 'sec_44ab_heading',
        createdAt: now,
      );

      final jsonStr = highlight.toJson();
      final restored = ReaderHighlight.fromJson(jsonStr);

      expect(restored.id, 'hl_001');
      expect(restored.partId, 'part_tax_01');
      expect(restored.text, 'Section 44AB tax audit requirement threshold');
      expect(restored.color, HighlightColor.emerald);
      expect(restored.startOffset, 120);
      expect(restored.endOffset, 165);
      expect(restored.anchorNodeId, 'sec_44ab_heading');
      expect(restored.createdAt, now);
    });

    test('ReaderBookmark serializes and deserializes accurately', () {
      final now = DateTime(2026, 9, 6, 12, 0, 0);
      final bookmark = ReaderBookmark(
        id: 'bm_001',
        partId: 'part_tax_01',
        title: 'Capital Gains Deductions',
        sectionId: 'sec_54f',
        scrollOffset: 450,
        createdAt: now,
      );

      final jsonStr = bookmark.toJson();
      final restored = ReaderBookmark.fromJson(jsonStr);

      expect(restored.id, 'bm_001');
      expect(restored.partId, 'part_tax_01');
      expect(restored.title, 'Capital Gains Deductions');
      expect(restored.sectionId, 'sec_54f');
      expect(restored.scrollOffset, 450);
      expect(restored.createdAt, now);
    });

    test('NoteAnnotationsBundle serializes and copies correctly', () {
      final bundle = NoteAnnotationsBundle(
        partId: 'part_law_01',
        highlights: [
          ReaderHighlight(
            id: 'hl_1',
            partId: 'part_law_01',
            text: 'Doctrine of Ultra Vires',
            color: HighlightColor.coral,
          ),
        ],
        bookmarks: [
          ReaderBookmark(
            id: 'bm_1',
            partId: 'part_law_01',
            title: 'Memorandum of Association',
            sectionId: 'sec_moa',
          ),
        ],
      );

      final jsonStr = bundle.toJson();
      final restored = NoteAnnotationsBundle.fromJson(jsonStr);

      expect(restored.partId, 'part_law_01');
      expect(restored.highlights.length, 1);
      expect(restored.highlights.first.color, HighlightColor.coral);
      expect(restored.bookmarks.length, 1);
      expect(restored.bookmarks.first.sectionId, 'sec_moa');

      // Test copyWith
      final updated = restored.copyWith(
        highlights: [
          ...restored.highlights,
          ReaderHighlight(
            id: 'hl_2',
            partId: 'part_law_01',
            text: 'Indoor Management Rule',
            color: HighlightColor.amber,
          ),
        ],
      );
      expect(updated.highlights.length, 2);
      expect(updated.bookmarks.length, 1);
    });
  });

  group('Rank 7: EncryptedCacheService Annotation Storage Tests', () {
    late Directory tempDir;
    late EncryptedCacheService cacheService;
    final fixedKey = Uint8List.fromList(List.generate(32, (i) => (i * 7) % 256));

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('notify_annot_test_');
      cacheService = EncryptedCacheService();
      cacheService.setCustomCacheDir(tempDir.path);
      cacheService.setCustomKey(fixedKey);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Annotations are saved on disk strictly encrypted via AES-256 and decrypt cleanly', () async {
      const partId = 'ca_inter_dt_ch3';
      final bundle = NoteAnnotationsBundle(
        partId: partId,
        highlights: [
          ReaderHighlight(
            id: 'hl_01',
            partId: partId,
            text: 'Exemption under Section 10(14) for special allowances',
            color: HighlightColor.amber,
          ),
          ReaderHighlight(
            id: 'hl_02',
            partId: partId,
            text: 'Standard deduction limit under Section 16(ia)',
            color: HighlightColor.emerald,
          ),
        ],
        bookmarks: [
          ReaderBookmark(
            id: 'bm_01',
            partId: partId,
            title: 'Salaries Computation',
            sectionId: 'sec_salary_computation',
          ),
        ],
      );

      // Save encrypted annotations
      final file = await cacheService.saveEncryptedAnnotations(partId, bundle);
      expect(await file.exists(), true);

      // Verify disk content is ciphertext (cannot be parsed directly as plaintext JSON)
      final diskBytes = await file.readAsBytes();
      expect(diskBytes.length, greaterThan(32)); // IV + ciphertext blocks
      final rawDiskString = String.fromCharCodes(diskBytes);
      expect(rawDiskString.contains('Exemption under Section 10(14)'), false);
      expect(rawDiskString.contains('part_id'), false);

      // Decrypt and verify full integrity
      final decrypted = await cacheService.readDecryptedAnnotations(partId);
      expect(decrypted, isNotNull);
      expect(decrypted!.partId, partId);
      expect(decrypted.highlights.length, 2);
      expect(decrypted.highlights[0].text, 'Exemption under Section 10(14) for special allowances');
      expect(decrypted.highlights[0].color, HighlightColor.amber);
      expect(decrypted.highlights[1].text, 'Standard deduction limit under Section 16(ia)');
      expect(decrypted.highlights[1].color, HighlightColor.emerald);
      expect(decrypted.bookmarks.length, 1);
      expect(decrypted.bookmarks[0].sectionId, 'sec_salary_computation');
    });

    test('readDecryptedAnnotations returns null for non-existent part', () async {
      final result = await cacheService.readDecryptedAnnotations('non_existent_part');
      expect(result, isNull);
    });

    test('removeCachedContent cleans up both content and annotation encrypted files', () async {
      const partId = 'ca_part_cleanup_test';
      await cacheService.saveEncryptedContent(partId, '<h1>Test</h1>');
      await cacheService.saveEncryptedAnnotations(
        partId,
        const NoteAnnotationsBundle(partId: partId),
      );

      expect(await cacheService.hasCachedContent(partId), true);
      await cacheService.removeCachedContent(partId);
      expect(await cacheService.hasCachedContent(partId), false);
      expect(await cacheService.readDecryptedAnnotations(partId), isNull);
    });
  });

  group('Rank 7: HtmlSecurityScripts Highlighting JS Generation Tests', () {
    test('buildApplyHighlightJs generates proper DOM manipulation script', () {
      final highlight = ReaderHighlight(
        id: 'hl_test_123',
        partId: 'part_test',
        text: 'Tax deductible expenses',
        color: HighlightColor.emerald,
      );

      final js = HtmlSecurityScripts.buildApplyHighlightJs(highlight);
      expect(js, contains('notify-hl-hl_test_123'));
      expect(js, contains('notify-hl-emerald'));
      expect(js, contains(HighlightColor.emerald.rgba));
      expect(js, contains(HighlightColor.emerald.hex));
      expect(js, contains('Tax deductible expenses'));
      expect(js, contains('window.getSelection'));
      expect(js, contains('document.createTreeWalker'));
    });

    test('buildRestoreHighlightsJs handles multiple highlights', () {
      final highlights = [
        ReaderHighlight(
          id: 'hl_1',
          partId: 'p1',
          text: 'First highlight',
          color: HighlightColor.amber,
        ),
        ReaderHighlight(
          id: 'hl_2',
          partId: 'p1',
          text: 'Second highlight',
          color: HighlightColor.coral,
        ),
      ];

      final js = HtmlSecurityScripts.buildRestoreHighlightsJs(highlights);
      expect(js, contains('notify-hl-hl_1'));
      expect(js, contains('notify-hl-amber'));
      expect(js, contains('notify-hl-hl_2'));
      expect(js, contains('notify-hl-coral'));
    });

    test('buildRemoveHighlightJs un-wraps highlighted mark elements', () {
      final js = HtmlSecurityScripts.buildRemoveHighlightJs('hl_test_99');
      expect(js, contains('notify-hl-hl_test_99'));
      expect(js, contains('mark.parentNode.insertBefore'));
      expect(js, contains('mark.parentNode.removeChild'));
    });
  });

  group('Rank 7: NotifyHighlightToolbar Widget Tests', () {
    testWidgets('Renders all 3 highlight color options and triggers callbacks', (tester) async {
      HighlightColor? selectedColor;
      bool bookmarkTapped = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotifyHighlightToolbar(
                themeConfig: ReaderThemeConfig.ink,
                isBookmarked: false,
                onColorSelected: (color) => selectedColor = color,
                onBookmark: () => bookmarkTapped = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      // Verify 3 circular color buttons exist (Amber, Emerald, Coral)
      final colorCircles = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(colorCircles, findsNWidgets(3));

      // Tap Emerald color (2nd circle)
      await tester.tap(colorCircles.at(1));
      await tester.pump();
      expect(selectedColor, HighlightColor.emerald);

      // Tap Amber color (1st circle)
      await tester.tap(colorCircles.at(0));
      await tester.pump();
      expect(selectedColor, HighlightColor.amber);

      // Tap Coral color (3rd circle)
      await tester.tap(colorCircles.at(2));
      await tester.pump();
      expect(selectedColor, HighlightColor.coral);

      // Verify Bookmark and Dismiss icon buttons exist
      expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap Bookmark
      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pump();
      expect(bookmarkTapped, true);

      // Tap Dismiss
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(dismissed, true);
    });

    testWidgets('Renders active bookmark state when isBookmarked is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotifyHighlightToolbar(
                themeConfig: ReaderThemeConfig.sepia,
                isBookmarked: true,
                onColorSelected: (_) {},
                onBookmark: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_add_outlined), findsNothing);
    });
  });
}
