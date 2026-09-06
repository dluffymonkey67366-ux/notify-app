import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'html_security_scripts.dart';

/// Mobile HTML Note Reader using flutter_inappwebview.
/// Enforces disabled context menu, disabled selection/copy/drag,
/// blocked downloads, and blocked external navigation.
class MobileHtmlPlayer extends StatefulWidget {
  final String htmlContent;
  final VoidCallback? onContentLoaded;

  const MobileHtmlPlayer({
    super.key,
    required this.htmlContent,
    this.onContentLoaded,
  });

  @override
  State<MobileHtmlPlayer> createState() => _MobileHtmlPlayerState();
}

class _MobileHtmlPlayerState extends State<MobileHtmlPlayer> {
  InAppWebViewController? _webViewController;

  @override
  void didUpdateWidget(MobileHtmlPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      final secureHtml = HtmlSecurityScripts.wrapSecureHtml(widget.htmlContent);
      _webViewController?.loadData(
        data: secureHtml,
        mimeType: 'text/html',
        encoding: 'utf-8',
        baseUrl: WebUri('about:blank'),
      );
    }
  }

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
        horizontalScrollBarEnabled: false,
        allowsInlineMediaPlayback: false,
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
        // Reinforce security script after DOM load
        await controller.evaluateJavascript(
          source: HtmlSecurityScripts.injectedSecurityJs,
        );
        widget.onContentLoaded?.call();
      },
      // Block all downloads
      onDownloadStartRequest: (controller, downloadStartRequest) {
        debugPrint('Notify Security: Blocked download attempt: ${downloadStartRequest.url}');
      },
      // Block all external navigation
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null || uri.toString() == 'about:blank' || uri.scheme == 'data') {
          return NavigationActionPolicy.ALLOW;
        }
        debugPrint('Notify Security: Blocked external navigation: $uri');
        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}
