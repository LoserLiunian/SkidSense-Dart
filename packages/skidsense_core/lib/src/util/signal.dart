import 'dart:async';

/// A conflated wake-up: [fire] with nobody waiting is remembered (once), so
/// the next [wait] returns at once — "retry now" pressed during a backoff and
/// pressed just before one mean the same thing.
class Signal {
  bool _pending = false;
  final List<Completer<bool>> _waiters = [];

  void fire() {
    if (_waiters.isEmpty) {
      _pending = true;
      return;
    }
    final waiters = List.of(_waiters);
    _waiters.clear();
    for (final waiter in waiters) {
      waiter.complete(true);
    }
  }

  /// True when fired, false when [timeout] passed first.
  Future<bool> wait({Duration? timeout}) {
    if (_pending) {
      _pending = false;
      return Future.value(true);
    }
    final waiter = Completer<bool>();
    _waiters.add(waiter);
    if (timeout != null) {
      Timer(timeout, () {
        if (_waiters.remove(waiter)) waiter.complete(false);
      });
    }
    return waiter.future;
  }

  /// Forget a remembered [fire].
  void clear() => _pending = false;
}
