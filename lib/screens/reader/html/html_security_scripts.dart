import '../../../design_system/reader_theme.dart';
import '../../../models/reader_annotation_models.dart';

/// Injected JavaScript and CSS security rules to enforce view-only DRM protection
/// inside the mobile and desktop Chromium webviews while enabling in-reader
/// text highlighting (Amber, Emerald, Coral) and encrypted bookmarking.
class HtmlSecurityScripts {
  /// JavaScript injected at document creation to lock down clipboard, contextmenu, and hotkeys
  /// while enabling DRM-safe text selection for in-app highlighting.
  static const String injectedSecurityJs = '''
(function() {
  // 1. Strictly block context menu (right-click / long-press inspect)
  document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  }, true);

  // 2. Block dragging of text, images, and anchors
  document.addEventListener('dragstart', function(e) {
    e.preventDefault();
    return false;
  }, true);

  // 3. Block copy and cut actions — wipe clipboard data
  document.addEventListener('copy', function(e) {
    e.preventDefault();
    if (e.clipboardData) {
      e.clipboardData.setData('text/plain', '');
    }
    return false;
  }, true);

  document.addEventListener('cut', function(e) {
    e.preventDefault();
    return false;
  }, true);

  // 4. Block keyboard shortcuts for save, print, copy, inspect, view-source
  document.addEventListener('keydown', function(e) {
    var key = e.key ? e.key.toLowerCase() : '';
    if ((e.ctrlKey || e.metaKey) && (key === 'c' || key === 's' || key === 'p' || key === 'u' || key === 'a')) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
    if (key === 'printscreen' || key === 'f12') {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
  }, true);

  // 5. Inject CSS disabling OS callout while permitting in-app reading selection
  function injectSecurityCss() {
    var style = document.createElement('style');
    style.type = 'text/css';
    style.id = 'notify-anti-copy-style';
    style.innerHTML = `
      * {
        -webkit-touch-callout: none !important;
      }
      body, p, h1, h2, h3, h4, h5, h6, li, span, blockquote, td, th, em, strong, mark {
        -webkit-user-select: text !important;
        -moz-user-select: text !important;
        -ms-user-select: text !important;
        user-select: text !important;
      }
      img, a, button, nav, header {
        -webkit-user-select: none !important;
        user-select: none !important;
        -webkit-user-drag: none !important;
        user-drag: none !important;
        pointer-events: auto !important;
      }
      ::selection {
        background-color: rgba(245, 158, 11, 0.35);
        color: inherit;
      }
    `;
    if (document.head) {
      document.head.appendChild(style);
    } else {
      document.documentElement.appendChild(style);
    }
  }

  // 6. Monitor in-reader text selection for the floating highlight toolbar
  function notifySelectionChange() {
    var sel = window.getSelection();
    if (sel && sel.rangeCount > 0) {
      var text = sel.toString().trim();
      if (text.length > 0 && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onTextSelected', {
          'text': text,
        });
        return;
      }
    }
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('onSelectionCleared');
    }
  }

  document.addEventListener('mouseup', notifySelectionChange);
  document.addEventListener('touchend', notifySelectionChange);

  // 7. Report canvas taps to Flutter for toggling reader HUD controls (only when no selection)
  document.addEventListener('click', function(e) {
    var sel = window.getSelection();
    var hasSelection = sel && sel.toString().trim().length > 0;
    if (!hasSelection && window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler('onCanvasTap');
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectSecurityCss);
  } else {
    injectSecurityCss();
  }
})();
''';

  /// Generates a live JavaScript snippet to update CSS variables on the active webview document
  /// without re-fetching or re-decrypting the note content.
  static String buildUpdateStyleJs({
    required ReaderThemeConfig themeConfig,
    required double fontSize,
    required bool isSerif,
  }) {
    final fontFamily = isSerif
        ? 'Georgia, "Times New Roman", serif'
        : '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

    return '''
(function() {
  var r = document.documentElement;
  r.style.setProperty('--reader-bg', '${themeConfig.bgHex}');
  r.style.setProperty('--reader-text', '${themeConfig.textHex}');
  r.style.setProperty('--reader-text-muted', '${themeConfig.textMutedHex}');
  r.style.setProperty('--reader-card-bg', '${themeConfig.cardBgHex}');
  r.style.setProperty('--reader-border', '${themeConfig.borderHex}');
  r.style.setProperty('--reader-accent', '${themeConfig.accentHex}');
  r.style.setProperty('--reader-font-size', '${fontSize}px');
  r.style.setProperty('--reader-font-family', '$fontFamily');
  document.body.style.backgroundColor = '${themeConfig.bgHex}';
  document.body.style.color = '${themeConfig.textHex}';
})();
''';
  }

