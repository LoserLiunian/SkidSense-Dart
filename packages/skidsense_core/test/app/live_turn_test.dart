import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

/// The transcript fold, ported from the desktop's `applyPatch` and
/// `useLiveTurn` (spec §6.4). The gap rule is the subtle part: a patch whose
/// `fromSeq` is not the seq we applied has no usable base, so the caller
/// re-reads — and when the re-read answers null, the new seq is accepted.
void main() {
  Map<String, Object?> snapshotJson([String text = '']) => {
        'taskId': 't1',
        'agent': 'claude',
        'workdir': '/tmp',
        'phase': 'running',
        'prompt': '做点事',
        'text': text,
        'toolCalls': [
          {'id': 'c1', 'name': 'Bash', 'summary': 'ls', 'status': 'ok'},
        ],
      };

  TurnSnapshot snapshot([String text = '']) => TurnSnapshot.fromJson(snapshotJson(text));

  SessionPatchPush push(int seq, int fromSeq, {SnapshotPatch patch = const SnapshotPatch(), TurnSnapshot? base}) =>
      SessionPatchPush(sessionKey: 'claude:1', taskId: 't1', seq: seq, fromSeq: fromSeq, patch: patch, base: base);

  test('a base replaces the snapshot and sets the seq', () {
    final turn = LiveTurn();
    expect(turn.apply(push(5, 0, base: snapshot())), Applied.ok);
    expect(turn.seq, 5);
    expect(turn.snapshot?.prompt, '做点事');
  });

  test('deltas append and fields replace, unknown fields included', () {
    final turn = LiveTurn()..apply(push(1, 0, base: snapshot('第一段')));
    final patch = SnapshotPatch(textDelta: '，第二段', reasoningDelta: '思考', fields: {
      'phase': 'done',
      'activity': '正在收尾',
      'toolCalls': [
        {'id': 'c1', 'name': 'Bash', 'summary': 'ls', 'status': 'ok'},
        {'id': 'c2', 'name': 'Read', 'status': 'running'},
      ],
      'segments': [
        {'kind': 'text', 'from': 0},
        {
          'kind': 'tools',
          'ids': ['c1', 'c2'],
        },
      ],
      // A field this app does not model must not break the merge — and it survives.
      'futureField': {'nested': true},
    });
    expect(turn.apply(push(2, 1, patch: patch)), Applied.ok);
    final merged = turn.snapshot!;
    expect(merged.text, '第一段，第二段');
    expect(merged.reasoning, '思考');
    expect(merged.phase, 'done');
    expect(merged.activity, '正在收尾');
    expect(merged.toolCalls.map((call) => call.id), ['c1', 'c2']);
    expect(merged.segments.map((segment) => segment.kind), ['text', 'tools']);
    expect(merged.json['futureField'], {'nested': true});
    expect(merged.prompt, '做点事', reason: 'untouched fields are kept');
    expect(turn.seq, 2);
  });

  test('a gap is reported rather than applied', () {
    final turn = LiveTurn()..apply(push(4, 0, base: snapshot('x')));
    expect(turn.apply(push(9, 8, patch: const SnapshotPatch(textDelta: '丢了'))), Applied.gap);
    expect(turn.snapshot?.text, 'x', reason: 'the patch is not applied onto a stale base');
    expect(turn.seq, 4);
  });

  test('a patch with no snapshot at all is a gap', () {
    final turn = LiveTurn();
    expect(turn.apply(push(1, 0, patch: const SnapshotPatch(textDelta: 'x'))), Applied.gap);
    expect(turn.snapshot, isNull);
  });

  test('accepting a seq without applying unblocks the next frame', () {
    // What happens when `turn.snapshot` answers null: the turn ended, and
    // holding the old seq would make every later frame look like a gap.
    final turn = LiveTurn()
      ..apply(push(2, 0, base: snapshot('a')))
      ..acceptSeq(7);
    expect(turn.apply(push(8, 7, patch: const SnapshotPatch(textDelta: 'b'))), Applied.ok);
    expect(turn.snapshot?.text, 'ab');
  });

  test('reset clears everything and bumps the revision', () {
    final turn = LiveTurn()..apply(push(3, 0, base: snapshot('a')));
    final before = turn.revision;
    turn.reset();
    expect(turn.snapshot, isNull);
    expect(turn.seq, 0);
    expect(turn.revision, before + 1);
  });

  test('history is replaced wholesale', () {
    final turn = LiveTurn()..setHistory(const [TurnRecord(taskId: 't0', prompt: '旧')]);
    expect(turn.history, hasLength(1));
    turn.setHistory(const []);
    expect(turn.history, isEmpty);
  });

  /// The latest unanswered question is the one on screen: a turn can ask
  /// more than once, and the new one is what the user has to answer.
  test('the open interaction is the latest unanswered one', () {
    TurnSnapshot withInteractions(List<Map<String, Object?>> interactions) =>
        TurnSnapshot.fromJson({...snapshotJson(), 'interactions': interactions});
    final three = [
      {'id': 'i1', 'answeredAt': 1},
      {'id': 'i2'},
      {'id': 'i3'},
    ];
    expect(withInteractions(three).openInteraction?.id, 'i3');
    expect(withInteractions(three.take(2).toList()).openInteraction?.id, 'i2');
    expect(withInteractions(three.take(1).toList()).openInteraction, isNull);
  });

  test('a fractional mtime decodes instead of killing the whole list (N01, C7)', () {
    final result = ListDirResult.fromJson({
      'entries': [
        {'name': 'hello.txt', 'path': 'hello.txt', 'kind': 'file', 'size': 6, 'mtime': 1791221032611.1711, 'git': null},
        {'name': 'notes.md', 'path': 'notes.md', 'kind': 'file', 'size': 12, 'mtime': 1791221032000, 'git': 'modified'},
      ],
      'truncated': false,
    });
    expect(result.entries.map((entry) => entry.name), ['hello.txt', 'notes.md']);
    expect(result.entries[0].mtime, 1791221032611);
    expect(ReadFileResult.fromJson({'mtime': 1791221032611.1711}).mtime, 1791221032611);
    expect(WriteFileResult.fromJson({'ok': true, 'etag': 'e2', 'mtime': 1791221032611.1711}).mtime, 1791221032611);
    expect(WriteFileResult.fromJson({'ok': false, 'conflict': true}).mtime, isNull);
  });
}
