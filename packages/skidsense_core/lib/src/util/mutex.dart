import 'dart:async';

/// Runs critical sections one at a time, in arrival order. Dart has one
/// thread, but state that spans an `await` still interleaves: a grant fetch
/// or a token refresh must not run twice at once.
class Mutex {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() body) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }
}
