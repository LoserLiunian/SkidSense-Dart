import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

/// `https://` anywhere, `http://` only on this machine or the local network:
/// a token must not cross the internet in the clear.
void main() {
  test('https is allowed anywhere; http only to local-network hosts', () {
    for (final base in [
      'https://ai.surise.cn',
      'https://1.2.3.4:8443/api',
      'http://localhost:3000',
      'http://127.0.0.1',
      'http://10.0.0.2:3000',
      'http://172.16.5.1',
      'http://172.31.255.255',
      'http://192.168.1.20:3000',
      'http://169.254.10.10',
      'http://100.101.102.103',
      'http://studio.local:3000',
      'http://[::1]:3000',
      'http://[fd12:3456::1]',
      'http://[fe80::1]',
    ]) {
      expect(backendAllowed(base), isTrue, reason: base);
    }
    for (final base in [
      'http://ai.surise.cn',
      'http://1.2.3.4',
      'http://172.32.0.1',
      'http://192.169.1.1',
      'http://100.128.0.1',
      'http://localhost.evil.com',
      'http://[2001:db8::1]',
      'ftp://ai.surise.cn',
      'ai.surise.cn',
      '',
    ]) {
      expect(backendAllowed(base), isFalse, reason: base);
    }
  });

  test('the client refuses a cleartext public server before sending anything', () async {
    final sent = <http.BaseRequest>[];
    final client = BackendClient(
      http: MockClient((request) async {
        sent.add(request);
        return http.Response('{"success":true,"message":"","data":{}}', 200);
      }),
      secrets: MemorySecretStore(),
    );
    await expectLater(
      client.login('http://ai.surise.cn', 'liunian', 'secret'),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'insecure-server')),
    );
    await expectLater(
      client.status('http://ai.surise.cn'),
      throwsA(isA<BackendException>().having((e) => e.code, 'code', 'insecure-server')),
    );
    expect(sent, isEmpty);

    // A development server on the LAN still works.
    await client.status('http://192.168.1.20:3000');
    expect(sent.single.url.toString(), 'http://192.168.1.20:3000/api/status');
  });

  test('the relay never carries the bearer over cleartext to a public host', () {
    const target = CarrierTarget('h1', 'd1');
    expect(IoCarrierFactory.relayUri('http://ai.surise.cn', target), isNull);
    expect(IoCarrierFactory.relayUri('https://ai.surise.cn', target)?.scheme, 'wss');
    expect(IoCarrierFactory.relayUri('http://10.0.0.2:3000', target)?.scheme, 'ws');
  });
}
