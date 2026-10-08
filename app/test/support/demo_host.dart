import 'package:skidsense_core/skidsense_core.dart';
import 'package:skidsense_core/testing.dart';

/// A desktop with something on it: four sessions (one running and waiting
/// for an approval), a workspace with files, and a Git repository with
/// changes — served over the real protocol by [FakeHost].
class DemoHost {
  DemoHost() : host = FakeHost(B64u.encode(Primitives.randomBytes(16)), Primitives.generateKeyPair()) {
    host
      ..scopes = const ['sessions', 'prompt', 'approve', 'files', 'files.write', 'git', 'git.write', 'terminal']
      ..methods = const [
        'workspaces.list', 'sessions.list', 'sessions.open', 'sessions.new', 'sessions.rename', 'sessions.delete',
        'sessions.search', 'turn.snapshot', 'turn.prompt', 'turn.stop', 'turn.steer', 'turn.interact',
        'agents.list', 'models.list', 'artifacts.list', 'fs.list', 'fs.read', 'fs.write', 'fs.op',
        'search.start', 'search.cancel', 'git.snapshot', 'git.diff', 'git.branches', 'git.mutate',
        'tui.open', 'tui.input', 'tui.resize', 'tui.close', 'upload.begin', 'upload.chunk', 'upload.abort',
        'subscribe',
      ]
      ..handler = _answer;
  }

  final FakeHost host;
  static const root = '/Users/me/Code/skidsense';
  static const runningKey = 'claude:s-running';

  PairedHost paired({required String server, required int userId}) => PairedHost(
        hostId: host.hostId,
        hostKey: B64u.encode(host.hostStatic.pub),
        deviceId: 'dev-demo',
        name: 'Studio Mac',
        machine: 'studio',
        lanAddrs: const ['192.168.1.20'],
        lanPort: 47290,
        server: server,
        userId: userId,
        pairedAt: 1,
      );

  /// Everything is dated relative to when the host is made, so "1 minute
  /// ago" reads the same on every machine and in every time zone.
  final int _now = DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> _row(String key, String title, String runState, int minutesAgo, {String agent = 'claude', String? preview}) => {
        'key': key,
        'agent': agent,
        'workdir': root,
        'title': title,
        'preview': ?preview,
        'runState': runState,
        'createdAt': _now - (minutesAgo + 60) * 60000,
        'updatedAt': _now - minutesAgo * 60000,
      };

  late final List<Map<String, Object?>> rows = [
    _row(runningKey, 'Refactor the relay reconnect', 'awaiting-input', 1, preview: 'Waiting for approval to run the tests'),
    _row('codex:s-done', 'Add Traditional Chinese strings', 'done', 25, agent: 'codex', preview: 'Added 380 strings with Taiwan terms'),
    _row('claude:s-idle', 'Why does the LAN probe time out?', 'idle', 180),
    _row('claude:s-error', 'Upgrade the Gradle wrapper', 'error', 1440, preview: 'Network error while downloading'),
  ];

  Map<String, Object?> _finished() => {
        'taskId': 'task-0',
        'agent': 'claude',
        'workdir': root,
        'phase': 'done',
        'prompt': 'Where does the client decide between LAN and relay?',
        'text': '''The choice is made in `RcClient._dial()`:

1. **LAN first** — every known address is tried with a 2.5 s budget.
2. **Relay** gets a 700 ms head start delay, so a fast LAN wins.

```dart
final route = await Future.any([lan, relay]);
```

Whichever completes the handshake first is kept; the other is closed.''',
        'reasoning': '',
        'toolCalls': [
          {'id': 't1', 'name': 'Read', 'summary': 'lib/src/transport/rc_client.dart', 'status': 'done'},
          {'id': 't2', 'name': 'Grep', 'summary': '"relayHeadStart"', 'status': 'done'},
        ],
        'usage': {'contextTokens': 18400, 'outputTokens': 512},
      };

  Map<String, Object?> _live() => {
        'taskId': 'task-1',
        'agent': 'claude',
        'workdir': root,
        'phase': 'running',
        'prompt': 'Make reconnect resume the live turn, then run the tests.',
        'text': 'I changed `_resyncAfterReconnect` to re-open the session and fold the snapshot. Now running the tests.',
        'reasoning': '',
        'activity': 'Waiting for approval',
        'plan': {
          'steps': [
            {'text': 'Find where reconnect drops the live turn', 'status': 'completed'},
            {'text': 'Resync the snapshot after reconnect', 'status': 'completed'},
            {'text': 'Run the test suite', 'status': 'in_progress'},
          ],
        },
        'toolCalls': [
          {'id': 'l1', 'name': 'Read', 'summary': 'lib/src/app/app_controller.dart', 'status': 'done'},
          {'id': 'l2', 'name': 'Edit', 'summary': 'lib/src/app/app_controller.dart', 'status': 'done'},
          {'id': 'l3', 'name': 'Bash', 'summary': 'dart test test/app', 'status': 'running'},
        ],
        'interactions': [
          {
            'id': 'q1',
            'askedAt': _now - 30000,
            'question': {
              'kind': 'approval',
              'title': 'Run a command?',
              'detail': 'Claude wants to run the app tests.',
              'subject': {'type': 'command', 'command': 'dart test test/app --reporter expanded', 'cwd': root},
              'choices': [
                {'id': 'allow', 'label': 'Allow', 'kind': 'allow'},
                {'id': 'always', 'label': 'Always allow in this session', 'kind': 'allow_always'},
                {'id': 'deny', 'label': 'Deny', 'kind': 'deny'},
              ],
              'allowFreeText': true,
            },
          },
        ],
        'usage': {'contextTokens': 42100, 'outputTokens': 1830},
      };

