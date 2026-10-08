import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

class RecordingSink implements TerminalSink {
  final StringBuffer data = StringBuffer();
  final List<TerminalExit> exits = [];

  @override
  void onData(String key, String data) => this.data.write(data);

  @override
  void onExit(TerminalExit exit) => exits.add(exit);
}

/// The phone-side followings that used to go silently stale: a terminal's
/// first bytes (N04), a search's results (N02), the composer's attachment
/// chips (N06), and a prompt whose answer never arrived (S28).
void main() {
  Future<(TestApp, FakeHost)> setUp() async {
    final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
      ..handler = (method, _) => method == 'workspaces.list' || method == 'sessions.list' ? <Object?>[] : true;
    final app = TestApp();
    await app.connectTo(host);
    return (app, host);
  }

  /// The desktop pushes the CLI's banner milliseconds after `tui.open`,
  /// before any screen could have mounted. The controller holds it until a
  /// sink for that key registers.
  test("a terminal's first bytes survive until the sink registers", () => runFake((_) async {
        final (app, host) = await setUp();
        host.beforeTuiOpenReply = () async => host.emitTerminal('claude:1', r'banner\r\n$ ');
        await app.controller.openTerminal('claude:1', 80, 24);
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(app.controller.bufferedTerminalData('claude:1'), isNotEmpty);

        final sink = RecordingSink();
        app.controller.attachTerminal('claude:1', sink);
        expect(sink.data.toString(), contains('banner'), reason: 'the early bytes arrive with the sink');
        expect(app.controller.bufferedTerminalData('claude:1'), '');

        host.emit(Events.tuiExit, {'key': 'claude:1', 'code': 0, 'signal': 9, 'tail': 'last words'});
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(sink.exits.single.signal, 9, reason: 'a desktop exit without `reason` keeps its signal (C2)');
        expect(sink.exits.single.tail, 'last words');
        app.controller.disconnect();
      }));

  /// The results must reach a listener as they arrive, not only at the end.
  test('search results are published as they arrive', () => runFake((_) async {
        final (app, host) = await setUp();
        final seen = <int>[];
        app.controller.search.changes.listen((view) {
          if (view != null) seen.add(view.state.matches);
        });
        await app.controller.startSearch('/w', 'find-me-token');
        await until(() => host.searchId != null);
        host.emitSearchProgress([
          {
            'path': 'notes.md',
            'matches': [
              {'line': 2, 'column': 1, 'text': 'find-me-token'},
            ],
          },
        ], 1);
        await until(() => app.controller.search.value?.state.done ?? false);
        expect(seen.any((matches) => matches > 0), isTrue, reason: 'the files frame was visible, got $seen');
        expect(app.controller.search.value!.state.totalMatches, 1);
        app.controller.disconnect();
      }));

  test('drafts are observable', () => runFake((_) async {
        final (app, _) = await setUp();
        final emissions = <List<String>>[];
        app.controller.uploads.drafts.changes.listen((drafts) => emissions.add([for (final d in drafts) d.name]));
        await app.controller.attach('attach-A.txt', 'text/plain', 'hello'.codeUnits, sessionKey: 'claude:1');
        await until(() => emissions.any((names) => names.contains('attach-A.txt')));
        await app.controller.detach(app.controller.uploads.drafts.value.firstWhere((d) => d.name == 'attach-A.txt').id);
        await until(() => emissions.last.isEmpty);
        expect(emissions.any((names) => names.length == 1 && names.single == 'attach-A.txt'), isTrue);
        app.controller.disconnect();
      }));

  /// A definite refusal keeps the attachments (spec §7); an answer that died
  /// with the connection may mean the turn is running — the attachments drop
  /// out instead of being replayed onto the next connection (S28).
  test('a refused prompt restores the attachments, a lost answer does not', () => runFake((_) async {
        final (app, host) = await setUp();
        host.handler = (method, _) => switch (method) {
              'workspaces.list' || 'sessions.list' => <Object?>[],
              'turn.prompt' => throw const RemoteCallError('bad-request', '不批准'),
              _ => true,
            };
        await app.controller.attach('one.txt', 'text/plain', '1'.codeUnits, sessionKey: 'claude:1');
        final refused = await app.controller.prompt('claude:1', 'hi');
        expect(refused, isA<PromptRefused>());
        expect(app.controller.uploads.drafts.value.map((d) => d.name), ['one.txt'], reason: 'a refusal restores');

        host.handler = (method, _) async {
          if (method == 'turn.prompt') {
            await host.drop();
            return Completer<Object?>().future;
          }
          return method == 'workspaces.list' || method == 'sessions.list' ? <Object?>[] : true;
        };
        final uncertain = await app.controller.prompt('claude:1', 'hi again');
        expect(uncertain, isA<PromptUncertain>().having((o) => o.droppedAttachments, 'droppedAttachments', isTrue));
        expect(app.controller.uploads.drafts.value, isEmpty, reason: 'no replay of ids the next connection does not know');
        app.controller.disconnect();
      }));

  test('a prompt with an attachment still uploading sends nothing', () => runFake((_) async {
        final (app, host) = await setUp();
        host.chunkDelay = const Duration(seconds: 1);
        final upload = app.controller.uploads.begin('big.bin', null, List.filled(Protocol.uploadChunk * 3, 1), sessionKey: 'claude:1');
        await until(() => app.controller.uploads.count == 1);
        final outcome = await app.controller.prompt('claude:1', 'now');
        expect(outcome, isA<PromptBlocked>().having((o) => o.error.code, 'code', 'upload-incomplete'));
        expect(host.calls.where((call) => call.$1 == 'turn.prompt'), isEmpty);
        await upload;
        app.controller.disconnect();
      }));

  /// Leaving a session aborts its uploads and only its uploads (S29).
  test('detachAll is scoped to the session', () => runFake((_) async {
        final (app, host) = await setUp();
        await app.controller.attach('a.txt', null, 'a'.codeUnits, sessionKey: 'claude:1');
        await app.controller.attach('b.txt', null, 'b'.codeUnits, sessionKey: 'claude:2');
        await app.controller.detachAll('claude:1');
        expect(app.controller.uploads.drafts.value.map((d) => d.name), ['b.txt']);
        expect(host.calls.where((call) => call.$1 == 'upload.abort'), hasLength(1));
        app.controller.disconnect();
      }));
}
