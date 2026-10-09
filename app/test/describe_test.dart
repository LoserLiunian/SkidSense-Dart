import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/ui/describe.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_core/skidsense_core.dart';

/// The words for what the relay, the backend and the grant cache report.
void main() {
  final en = lookupL10n(const Locale('en'));
  final hans = lookupL10n(const Locale('zh'));
  final hant = lookupL10n(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));

  RcException onRelay(CarrierUnavailable error) =>
      RcException('unreachable', detail: error.reason, route: const RouteRelay(), cause: error);

  test('the desktop closing the session: its own reason, or the plain fact', () {
    const withReason = RelayRejected('host-closed', message: '這支手機的權限已變更');
    const without = RelayRejected('host-closed', message: ' ');
    expect(hant.error(withReason), '這支手機的權限已變更');
    expect(hant.error(without), '電腦結束了這個連線');
    expect(hans.error(without), '电脑结束了这个连接');
    expect(en.error(without), 'The computer ended this connection');
    expect(hant.error(const RelayRejected('unauthorized', message: 'x')), '登入已失效，請重新登入', reason: 'unchanged');
  });

  test('remote control turned off on the server', () {
    expect(hant.error(const RcException('companion-disabled')), '伺服器未啟用遠端控制');
    expect(hans.error(const RcException('companion-disabled')), '服务器未启用远程控制');
    expect(en.error(const RcException('companion-disabled')), 'Remote control is not turned on on this server');
  });

  test('what the relay answered the upgrade with', () {
    expect(hant.error(onRelay(const CarrierUnavailable('forbidden'))), '中繼：伺服器拒絕了這支手機');
    expect(hant.error(onRelay(const CarrierUnavailable('not-found'))), '中繼：伺服器上找不到這次配對或中繼端點');
    expect(hant.error(onRelay(const CarrierUnavailable('rate-limited'))), '中繼：請求過於頻繁，請稍後再試');
    expect(hans.error(onRelay(const CarrierUnavailable('forbidden'))), '中继：服务器拒绝了这台手机');
    expect(en.error(onRelay(const CarrierUnavailable('forbidden'))), 'Relay: the server refused this phone');
    for (final l in [en, hans, hant]) {
      for (final reason in ['forbidden', 'not-found', 'rate-limited', 'credentials-unavailable']) {
        expect(l.error(onRelay(CarrierUnavailable(reason))), isNot(l.errUnreachableRoute(l.routeRelay)), reason: reason);
      }
    }
  });

  /// A refresh that could not reach the backend is not a sign-out, and is
  /// not worded as one.
  test('a bearer that cannot be had now says why, not "sign-in expired"', () {
    const unreachable = BackendException('unreachable', base: 'https://ai.surise.cn');
    final relay = onRelay(const CarrierUnavailable('credentials-unavailable', cause: unreachable));
    expect(hant.error(relay), '中繼：無法連線到伺服器（https://ai.surise.cn）');
    expect(hant.error(onRelay(const CarrierUnavailable('credentials-unavailable'))), '中繼：暫時無法確認登入狀態');
    for (final l in [en, hans, hant]) {
      expect(l.error(relay), isNot(contains(l.backendSessionExpired)));
      expect(l.error(const BackendException('server', status: 502, message: 'Bad Gateway')), isNot(l.backendSessionExpired));
    }
    expect(hant.error(onRelay(const CarrierUnavailable('no-credentials'))), '中繼：尚未登入');
  });

  test('a 429: the server’s sentence, or its Retry-After', () {
    const wait = BackendException('http', status: 429, retryAfter: Duration(seconds: 600));
    expect(hant.error(wait), '請求太頻繁，請於 600 秒後再試');
    expect(hans.error(wait), '请求太频繁，请在 600 秒后再试');
    expect(en.error(wait), 'Too many requests. Try again in 600 seconds.');
    expect(en.error(const BackendException('http', status: 429, retryAfter: Duration(seconds: 1))), 'Too many requests. Try again in 1 second.');
    expect(hant.error(const BackendException('http', status: 429)), '請求太頻繁，請稍後再試');
    expect(
      hant.error(const BackendException('server', status: 429, message: '請求過於頻繁，請 600 秒後再試', retryAfter: Duration(seconds: 600))),
      '請求過於頻繁，請 600 秒後再試',
    );
    expect(hant.error(const BackendException('http', status: 502)), '伺服器回傳 HTTP 502', reason: 'unchanged');
    // `/grant` over its limit, as the client reports it: worded once.
    expect(hant.error(const RcException('grant', cause: wait, retryAfter: Duration(seconds: 600))), '無法取得授權憑證：請求太頻繁，請於 600 秒後再試');
  });

  /// The refresh in front of a call failing with its own status: the
  /// sign-in could not be renewed for now, said in the app's language — not
  /// the refresh endpoint's status text in English ("Conflict") — with the
  /// pause left when there is one (spec §12).
  /// A waiting connection's line counts down to the retry: the error in it
  /// does not name the same wait a second time (rounded the other way).
  test('a waiting connection names its wait once', () {
    const down = BackendException('server', status: 502, message: 'Bad Gateway', retryAfter: Duration(milliseconds: 57300), fromRefresh: true);
    const limited = BackendException('http', status: 429, retryAfter: Duration(milliseconds: 57300));
    const wait = Duration(milliseconds: 57300);
    expect(
      hant.connection(const ClientWaiting(RcException('grant', cause: down, retryAfter: wait), wait, 1)),
      '無法取得授權憑證：暫時無法更新登入狀態（HTTP 502），請稍後再試 · 58 秒後重試',
    );
    expect(hant.connection(const ClientWaiting(RcException('grant', cause: limited, retryAfter: wait), wait, 1)), '無法取得授權憑證：請求太頻繁，請稍後再試 · 58 秒後重試');
    // Elsewhere — a banner — the error says how long, rounded up.
    expect(hant.error(down), '暫時無法更新登入狀態（HTTP 502），請於 58 秒後再試');
    expect(hant.error(limited), '請求太頻繁，請於 58 秒後再試');
  });

  test('a refresh that answered with an error says the sign-in was not renewed', () {
    const race = BackendException('server', status: 409, message: 'Conflict', errorCode: 'AUTH_REFRESH_RACE', fromRefresh: true);
    const down = BackendException('server', status: 500, message: 'Internal Server Error', retryAfter: Duration(minutes: 1), fromRefresh: true);
    const proxy = BackendException('http', status: 502, fromRefresh: true);
    expect(hant.error(race), '暫時無法更新登入狀態（HTTP 409），請稍後再試');
    expect(hans.error(down), '暂时无法更新登录状态（HTTP 500），请在 60 秒后再试', reason: 'the pause after a 5xx, left');
    expect(en.error(proxy), "Couldn't renew the sign-in for now (HTTP 502). Try again later.");
    expect(hant.error(const RcException('grant', cause: down, retryAfter: Duration(minutes: 1))), '無法取得授權憑證：暫時無法更新登入狀態（HTTP 500），請於 60 秒後再試');
    // The call's own answer is the call's; a refresh's 429 says when, and no
    // answer says where from.
    expect(hant.error(const BackendException('server', status: 409, message: '裝置已撤銷')), '裝置已撤銷');
    expect(hant.error(const BackendException('http', status: 429, retryAfter: Duration(seconds: 60), fromRefresh: true)), '請求太頻繁，請於 60 秒後再試');
    expect(hant.error(const BackendException('unreachable', base: 'https://ai.surise.cn', fromRefresh: true)), '無法連線到伺服器（https://ai.surise.cn）');
  });

  test('the three ARB files have the same keys', () {
    Set<String> keys(String locale) =>
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, Object?>).keys.where((key) => !key.startsWith('@')).toSet();
    expect(keys('zh'), keys('en'));
    expect(keys('zh_Hant'), keys('en'));
  });
}
