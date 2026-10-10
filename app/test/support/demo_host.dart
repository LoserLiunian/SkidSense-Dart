import 'package:skidsense_core/skidsense_core.dart';
import 'package:skidsense_core/testing.dart';

/// A desktop with something on it: four sessions (one running and waiting
/// for an approval), a workspace with files, a Git repository with changes,
/// and models and accounts to manage — served over the real protocol by
/// [FakeHost].
class DemoHost {
  DemoHost() : host = FakeHost(B64u.encode(Primitives.randomBytes(16)), Primitives.generateKeyPair()) {
    host
      ..handler = _answer
      ..features = const [Features.promptProviderId];
    grant(const ['sessions', 'prompt', 'approve', 'files', 'files.write', 'git', 'git.write', 'terminal']);
  }

  static const _methods = [
    'workspaces.list', 'sessions.list', 'sessions.open', 'sessions.new', 'sessions.rename', 'sessions.delete',
    'sessions.search', 'turn.snapshot', 'turn.prompt', 'turn.stop', 'turn.steer', 'turn.interact',
    'agents.list', 'models.list', 'artifacts.list', 'fs.list', 'fs.read', 'fs.write', 'fs.op',
    'search.start', 'search.cancel', 'git.snapshot', 'git.diff', 'git.branches', 'git.mutate',
    'tui.open', 'tui.input', 'tui.resize', 'tui.close', 'upload.begin', 'upload.chunk', 'upload.abort',
    'subscribe', 'mode.get', 'mode.set', 'accounts.list', 'accounts.presets', 'accounts.setActive',
    'accounts.saveGroup', 'accounts.removeGroup', 'accounts.remove', 'models.discover', 'models.context.list',
    'models.context.set', 'cloud.keys.models', 'cloud.assign', 'cloud.unassign', 'commands.list',
  ];

