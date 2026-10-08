import '../util/json.dart';

/// Everything a `tui.exit` carries (spec §6.4, C2). [code] is -1 when the
/// desktop sent none (a spawn that never ran); [reason] is the desktop's own
/// sentence when a current desktop sent one.
class TerminalExit {
  const TerminalExit({required this.key, required this.code, this.signal, this.reason, this.tail = ''});

  final String key;
  final int code;
  final int? signal;
  final String? reason;

  /// The last output of a process that died before drawing anything.
  final String tail;
}

/// What the screen draws on: the platform's terminal view.
abstract interface class TerminalSurface {
  void write(String data);
}

/// Where the controller sends terminal events.
abstract interface class TerminalSink {
  void onData(String key, String data);
  void onExit(TerminalExit exit);
}

abstract final class TerminalEvents {
  /// The `tui.data` payload: `{key, data}`.
  static (String, String)? decodeData(Object? payload) {
    final json = asMap(payload);
    final key = json.str('key');
    final data = json.str('data');
    return key == null || data == null ? null : (key, data);
  }

  /// `{key, code, signal, reason, tail}`. `code` is nullable on the wire, so
  /// a missing or non-integer value is -1, not 0 — a signal-killed process
  /// used to report "exit code 0".
  static TerminalExit? decodeExit(Object? payload) {
    final json = asMap(payload);
    final key = json.str('key');
    if (key == null) return null;
    return TerminalExit(
      key: key,
      code: json.integer('code') ?? -1,
      signal: json.integer('signal'),
      reason: json.str('reason'),
      tail: json.str('tail') ?? '',
    );
  }
}

/// One terminal's two directions on the phone. Output accumulates until the
/// surface is ready — a PTY usually has something to say before the view has
/// finished loading, and losing that would lose the prompt — and only the
/// tail is kept, so a shell that floods cannot grow it without bound.
class TerminalChannel implements TerminalSink {
  TerminalChannel(this.sessionKey, {required this.exitFooter});

  final String sessionKey;

  /// The line drawn when the process ends, in the app's language.
  final String Function(TerminalExit exit) exitFooter;

  static const bufferLimit = 200000;

  final StringBuffer _pending = StringBuffer();
  TerminalSurface? _surface;

  void attach(TerminalSurface surface) => _surface = surface;

  void detach() => _surface = null;

  void flush() {
    final surface = _surface;
    if (surface == null || _pending.isEmpty) return;
    surface.write(_pending.toString());
    _pending.clear();
  }

  @override
  void onData(String key, String data) {
    if (key != sessionKey) return;
    final surface = _surface;
    if (surface != null) {
      surface.write(data);
      return;
    }
    _pending.write(data);
    if (_pending.length > bufferLimit) {
      final text = _pending.toString();
      _pending
        ..clear()
        ..write(text.substring(text.length - bufferLimit));
    }
  }

  @override
  void onExit(TerminalExit exit) {
    if (exit.key != sessionKey) return;
    final surface = _surface;
    if (surface == null) return;
    surface.write('\r\n\u001b[2m[${exitFooter(exit)}]\u001b[0m\r\n');
    // Worth showing only when the process died before drawing anything (C2).
    if (exit.tail.isNotEmpty) surface.write('${exit.tail.replaceAll('\n', '\r\n')}\r\n');
  }
}
