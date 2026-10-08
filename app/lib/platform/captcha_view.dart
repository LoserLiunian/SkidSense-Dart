import 'package:webview_flutter/webview_flutter.dart';

import '../ui/material.dart';

/// The name the page reaches the app under: `SKIDSENSE_CAPTCHA.postMessage(value)`.
const captchaChannel = 'SKIDSENSE_CAPTCHA';

/// How every captcha page hands its result over: one function, one bridge.
const captchaSendJs = 'function skidsenseSend(value) { $captchaChannel.postMessage(value); }';

/// A captcha id or site key as it may appear inside the page. The server's
/// `/api/status` supplies them, and they go into a script string and an HTML
/// attribute; both providers issue plain tokens, so anything else is dropped
/// and the widget then fails visibly instead of running what the server sent.
String captchaToken(String value) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value) ? value : '';

/// GeeTest v4 in its `bind` form: no widget on the page, the challenge
/// opens at once over the whole view — which the app shows in a sheet when
/// the user signs in. On success the four fields of `getValidate()` come
/// back as JSON (the `geetest` query parameter of the login); closing gives
/// `close`, a failure `err:<code>`.
///
/// [language] is GeeTest's code: `zho`, `zho-tw`, `eng`.
String geeTestPage(String captchaId, {String language = 'eng'}) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://static.geetest.com/v4/gt4.js"></script>
<style>html,body{margin:0;height:100%;background:transparent;font-family:sans-serif}</style>
</head><body>
<script>
  $captchaSendJs
  initGeetest4({ captchaId: '${captchaToken(captchaId)}', product: 'bind', mask: { outside: true, bgColor: '#00000000' }, language: '${captchaToken(language)}' }, function (captcha) {
    captcha.onReady(function () { captcha.showCaptcha(); });
    captcha.onSuccess(function () { skidsenseSend(JSON.stringify(captcha.getValidate())); });
    captcha.onError(function (e) { skidsenseSend('err:' + ((e && e.code) || 'unknown')); });
    captcha.onClose(function () { skidsenseSend('close'); });
  });
</script></body></html>''';

/// Turnstile, the same bridge: the token comes back as a string, an error as
/// `err:<code>`, an expiry as ''.
String turnstilePage(String siteKey) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<style>html,body{margin:0;background:transparent;font-family:sans-serif}</style>
</head><body>
<div class="cf-turnstile" data-sitekey="${captchaToken(siteKey)}" data-callback="onToken"
  data-error-callback="onTurnstileError" data-expired-callback="onTurnstileExpired"></div>
<script>
  $captchaSendJs
  function onToken(token) { skidsenseSend(token); }
  function onTurnstileError(code) { skidsenseSend('err:' + code); }
  function onTurnstileExpired() { skidsenseSend(''); }
</script></body></html>''';

/// A WebView that loads [html] from memory and reports one string back.
///
/// JavaScript on (the SDKs need it) and nothing else: the page is loaded from
/// memory against [baseUrl] — GeeTest's CDN for its widget, the *login
/// server* for Turnstile, whose site-key allowlist checks the page's
/// hostname (S26) — and navigation away from it is refused, so a redirect
/// cannot take the bridge somewhere else.
class CaptchaView extends StatefulWidget {
  const CaptchaView({super.key, required this.html, required this.baseUrl, required this.onResult, this.height});

  final String html;
  final String baseUrl;
  final ValueChanged<String> onResult;
  /// Null fills the space given.
  final double? height;

  @override
  State<CaptchaView> createState() => _CaptchaViewState();
}

class _CaptchaViewState extends State<CaptchaView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0x00000000))
    ..addJavaScriptChannel(captchaChannel, onMessageReceived: (message) => widget.onResult(message.message))
    ..setNavigationDelegate(NavigationDelegate(
      // The in-memory page loads under its base URL; the SDK's own frames
      // are subresources, not navigations of the main frame.
      onNavigationRequest: (request) =>
          request.isMainFrame && !request.url.startsWith(widget.baseUrl) ? NavigationDecision.prevent : NavigationDecision.navigate,
    ))
    ..loadHtmlString(widget.html, baseUrl: widget.baseUrl);

  @override
  Widget build(BuildContext context) => SizedBox(height: widget.height, child: WebViewWidget(controller: _controller));
}

/// GeeTest's language for the app's: Traditional for Hant, Simplified for
/// other Chinese, English otherwise.
String geeTestLanguage(Locale locale) => switch (locale) {
      Locale(languageCode: 'zh', scriptCode: 'Hant') => 'zho-tw',
      Locale(languageCode: 'zh') => 'zho',
      _ => 'eng',
    };
