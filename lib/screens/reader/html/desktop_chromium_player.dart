import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'html_security_scripts.dart';

/// Embedded Chromium view for Desktop (Windows, macOS, Linux).
/// Enforces disabled context menu, disabled selection/copy/drag,
/// blocked downloads, and blocked external navigation.
class DesktopChromiumPlayer extends StatefulWidget {
  final String htmlContent;
  final VoidCallback? onContentLoaded;

  const DesktopChromiumPlayer({
    super.key,
    required this.htmlContent,
    this.onContentLoaded,
  });

  @override
  State<DesktopChromiumPlayer> createState() => _DesktopChromiumPlayerState();
}

class _DesktopChromiumPlayerState extends State<DesktopChromiumPlayer> {
  InAppWebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    final secureHtml = HtmlSecurityScripts.wrapSecureHtml(widget.htmlContent);

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: secureHtml,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      ),
      initialSettings: InAppWebViewSettings(
        disableContextMenu: true,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        useOnDownloadStart: true,
        javaScriptEnabled: true,
        supportZoom: true,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
        transparentBackground: false,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: HtmlSecurityScripts.injectedSecurityJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: HtmlSecurityScripts.injectedSecurityJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStop: (controller, url) async {
        // Enforce security injection after initial DOM load
        await controller.evaluateJavascript(
          source: HtmlSecurityScripts.injectedSecurityJs,
        );
        widget.onContentLoaded?.call();
      },
      // Block all download attempts
      onDownloadStartRequest: (controller, downloadStartRequest) {
        debugPrint('Notify Desktop Chromium: Download blocked: ${downloadStartRequest.url}');
      },
      // Block external links and navigation away from note
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null || uri.toString() == 'about:blank' || uri.scheme == 'data') {
          return NavigationActionPolicy.ALLOW;
        }
        debugPrint('Notify Desktop Chromium: Blocked external navigation to $uri');
        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}