  /// Generates a JavaScript snippet to smoothly scroll to a specific section anchor or heading
  static String buildScrollToSectionJs(String anchorId) {
    final cleanId = anchorId.replaceAll("'", "\\'");
    final searchHeading = cleanId.replaceAll('-', ' ').replaceAll('_', ' ');
    return '''
(function() {
  var el = document.getElementById('$cleanId') ||
           document.querySelector('[name="$cleanId"]') ||
           document.querySelector('[data-anchor="$cleanId"]');
  if (!el) {
    var headings = document.querySelectorAll('h1, h2, h3, h4, h5, section');
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].textContent.toLowerCase().indexOf('$searchHeading') !== -1) {
        el = headings[i];
        break;
      }
    }
  }
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
})();
''';
  }

  /// Generates JavaScript to apply a persistent highlight to the current DOM selection
  static String buildApplyHighlightJs(ReaderHighlight highlight) {
    final cleanText = highlight.text.replaceAll("'", "\\'").replaceAll('\n', ' ');
    final cleanId = highlight.id.replaceAll("'", "\\'");
    final colorName = highlight.color.name;
    final rgba = highlight.color.rgba;
    final hex = highlight.color.hex;

    return '''
(function() {
  var sel = window.getSelection();
  var applied = false;
  if (sel && sel.rangeCount > 0) {
    var range = sel.getRangeAt(0);
    if (range && !range.collapsed) {
      var mark = document.createElement('mark');
      mark.id = 'notify-hl-$cleanId';
      mark.className = 'notify-hl notify-hl-$colorName';
      mark.setAttribute('data-hl-id', '$cleanId');
      mark.setAttribute('data-hl-color', '$colorName');
      mark.style.backgroundColor = '$rgba';
      mark.style.borderBottom = '2px solid $hex';
      mark.style.borderRadius = '3px';
      mark.style.padding = '1px 3px';
      mark.style.color = 'inherit';

      try {
        range.surroundContents(mark);
        applied = true;
      } catch (e) {
        var span = document.createElement('span');
        span.appendChild(range.extractContents());
        mark.appendChild(span);
        range.insertNode(mark);
        applied = true;
      }
      sel.removeAllRanges();
    }
  }

  if (!applied && '$cleanText'.length > 0) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var node;
    while (node = walker.nextNode()) {
      var idx = node.nodeValue.indexOf('$cleanText');
      if (idx !== -1 && !node.parentElement.classList.contains('notify-hl')) {
        var r = document.createRange();
        r.setStart(node, idx);
        r.setEnd(node, idx + '$cleanText'.length);
        var m = document.createElement('mark');
        m.id = 'notify-hl-$cleanId';
        m.className = 'notify-hl notify-hl-$colorName';
        m.setAttribute('data-hl-id', '$cleanId');
        m.style.backgroundColor = '$rgba';
        m.style.borderBottom = '2px solid $hex';
        m.style.borderRadius = '3px';
        m.style.padding = '1px 3px';
        m.style.color = 'inherit';
        try {
          r.surroundContents(m);
        } catch (_) {}
        break;
      }
    }
  }
})();
''';
  }

