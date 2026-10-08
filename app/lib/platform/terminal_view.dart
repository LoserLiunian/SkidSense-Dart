import 'package:skidsense_core/skidsense_core.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../ui/material.dart';

/// The host's PTY drawn natively by xterm.dart: no WebView, no page bridge,
/// and the terminal takes the app's colours.
class NativeTerminal implements TerminalSurface {
  NativeTerminal({required void Function(String data) onInput, required void Function(int cols, int rows) onResize})
      : terminal = xterm.Terminal(maxLines: 5000) {
    terminal
      ..onOutput = onInput
      ..onResize = (cols, rows, _, _) => onResize(cols, rows);
  }

  final xterm.Terminal terminal;

  @override
  void write(String data) => terminal.write(data);
}

class TerminalPane extends StatelessWidget {
  const TerminalPane({super.key, required this.terminal});

  final NativeTerminal terminal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return xterm.TerminalView(
      terminal.terminal,
      autofocus: true,
      textStyle: const xterm.TerminalStyle(fontSize: 13),
      keyboardAppearance: colors.brightness,
      theme: xterm.TerminalThemes.defaultTheme,
      padding: const EdgeInsets.all(8),
    );
  }
}
