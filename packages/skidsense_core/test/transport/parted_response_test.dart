import 'dart:async';
import 'dart:convert';

import 'package:skidsense_core/protocol.dart';
import 'package:skidsense_core/transport.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';

/// Parted responses (spec §6.3, C3): `part` and `parts` are JSON integers,
/// `parts` is in 1..4096, and a slice that repeats, moves `parts`, or falls
/// outside it fails the request with `bad-response` — without closing a
/// connection whose host has already authenticated.
void main() {
  String part(String id, Object? part, Object? parts, Object? d) => jsonEncode({
        't': 'res',
        'id': id,
        'part': ?part,
        'parts': ?parts,
        'd': ?d,
      });

  /// Issue one request and let [answer] reply to it; `ok:<r>` or the error code.
  Future<String> outcome(RcConnection connection, RawHost host, void Function(String id) answer) async {
    final call = connection.request('fs.read', null, const Duration(seconds: 5)).then<String>(
          (value) => 'ok:$value',
          onError: (Object error) => error is RcException ? error.code : '$error',
        );
    final request = (await host.requests.next())!;
    answer(request['id']! as String);
    return call;
  }

  const body = '{"ok":true,"r":"AB"}';
  final a = body.substring(0, 10);
  final b = body.substring(10);

  test('well-formed slices reassemble in any order', () => runFake((_) async {
        final (connection, host) = await RawHost.connect();
        expect(await outcome(connection, host, (id) => host..sendInner(part(id, 0, 2, a))..sendInner(part(id, 1, 2, b))), 'ok:AB');
        expect(await outcome(connection, host, (id) => host..sendInner(part(id, 1, 2, b))..sendInner(part(id, 0, 2, a))), 'ok:AB');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, 1, body))), 'ok:AB');
      }));

  test('indices and counts must be JSON integers', () => runFake((_) async {
        final (connection, host) = await RawHost.connect();
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, '0', 2, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, '2', a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 1.5, 2, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, 1 << 40, a))), 'bad-response');
        expect(connection.isOpen, isTrue, reason: 'a malformed slice fails the request, not the connection');
      }));

  test('a repeated slice is refused rather than overwritten', () => runFake((_) async {
        final (connection, host) = await RawHost.connect();
        final result = await outcome(connection, host, (id) {
          host
            ..sendInner(part(id, 0, 2, '{"ok":fals'))
            ..sendInner(part(id, 0, 2, a))
            ..sendInner(part(id, 1, 2, b));
        });
        expect(result, 'bad-response');
      }));

  test('counts and bounds are checked', () => runFake((_) async {
        final (connection, host) = await RawHost.connect();
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, -1, 2, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 2, 2, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, null, 2, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, 0, a))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, 2, null))), 'bad-response');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, 2, 7))), 'bad-response');
        expect(await outcome(connection, host, (id) => host..sendInner(part(id, 0, 2, a))..sendInner(part(id, 1, 3, b))),
            'bad-response');
        expect(connection.isOpen, isTrue);
      }));

  test('the cap is 4096 slices', () => runFake((_) async {
        final (connection, host) = await RawHost.connect();
        final atCap = '{"ok":true,"r":"${'z' * (Protocol.maxResponseParts - 18)}"}';
        final result = await outcome(connection, host, (id) {
          for (var i = 0; i < Protocol.maxResponseParts; i++) {
            host.sendInner(part(id, i, Protocol.maxResponseParts, atCap.substring(i, i + 1)));
          }
        });
        expect(result, 'ok:${'z' * (Protocol.maxResponseParts - 18)}');
        expect(await outcome(connection, host, (id) => host.sendInner(part(id, 0, Protocol.maxResponseParts + 1, '{'))),
            'bad-response');
      }));
}
