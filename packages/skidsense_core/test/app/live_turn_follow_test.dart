import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

const key = 'claude:follow';

/// The host's truth for one turn, and the patches it publishes.
class HostTurn {
  HostTurn({this.withSeq = true});

  final bool withSeq;
  int seq = 5;
  String text = 'hello ';
  String phase = 'running';
  int toolCalls = 0;
  bool ended = false;
  late FutureOr<Object?> Function() snapshotBehaviour = snapshotJson;

  Map<String, Object?> snapshotJson() => {
        'taskId': 'task-1',
        'agent': 'claude',
        'workdir': '/w',
        'phase': phase,
        'prompt': 'do it',
        'text': text,
        'reasoning': '',
        'toolCalls': [
          for (var n = 0; n < toolCalls; n++) {'id': 't$n', 'name': 'Bash', 'status': 'done'},
        ],
        // C1: the seq of the last patch this snapshot already contains.
        if (withSeq) 'seq': seq,
      };

  Map<String, Object?> patch(String delta) {
    final from = seq;
    seq += 1;
    text += delta;
    return {
      'sessionKey': key,
      'taskId': 'task-1',
      'seq': seq,
      'fromSeq': from,
      'patch': {'textDelta': delta},
    };
  }

  /// What the desktop sends instead of a patch that does not fit one frame.
  Map<String, Object?> gapFrame() => {
        'sessionKey': key,
        'taskId': 'task-1',
        'seq': seq,
        'fromSeq': -1,
        'patch': <String, Object?>{},
      };

  Map<String, Object?> row() => {
        'key': key,
        'agent': 'claude',
        'workdir': '/w',
        'title': 'follow',
        'runState': ended ? 'idle' : 'running',
      };

  /// `sessions.open`: the live turn while it runs, its record once written.
  Map<String, Object?> opened() => {
        'row': row(),
        'turns': [
          if (ended) {'taskId': 'task-1', 'prompt': 'do it', 'ok': phase == 'done', 'snapshot': snapshotJson()},
        ],
        'live': ended ? null : snapshotJson(),
      };
}

class Rig {
  Rig(this.app, this.host);
  final TestApp app;
  final FakeHost host;

  AppController get controller => app.controller;
}

