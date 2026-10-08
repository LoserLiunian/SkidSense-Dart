import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

const key = 'echo:r4';

/// The desktop's truth for one turn.
class Turn {
  int seq = 5;
  String phase = 'running';
  bool asking = false;
  bool ended = false;
  String title = 'r4';

  /// What the desktop's index said about a live turn before round 4.
  String? rowRunState;

  Map<String, Object?> snapshot() => {
        'taskId': 'task-1',
        'agent': 'echo',
        'workdir': '/w',
        'phase': phase,
        'prompt': 'do it',
        'text': 'hello',
        'reasoning': '',
        'interactions': [
          if (asking)
            {
              'id': 'ask-1',
              'askedAt': 1,
              'question': {'kind': 'permission', 'title': '允许吗'},
            },
        ],
        'seq': seq,
      };

  Map<String, Object?> row() => {
        'key': key,
        'agent': 'echo',
        'workdir': '/w',
        'title': title,
        'runState': rowRunState ?? (ended ? 'idle' : 'running'),
      };

  Map<String, Object?> opened() => {
        'row': row(),
        'turns': [
          if (ended) {'taskId': 'task-1', 'prompt': 'do it', 'ok': true, 'stopReason': 'complete', 'snapshot': snapshot()},
        ],
        'live': ended ? null : snapshot(),
      };

  Map<String, Object?> donePatch() {
    final from = seq;
    seq += 1;
    phase = 'done';
    return {
      'sessionKey': key,
      'taskId': 'task-1',
      'seq': seq,
      'fromSeq': from,
      'patch': {
        'fields': {'phase': 'done'},
      },
    };
  }
}

