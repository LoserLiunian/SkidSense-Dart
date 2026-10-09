import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/platform/captcha_view.dart';
import 'package:skidsense_app/ui/kit/actions.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/login_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';

import 'support/fake_webview.dart';
import 'support/harness.dart';

void main() {
  testWidgets('a cleartext public server is refused, with the reason', (tester) async {
    phoneSurface(tester);
    final services = TestServices();
    await tester.runAsync(services.controller.start);
    await tester.pumpWidget(harness(services, const LoginScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'http://ai.surise.cn');
    // The server is asked once typing pauses.
    await settle(tester, rounds: 20);
    expect(find.textContaining('is plain http://'), findsOneWidget);

    // A development server on the local network is fine.
    await tester.enterText(find.byType(TextField).first, 'http://192.168.1.20:3000');
    await settle(tester, rounds: 20);
    expect(find.textContaining('is plain http://'), findsNothing);
  });

  group('where the server asks for a captcha', () {
    late FakeWebViews webViews;
    late _CaptchaServer server;

    Future<void> open(
      WidgetTester tester, {
      bool turnstile = false,
      int failedProbes = 0,
      Completer<void>? holdFirstProbe,
      List<Map<String, Object?>>? methods,
      Size size = const Size(412, 915),
      DesignStyle style = DesignStyle.expressive,
      Brightness brightness = Brightness.light,
      Locale locale = const Locale('en'),
      double textScale = 1,
    }) async {
      phoneSurface(tester, size: size);
      webViews = FakeWebViews()..install(tester);
      server = _CaptchaServer(turnstile: turnstile, failedProbes: failedProbes, methods: methods)
        ..holdFirstProbe = holdFirstProbe;
      final services = _Services(server);
      await tester.runAsync(services.controller.start);
      await tester.pumpWidget(harness(
        services,
        const LoginScreen(),
        style: style,
        brightness: brightness,
        locale: locale,
        textScale: textScale,
      ));
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(1), 'liunian');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await settle(tester);
    }

    Finder button(String label) => find.widgetWithText(AppButton, label);

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(button(label));
      await tester.tap(button(label));
      await settle(tester);
    }

    /// The latest captcha page answers as its script would.
    Future<void> answer(WidgetTester tester, String message) async {
      webViews.pages.last.post(captchaChannel, message);
      await settle(tester);
    }

    testWidgets('the GeeTest slider follows the finger: the WebView gets every move as it happens', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      await answer(tester, 'ready');
      final view = find.byType(AndroidViewSurface);
      expect(view, findsOneWidget);
      final top = tester.getTopLeft(view).dy;

      // A human slide: rightwards, drifting down a little (25dp in all,
      // more than the sheet's drag slop).
      final gesture = await tester.startGesture(tester.getCenter(view) - const Offset(100, 0));
      await tester.pump(const Duration(milliseconds: 30));
      expect(webViews.touches, [0], reason: 'the press reaches the page at once');
      for (var i = 1; i <= 10; i++) {
        await gesture.moveBy(const Offset(20, 2.5));
        await tester.pump(const Duration(milliseconds: 30));
        expect(webViews.touches.length, 1 + i, reason: 'move $i reaches the page as it happens');
      }
      expect(tester.getTopLeft(view).dy, top, reason: 'the sheet does not move under the slide');
      await gesture.up();
      await settle(tester);
      expect(webViews.touches.last, 1);
      expect(view, findsOneWidget, reason: 'the sheet is still open');
    });

    testWidgets('after a failed probe, signing in asks the server again and opens the captcha', (tester) async {
      await open(tester, failedProbes: 1);
      expect(find.textContaining("Can't reach the server"), findsOneWidget);

      await tap(tester, 'Sign in');
      expect(server.probes, 2);
      expect(find.textContaining("Can't reach the server"), findsNothing);
      expect(webViews.pages, hasLength(1), reason: 'the GeeTest sheet is open');
      expect(server.logins, isEmpty, reason: 'no login went out without the captcha');
    });

    testWidgets('a probe still out when signing in does not decide, nor overwrite the answer', (tester) async {
      final first = Completer<void>();
      await open(tester, holdFirstProbe: first);
      expect(server.probes, 1);

      await tap(tester, 'Sign in');
      expect(server.probes, 2);
      expect(webViews.pages, hasLength(1), reason: 'the GeeTest sheet is open');

      // The first answer comes back late, and failed: it is not shown.
      first.complete();
      await settle(tester);
      expect(find.textContaining("Can't reach the server"), findsNothing);
    });

    testWidgets('back from the second step, signing in solves a new GeeTest', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      await answer(tester, 'ready');
      await answer(tester, '{"lot_number":"one"}');
      expect(server.logins, ['{"lot_number":"one"}']);
      expect(find.text('Two-step verification'), findsOneWidget);

      await tap(tester, 'Back');
      await tap(tester, 'Sign in');
      expect(webViews.pages, hasLength(2), reason: 'a new GeeTest sheet, not the spent token');
      await answer(tester, 'ready');
      await answer(tester, '{"lot_number":"two"}');
      expect(server.logins, ['{"lot_number":"one"}', '{"lot_number":"two"}']);
    });

    testWidgets('Turnstile gets its touches inside the scrolling form, and a spent token is not kept', (tester) async {
      // Short enough that the form scrolls.
      await open(tester, turnstile: true, size: const Size(360, 640));
      final view = find.byType(AndroidViewSurface);
      await tester.ensureVisible(view);
      await settle(tester);
      final gesture = await tester.startGesture(tester.getCenter(view));
      await tester.pump(const Duration(milliseconds: 30));
      expect(webViews.touches, [0], reason: 'the press reaches the widget at once');
      await gesture.up();
      await settle(tester);

      await answer(tester, 'token-one');
      expect(find.text('Verified'), findsOneWidget);
      await tap(tester, 'Sign in');
      expect(server.turnstiles, ['token-one']);

      await tap(tester, 'Back');
      expect(find.text('Verified'), findsNothing);
      expect(webViews.pages, hasLength(2), reason: 'a new widget to solve');
      expect(tester.widget<AppButton>(button('Sign in')).onPressed, isNull);
    });

    testWidgets('an account whose second step is a passkey alone is told so, not asked for a code', (tester) async {
      await open(tester, methods: [
        {'method': 'passkey', 'available': true},
      ]);
      await tap(tester, 'Sign in');
      await answer(tester, 'ready');
      await answer(tester, '{"lot_number":"one"}');

      expect(find.textContaining("second step is a passkey, which the app can't use yet"), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(button('Verify'), findsNothing);
      await tap(tester, 'Back');
      expect(button('Sign in'), findsOneWidget);
    });

    testWidgets('GeeTest that cannot load says so in the sheet, and loads again on retry', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      expect(find.bySemanticsLabel('Loading the human check…'), findsOneWidget);

      await answer(tester, 'err:load');
      expect(find.text("The human check didn't load"), findsOneWidget);
      expect(find.byType(AndroidViewSurface), findsNothing);

      await tap(tester, 'Retry');
      expect(webViews.pages, hasLength(2), reason: 'the page is loaded anew');
      expect(find.byType(BusyIndicator), findsOneWidget);

      // The SDK arrived, and the challenge's own scripts could not be had.
      await answer(tester, 'err:60204');
      expect(find.text("The human check didn't load"), findsOneWidget);
      expect(server.logins, isEmpty);

      await tap(tester, 'Retry');
      expect(webViews.pages, hasLength(3));
      await answer(tester, 'ready');
      expect(find.byType(BusyIndicator), findsNothing);
      await answer(tester, '{"lot_number":"one"}');
      expect(server.logins, ['{"lot_number":"one"}']);
    });

    /// The challenge's stylesheet or language pack, before it comes up, or
    /// its pictures, after (it then shows only "network failure"): GeeTest's
    /// CDN out of reach, as for its script — not the user failing the check,
    /// which closed the sheet to "Verification failed (60201)".
    for (final (code, what, afterReady) in [
      ('60200', 'stylesheet', false),
      ('60201', 'language pack', false),
      ('60202', 'pictures', true),
    ]) {
      testWidgets('GeeTest without its $what ($code) says it did not load, and loads again on retry', (tester) async {
        await open(tester);
        await tap(tester, 'Sign in');
        if (afterReady) await answer(tester, 'ready');
        await answer(tester, 'err:$code');
        expect(find.text("The human check didn't load"), findsOneWidget);
        expect(find.textContaining(code), findsNothing);
        expect(server.logins, isEmpty);

        await tap(tester, 'Retry');
        expect(webViews.pages, hasLength(2), reason: 'the page is loaded anew');
        await answer(tester, 'ready');
        await answer(tester, '{"lot_number":"one"}');
        expect(server.logins, ['{"lot_number":"one"}']);
      });
    }

    /// GeeTest's device script (gct) refused, as a filter by path or a CDN
    /// missing that one file does: the SDK reports 60205, and the challenge
    /// comes up and is solved without it — as the real one was, in Chrome.
    /// Taken for a load failure, it made signing in impossible.
    testWidgets('GeeTest without its device script (60205) is still solved', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      await answer(tester, 'err:60205');
      expect(find.text("The human check didn't load"), findsNothing);
      expect(find.byType(CaptchaView), findsOneWidget);
      await answer(tester, 'ready');
      expect(find.byType(BusyIndicator), findsNothing);
      await answer(tester, '{"lot_number":"one"}');
      expect(server.logins, ['{"lot_number":"one"}']);
    });

    /// A device script that hangs reports 60205 only after 20 s, the
    /// challenge long up and maybe half solved.
    testWidgets('a late 60205 leaves the challenge on screen, and its answer counts', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      await answer(tester, 'ready');
      await answer(tester, 'err:60205');
      expect(find.text("The human check didn't load"), findsNothing);
      expect(find.textContaining('60205'), findsNothing);
      expect(webViews.pages, hasLength(1), reason: 'the same page');
      await answer(tester, '{"lot_number":"one"}');
      expect(server.logins, ['{"lot_number":"one"}']);
    });

    testWidgets('a GeeTest page given up on is not heard: its late answers are not the new one’s', (tester) async {
      await open(tester);
      await tap(tester, 'Sign in');
      await answer(tester, 'err:timeout');
      await tap(tester, 'Retry');
      expect(webViews.pages, hasLength(2));

      // The first page's SDK arrives after all, and later fails.
      webViews.pages.first.post(captchaChannel, 'ready');
      await settle(tester);
      expect(find.byType(BusyIndicator), findsOneWidget, reason: 'the new page is not up yet');
      webViews.pages.first.post(captchaChannel, 'err:-50005');
      await settle(tester);
      expect(find.byType(CaptchaView), findsOneWidget, reason: 'the sheet is still open');
      expect(find.textContaining('-50005'), findsNothing);

      await answer(tester, 'ready');
      expect(find.byType(BusyIndicator), findsNothing);
      await answer(tester, '{"lot_number":"one"}');
      expect(server.logins, ['{"lot_number":"one"}']);
    });

    testWidgets('an address without a scheme, or in capitals, is probed as https and needs the captcha', (tester) async {
      await open(tester);
      final address = find.byType(TextField).first;

      await tester.enterText(address, 'surise.example');
      await settle(tester, rounds: 20);
      expect(find.text('Will use https://surise.example'), findsOneWidget);
      expect(server.probed.last, 'https://surise.example/api/status');

      // The address shown is the one the client keeps: host in lower case,
      // no trailing slash (normalizeBackendBase, as the session's baseUrl).
      await tester.enterText(address, 'HTTPS://AI.Surise.CN/');
      await settle(tester, rounds: 20);
      expect(find.text('Will use https://ai.surise.cn'), findsOneWidget);
      expect(server.probed, hasLength(3));
      expect(server.probed.last, 'https://ai.surise.cn/api/status');
      await tap(tester, 'Sign in');
      expect(webViews.pages, hasLength(1), reason: 'the GeeTest sheet is open');

      Navigator.of(tester.element(find.byType(CaptchaView))).pop();
      await settle(tester);
      await tester.enterText(address, 'https://');
      await settle(tester, rounds: 20);
      expect(find.text("Enter the server's address, such as https://example.com"), findsOneWidget);
      expect(tester.widget<AppButton>(button('Sign in')).onPressed, isNull);
    });

    /// Through every new state: the address hint and error, the sheet loading
    /// and failed, the passkey explanation. [check] runs at each.
    Future<void> walk(WidgetTester tester, L10n l, Future<void> Function() check) async {
      final address = find.byType(TextField).first;
      await tester.enterText(address, 'surise.example');
      await settle(tester, rounds: 20);
      await check();
      await tester.enterText(address, 'https://');
      await settle(tester, rounds: 20);
      await check();
      await tester.enterText(address, 'https://ai.surise.cn');
      await settle(tester, rounds: 20);
      await tap(tester, l.signIn);
      await check();
      await answer(tester, 'err:timeout');
      await check();
      await tap(tester, l.retry);
      await answer(tester, 'ready');
      await answer(tester, '{"lot_number":"one"}');
      expect(find.text(l.twoFactorPasskeyOnly), findsOneWidget);
      await check();
    }

    const passkeyOnly = [
      {'method': 'passkey', 'available': true},
    ];

    // As large_text_test.dart: the largest text, a small phone, nothing may
    // overflow (an overflow fails the test).
    for (final style in DesignStyle.values) {
      for (final locale in const [Locale('en'), Locale('zh'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')]) {
        testWidgets('the new states hold at the largest text: ${style.name} ${locale.toLanguageTag()}', (tester) async {
          await open(tester, methods: passkeyOnly, size: const Size(360, 740), style: style, locale: locale, textScale: 2);
          await walk(tester, lookupL10n(locale), () async {});
        });
      }
    }

    // As accessibility_test.dart: tap targets, labels, contrast.
    for (final style in DesignStyle.values) {
      for (final brightness in Brightness.values) {
        testWidgets('the new states meet the guidelines: ${style.name} ${brightness.name}', (tester) async {
          final semantics = tester.ensureSemantics();
          await open(tester, methods: passkeyOnly, style: style, brightness: brightness);
          await walk(tester, lookupL10n(const Locale('en')), () async {
            final problems = <String>[];
            for (final guideline in [androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline]) {
              final result = await guideline.evaluate(tester);
              if (!result.passed) problems.add('${guideline.description}:\n${result.reason}');
            }
            expect(problems, isEmpty, reason: problems.join('\n\n'));
          });
          semantics.dispose();
        });
      }
    }
  });

  test('the GeeTest page reports an SDK that does not load', () {
    final page = geeTestPage('gt0123');
    final sdk = page.indexOf('gt4.js');
    // The bridge must exist before the SDK's tag can fail.
    expect(page.indexOf('function skidsenseSend'), lessThan(sdk));
    expect(page.indexOf('function skidsenseLoadFailed'), lessThan(sdk));
    expect(page, contains('onerror="skidsenseLoadFailed()"'));
    expect(page, contains("skidsenseSend('err:timeout')"));
    expect(page, contains("skidsenseSend('ready')"));
    // What fails once the SDK is there goes to the config's onError — given
    // none, the SDK throws, and the page never hears of it.
    expect(page.indexOf('function skidsenseError'), lessThan(sdk));
    expect(page, matches(RegExp(r"initGeetest4\(\{[^}]*onError: skidsenseError")));
  });
}

