import 'dart:convert';
import 'dart:io';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

/// An account's base URL, held to the desktop's own check and no more: its
/// `accountProblem` (`src/shared/accounts.ts`) parses one with `new URL` —
/// the URL Standard — where Dart's `Uri` refuses some addresses it takes
/// (`http:host`, a backslash for a slash, `a@b@host`) and takes some it
/// refuses (`http://999.1.1.1`, `http://a<b`).
///
/// `fixtures/account-urls.json` is what the desktop said of each address:
/// its `accountProblem` run under node over the same list, `ok`,
/// `notAddress` (不是有效地址) or `notHttp` (必须是 http(s)).
void main() {
  final fixture = jsonDecode(File('test/fixtures/account-urls.json').readAsStringSync()) as Map<String, Object?>;
  final desktop = (fixture['verdicts']! as Map<String, Object?>).cast<String, String>();

  /// What the phone says of [url] before saving, in the fixture's words.
  String phone(String url) {
    final input = AccountGroupInput(name: 'A', endpoints: [AccountEndpointInput(dialect: 'anthropic', baseUrl: url)]);
    final kinds = {
      for (final problem in [...input.problems, ...input.accountProblems])
        if (problem.field == 'baseUrl') problem.kind,
    };
    if (kinds.contains(AccountInputFault.invalid)) return 'invalid';
    if (kinds.contains(AccountInputFault.notAddress)) return 'notAddress';
    if (kinds.contains(AccountInputFault.notHttp)) return 'notHttp';
    return 'ok';
  }

  // Whitespace or a control character: refused before the desktop parses
  // it, by the remote check on the parameter (`url` in its
  // `src/main/remote/params.ts`), as by the phone's [AccountGroupInput.problems].
  bool spaced(String url) => RegExp(r'\s').hasMatch(url.trim()) || RegExp(r'[\u0000-\u001f\u007f-\u009f]').hasMatch(url.trim());

  // What UTS #46 refuses by its tables alone — characters that map to a
  // dot or a slash in its latest version, a tatweel between Latin letters,
  // a non-ASCII `xn--` label, a non-joiner between letters that do not join
  // (Latin ones; an alef, which joins only to what is before it), a joiner
  // after a mark that is no virama (an acute accent). Older
  // versions of the desktop's runtime take some of them: the phone takes
  // them all, and the computer, if it does not, says so in its own words.
  const tableOnly = {
    'http://a․b.com',
    'http://a‥b.com',
    'http://a…b.com',
    'http://⒈.com',
    'http://a﹒b.com',
    'http://aـb.com',
    'http://℀.com',
    'http://xn--aü.com',
    'http://ü‌ü.com',
    'http://ا‌ب.com',
    'https://x́‍ب.com',
  };

  test('every address the desktop takes, the phone takes', () {
    final refused = [
      for (final MapEntry(key: url, value: verdict) in desktop.entries)
        if (verdict == 'ok' && !spaced(url) && phone(url) != 'ok') '$url: ${phone(url)}',
    ];
    expect(refused, isEmpty);
    // Among them, those Dart's own parser would have refused.
    for (final url in ['http:api.example.com', 'http:///api.example.com', r'http:\\api.example.com', 'https://a@b@c.com', 'HTTPS://API.EXAMPLE.COM']) {
      expect(desktop[url], 'ok', reason: url);
      expect(phone(url), 'ok', reason: url);
    }
  });

  test('and says the same of every other, but for what only its tables know', () {
    final differs = [
      for (final MapEntry(key: url, value: verdict) in desktop.entries)
        if (!spaced(url) && !tableOnly.contains(url) && phone(url) != verdict) '$url: desktop $verdict, phone ${phone(url)}',
    ];
    expect(differs, isEmpty);
    for (final url in tableOnly.where(desktop.containsKey)) {
      expect(phone(url), 'ok', reason: url);
    }
    expect(desktop.length, greaterThan(200));
  });

  test('a forbidden code point in a label that is not ASCII is refused, as in an ASCII one', () {
    // It stays in the label's punycode, where the desktop finds it.
    for (final url in ['https://例|.com', 'https://例子^.测试', 'https://ü%.com', 'https://ü<.com', 'https://ü%3C.com', 'https://例子.测试|']) {
      expect(desktop[url], 'notAddress', reason: url);
      expect(phone(url), 'notAddress', reason: url);
    }
    // A percent escape of a letter is no forbidden code point.
    expect(desktop['https://ü%41.com'], 'ok');
    expect(phone('https://ü%41.com'), 'ok');
  });

  test('a non-joiner between joining letters settles its label, Latin letters in it or not', () {
    for (final url in [
      'https://xب‌ب',
      'https://aب‌ب.com',
      'http://بx‌ب.com',
      'http://ب‌ب‌a.com',
    ]) {
      expect(desktop[url], 'ok', reason: url);
      expect(phone(url), 'ok', reason: url);
    }
    // But not with no letter on one side that might join, and a joiner
    // still goes after a virama alone.
    for (final url in [
      'http://ب‌x.com',
      'http://x‌ب.com',
      'http://a‌b.com',
      'http://aب‍ب.com',
      'http://ب‌ب|.com',
    ]) {
      expect(desktop[url], 'notAddress', reason: url);
      expect(phone(url), 'notAddress', reason: url);
    }
  });

  test('a joiner after a virama settles its label too, as the desktop\'s runtime has it', () {
    // Past it, neither Latin letters with right-to-left ones nor a
    // non-joiner or joiner of no virama is refused.
    for (final url in [
      'https://x्‍ب',
      'https://a्‍ب.com',
      'https://ب्‍x.com',
      'https://क्‍a‌b.com',
      'https://क्‍‍.com',
    ]) {
      expect(desktop[url], 'ok', reason: url);
      expect(phone(url), 'ok', reason: url);
    }
    // Only the first: one of no virama before it is refused.
    expect(desktop['https://a‍क्‍.com'], 'notAddress');
    expect(phone('https://a‍क्‍.com'), 'notAddress');
  });

  test('whitespace and control characters are the parameter check\'s to refuse', () {
    final spacedOnes = [for (final url in desktop.keys) if (spaced(url)) url];
    expect(spacedOnes, isNotEmpty);
    for (final url in spacedOnes) {
      expect(phone(url), 'invalid', reason: url);
    }
  });

  test('the common shapes, said as the desktop says them', () {
    expect({
      for (final url in [
        'https://api.deepseek.com/anthropic',
        'http://localhost:11434/v1',
        'http://[::1]:8080',
        'https://例子.测试:8443/api',
        'https://api.example.com/',
        'api.example.com',
        'https://api.example.com:65536',
        'http://999.1.1.1',
        'localhost:11434',
        'ftp://files.example',
      ])
        url: phone(url),
    }, {
      'https://api.deepseek.com/anthropic': 'ok',
      'http://localhost:11434/v1': 'ok',
      'http://[::1]:8080': 'ok',
      'https://例子.测试:8443/api': 'ok',
      'https://api.example.com/': 'ok',
      'api.example.com': 'notAddress',
      'https://api.example.com:65536': 'notAddress',
      'http://999.1.1.1': 'notAddress',
      'localhost:11434': 'notHttp',
      'ftp://files.example': 'notHttp',
    });
  });
}