/// What the real three-way runs found in how the reference phone followed a
/// live turn and the session list across drops and reloads.
void main() {
  Future<(TestApp, FakeHost)> rig(Turn turn, {FutureOr<Object?>? Function(String method, Object? params)? override}) async {
    final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair());
    host.handler = (method, params) async {
      final custom = override?.call(method, params);
      if (custom != null) return await custom;
      return switch (method) {
        'workspaces.list' => <Object?>[],
        'sessions.list' => [turn.row()],
        'sessions.open' => turn.opened(),
        'turn.snapshot' => turn.ended ? null : turn.snapshot(),
        _ => true,
      };
    };
    final app = TestApp();
    await app.connectTo(host);
    await app.controller.openSession(key);
    return (app, host);
  }

  Future<void> awaitReconnect(TestApp app, FakeHost host, int before) =>
      until(() => host.connections > before && app.controller.state.connected, timeout: const Duration(minutes: 2));

  /// An approval asked while the phone was away: nothing re-read the turn
  /// after the reconnect — a turn waiting on an answer publishes no patch —
  /// so the card never appeared and the turn waited forever.
  test('a reconnect re-reads the turn and shows a question asked meanwhile', () => runFake((_) async {
        final turn = Turn();
        final (app, host) = await rig(turn);
        expect(app.controller.liveTurn.snapshot?.phase, 'running');
        final before = host.connections;
        await host.drop();
        turn
          ..phase = 'awaiting-input'
          ..asking = true
          ..seq = 9;
        await awaitReconnect(app, host, before);
        await until(() => app.controller.liveTurn.snapshot?.openInteraction != null);
        expect(app.controller.liveTurn.snapshot?.openInteraction?.id, 'ask-1');
      }));

  test('a turn that ended while away is shown ended after the reconnect', () => runFake((_) async {
        final turn = Turn();
        final (app, host) = await rig(turn);
        final before = host.connections;
        await host.drop();
        turn
          ..phase = 'done'
          ..ended = true;
        await awaitReconnect(app, host, before);
        await until(() => app.controller.liveTurn.snapshot?.running == false);
        expect(app.controller.liveTurn.snapshot?.phase, 'done');
      }));

  /// The list said `idle` mid-turn; the heal re-fetched, the turn's last
  /// patch arrived meanwhile, and the older answer was painted over it.
  test('an older re-read does not overwrite a newer patch', () => runFake((_) async {
        final turn = Turn();
        final gate = Completer<void>();
        var gated = false;
        final (app, host) = await rig(turn, override: (method, _) {
          if (method != 'sessions.open' || !gated) return null;
          final computed = turn.opened();
          return gate.future.then((_) => computed);
        });
        // Follow the turn from a base frame, as a phone that watched it start does.
        turn.seq = 6;
        host.emit(Events.sessionPatch, {
          'sessionKey': key,
          'taskId': 'task-1',
          'seq': 6,
          'fromSeq': 0,
          'base': turn.snapshot(),
          'patch': <String, Object?>{},
        });
        await until(() => app.controller.liveTurn.seq == 6);
        turn.rowRunState = 'idle';
        gated = true;
        final mark = host.calls.length;
        host.emit(Events.sessionsChanged, <String, Object?>{});
        await until(() => host.calls.skip(mark).any((call) => call.$1 == 'sessions.open' || call.$1 == 'turn.snapshot'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        host.emit(Events.sessionPatch, turn.donePatch());
        turn.ended = true;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        gate.complete();
        await Future<void>.delayed(const Duration(seconds: 5));
        expect(app.controller.liveTurn.snapshot?.phase, 'done', reason: 'an older re-read painted over the turn’s end');
      }));

  /// A `sessions.changed` arriving while a list reload was in flight used to
  /// be dropped, and the list kept whatever that reload had read.
  test('a change during a reload is not lost', () => runFake((_) async {
        final turn = Turn()
          ..ended = true
          ..phase = 'done';
        final hold = Completer<void>();
        var holding = false;
        final (app, host) = await rig(turn, override: (method, _) {
          if (method != 'sessions.list' || !holding) return null;
          holding = false;
          final computed = [turn.row()];
          return hold.future.then((_) => computed);
        });
        holding = true;
        host.emit(Events.sessionsChanged, <String, Object?>{});
        await Future<void>.delayed(const Duration(milliseconds: 100));
        turn.title = 'renamed';
        host.emit(Events.sessionsChanged, <String, Object?>{});
        await Future<void>.delayed(const Duration(milliseconds: 100));
        hold.complete();
        await until(() => app.controller.state.sessions.firstOrNull?.title == 'renamed');
      }));

  /// A search running when the connection drops ends there, instead of
  /// spinning for ever.
  test('a search cut off by a drop ends', () => runFake((_) async {
        final turn = Turn();
        final (app, host) = await rig(turn);
        await app.controller.startSearch('/w', 'needle');
        expect(app.controller.search.value?.state.done, isFalse);
        final before = host.connections;
        await host.drop();
        await awaitReconnect(app, host, before);
        await until(() => app.controller.search.value?.state.done ?? false);
        expect(app.controller.search.value?.state.end, SearchEnd.interrupted);
      }));

  /// Over the budgeted relay an attachment goes in small chunks, so the
  /// phone's other requests are not queued behind a third of a megabyte.
  test('attachments go in small chunks over the relay', () => runFake((_) async {
        final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
          ..maxChunk = 64 * 1024
          ..handler = (method, _) => method == 'workspaces.list' || method == 'sessions.list' ? <Object?>[] : true;
        final app = TestApp();
        await TestApp.writePaired(app.files, [TestApp.pairedHost(host.hostId, host.hostStatic, 'dev-1')]);
        app.carriers.relay = () => host;
        await app.start();
        await app.controller.connect(host.hostId);
        final connected = await app.controller.states.firstWhere((s) => s.connected, timeout: const Duration(minutes: 1));
        expect((connected!.connection as ClientConnected).route, isA<RouteRelay>());
        await app.controller.attach('big.bin', 'application/octet-stream', List.filled(300 * 1024, 7));
        expect(host.uploads.values.single.received, 300 * 1024);
      }));
}
