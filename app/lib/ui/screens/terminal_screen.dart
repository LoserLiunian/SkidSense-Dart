import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../platform/terminal_view.dart';
import '../../state/scope.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';

/// The host's PTY for one session — and the one screen with a warning
/// before anything opens: inside a terminal the CLI answers its own
/// permission prompts, so the approval flow does not apply. The `terminal`
/// scope is off by default and must be granted on the desktop.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key, required this.sessionKey});

  final String sessionKey;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final AppController _app = context.app;
  late final TerminalChannel _channel = TerminalChannel(widget.sessionKey, exitFooter: (exit) => context.l10n.terminalExit(exit));
  NativeTerminal? _terminal;
  bool _confirmed = false;
  bool _opening = false;
  bool _open = false;
  Object? _error;
  int _cols = 80;
  int _rows = 24;

  Future<void> _start() async {
    setState(() {
      _confirmed = true;
      _opening = true;
      _error = null;
    });
    final terminal = NativeTerminal(
      onInput: (data) => unawaited(_app.terminalInput(widget.sessionKey, data).catchError((Object _) {})),
      onResize: (cols, rows) {
        _cols = cols;
        _rows = rows;
        if (_open) unawaited(_app.terminalResize(widget.sessionKey, cols, rows).catchError((Object _) {}));
      },
    );
    _terminal = terminal;
    _channel.attach(terminal);
    // The sink registers before the open: the CLI's first screen is on the
    // wire milliseconds after the reply, and what arrives in between is
    // held by the controller and handed over now (N04).
    _app.attachTerminal(widget.sessionKey, _channel);
    try {
      await _app.openTerminal(widget.sessionKey, _cols, _rows);
      if (!mounted) return;
      setState(() => _open = true);
      _channel.flush();
    } catch (error) {
      _app.detachTerminal(_channel);
      if (mounted) {
        setState(() {
          _error = error;
          _confirmed = false;
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _app.detachTerminal(_channel);
    // Runs on its own: the screen is gone before the reply would come (S29).
    if (_open) unawaited(_app.closeTerminal(widget.sessionKey));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final terminal = _terminal;
    return FixedPage(
      title: l.terminalTitle,
      subtitle: const ConnectionSubtitle(),
      actions: [
        if (_open)
          IconButton(
            tooltip: l.terminalClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ],
      body: !_confirmed || terminal == null
          ? ListView(padding: const EdgeInsets.all(Gap.lg), children: [
              if (_error != null) ...[
                InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
                const SizedBox(height: Gap.lg),
              ],
              InlineBanner(
                tone: BannerTone.warning,
                title: l.terminalWarningTitle,
                message: l.terminalWarningBody,
                icon: Icons.gpp_maybe_outlined,
              ),
              const SizedBox(height: Gap.xl),
              AppButton(label: l.terminalOpen, icon: Icons.terminal_rounded, large: true, expand: true, onPressed: _start),
            ])
          : Stack(children: [
              // xterm.dart reaches for the SDK's Material theme; the bridge
              // hands it this one.
              // ignore: deprecated_member_use
              MaterialUiCompatibilityBridge(child: TerminalPane(terminal: terminal)),
              if (_opening) Center(child: BusyIndicator(contained: true, semanticsLabel: l.terminalOpening)),
            ]),
    );
  }
}
