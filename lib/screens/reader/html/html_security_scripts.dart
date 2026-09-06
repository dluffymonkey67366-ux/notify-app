import '../../../design_system/reader_theme.dart';

/// Injected JavaScript and CSS security rules to enforce view-only DRM protection
/// inside the mobile and desktop Chromium webviews.
class HtmlSecurityScripts {
  /// JavaScript injected at document creation to lock down clipboard, selection, contextmenu, and hotkeys.
  static const String injectedSecurityJs = '''
(function() {
  // 1. Disable context menu
  document.addEventListener('contextmenu', function(e) {
    e.preventDefault();
    e.stopPropagation();
    return false;
  }, true);

  // 2. Disable text selection and dragging
  document.addEventListener('selectstart', function(e) {
    e.preventDefault();
    return false;
  }, true);

  document.addEventListener('dragstart', function(e) {
    e.preventDefault();
    return false;
  }, true);

  // 3. Block copy and cut actions
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

  // 5. Inject CSS disabling user-select across all elements
  function injectSecurityCss() {
    var style = document.createElement('style');
    style.type = 'text/css';
    style.id = 'notify-anti-copy-style';
    style.innerHTML = `
      * {
        -webkit-user-select: none !important;
        -moz-user-select: none !important;
        -ms-user-select: none !important;
        user-select: none !important;
        -webkit-touch-callout: none !important;
      }
      img, a {
        -webkit-user-drag: none !important;
        user-drag: none !important;
        pointer-events: auto !important;
      }
    `;
    if (document.head) {
      document.head.appendChild(style);
    } else {
      document.documentElement.appendChild(style);
    }
  }

  // 6. Report canvas taps to Flutter for toggling reader HUD controls
  document.addEventListener('click', function(e) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
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
      -webkit-user-select: none !important;
      -moz-user-select: none !important;
      -ms-user-select: none !important;
      user-select: none !important;
      -webkit-touch-callout: none !important;
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
<body oncontextmenu="return false;" onselectstart="return false;" ondragstart="return false;">
  $rawHtml
</body>
</html>
''';
  }
}

