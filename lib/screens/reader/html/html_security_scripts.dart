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

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectSecurityCss);
  } else {
    injectSecurityCss();
  }
})();
''';

  /// Wraps decrypted raw HTML into a secure, self-contained document with security styles
  static String wrapSecureHtml(String rawHtml) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * {
      -webkit-user-select: none !important;
      -moz-user-select: none !important;
      -ms-user-select: none !important;
      user-select: none !important;
      -webkit-touch-callout: none !important;
    }
    body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #0d1117;
      color: #e6edf3;
      line-height: 1.6;
      word-wrap: break-word;
    }
    img {
      max-width: 100%;
      height: auto;
      pointer-events: none;
      -webkit-user-drag: none;
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