/// The real controller following a live turn through the gap rule (spec
/// §6.4, C1), against a host whose `turn.snapshot` answers what the
/// desktop's does: the engine's snapshot, which already holds every patch
/// published so far — and, from a current desktop, the `seq` of the last.
void main() {
  Future<Rig> setUp(HostTurn turn, {FutureOr<Object?> Function()? sessionsList}) async {
    final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
      ..handler = (method, _) => switch (method) {
            'workspaces.list' => <Object?>[],
            'sessions.list' => sessionsList?.call() ?? [turn.row()],
            'sessions.open' => turn.opened(),
            'turn.snapshot' => turn.snapshotBehaviour(),
            _ => true,
          };
    final app = TestApp();
    await app.connectTo(host);
    await app.controller.openSession(key);
    return Rig(app, host);
  }

  Future<void> awaitText(Rig rig, String text) =>
      until(() => rig.controller.liveTurn.snapshot?.text == text, timeout: const Duration(minutes: 2));

  /// In step: one patch, applied.
  Future<void> syncUp(Rig rig, HostTurn turn) async {
    rig.host.emit(Events.sessionPatch, turn.patch('w${turn.seq + 1} '));
    await awaitText(rig, turn.text);
  }

  /// Patches published while the re-read is on its way are already in the
  /// snapshot it brings back. Applying them again used to duplicate text.
  test('patches in flight during the re-read are not applied twice', () => runFake((_) async {
        final turn = HostTurn();
        late Rig rig;
        var first = true;
        turn.snapshotBehaviour = () {
          if (first) {
            first = false;
            rig.host
              ..emit(Events.sessionPatch, turn.patch('w7 '))
              ..emit(Events.sessionPatch, turn.patch('w8 '));
          }
          return turn.snapshotJson();
        };
        rig = await setUp(turn);
        // Open with no live base: the first patch is a gap, and is re-read.
        rig.host.emit(Events.sessionPatch, turn.patch('w6 '));
        await Future<void>.delayed(const Duration(seconds: 1));
        rig.host.emit(Events.sessionPatch, turn.patch('w9 '));
        await Future<void>.delayed(const Duration(seconds: 5));
        expect(turn.text, 'hello w6 w7 w8 w9 ');
        expect(rig.controller.liveTurn.snapshot?.text, turn.text);
      }));

  /// A desktop from before C1 answers without `seq`: the gap frame's own seq
  /// is the baseline.
  test('a snapshot without seq falls back to the gap frame’s seq', () => runFake((_) async {
        final turn = HostTurn(withSeq: false);
        final rig = await setUp(turn);
        await syncUp(rig, turn);
        rig.host.emit(Events.sessionPatch, turn.patch('next '));
        await awaitText(rig, turn.text);
        expect(rig.controller.liveTurn.seq, turn.seq);
      }));

  /// The last frame of a turn became a gap; by the time the phone asks, the
  /// host has written the turn and `turn.snapshot` is null. The turn ends
  /// from `sessions.open` instead of showing as running until reopened.
  test('a null re-read ends the turn from sessions.open', () => runFake((_) async {
        final turn = HostTurn();
        final rig = await setUp(turn);
        await syncUp(rig, turn);

        turn
          ..text += 'final words'
          ..phase = 'aborted'
          ..toolCalls = 100
          ..seq += 1
          ..ended = true
          ..snapshotBehaviour = () => null;
        rig.host.emit(Events.sessionPatch, turn.gapFrame());
        await Future<void>.delayed(const Duration(seconds: 5));

        final phone = rig.controller.liveTurn.snapshot!;
        expect(phone.running, isFalse, reason: 'phase=${phone.phase}');
        expect(phone.phase, 'aborted');
        expect(phone.text.endsWith('final words'), isTrue);
        expect(rig.controller.liveTurn.history.map((record) => record.taskId), ['task-1']);
      }));

  /// A re-read that times out says nothing about the turn: the baseline does
  /// not move, so the next patch is not applied onto a stale base.
  test('a failed re-read does not advance the baseline', () => runFake((_) async {
        final turn = HostTurn();
        final rig = await setUp(turn);
        await syncUp(rig, turn);

        var slow = true;
        turn.snapshotBehaviour = () async {
          if (slow) {
            slow = false;
            await Future<void>.delayed(const Duration(minutes: 2));
          }
          return turn.snapshotJson();
        };
        turn
          ..text += 'w7 '
          ..toolCalls = 100
          ..seq += 1;
        rig.host.emit(Events.sessionPatch, turn.gapFrame());
        await Future<void>.delayed(const Duration(seconds: 31)); // past the request timeout
        rig.host.emit(Events.sessionPatch, turn.patch('w8 '));
        await Future<void>.delayed(const Duration(seconds: 5));

        final phone = rig.controller.liveTurn.snapshot!;
        expect(phone.text, turn.text, reason: 'nothing applied onto a stale base');
        expect(phone.toolCalls, hasLength(100));
      }));

  /// The last frame was a gap and its re-read failed: no later frame will
  /// come. `sessions.changed` is the backstop — the row says the turn is
  /// over, so the phone reads its end from the session record.
  test('sessions.changed heals a turn stuck running', () => runFake((_) async {
        final turn = HostTurn();
        final rig = await setUp(turn);
        await syncUp(rig, turn);

        turn
          ..text += 'done now'
          ..phase = 'done'
          ..seq += 1
          ..snapshotBehaviour = () => throw const RemoteCallError('internal', '暂时读不到');
        rig.host.emit(Events.sessionPatch, turn.gapFrame());
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(rig.controller.liveTurn.snapshot?.running, isTrue, reason: 'precondition: the re-read failed');

        turn.ended = true;
        rig.host.emit(Events.sessionsChanged, <String, Object?>{});
        await Future<void>.delayed(const Duration(seconds: 5));
        final phone = rig.controller.liveTurn.snapshot!;
        expect(phone.phase, 'done');
        expect(phone.text, turn.text);
      }));

  /// The event handler must not make its own requests: a burst of events
  /// arriving while one is out must not stall it (N09).
  test('a burst of events during the re-read does not stall it', () => runFake((time) async {
        final turn = HostTurn();
        final rig = await setUp(turn);
        await syncUp(rig, turn);
        turn.snapshotBehaviour = () {
          for (var n = 0; n < 1100; n++) {
            rig.host.emit(Events.tuiData, {'key': 'claude:other', 'data': 'line $n\r\n'});
          }
          return turn.snapshotJson();
        };
        turn
          ..text += 'w7 '
          ..seq += 1;
        final started = time.elapsed;
        rig.host.emit(Events.sessionPatch, turn.gapFrame());
        await awaitText(rig, turn.text);
        final waited = time.elapsed - started;
        expect(waited < const Duration(seconds: 1), isTrue, reason: 're-read took $waited (virtual)');
      }));

  test('a burst of events while the session list loads does not stall it', () => runFake((time) async {
        final turn = HostTurn();
        var burst = false;
        late Rig rig;
        rig = await setUp(turn, sessionsList: () {
          if (burst) {
            burst = false;
            for (var n = 0; n < 1100; n++) {
              rig.host.emit(Events.tuiData, {'key': 'claude:other', 'data': 'line $n\r\n'});
            }
          }
          return [
            {...turn.row(), 'title': 'renamed'},
          ];
        });
        burst = true;
        final started = time.elapsed;
        rig.host.emit(Events.sessionsChanged, <String, Object?>{});
        await until(() => rig.controller.state.sessions.firstOrNull?.title == 'renamed', timeout: const Duration(minutes: 2));
        final waited = time.elapsed - started;
        expect(waited < const Duration(seconds: 1), isTrue, reason: 'sessions.list took $waited (virtual)');
      }));
}
