/// `skidsense-rc/1` as constants — the Dart twin of the desktop's
/// `src/shared/remote/protocol.ts`. The normative text is the desktop repo's
/// `docs/remote-control.md`; where this file and that one disagree, the
/// known-answer vectors decide.
abstract final class Protocol {
  static const name = 'skidsense-rc/1';
  static const version = 1;

  /// LAN carrier path (spec §10.4): `ws://<addr>:<port>/rc/1`.
  static const lanPath = '/rc/1';

  /// Relay carrier path (spec §9/§10).
  static const relayPath = 'api/companion/ws';

  static const pairingUrlPrefix = 'skidsense://pair/1?d=';

  /// Largest inner message one `d` frame carries, in UTF-8 bytes.
  static const maxPlaintext = 1024 * 1024;

  /// Largest outer frame a carrier accepts.
  static const maxFrame = 2 * 1024 * 1024;

  /// A response in parts is refused past this.
  static const maxResponse = 64 * 1024 * 1024;

  /// Most slices one response may come in (spec §6.3).
  static const maxResponseParts = 4096;

  /// Upload chunk size, raw bytes.
  static const uploadChunk = 384 * 1024;

  /// One attachment, and a turn's attachments together.
  static const maxUpload = 20 * 1024 * 1024;

  /// Frames / bytes one key may seal before the carrier must be re-established.
  static const maxFramesPerKey = 1 << 32;
  static const maxBytesPerKey = 8 * 1024 * 1024 * 1024;

  /// The handshake must finish within this on the host's side (spec §10.4).
  static const handshakeTimeout = Duration(seconds: 10);
}

enum HandshakeMode {
  enroll('enroll'),
  connect('connect');

  const HandshakeMode(this.wire);

  final String wire;

  static HandshakeMode? fromWire(String? value) {
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    return null;
  }
}

/// What a device may do (spec §7). Unknown values are dropped, not errors.
abstract final class Scopes {
  static const sessions = 'sessions';
  static const prompt = 'prompt';
  static const approve = 'approve';
  static const files = 'files';
  static const filesWrite = 'files.write';
  static const git = 'git';
  static const gitWrite = 'git.write';
  static const terminal = 'terminal';

  static const all = [sessions, prompt, approve, files, filesWrite, git, gitWrite, terminal];

  /// Everything but the terminal: inside a TUI the CLI answers its own
  /// permission prompts.
  static const byDefault = [sessions, prompt, approve, files, filesWrite, git, gitWrite];

  static bool isScope(String value) => all.contains(value);
}

/// Every request method and the scope it needs — `METHODS` in protocol.ts.
abstract final class Methods {
  static const scope = <String, String>{
    'subscribe': Scopes.sessions,
    'unsubscribe': Scopes.sessions,
    'agents.list': Scopes.sessions,
    'models.list': Scopes.sessions,
    'workspaces.list': Scopes.sessions,
    'sessions.list': Scopes.sessions,
    'sessions.search': Scopes.sessions,
    'sessions.open': Scopes.sessions,
    'sessions.new': Scopes.prompt,
    'sessions.rename': Scopes.prompt,
    'sessions.delete': Scopes.prompt,
    'turn.snapshot': Scopes.sessions,
    'turn.prompt': Scopes.prompt,
    'turn.stop': Scopes.prompt,
    'turn.steer': Scopes.prompt,
    'turn.interact': Scopes.approve,
    'upload.begin': Scopes.prompt,
    'upload.chunk': Scopes.prompt,
    'upload.abort': Scopes.prompt,
    'fs.list': Scopes.files,
    'fs.listAll': Scopes.files,
    'fs.read': Scopes.files,
    'fs.write': Scopes.filesWrite,
    'fs.op': Scopes.filesWrite,
    'search.start': Scopes.files,
    'search.cancel': Scopes.files,
    'git.snapshot': Scopes.git,
    'git.diff': Scopes.git,
    'git.branches': Scopes.git,
    'git.mutate': Scopes.gitWrite,
    'artifacts.list': Scopes.files,
    'tui.open': Scopes.terminal,
    'tui.input': Scopes.terminal,
    'tui.resize': Scopes.terminal,
    'tui.close': Scopes.terminal,
  };
}

/// Events, each gated by a scope — `EVENTS` in protocol.ts.
abstract final class Events {
  static const sessionPatch = 'session.patch';
  static const sessionsChanged = 'sessions.changed';
  static const backgroundJobs = 'background.jobs';
  static const agentsChanged = 'agents.changed';
  static const fsChanged = 'fs.changed';
  static const searchProgress = 'search.progress';
  static const gitChanged = 'git.changed';
  static const tuiData = 'tui.data';
  static const tuiExit = 'tui.exit';
}
