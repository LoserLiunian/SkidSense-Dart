import '../model/desktop.dart';

enum Applied {
  /// Applied.
  ok,

  /// The patch cannot be applied onto what we hold: read the turn again.
  gap,
}

/// Following one session's live turn.
///
/// The fold is the desktop's (`applyPatch` in `src/core/snapshot.ts`): text
/// and reasoning travel as deltas, everything else is replaced wholesale by
/// key. Gap handling is the desktop renderer's (`useLiveTurn`): when
/// `fromSeq` is not the seq we last applied, the patch has no usable base, so
/// the turn is re-read whole with `turn.snapshot`; if that answers null the
/// turn has ended, and the new seq is accepted anyway — otherwise every later
/// frame would look like another gap and the composer would never unlock.
class LiveTurn {
  TurnSnapshot? _snapshot;
  TurnSnapshot? get snapshot => _snapshot;

  /// The seq of the last frame applied, as `useLiveTurn`'s `seqRef`.
  int _seq = 0;
  int get seq => _seq;

  /// Bumped on every change.
  int _revision = 0;
  int get revision => _revision;

  /// Finished turns read with the session.
  List<TurnRecord> _history = const [];
  List<TurnRecord> get history => _history;

  void reset() {
    _snapshot = null;
    _seq = 0;
    _revision += 1;
  }

  void setHistory(List<TurnRecord> turns) {
    _history = turns;
    _revision += 1;
  }

  void setSnapshot(TurnSnapshot? fresh) {
    _snapshot = fresh;
    _revision += 1;
  }

  /// The seq of the last frame applied; set when a gap is accepted without a re-read.
  void acceptSeq(int value) => _seq = value;

  Applied apply(SessionPatchPush push) {
    final base = push.base;
    if (base != null) {
      _seq = push.seq;
      _snapshot = base;
      _revision += 1;
      return Applied.ok;
    }
    final current = _snapshot;
    if (current == null || push.fromSeq != _seq) return Applied.gap;
    _seq = push.seq;
    _snapshot = _patch(current, push.patch);
    _revision += 1;
    return Applied.ok;
  }

  /// The patch is laid over the JSON the snapshot was read from: one path for
  /// every field, and a field this app does not model survives intact.
  static TurnSnapshot _patch(TurnSnapshot current, SnapshotPatch patch) {
    final textDelta = patch.textDelta ?? '';
    final reasoningDelta = patch.reasoningDelta ?? '';
    final fields = patch.fields;
    if ((fields == null || fields.isEmpty) && textDelta.isEmpty && reasoningDelta.isEmpty) return current;
    final merged = <String, Object?>{
      ...current.json,
      'text': current.text + textDelta,
      'reasoning': current.reasoning + reasoningDelta,
      ...?fields,
    };
    return TurnSnapshot.fromJson(merged);
  }
}
