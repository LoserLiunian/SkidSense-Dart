import 'dart:async';
import 'dart:collection';

/// A one-consumer queue: values go in synchronously, come out one `await` at
/// a time, in order. Closing lets what is buffered drain first, then every
/// [next] answers `null` — the shape of a closed channel, which is what lets a
/// relay's last word (its `relay-error` frame) be read after the socket shut.
class AsyncQueue<T> {
  AsyncQueue({this.highWater = 0, this.onHigh, this.onLow});

  /// Above this many buffered values [onHigh] runs (pause the source); back
  /// under half of it, [onLow] (resume). Zero means unbounded.
  final int highWater;
  final void Function()? onHigh;
  final void Function()? onLow;

  final ListQueue<T> _buffer = ListQueue<T>();
  Completer<T?>? _waiter;
  Timer? _waiterTimer;
  bool _closed = false;
  bool _paused = false;

  bool get isClosed => _closed;
  int get length => _buffer.length;

  void add(T value) {
    if (_closed) return;
    final waiter = _waiter;
    if (waiter != null) {
      _clearWaiter();
      waiter.complete(value);
      return;
    }
    _buffer.add(value);
    if (highWater > 0 && !_paused && _buffer.length >= highWater) {
      _paused = true;
      onHigh?.call();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final waiter = _waiter;
    _clearWaiter();
    waiter?.complete(null);
  }

  /// The next value, or `null` once closed and drained. With [timeout], a
  /// [TimeoutException] when nothing arrives in time — and the wait is
  /// withdrawn, so a later value is not swallowed by an abandoned waiter.
  Future<T?> next({Duration? timeout}) {
    if (_waiter != null) throw StateError('AsyncQueue has one consumer at a time');
    if (_buffer.isNotEmpty) {
      final value = _buffer.removeFirst();
      if (_paused && _buffer.length <= highWater ~/ 2) {
        _paused = false;
        onLow?.call();
      }
      return Future.value(value);
    }
    if (_closed) return Future.value(null);
    final waiter = Completer<T?>();
    _waiter = waiter;
    if (timeout != null) {
      _waiterTimer = Timer(timeout, () {
        if (!identical(_waiter, waiter)) return;
        _clearWaiter();
        waiter.completeError(TimeoutException('nothing arrived', timeout));
      });
    }
    return waiter.future;
  }

  /// A buffered value without waiting, or `null`.
  T? poll() => _buffer.isEmpty ? null : _buffer.removeFirst();

  void _clearWaiter() {
    _waiter = null;
    _waiterTimer?.cancel();
    _waiterTimer = null;
  }
}
