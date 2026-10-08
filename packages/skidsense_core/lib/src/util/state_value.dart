import 'dart:async';

/// A current value plus a stream of its changes — the core's stand-in for a
/// Kotlin `StateFlow`. Setting a value equal to the current one emits
/// nothing; anything that must be seen twice is a new object.
class StateValue<T> {
  StateValue(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast();

  T get value => _value;

  set value(T next) {
    if (identical(next, _value) || next == _value) return;
    _value = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  /// Changes from now on (not the current value).
  Stream<T> get changes => _changes.stream;

  /// The current value, then every change.
  Stream<T> watch() {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_value);
        subscription = _changes.stream.listen(controller.add, onDone: controller.close);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// The first value (current included) that passes [test]; with [timeout],
  /// null when none did in time.
  Future<T?> firstWhere(bool Function(T value) test, {Duration? timeout}) {
    if (test(_value)) return Future.value(_value);
    final completer = Completer<T?>();
    late StreamSubscription<T> subscription;
    Timer? timer;
    subscription = _changes.stream.listen((value) {
      if (!test(value) || completer.isCompleted) return;
      timer?.cancel();
      subscription.cancel();
      completer.complete(value);
    });
    if (timeout != null) {
      timer = Timer(timeout, () {
        if (completer.isCompleted) return;
        subscription.cancel();
        completer.complete(null);
      });
    }
    return completer.future;
  }

  Future<void> close() => _changes.close();
}
