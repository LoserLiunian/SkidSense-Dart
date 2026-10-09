import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The classes a webview_flutter platform extends; webview_flutter itself
// exports only WebViewPlatform.
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

/// webview_flutter's platform for tests. Every page is kept, so a test can
/// answer as its script would ([FakePage.post]); the view is built as on
/// Android — a platform view under the widget's gesture recognizers — and
/// the pointer events that reach the native view are recorded in [touches].
class FakeWebViews extends WebViewPlatform {
  final List<FakePage> pages = [];

  /// The Android `MotionEvent` actions delivered to the native view, in order
  /// (0 down, 1 up, 2 move, 3 cancel).
  final List<int> touches = [];

  /// Makes this the platform, and answers the platform-view channel.
  void install(WidgetTester tester) {
    WebViewPlatform.instance = this;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      switch (call.method) {
        case 'create':
          return 1;
        case 'resize':
          final size = call.arguments as Map<Object?, Object?>;
          return <String, Object?>{'width': size['width'], 'height': size['height']};
        case 'touch':
          touches.add((call.arguments as List<Object?>)[3]! as int);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
  }

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    final page = FakePage(params);
    pages.add(page);
    return page;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _Navigation(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) => _View(params);
}

/// One WebView: the HTML it was given and the channels its script can post on.
class FakePage extends PlatformWebViewController {
  FakePage(super.params) : super.implementation();

  String? html;
  final Map<String, JavaScriptChannelParams> _channels = {};

  /// What the page's script posts on [channel].
  void post(String channel, String message) => _channels[channel]!.onMessageReceived(JavaScriptMessage(message: message));

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async =>
      _channels[javaScriptChannelParams.name] = javaScriptChannelParams;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async => this.html = html;
}

class _Navigation extends PlatformNavigationDelegate {
  _Navigation(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {}
}

/// As webview_flutter_android builds it: a texture-layer platform view whose
/// touches go through the framework's gesture arena.
class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => PlatformViewLink(
        viewType: 'plugins.flutter.io/webview',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: params.gestureRecognizers,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (view) {
          final controller = PlatformViewsService.initSurfaceAndroidView(
            id: view.id,
            viewType: 'plugins.flutter.io/webview',
            layoutDirection: params.layoutDirection,
          )..addOnPlatformViewCreatedListener(view.onPlatformViewCreated);
          unawaited(controller.create());
          return controller;
        },
      );
}