  Object? _answer(String method, Object? params) {
    final p = params is Map<String, Object?> ? params : const <String, Object?>{};
    return switch (method) {
      'workspaces.list' => [
          {'id': 'w1', 'name': 'skidsense', 'path': root},
          {'id': 'w2', 'name': 'website', 'path': '/Users/me/Code/website'},
        ],
      'sessions.list' || 'sessions.search' => rows,
      'sessions.open' => {
          'row': rows.firstWhere((row) => row['key'] == p['key'], orElse: () => rows.first),
          'turns': [
            {'taskId': 'task-0', 'prompt': _finished()['prompt'], 'ok': true, 'startedAt': _now - 600000, 'endedAt': _now - 540000, 'snapshot': _finished()},
          ],
          'live': p['key'] == runningKey ? _live() : null,
        },
      'turn.snapshot' => p['key'] == runningKey ? _live() : null,
      'agents.list' => [
          {'id': 'claude', 'label': 'Claude Code', 'driven': true, 'installed': true, 'tui': true},
          {'id': 'codex', 'label': 'Codex', 'driven': true, 'installed': true, 'tui': true},
        ],
      'models.list' => {
          'agent': p['agent'] ?? 'claude',
          'models': [
            {'id': 'opus', 'label': 'Opus'},
            {'id': 'sonnet', 'label': 'Sonnet'},
          ],
        },
      'artifacts.list' => <Object?>[],
      'fs.list' => {
          'entries': [
            {'name': 'lib', 'path': 'lib', 'kind': 'dir'},
            {'name': 'test', 'path': 'test', 'kind': 'dir'},
            {'name': 'docs', 'path': 'docs', 'kind': 'dir'},
            {'name': 'pubspec.yaml', 'path': 'pubspec.yaml', 'kind': 'file', 'size': 1260, 'mtime': _now - 3600000, 'git': 'modified'},
            {'name': 'README.md', 'path': 'README.md', 'kind': 'file', 'size': 4820, 'mtime': _now - 86400000},
            {'name': 'analysis_options.yaml', 'path': 'analysis_options.yaml', 'kind': 'file', 'size': 412, 'mtime': _now - 172800000},
          ],
        },
      'fs.read' => {
          'path': p['path'],
          'encoding': 'utf8',
          'text': 'name: skidsense_core\ndescription: The SkidSense remote-control protocol.\nversion: 0.1.0\n\nenvironment:\n  sdk: ^3.13.0\n\ndependencies:\n  cryptography: 2.9.0\n  http: ^1.6.0\n',
          'size': 1260,
          'lines': 10,
          'etag': 'e1',
        },
      'git.snapshot' => {
          'repo': {'path': root, 'branch': 'feature/reconnect', 'shortSha': 'a190269', 'upstream': 'origin/feature/reconnect', 'ahead': 2, 'behind': 0},
          'files': [
            {'path': 'lib/src/app/app_controller.dart', 'status': 'modified', 'staged': true, 'insertions': 24, 'deletions': 6},
            {'path': 'test/app/reconnect_app_test.dart', 'status': 'modified', 'staged': false, 'insertions': 58, 'deletions': 2},
            {'path': 'lib/src/app/resync.dart', 'status': 'untracked', 'staged': false, 'insertions': 40, 'deletions': 0},
            {'path': 'docs/notes.md', 'status': 'deleted', 'staged': false, 'insertions': 0, 'deletions': 12},
          ],
          'conflicted': <String>[],
          'fetch': {'lastOkAt': _now - 300000},
        },
      'git.diff' => {
          'path': p['path'],
          'hunks': [
            {
              'header': '@@ -610,7 +610,9 @@ Future<void> connect(String hostId) async {',
              'lines': [
                {'kind': 'context', 'text': '    _grants.clear();', 'oldLine': 610, 'newLine': 610},
                {'kind': 'del', 'text': '    _client?.dispose();', 'oldLine': 611},
                {'kind': 'add', 'text': '    await _client?.dispose();', 'newLine': 611},
                {'kind': 'add', 'text': '    _resyncAfterReconnect();', 'newLine': 612},
                {'kind': 'context', 'text': '    final rc = RcClient(', 'oldLine': 612, 'newLine': 613},
              ],
            },
          ],
        },
      'git.branches' => [
          {'name': 'feature/reconnect', 'current': true},
          {'name': 'main'},
          {'name': 'origin/main', 'remote': true},
        ],
      _ => true,
    };
  }
}
