import '../model/desktop.dart';

/// Why a search ended without its own `done`.
enum SearchEnd {
  /// The desktop said `kind: error`; its sentence is in [SearchState.error].
  host,

  /// `search.start` itself failed.
  request,

  /// The connection dropped; the desktop cancels a device's searches with it.
  interrupted,
}

class SearchState {
  const SearchState({
    required this.id,
    required this.query,
    this.files = const [],
    this.done = false,
    this.cancelled = false,
    this.end,
    this.error,
    this.totalMatches = 0,
    this.fileCount = 0,
    this.elapsedMs = 0,
  });

  final String id;
  final String query;
  final List<SearchFileResult> files;
  final bool done;
  final bool cancelled;

  /// Set when the search ended in failure.
  final SearchEnd? end;

  /// The desktop's message, or the failed request's error.
  final Object? error;
  final int totalMatches;
  final int fileCount;
  final int elapsedMs;

  int get matches => files.fold(0, (sum, file) => sum + file.matches.length);

  SearchState copyWith({
    List<SearchFileResult>? files,
    bool? done,
    bool? cancelled,
    SearchEnd? end,
    Object? error,
    int? totalMatches,
    int? fileCount,
    int? elapsedMs,
  }) =>
      SearchState(
        id: id,
        query: query,
        files: files ?? this.files,
        done: done ?? this.done,
        cancelled: cancelled ?? this.cancelled,
        end: end ?? this.end,
        error: error ?? this.error,
        totalMatches: totalMatches ?? this.totalMatches,
        fileCount: fileCount ?? this.fileCount,
        elapsedMs: elapsedMs ?? this.elapsedMs,
      );
}

/// One files search's progress, folded as `search.progress` frames arrive.
///
/// A search is identified by an id **this device chose** (spec §6.4): the
/// desktop prefixes it with the connection id for its own bookkeeping and
/// echoes ours back on every frame, so the id here is what matches — and
/// another device's search, or another connection's, is not ours to display.
/// `done` and `error` are terminal.
class SearchFold {
  SearchFold(this.id, this.query) : _state = SearchState(id: id, query: query);

  final String id;
  final String query;
  SearchState _state;
  SearchState get state => _state;

  /// Apply one frame. True when the state changed.
  bool apply(SearchProgressPush push) {
    if (push.id != id) return false;
    // A search that has ended does not reopen: a late frame, or one that
    // crossed our cancel, must not add results.
    if (_state.done) return false;
    switch (push.kind) {
      case 'files':
        _state = _state.copyWith(files: [..._state.files, ...push.files]);
      case 'done':
        _state = _state.copyWith(
          done: true,
          totalMatches: push.totalMatches,
          fileCount: push.fileCount,
          elapsedMs: push.elapsedMs,
        );
      case 'error':
        _state = _state.copyWith(done: true, end: SearchEnd.host, error: push.error.trim().isEmpty ? null : push.error);
      default:
        return false;
    }
    return true;
  }

  /// Finished because we asked the host to stop.
  void cancel() {
    if (!_state.done) _state = _state.copyWith(done: true, cancelled: true);
  }

  /// Finished because something on our side failed.
  void fail(SearchEnd end, [Object? error]) {
    if (!_state.done) _state = _state.copyWith(done: true, end: end, error: error);
  }
}