/// A new-api that wants GeeTest — or Turnstile — on its login, for an account
/// with a second factor ([methods]).
class _CaptchaServer extends FakeBackend {
  _CaptchaServer({this.turnstile = false, this.failedProbes = 0, List<Map<String, Object?>>? methods})
      : methods = methods ??
            [
              {'method': '2fa', 'available': true},
            ];

  final bool turnstile;

  /// How many `/api/status` requests fail before one is answered.
  int failedProbes;

  /// Held until completed, then failed: a probe still out.
  Completer<void>? holdFirstProbe;
  final List<Map<String, Object?>> methods;

  final List<String> probed = [];
  int get probes => probed.length;

  /// The `geetest` and `turnstile` parameters of each login.
  final List<String?> logins = [];
  final List<String?> turnstiles = [];

  static http.Response _ok(Object? data) =>
      http.Response(FakeBackend.ok(data), 200, headers: {'content-type': 'application/json'});

  @override
  http.Client client() => MockClient((request) async {
        switch (request.url.path) {
          case '/api/status':
            probed.add(request.url.toString());
            final hold = holdFirstProbe;
            if (hold != null && probes == 1) {
              await hold.future;
              throw http.ClientException('offline');
            }
            if (failedProbes > 0) {
              failedProbes--;
              throw http.ClientException('offline');
            }
            return _ok(turnstile
                ? {'turnstile_check': true, 'turnstile_site_key': 'site-key', 'system_name': 'Surise'}
                : {'geetest_check': true, 'geetest_id': 'gt0123', 'system_name': 'Surise'});
          case '/api/user/login/encryption-key':
            return _ok({'enabled': false});
          case '/api/user/login':
            final query = request.url.queryParameters;
            if (turnstile) {
              turnstiles.add(query['turnstile']);
            } else {
              logins.add(query['geetest']);
              if (query['geetest'] == null) {
                return http.Response(jsonEncode({'success': false, 'message': '极验验证参数为空'}), 200);
              }
            }
            return _ok({'require_verification': true, 'flow_token': 'flow', 'methods': methods});
        }
        return http.Response(jsonEncode({'success': false, 'message': 'not found'}), 404);
      });
}

class _Services extends TestServices {
  _Services(this.server);

  final _CaptchaServer server;

  @override
  FakeBackend get backend => server;
}