  /// What the desktop gives this phone: [scopes], and in `welcome.methods`
  /// the methods they reach, as the desktop lists them (spec §6.1).
  void grant(List<String> scopes) {
    host
      ..scopes = scopes
      ..methods = [for (final method in _methods) if (scopes.contains(Methods.scope[method] ?? Scopes.sessions)) method];
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
    // The agents too may be answered in place of the demo's own ([answers]).
    if (method == 'agents.list' && answers.containsKey(method)) {
      final answer = answers[method];
      if (answer is RemoteCallError) throw answer;
      return answer;
    }
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
      'turn.prompt' => {'ok': true, 'sessionKey': p['sessionKey'], 'taskId': 'task-sent'},
      'agents.list' => [
          {'id': 'claude', 'label': 'Claude Code', 'driven': true, 'installed': true, 'tui': true},
          {'id': 'codex', 'label': 'Codex', 'driven': true, 'installed': true, 'tui': true},
        ],
      'models.list' => _models(p['agent'] as String? ?? 'claude'),
      'commands.list' => commands,
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
      _ => _settings(method, p),
    };
  }

  // --- models and accounts (spec §7.1) -----------------------------------------------

  /// `local` or `cloud`.
  String mode = 'local';

  /// Every row, as `accounts.list` gives them: two accounts (one with two
  /// protocols), an endpoint from before accounts, two cloud assignments.
  late final List<Map<String, Object?>> providers = [
    {
      'id': 'ds-a', 'name': 'DeepSeek', 'note': 'Personal key, pay as you go', 'kind': 'anthropic', 'agents': <String>[],
      'baseUrl': 'https://api.deepseek.com/anthropic', 'models': ['deepseek-v4-pro', 'deepseek-flash'], 'hasKey': true,
      'source': 'byok', 'createdAt': _now - 86400000, 'dialect': 'anthropic', 'groupId': 'g-ds', 'presetId': 'deepseek',
      'modelMap': {'main': 'deepseek-v4-pro', 'haiku': 'deepseek-flash'}, 'extraEnv': {'API_TIMEOUT_MS': '600000'},
    },
    {
      'id': 'ds-c', 'name': 'DeepSeek', 'note': 'Personal key, pay as you go', 'kind': 'openai-compatible', 'agents': <String>[],
      'baseUrl': 'https://api.deepseek.com', 'models': ['deepseek-v4-pro', 'deepseek-flash'], 'hasKey': true,
      'source': 'byok', 'createdAt': _now - 86400000, 'dialect': 'openai-chat', 'groupId': 'g-ds', 'presetId': 'deepseek',
      'modelMap': {'main': 'deepseek-v4-pro'},
    },
    {
      'id': 'ol-c', 'name': 'Ollama on the Mac Studio', 'note': '', 'kind': 'openai-compatible', 'agents': <String>[],
      'baseUrl': 'http://192.168.1.20:11434/v1', 'models': ['qwen3-coder:30b', 'gpt-oss:20b'], 'hasKey': false,
      'source': 'byok', 'createdAt': _now - 3600000, 'dialect': 'openai-chat', 'groupId': 'g-ol', 'presetId': 'custom',
    },
    {
      'id': 'old-1', 'name': 'Old relay', 'note': '', 'kind': 'openai-compatible', 'agents': <String>[],
      'baseUrl': 'https://relay.example.com/v1', 'models': ['gpt-4.1'], 'hasKey': true, 'source': 'byok', 'createdAt': _now - 864000000,
    },
    {
      'id': 'fp-1', 'name': '第一方 · Claude Code · Laptop', 'note': '云端 Key「Laptop」', 'kind': 'anthropic', 'agents': ['claude'],
      'baseUrl': 'https://ai.surise.cn', 'models': ['claude-sonnet-5', 'claude-opus-5'], 'hasKey': true,
      'source': 'first-party', 'createdAt': _now - 7200000,
    },
    {
      'id': 'fp-2', 'name': '第一方 · Codex · Laptop', 'note': '云端 Key「Laptop」', 'kind': 'openai-compatible', 'agents': ['codex'],
      'baseUrl': 'https://ai.surise.cn/v1', 'models': ['gpt-5.6-codex'], 'hasKey': true,
      'source': 'first-party', 'createdAt': _now - 7200000,
    },
  ];

  final Map<String, Map<String, Object?>> active = {
    'claude': {'kind': 'account', 'providerId': 'ds-a'},
    'zcode': {'kind': 'cli'},
    'codex': {'kind': 'cli'},
    'qwen': {'kind': 'account', 'providerId': 'ol-c'},
    'dsh': {'kind': 'cli'},
    'gemini': {'kind': 'cli'},
  };

  /// Each account's revision, as `accounts.list` gives it to a phone with
  /// `settings`: a group's by its id, an older endpoint's by its own. A save
  /// moves it on.
  final Map<String, String> revisions = {'g-ds': 'rev-ds-1', 'g-ol': 'rev-ol-1', 'old-1': 'rev-old-1'};
  int _saves = 0;

  static const _conflict = {'ok': false, 'error': '这个账号已在别处修改，请重新载入后再保存', 'code': 'conflict'};

  /// `accounts.list`: a phone without `settings` reads the rows without
  /// their extra environment, and revisions of what it was shown — never
  /// the full ones, so a save from it is a conflict (spec §7).
  Map<String, Object?> _accounts() {
    final full = host.scopes.contains(Scopes.settings);
    return {
      'providers': full ? providers : [for (final row in providers) {...row}..remove('extraEnv')],
      'active': active,
      'harnesses': harnesses,
      'revisions': full ? revisions : {for (final MapEntry(:key, :value) in revisions.entries) key: 'redacted-$value'},
    };
  }

  /// Whether [sent] is the set of [now] (`revisionConflict` on the desktop):
  /// nothing sent is not checked.
  static bool _stale(Object? sent, List<String> now) {
    if (sent == null) return false;
    final read = sent is List ? sent.cast<String>() : [sent as String];
    return read.length != now.length || !now.every(read.contains);
  }

  /// `accounts.saveGroup` as the desktop's `planGroup` and `saveGuard` do
  /// it: the revisions of every account the save writes over — the group,
  /// each older endpoint it takes in — checked as a set, then the rows
  /// written and the revisions moved on.
  Map<String, Object?> _saveGroup(Map<String, Object?> p) {
    final groupId = p['groupId'] as String?;
    final endpoints = [for (final endpoint in p['endpoints']! as List) (endpoint as Map).cast<String, Object?>()];
    final existing = [for (final row in providers) if (groupId != null && row['groupId'] == groupId) row];
    if (groupId != null && existing.isEmpty) throw const RemoteCallError('not-found', '这个账号不存在，可能已被删除');
    final adopted = [
      for (final row in providers)
        if (row['source'] == 'byok' && row['groupId'] == null && endpoints.any((endpoint) => endpoint['id'] == row['id'])) row,
    ];
    final now = [if (existing.isNotEmpty) revisions[groupId]!, for (final row in adopted) revisions[row['id']]!];
    if (_stale(p['revision'], now)) return _conflict;
    final id = groupId ?? 'g-new-${++_saves}';
    final apiKey = p['apiKey'] as String?;
    final hadKey = [...existing, ...adopted].any((row) => row['hasKey'] == true);
    final written = [
      for (final (index, endpoint) in endpoints.indexed)
        {
          'id': endpoint['id'] ?? '$id-${index + 1}',
          'name': p['name'],
          'note': p['note'] ?? '',
          'kind': switch (endpoint['dialect']) { 'anthropic' => 'anthropic', 'gemini' => 'google', _ => 'openai-compatible' },
          'agents': <String>[],
          'baseUrl': endpoint['baseUrl'],
          'models': endpoint['models'] ?? const <String>[],
          'hasKey': apiKey == null ? hadKey : apiKey.isNotEmpty,
          'source': 'byok',
          'createdAt': _now,
          'dialect': endpoint['dialect'],
          'groupId': id,
          'presetId': ?p['presetId'],
          'modelMap': ?endpoint['modelMap'],
          'extraEnv': ?endpoint['extraEnv'],
        },
    ];
    providers
      ..removeWhere((row) => existing.contains(row) || adopted.contains(row))
      ..addAll(written);
    for (final row in adopted) {
      revisions.remove(row['id']);
    }
    final revision = revisions[id] = 'rev-$id-${++_saves}';
    host.emit(Events.accountsChanged, const {});
    return {'ok': true, 'groupId': id, 'ids': [for (final row in written) row['id']], 'revision': revision};
  }

  static const harnesses = [
    {'agent': 'claude', 'label': 'Claude Code', 'dialect': 'anthropic', 'official': true, 'installed': true, 'driven': true},
    {'agent': 'zcode', 'label': 'ZCode', 'dialect': 'anthropic', 'official': false, 'installed': false, 'driven': true},
    {'agent': 'codex', 'label': 'Codex', 'dialect': 'openai-responses', 'official': false, 'installed': true, 'driven': true},
    {'agent': 'qwen', 'label': 'Qwen Code', 'dialect': 'openai-chat', 'official': false, 'installed': true, 'driven': true},
    {'agent': 'dsh', 'label': 'dsh', 'dialect': 'openai-chat', 'official': false, 'installed': true, 'driven': false},
    {'agent': 'gemini', 'label': 'Gemini CLI', 'dialect': 'gemini', 'official': false, 'installed': false, 'driven': true},
  ];

  static Map<String, Object?> _preset(String id, String name, String category, [List<Map<String, Object?>> endpoints = const []]) =>
      {'id': id, 'name': name, 'websiteUrl': '', 'category': category, 'endpoints': endpoints};

  static final presets = [
    _preset('deepseek', 'DeepSeek', 'cn_official', [
      {
        'dialect': 'anthropic', 'baseUrl': 'https://api.deepseek.com/anthropic', 'models': ['deepseek-v4-pro', 'deepseek-flash'],
        'modelMap': {'main': 'deepseek-v4-pro', 'sonnet': 'deepseek-v4-pro', 'opus': 'deepseek-v4-pro', 'haiku': 'deepseek-flash'},
        'modelsUrl': 'https://api.deepseek.com/models', 'origin': 'cc-switch',
      },
      {
        'dialect': 'openai-responses', 'baseUrl': 'https://api.deepseek.com', 'models': ['deepseek-flash', 'deepseek-v4-pro'],
        'modelMap': {'main': 'deepseek-flash'}, 'modelsUrl': 'https://api.deepseek.com/models', 'origin': 'cc-switch',
      },
      {
        'dialect': 'openai-chat', 'baseUrl': 'https://api.deepseek.com', 'models': ['deepseek-v4-pro', 'deepseek-flash'],
        'modelMap': {'main': 'deepseek-v4-pro'}, 'modelsUrl': 'https://api.deepseek.com/models', 'origin': 'skidsense',
      },
    ]),
    _preset('zhipu', '智谱 GLM', 'cn_official'),
    _preset('zai', 'Z.ai GLM', 'cn_official'),
    _preset('kimi', 'Kimi（月之暗面）', 'cn_official'),
    _preset('kimi-global', 'Kimi Global', 'cn_official'),
    _preset('kimi-coding', 'Kimi For Coding', 'cn_official'),
    _preset('minimax', 'MiniMax', 'cn_official'),
    _preset('minimax-global', 'MiniMax Global', 'cn_official'),
    _preset('bailian', '阿里云百炼（千问）', 'cn_official'),
    _preset('mimo', '小米 MiMo', 'cn_official'),
    _preset('ark-coding', '火山方舟 Coding Plan', 'cn_official'),
    _preset('siliconflow', '硅基流动', 'aggregator'),
    _preset('openrouter', 'OpenRouter', 'aggregator'),
    _preset('google-ai-studio', 'Google AI Studio', 'cn_official'),
    _preset('custom', '自定义', 'custom', [
      for (final dialect in ['anthropic', 'openai-responses', 'openai-chat', 'gemini'])
        {'dialect': dialect, 'baseUrl': '', 'models': <String>[], 'origin': 'skidsense'},
    ]),
  ];

  static const presetNotice = 'Portions of the account presets are derived from cc-switch\n'
      '(https://github.com/farion1231/cc-switch), used under the MIT License:\n\nMIT License\n\nCopyright (c) 2025 Jason Young';

  /// `models.list` as the desktop's `Host.listModels` makes it: in cloud
  /// mode the assignments serving [agent]; in local mode its account's models
  /// (or the CLI's own), then the other endpoints of its protocol.
  Map<String, Object?> _models(String agent) {
    List<Map<String, Object?>> optionsOf(Map<String, Object?> row, [String? group]) {
      final main = (row['modelMap'] as Map?)?['main'] as String?;
      final ids = [if (main != null && !(row['models']! as List).contains(main)) main, ...(row['models']! as List).cast<String>()];
      return [
        for (final id in ids) {'id': id, 'label': '$id · ${row['name']}', 'description': row['baseUrl'], 'providerId': row['id'], 'group': ?group},
      ];
    }

    bool serves(Map<String, Object?> row) => (row['agents']! as List).isEmpty || (row['agents']! as List).contains(agent);
    if (mode == 'cloud') {
      final models = [for (final row in providers) if (row['source'] == 'first-party' && serves(row)) ...optionsOf(row)];
      return {'agent': agent, 'models': models, 'source': 'static', 'route': {'kind': 'cloud', 'defaultModel': models.firstOrNull?['id']}};
    }
    final dialect = harnesses.where((harness) => harness['agent'] == agent).firstOrNull?['dialect'];
    final choice = active[agent] ?? const {'kind': 'cli'};
    final byok = [
      for (final row in providers)
        if (row['source'] == 'byok' && (row['dialect'] == null ? serves(row) : dialect != null && row['dialect'] == dialect)) row,
    ];
    final account = choice['kind'] == 'account' ? byok.where((row) => row['id'] == choice['providerId'] && row['dialect'] != null).firstOrNull : null;
    final others = [for (final row in byok) if (!identical(row, account)) ...optionsOf(row, 'other')];
    if (account != null) {
      final map = account['modelMap'] as Map?;
      return {
        'agent': agent,
        'models': [...optionsOf(account, 'account'), ...others],
        'source': 'static',
        'route': {
          'kind': 'account',
          'accountId': account['id'],
          'accountName': account['name'],
          'defaultModel': map?['main'] ?? (account['models']! as List).firstOrNull,
        },
      };
    }
    return {
      'agent': agent,
      'models': [
        {'id': 'opus', 'label': 'Opus'},
        {'id': 'sonnet', 'label': 'Sonnet'},
        ...others,
      ],
      'source': 'static',
      'route': {'kind': choice['kind'] == 'official' ? 'official' : 'cli', 'defaultModel': null},
    };
  }

  /// The `/` menu (`commands.list`), in the harness's order.
  List<Map<String, Object?>> commands = [
    {'name': 'compact', 'description': 'Clear the conversation but keep a summary of it in context', 'argumentHint': '[instructions]', 'source': 'builtin'},
    {'name': 'clear', 'description': 'Clear the conversation history and free up context', 'aliases': ['reset', 'new'], 'source': 'builtin'},
    {'name': 'review', 'description': 'Review a pull request for correctness and style', 'argumentHint': '<pr>', 'source': 'command', 'scope': 'workspace'},
    {'name': 'release-notes', 'description': 'Draft release notes from the commits since the last tag', 'source': 'command', 'scope': 'global'},
    {'name': 'pdf', 'description': 'Read, fill in and merge PDF files', 'source': 'skill', 'store': 'claude'},
    {'name': 'frontend-design', 'description': 'Distinctive, intentional visual design for new UI', 'source': 'skill', 'store': 'skidsense'},
  ];

  /// The context table: a threshold set on one model, a window set on another.
  final Map<String, Map<String, Object?>> context = {};

  List<Map<String, Object?>> _contextRows() {
    Map<String, Object?> row(String key, Map<String, Object?> group, String modelId, String label, int window, String source, List<(String, String, String)> agents) {
      final set = context[key] ?? const {};
      return {
        'key': key,
        'group': group,
        'modelId': modelId,
        'label': label,
        'window': set['window'] ?? window,
        'windowSource': set['window'] == null ? source : 'custom',
        'compactAt': set['compactAt'],
        'agents': [for (final (agent, label, support) in agents) {'agent': agent, 'label': label, 'support': support}],
      };
    }

    const claude = ('claude', 'Claude Code', 'native');
    const codex = ('codex', 'Codex', 'managed');
    const qwen = ('qwen', 'Qwen Code', 'unsupported');
    final cloud = {'kind': 'cloud', 'id': 'fp-1', 'label': '云端 · 第一方 · Claude Code · Laptop'};
    final deepseek = {'kind': 'account', 'id': 'ds-a', 'label': 'DeepSeek'};
    final cli = {'kind': 'cli', 'id': 'claude', 'label': 'Claude Code 自带'};
    return [
      row('provider:claude:fp-1:claude-sonnet-5', cloud, 'claude-sonnet-5', 'claude-sonnet-5', 1000000, 'known', [claude]),
      row('provider:claude:fp-1:claude-opus-5', cloud, 'claude-opus-5', 'claude-opus-5', 200000, 'known', [claude]),
      row('provider:claude:ds-a:deepseek-v4-pro', deepseek, 'deepseek-v4-pro', 'deepseek-v4-pro', 128000, 'discovered', [claude, codex, qwen]),
      row('cli:claude:', cli, '', '默认模型', 200000, 'estimate', [claude]),
    ];
  }

  Map<String, Object?> _contextList() => {'rows': _contextRows(), 'compactMin': 10000, 'compactMax': 5000000};

  /// The models a cloud key offers (`cloud.keys.models`).
  static const keyModels = ['claude-sonnet-5', 'claude-opus-5', 'claude-haiku-4.5', 'gpt-5.6-codex', 'gpt-5.6', 'deepseek-v4-pro', 'gemini-3.6-pro'];

  /// The settings a phone sends, in order — what the screens are tested on.
  final List<(String, Map<String, Object?>)> settingsCalls = [];

  /// Answers in place of the desktop's own, by method — the settings
  /// methods' and `agents.list`: a value, a future of one (a request left
  /// open), or a [RemoteCallError] to refuse with.
  final Map<String, Object?> answers = {};

  /// What `models.discover` answers.
  Map<String, Object?> discoverAnswer = {
    'ok': true,
    'models': [
      {'id': 'deepseek-v4-pro', 'contextLength': 128000},
      {'id': 'deepseek-flash', 'contextLength': 128000},
      {'id': 'deepseek-reasoner'},
    ],
  };

  Object? _settings(String method, Map<String, Object?> p) {
    if (method.startsWith('mode.') || method.startsWith('accounts.') || method.startsWith('models.') || method.startsWith('cloud.')) {
      settingsCalls.add((method, p));
    }
    if (answers.containsKey(method)) {
      final answer = answers[method];
      if (answer is RemoteCallError) throw answer;
      return answer;
    }
    switch (method) {
      case 'mode.get':
        return {'mode': mode};
      case 'mode.set':
        if (p['mode'] == 'cloud' && !providers.any((row) => row['source'] == 'first-party')) {
          return {'ok': false, 'error': '云端模式需要先分配模型 —— 到「API Key」里选一把 Key 分配模型'};
        }
        mode = p['mode']! as String;
        host.emit(Events.modeChanged, {'mode': mode});
        return {'ok': true, 'mode': mode};
      case 'accounts.list':
        return _accounts();
      case 'accounts.presets':
        return {'presets': presets, 'notice': presetNotice};
      case 'accounts.setActive':
        active[p['agent']! as String] = p['choice']! as Map<String, Object?>;
        host.emit(Events.accountsChanged, const {});
        return {'ok': true};
      case 'accounts.saveGroup':
        return _saveGroup(p);
      case 'accounts.removeGroup':
        if (!providers.any((row) => row['groupId'] == p['groupId'])) throw const RemoteCallError('not-found', '这个账号不存在，可能已被删除');
        if (_stale(p['revision'], [revisions[p['groupId']]!])) return _conflict;
        providers.removeWhere((row) => row['groupId'] == p['groupId']);
        revisions.remove(p['groupId']);
        host.emit(Events.accountsChanged, const {});
        return {'ok': true};
      case 'accounts.remove':
        providers.removeWhere((row) => row['id'] == p['providerId']);
        revisions.remove(p['providerId']);
        host.emit(Events.accountsChanged, const {});
        return {'ok': true};
      case 'models.discover':
        return discoverAnswer;
      case 'models.context.list':
        return _contextList();
      case 'models.context.set':
        final entry = context.putIfAbsent(p['key']! as String, () => {});
        if (p.containsKey('compactAt')) entry['compactAt'] = p['compactAt'];
        if (p.containsKey('window')) entry['window'] = p['window'];
        host.emit(Events.modelsContextChanged, const {});
        return _contextList();
      case 'cloud.keys.models':
        return {'ok': true, 'models': keyModels};
      case 'cloud.assign':
        final made = [
          for (final assignment in p['assignments']! as List)
            '第一方 · ${(assignment as Map)['agent']} · ${p['keyName'] ?? '第一方 Key'}',
        ];
        host.emit(Events.accountsChanged, const {});
        return {'ok': true, 'providers': made};
      case 'cloud.unassign':
        providers.removeWhere((row) => row['id'] == p['providerId']);
        host.emit(Events.accountsChanged, const {});
        return {'ok': true};
    }
    return true;
  }
}
