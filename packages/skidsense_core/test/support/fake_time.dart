import 'dart:async';

import 'package:fake_async/fake_async.dart';

/// Runs [body] on virtual time — timers, `Future.delayed`, timeouts and
/// `clock.now()` all advance only as the loop below moves the clock — and
/// returns its result. The clock steps in [step]s until the body finishes;
/// [limit] of virtual time without finishing is a failure.
///
/// It is the counterpart of `runTest` in the reference's coroutine tests: a
/// reconnect backoff of 30 s or a LAN probe every 60 s costs nothing real.
T runFake<T>(
  Future<T> Function(FakeAsync time) body, {
  Duration step = const Duration(milliseconds: 20),
  Duration limit = const Duration(minutes: 30),
}) {
  return fakeAsync((time) {
    var done = false;
    late T result;
    Object? error;
    StackTrace? stack;
    body(time).then((value) {
      result = value;
      done = true;
    }, onError: (Object e, StackTrace s) {
      error = e;
      stack = s;
      done = true;
    });
    var elapsed = Duration.zero;
    time.flushMicrotasks();
    while (!done) {
      if (elapsed > limit) throw TimeoutException('the test did not finish in $limit of virtual time');
      time.elapse(step);
      elapsed += step;
    }
    // Let whatever the body set off settle (closing carriers, loops ending).
    time.elapse(const Duration(seconds: 1));
    if (error != null) Error.throwWithStackTrace(error!, stack!);
    return result;
  });
}

/// Wait (on virtual time, when run under [runFake]) for [condition].
Future<void> until(bool Function() condition, {Duration timeout = const Duration(minutes: 1)}) async {
  var waited = Duration.zero;
  while (!condition()) {
    if (waited > timeout) throw TimeoutException('condition not met', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    waited += const Duration(milliseconds: 10);
  }
}