  /// Generates JavaScript to restore all saved highlights into the DOM
  static String buildRestoreHighlightsJs(List<ReaderHighlight> highlights) {
    if (highlights.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('(function() {');
    for (final hl in highlights) {
      final cleanText = hl.text.replaceAll("'", "\\'").replaceAll('\n', ' ');
      final cleanId = hl.id.replaceAll("'", "\\'");
      final colorName = hl.color.name;
      final rgba = hl.color.rgba;
      final hex = hl.color.hex;
      buffer.writeln('''
  if (!document.getElementById('notify-hl-$cleanId')) {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var node;
    while (node = walker.nextNode()) {
      var idx = node.nodeValue.indexOf('$cleanText');
      if (idx !== -1 && !node.parentElement.classList.contains('notify-hl')) {
        var r = document.createRange();
        r.setStart(node, idx);
        r.setEnd(node, idx + '$cleanText'.length);
        var m = document.createElement('mark');
        m.id = 'notify-hl-$cleanId';
        m.className = 'notify-hl notify-hl-$colorName';
        m.setAttribute('data-hl-id', '$cleanId');
        m.style.backgroundColor = '$rgba';
        m.style.borderBottom = '2px solid $hex';
        m.style.borderRadius = '3px';
        m.style.padding = '1px 3px';
        m.style.color = 'inherit';
        try {
          r.surroundContents(m);
        } catch (_) {}
        break;
      }
    }
  }
''');
    }
    buffer.writeln('})();');
    return buffer.toString();
  }

  /// Generates JavaScript to remove a highlight from the DOM
  static String buildRemoveHighlightJs(String highlightId) {
    final cleanId = highlightId.replaceAll("'", "\\'");
    return '''
(function() {
  var mark = document.getElementById('notify-hl-$cleanId');
  if (mark && mark.parentNode) {
    while (mark.firstChild) {
      mark.parentNode.insertBefore(mark.firstChild, mark);
    }
    mark.parentNode.removeChild(mark);
  }
})();
''';
  }

  /// Wraps decrypted raw HTML into a secure, self-contained document with responsive CSS variables
  /// matching the user's active theme and typography preferences.
  static String wrapSecureHtml(
    String rawHtml, {
    ReaderThemeConfig themeConfig = ReaderThemeConfig.ink,
    double fontSize = 16.0,
    bool isSerif = true,
  }) {
    final fontFamily = isSerif
        ? 'Georgia, "Times New Roman", serif'
        : '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    :root {
      --reader-bg: ${themeConfig.bgHex};
      --reader-text: ${themeConfig.textHex};
      --reader-text-muted: ${themeConfig.textMutedHex};
      --reader-card-bg: ${themeConfig.cardBgHex};
      --reader-border: ${themeConfig.borderHex};
      --reader-accent: ${themeConfig.accentHex};
      --reader-font-size: ${fontSize}px;
      --reader-font-family: $fontFamily;
      --reader-line-height: 1.65;
    }
    * {
      -webkit-touch-callout: none !important;
    }
    body, p, h1, h2, h3, h4, h5, h6, li, span, blockquote, td, th, em, strong, mark {
      -webkit-user-select: text !important;
      -moz-user-select: text !important;
      -ms-user-select: text !important;
      user-select: text !important;
    }
    img, a, button, nav, header {
      -webkit-user-select: none !important;
      user-select: none !important;
      -webkit-user-drag: none !important;
      user-drag: none !important;
    }
    html {
      background-color: var(--reader-bg);
    }
    body {
      margin: 0 auto;
      padding: 24px 20px 80px 20px;
      max-width: 820px;
      background-color: var(--reader-bg) !important;
      color: var(--reader-text) !important;
      font-family: var(--reader-font-family);
      font-size: var(--reader-font-size);
      line-height: var(--reader-line-height);
      word-wrap: break-word;
      box-sizing: border-box;
      transition: background-color 0.2s ease, color 0.2s ease;
    }
    h1, h2, h3, h4, h5, h6 {
      color: var(--reader-text) !important;
      font-family: var(--reader-font-family);
      line-height: 1.35;
      margin-top: 1.4em;
      margin-bottom: 0.6em;
    }
    p {
      margin: 0.8em 0;
      color: inherit;
    }
    blockquote {
      border-left: 3.5px solid var(--reader-accent) !important;
      margin: 16px 0;
      padding: 12px 16px;
      background-color: var(--reader-card-bg);
      border-radius: 6px;
      color: var(--reader-text);
    }
    img {
      max-width: 100%;
      height: auto;
      pointer-events: none;
      -webkit-user-drag: none;
    }
    hr {
      border: 0;
      border-top: 1px solid var(--reader-border);
      margin: 20px 0;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 16px 0;
    }
    th, td {
      border: 1px solid var(--reader-border);
      padding: 8px 12px;
    }
    th {
      background-color: var(--reader-card-bg);
    }
  </style>
  <script>
    $injectedSecurityJs
  </script>
</head>
<body oncontextmenu="return false;" ondragstart="return false;">
  $rawHtml
</body>
</html>
''';
  }
}

