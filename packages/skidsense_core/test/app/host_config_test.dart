import 'dart:async';
import 'dart:convert';

import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

import '../support/fake_host.dart';
import '../support/fake_time.dart';
import '../support/test_app.dart';

/// A host call answered by [answer], every call recorded.
class Calls {
  final List<(String, Object?)> log = [];
  FutureOr<Object?> Function(String method, Object? params) answer = (_, _) => null;

  Future<Object?> call(String method, Object? params) async {
    log.add((method, params));
    return answer(method, params);
  }

  Map<String, Object?> last(String method) => log.lastWhere((call) => call.$1 == method).$2! as Map<String, Object?>;
  int count(String method) => log.where((call) => call.$1 == method).length;
}

Map<String, Object?> accounts(String name) => {
      'providers': [
        {'id': 'r1', 'name': name, 'source': 'byok', 'dialect': 'anthropic', 'groupId': 'g1', 'hasKey': true},
      ],
      'active': {
        'claude': {'kind': 'account', 'providerId': 'r1'},
      },
      'harnesses': [
        {'agent': 'claude', 'label': 'Claude Code', 'dialect': 'anthropic', 'official': true, 'installed': true, 'driven': true},
      ],
      'revisions': {'g1': 'rev-$name'},
    };

/// The settings of the desktop's 模型管理 over `skidsense-rc/1` (spec §7.1):
/// what each call sends, what comes back however loosely shaped, and how the
/// screens' copies follow the host's change events.
void main() {
  group('requests', () {
    test('each method sends the parameters the spec names, and nothing else', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);

      await config.setMode('cloud');
      expect(calls.last('mode.set'), {'mode': 'cloud'});

      await config.setActive('claude', const AccountChoice.account('r1'));
      expect(calls.last('accounts.setActive'), {
        'agent': 'claude',
        'choice': {'kind': 'account', 'providerId': 'r1'},
      });
      await config.setActive('codex', const AccountChoice.cli());
      expect(calls.last('accounts.setActive'), {
        'agent': 'codex',
        'choice': {'kind': 'cli'},
      });

      await config.removeGroup('g1', revision: 'rev-1');
      expect(calls.last('accounts.removeGroup'), {'groupId': 'g1', 'revision': 'rev-1'});
      await config.removeLegacy('old-1');
      expect(calls.last('accounts.remove'), {'providerId': 'old-1'});

      await config.discoverModels(dialect: 'openai-chat', baseUrl: 'http://192.168.1.5:11434/v1', apiKey: '', providerId: 'r2', presetId: 'ollama');
      expect(calls.last('models.discover'), {
        'dialect': 'openai-chat',
        'baseUrl': 'http://192.168.1.5:11434/v1',
        'providerId': 'r2',
        'presetId': 'ollama',
      }, reason: "an empty key is no key: the stored one, if any, is the host's to use");
      await config.discoverModels(dialect: 'anthropic', baseUrl: 'https://api.example', apiKey: 'sk-typed');
      expect(calls.last('models.discover'), {'dialect': 'anthropic', 'baseUrl': 'https://api.example', 'apiKey': 'sk-typed'});

      await config.cloudKeyModels(7);
      expect(calls.last('cloud.keys.models'), {'keyId': 7});
      await config.cloudAssign(7, const [CloudAssignment(agent: 'claude', models: ['m1', 'm2'])], keyName: '  我的 Key ');
      expect(calls.last('cloud.assign'), {
        'keyId': 7,
        'keyName': '我的 Key',
        'assignments': [
          {
            'agent': 'claude',
            'models': ['m1', 'm2'],
          },
        ],
      });
      await config.cloudAssign(7, const [CloudAssignment(agent: 'codex', models: ['m'])], keyName: ' ');
      expect(calls.last('cloud.assign').containsKey('keyName'), isFalse, reason: 'blank: the desktop names it');
      await config.cloudUnassign('fp-1');
      expect(calls.last('cloud.unassign'), {'providerId': 'fp-1'});
    });

    test('models.context.set tells keeping, resetting and setting apart', () async {
      final calls = Calls()..answer = (_, _) => {'rows': <Object?>[]};
      final config = HostConfigController(calls.call);
      await config.setContext('cli:claude:');
      expect(calls.last('models.context.set'), {'key': 'cli:claude:'});
      await config.setContext('cli:claude:', compactAt: const Change(200000), window: const Change(null));
      expect(calls.last('models.context.set'), {'key': 'cli:claude:', 'compactAt': 200000, 'window': null});
    });

    test('a save carries the account back whole; other protocols send only the main slot', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true, 'groupId': 'g1', 'ids': ['r1', 'r2'], 'revision': 'rev-2'};
      final config = HostConfigController(calls.call);
      final snapshot = AccountsSnapshot.fromJson({
        'providers': [
          {
            'id': 'r1',
            'name': 'DeepSeek',
            'note': '公司的 key',
            'source': 'byok',
            'dialect': 'anthropic',
            'groupId': 'g1',
            'presetId': 'deepseek',
            'baseUrl': 'https://api.deepseek.com/anthropic',
            'models': ['deepseek-chat'],
            'modelMap': {'main': 'deepseek-chat', 'haiku': 'deepseek-chat'},
            'extraEnv': {'API_TIMEOUT_MS': '600000'},
            'contextWindows': {'deepseek-chat': 128000},
            'hasKey': true,
          },
          {
            'id': 'r2',
            'name': 'DeepSeek',
            'note': '公司的 key',
            'source': 'byok',
            'dialect': 'openai-chat',
            'groupId': 'g1',
            'presetId': 'deepseek',
            'baseUrl': 'https://api.deepseek.com',
            'models': ['deepseek-chat'],
            'modelMap': {'main': 'deepseek-chat', 'opus': 'ignored'},
            'extraEnv': {'IGNORED': '1'},
            'hasKey': true,
          },
          {'id': 'old', 'name': 'Old relay', 'source': 'byok', 'baseUrl': 'https://relay.example'},
          {'id': 'fp', 'name': 'Cloud', 'source': 'first-party', 'agents': ['claude']},
        ],
        'revisions': {'g1': 'rev-1', 'old': 'rev-old'},
      });
      final groups = snapshot.accounts;
      expect(groups.map((g) => g.key), ['g1', 'old'], reason: 'a cloud assignment is not an account');
      expect(groups.last.groupId, isNull);
      expect(groups.last.revision, 'rev-old');

      final result = await config.saveGroup(AccountGroupInput.fromGroup(groups.first).copyWith(name: 'DeepSeek 2'));
      expect(result.ok, isTrue);
      expect(result.groupId, 'g1');
      expect(result.ids, ['r1', 'r2']);
      expect(result.revision, 'rev-2');
      expect(calls.last('accounts.saveGroup'), {
        'groupId': 'g1',
        'revision': 'rev-1',
        'name': 'DeepSeek 2',
        'note': '公司的 key',
        'presetId': 'deepseek',
        'endpoints': [
          {
            'id': 'r1',
            'dialect': 'anthropic',
            'baseUrl': 'https://api.deepseek.com/anthropic',
            'models': ['deepseek-chat'],
            'modelMap': {'main': 'deepseek-chat', 'haiku': 'deepseek-chat'},
            'extraEnv': {'API_TIMEOUT_MS': '600000'},
          },
          {
            'id': 'r2',
            'dialect': 'openai-chat',
            'baseUrl': 'https://api.deepseek.com',
            'models': ['deepseek-chat'],
            'modelMap': {'main': 'deepseek-chat'},
          },
        ],
      }, reason: 'no apiKey (keep it), no contextWindows (keep them); the note and preset sent back as read');

      await config.saveGroup(const AccountGroupInput(name: 'New', apiKey: ''));
      expect(calls.last('accounts.saveGroup'), {'name': 'New', 'note': '', 'apiKey': '', 'endpoints': <Object?>[]});
    });

    // The host checks a revision against what the save writes over (spec §7):
    // the group, or an old endpoint taken in by its id. With neither the save
    // makes a new account, and a revision sent with it is refused as stale —
    // again after every reload.
    test('a revision goes only with a save that writes over what was read', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);
      final groups = AccountsSnapshot.fromJson({
        'providers': [
          {'id': 'old-1', 'name': 'Old relay', 'source': 'byok', 'dialect': 'anthropic', 'baseUrl': 'https://relay.example'},
          {'id': 'r1', 'name': 'DeepSeek', 'source': 'byok', 'dialect': 'anthropic', 'groupId': 'g1', 'baseUrl': 'https://api.deepseek.com/anthropic'},
        ],
        'revisions': {'old-1': 'rev-old', 'g1': 'rev-1'},
      }).accounts;
      const chat = AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'https://relay.example/v1', models: ['m']);

      final legacy = AccountGroupInput.fromGroup(groups.first);
      await config.saveGroup(legacy);
      expect(calls.last('accounts.saveGroup'), containsPair('revision', 'rev-old'), reason: 'it takes the old endpoint in');

      // Its protocol turned off, another turned on: the old endpoint stays
      // as it is, and the save is a new account.
      await config.saveGroup(legacy.copyWith(endpoints: [chat]));
      expect(calls.last('accounts.saveGroup'), {
        'name': 'Old relay',
        'note': '',
        'endpoints': [
          {'dialect': 'openai-chat', 'baseUrl': 'https://relay.example/v1', 'models': ['m']},
        ],
      });
      expect(legacy.copyWith(endpoints: [chat]).revision, 'rev-old', reason: 'kept, for when its protocol is turned back on');

      await config.saveGroup(AccountGroupInput.fromGroup(groups.last).copyWith(endpoints: [chat]));
      expect(calls.last('accounts.saveGroup'), allOf(containsPair('groupId', 'g1'), containsPair('revision', 'rev-1')),
          reason: 'the group is written over, whichever rows it keeps');
    });

    // A new account may take in two old endpoints at once: the host compares
    // each one's revision, as a set (spec §7, `revisionParam`).
    test('a new account taking in several old endpoints sends each one\'s revision', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);
      const merged = AccountGroupInput(
        name: 'Merged',
        revisions: ['rev-a', 'rev-b'],
        endpoints: [
          AccountEndpointInput(id: 'old-a', dialect: 'anthropic', baseUrl: 'https://a.example'),
          AccountEndpointInput(id: 'old-b', dialect: 'openai-chat', baseUrl: 'https://b.example/v1', models: ['m']),
        ],
      );
      expect(merged.problems, isEmpty);
      await config.saveGroup(merged);
      expect(calls.last('accounts.saveGroup')['revision'], ['rev-a', 'rev-b']);

      await config.saveGroup(merged.copyWith(revision: 'rev-a', revisions: const <String>[]));
      expect(calls.last('accounts.saveGroup')['revision'], 'rev-a', reason: 'an empty list is refused: the one goes instead');

      await config.saveGroup(merged.copyWith(endpoints: const [
        AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'https://b.example/v1', models: ['m']),
      ]));
      expect(calls.last('accounts.saveGroup').containsKey('revision'), isFalse, reason: 'it takes nothing in: a new account');

      final saved = merged.afterSave(const SaveGroupResult(ok: true, groupId: 'g-new', ids: ['old-a', 'old-b'], revision: 'R'));
      expect(saved.revisions, isNull);
      expect(saved.toJson()['revision'], 'R', reason: 'one account now: its own revision');
    });

    // Taken into a group, an old endpoint is written over as much as the
    // group: the host checks both, and the group's alone is a conflict.
    test('an edit taking an old endpoint into its group sends both revisions', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);
      const edit = AccountGroupInput(
        groupId: 'g1',
        revision: 'rev-g',
        revisions: ['rev-g', 'rev-old'],
        name: 'Mine',
        endpoints: [
          AccountEndpointInput(id: 'a1', dialect: 'anthropic', baseUrl: 'https://a.example'),
          AccountEndpointInput(id: 'old-a', dialect: 'gemini', baseUrl: 'https://g.example'),
        ],
      );
      expect(edit.problems, isEmpty);
      await config.saveGroup(edit);
      expect(calls.last('accounts.saveGroup'), allOf(containsPair('groupId', 'g1'), containsPair('revision', ['rev-g', 'rev-old'])));
    });

    test('revisions the host would refuse as bad-request are said before anything is sent', () {
      const merged = AccountGroupInput(
        name: 'Merged',
        endpoints: [AccountEndpointInput(id: 'old-a', dialect: 'anthropic', baseUrl: 'https://a.example')],
      );
      expect(merged.copyWith(revisions: ['1', '2', '3', '4', '5']).problems, isEmpty, reason: 'a group\'s, and one for each of four endpoints');
      expect(merged.copyWith(revisions: ['1', '2', '3', '4', '5', '6']).problems, [
        const AccountInputProblem('revision', AccountInputFault.tooMany, limit: 5),
      ]);
      expect(merged.copyWith(revisions: ['x' * 65]).problems, [
        const AccountInputProblem('revision', AccountInputFault.tooLong, limit: 64),
      ]);
      expect(merged.copyWith(revision: 'a\nb').problems, [const AccountInputProblem('revision', AccountInputFault.invalid)]);
      expect(merged.copyWith(endpoints: const [AccountEndpointInput(dialect: 'anthropic', baseUrl: 'https://a.example')], revision: 'x' * 65).problems,
          isEmpty, reason: 'a new account sends none');
    });

    test('an account saved is edited on with the groupId, revision and row ids the save gave', () async {
      final calls = Calls();
      final config = HostConfigController(calls.call);
      const created = AccountGroupInput(
        name: 'New',
        apiKey: 'sk-typed',
        endpoints: [
          AccountEndpointInput(dialect: 'anthropic', baseUrl: 'https://api.example/anthropic'),
          AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'https://api.example/v1', models: ['m']),
        ],
      );

      calls.answer = (_, _) => {'ok': false, 'error': '这个账号已在别处修改，请重新载入后再保存', 'code': 'conflict'};
      final refused = await config.saveGroup(created);
      expect(identical(created.afterSave(refused), created), isTrue, reason: 'nothing was saved');

      calls.answer = (_, _) => {'ok': true, 'groupId': 'g-new', 'ids': ['n1', 'n2'], 'revision': 'R'};
      final result = await config.saveGroup(created);
      expect((result.groupId, result.revision), ('g-new', 'R'));
      expect(result.ids, ['n1', 'n2']);

      await config.saveGroup(created.afterSave(result).copyWith(name: 'New 2'));
      expect(calls.last('accounts.saveGroup'), {
        'groupId': 'g-new',
        'revision': 'R',
        'name': 'New 2',
        'note': '',
        'endpoints': [
          {'id': 'n1', 'dialect': 'anthropic', 'baseUrl': 'https://api.example/anthropic', 'models': <Object?>[]},
          {'id': 'n2', 'dialect': 'openai-chat', 'baseUrl': 'https://api.example/v1', 'models': ['m']},
        ],
      }, reason: 'no apiKey: the one typed is stored now, and kept');
    });
  });

  // The desktop's own window keeps none of the remote limits: an account made
  // there reaches the phone over them, and saved back as read it would be
  // refused whole — renaming it included.
  group('remote limits', () {
    test('are the spec\'s (§7.1, §13)', () {
      expect(
        [SettingLimits.name, SettingLimits.note, SettingLimits.apiKey, SettingLimits.endpoints, SettingLimits.baseUrl],
        [100, 2000, 4096, 4, 2048],
      );
      expect([SettingLimits.models, SettingLimits.modelId, SettingLimits.discovered], [1000, 200, 5000]);
      expect([SettingLimits.extraEnv, SettingLimits.envName, SettingLimits.envValue], [32, 128, 4096]);
      expect([SettingLimits.windowMin, SettingLimits.windowMax], [1000, 100000000]);
      expect(
        [SettingLimits.keyModels, SettingLimits.assignAgents, SettingLimits.assignModels, SettingLimits.keyName],
        [5000, 16, 500, 100],
      );
      expect([SettingLimits.revision, SettingLimits.revisions], [64, 5]);
    });

    AccountGroup group(Map<String, Object?> anthropic, {Map<String, Object?> chat = const {}, String presetId = 'deepseek'}) =>
        AccountsSnapshot.fromJson({
          'providers': [
            {'id': 'r1', 'name': 'DeepSeek', 'source': 'byok', 'dialect': 'anthropic', 'groupId': 'g1', 'presetId': presetId, ...anthropic},
            {'id': 'r2', 'name': 'DeepSeek', 'source': 'byok', 'dialect': 'openai-chat', 'groupId': 'g1', 'presetId': presetId, ...chat},
          ],
          'revisions': {'g1': 'rev-1'},
        }).accounts.single;

    test('an account within them has no problems', () {
      final input = AccountGroupInput.fromGroup(group(
        {'baseUrl': 'https://api.deepseek.com/anthropic', 'models': ['deepseek-chat'], 'extraEnv': {'API_TIMEOUT_MS': '600000'}},
        // Not sent for any protocol but Anthropic's: not the host's to refuse.
        chat: {'baseUrl': 'https://api.deepseek.com', 'models': ['deepseek-chat'], 'extraEnv': {'BAD\u0000': '1'}},
      ));
      expect(input.problems, isEmpty);
      expect(input.copyWith(apiKey: '').problems, isEmpty, reason: "'' clears the key");
      expect(input.copyWith(apiKey: 'sk-${'a' * 4093}').problems, isEmpty);
    });

    test('one the desktop saved over them says where, before anything is sent', () {
      final fetched = [for (var index = 0; index < 1001; index++) 'model-$index'];
      final longId = 'x' * 201;
      final input = AccountGroupInput.fromGroup(group({
        'name': '  ${'名' * 101}  ',
        'note': 'a\u0007bell',
        'baseUrl': 'https://api.example/anthropic',
        'models': [...fetched, longId, '   ', 'tab\tinside'],
        'modelMap': {'main': 'model-1', 'opus': 'z' * 201, 'haiku': '  '},
        'extraEnv': {
          for (var index = 0; index < 32; index++) 'VAR_$index': '$index',
          'N' * 129: '1',
          'LONG': 'v' * 4097,
        },
      }, chat: {
        'baseUrl': 'https://api.example/v1 ',
        'models': ['ok'],
        // Only `main` goes out for this protocol: a bad other slot is not sent.
        'modelMap': {'main': 'm\u0001', 'opus': 'z' * 201},
      })).copyWith(apiKey: 'sk-with space');

      expect(input.problems, [
        const AccountInputProblem('name', AccountInputFault.tooLong, limit: 100),
        const AccountInputProblem('note', AccountInputFault.invalid),
        const AccountInputProblem('apiKey', AccountInputFault.invalid),
        const AccountInputProblem('models', AccountInputFault.tooMany, dialect: 'anthropic', limit: 1000),
        AccountInputProblem('models', AccountInputFault.tooLong, dialect: 'anthropic', limit: 200, value: longId),
        const AccountInputProblem('models', AccountInputFault.empty, dialect: 'anthropic', value: '   '),
        const AccountInputProblem('models', AccountInputFault.invalid, dialect: 'anthropic', value: 'tab\tinside'),
        const AccountInputProblem('modelMap', AccountInputFault.tooLong, dialect: 'anthropic', limit: 200, value: 'opus'),
        const AccountInputProblem('extraEnv', AccountInputFault.tooMany, dialect: 'anthropic', limit: 32),
        AccountInputProblem('extraEnv', AccountInputFault.tooLong, dialect: 'anthropic', limit: 128, value: 'N' * 129),
        const AccountInputProblem('extraEnv', AccountInputFault.tooLong, dialect: 'anthropic', limit: 4096, value: 'LONG'),
        const AccountInputProblem('baseUrl', AccountInputFault.invalid, dialect: 'openai-chat'),
        const AccountInputProblem('modelMap', AccountInputFault.invalid, dialect: 'openai-chat', value: 'main'),
      ]);
      expect(input.copyWith(apiKey: 'k' * 4097).problems, contains(const AccountInputProblem('apiKey', AccountInputFault.tooLong, limit: 4096)));
    });

    // The host takes a window only for a model the endpoint keeps (the ids
    // trimmed, as it keeps them) and only within 1–1e8; one more is the whole
    // save refused. Fetched windows cover every model found, the user keeps a few.
    test('only the windows of the models kept go out, and only those in range', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);
      const endpoint = AccountEndpointInput(
        dialect: 'openai-chat',
        baseUrl: 'https://api.example/v1',
        models: ['kept', ' padded '],
        contextWindows: {'kept': 128000, 'padded': 64000, ' padded ': 32000, 'not-kept': 200000},
      );
      final input = const AccountGroupInput(name: 'A', endpoints: [endpoint]);
      expect(input.problems, isEmpty, reason: 'a window of a model not kept is moot, not wrong');
      await config.saveGroup(input);
      expect((calls.last('accounts.saveGroup')['endpoints']! as List).single, {
        'dialect': 'openai-chat',
        'baseUrl': 'https://api.example/v1',
        'models': ['kept', ' padded '],
        'contextWindows': {'kept': 128000, 'padded': 64000},
      });

      const wild = AccountEndpointInput(
        dialect: 'anthropic',
        baseUrl: 'https://api.example/anthropic',
        models: ['zero', 'huge', 'max', 'min'],
        contextWindows: {'zero': 0, 'huge': 100000001, 'max': 100000000, 'min': 1, 'gone': -1},
      );
      expect(const AccountGroupInput(name: 'B', endpoints: [wild]).problems, [
        const AccountInputProblem('contextWindows', AccountInputFault.outOfRange, dialect: 'anthropic', limit: 100000000, value: 'zero'),
        const AccountInputProblem('contextWindows', AccountInputFault.outOfRange, dialect: 'anthropic', limit: 100000000, value: 'huge'),
      ], reason: 'the model would save without its window');
      expect(wild.toJson()['contextWindows'], {'max': 100000000, 'min': 1});

      const none = AccountEndpointInput(dialect: 'gemini', baseUrl: 'https://g.example', models: ['m'], contextWindows: {'other': 1000});
      expect(none.toJson()['contextWindows'], isEmpty, reason: 'still replaces the stored ones, as the desktop form does');
      expect(const AccountEndpointInput(dialect: 'gemini', baseUrl: 'https://g.example').toJson(), isNot(contains('contextWindows')),
          reason: 'none at all keeps the stored ones');
    });

    // An endpoint from before accounts has no protocol: the host refuses an
    // endpoint with none (or with '') as a bad request.
    test('an old endpoint has no protocol until one is chosen, and is not sent without one', () async {
      final calls = Calls()..answer = (_, _) => {'ok': true};
      final config = HostConfigController(calls.call);
      final groups = AccountsSnapshot.fromJson({
        'providers': [
          {'id': 'old-1', 'name': 'Old relay', 'source': 'byok', 'baseUrl': 'https://relay.example', 'models': ['m']},
          {'id': 'old-2', 'name': 'Older relay', 'source': 'byok', 'dialect': '', 'baseUrl': 'https://older.example'},
        ],
        'revisions': {'old-1': 'rev-old', 'old-2': 'rev-older'},
      }).accounts;
      final legacy = AccountGroupInput.fromGroup(groups.first);
      expect(legacy.endpoints.single.dialect, isNull);
      expect(AccountGroupInput.fromGroup(groups.last).endpoints.single.dialect, isNull, reason: "'' is none either");
      expect(legacy.problems, [const AccountInputProblem('dialect', AccountInputFault.empty)]);
      await expectLater(config.saveGroup(legacy), throwsStateError);
      expect(calls.log, isEmpty, reason: 'nothing the host would refuse whole is sent');

      final chosen = legacy.copyWith(endpoints: [
        const AccountEndpointInput(id: 'old-1', dialect: 'openai-chat', baseUrl: 'https://relay.example', models: ['m']),
      ]);
      expect(chosen.problems, isEmpty);
      await config.saveGroup(chosen);
      expect(calls.last('accounts.saveGroup'), {
        'revision': 'rev-old',
        'name': 'Old relay',
        'note': '',
        'endpoints': [
          {'id': 'old-1', 'dialect': 'openai-chat', 'baseUrl': 'https://relay.example', 'models': ['m']},
        ],
      });
    });

    test('a preset the desktop no longer lists is left out of the save; one it lists is kept', () {
      const catalog = PresetCatalog(presets: [AccountPreset(id: 'deepseek'), AccountPreset(id: 'kimi')]);
      final stored = group({'baseUrl': 'https://api.deepseek.com/anthropic'});
      expect(AccountGroupInput.fromGroup(stored, presets: catalog).toJson()['presetId'], 'deepseek');
      final gone = group({'baseUrl': 'https://api.example/anthropic'}, presetId: 'retired-vendor');
      final input = AccountGroupInput.fromGroup(gone, presets: catalog);
      expect(input.presetId, isNull);
      expect(input.toJson(), isNot(contains('presetId')), reason: 'the host refuses a save naming a preset it does not have');
      expect(AccountGroupInput.fromGroup(gone).presetId, 'retired-vendor', reason: 'with no catalog to tell, it stays as stored');
    });
  });

  // `accountProblem` in the desktop's src/shared/accounts.ts: the host runs
  // it on every save and answers its first finding in its own words.
  group("the desktop's own rules", () {
    const fine = AccountGroupInput(name: 'DeepSeek', endpoints: [
      AccountEndpointInput(
        dialect: 'anthropic',
        baseUrl: 'https://api.deepseek.com/anthropic',
        extraEnv: {'API_TIMEOUT_MS': '600000', 'CLAUDE_CODE_MAX_OUTPUT_TOKENS': '64000'},
      ),
      AccountEndpointInput(dialect: 'openai-responses', baseUrl: 'http://192.168.1.20:11434/v1', modelMap: ModelMap(main: 'qwen3')),
      AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'http://[::1]:8080/v1'),
      // Variables go out for Anthropic's alone: another protocol's are not checked.
      AccountEndpointInput(dialect: 'gemini', baseUrl: 'https://g.example', extraEnv: {'lower': '1'}),
    ]);

    test('an account they take has no problems', () {
      expect(fine.accountProblems, isEmpty);
      expect(fine.problems, isEmpty);
    });

    test('each is said where it is', () {
      const input = AccountGroupInput(name: '   ', endpoints: [
        AccountEndpointInput(dialect: 'anthropic', baseUrl: '', extraEnv: {'lower_case': '1', 'ANTHROPIC_BASE_URL': 'x', 'GITHUB_TOKEN': 'y', 'https_proxy': 'z', 'OK_VAR': '1'}),
        AccountEndpointInput(dialect: 'openai-responses', baseUrl: 'api.example.com/v1', models: ['  '], modelMap: ModelMap(main: ' ')),
        AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'ftp://files.example'),
        AccountEndpointInput(dialect: 'openai-chat', baseUrl: 'localhost:11434'),
        AccountEndpointInput(dialect: 'gemini', baseUrl: 'https://'),
      ]);
      expect(input.accountProblems, [
        const AccountInputProblem('name', AccountInputFault.missing),
        const AccountInputProblem('baseUrl', AccountInputFault.missing, dialect: 'anthropic'),
        const AccountInputProblem('extraEnv', AccountInputFault.badName, dialect: 'anthropic', value: 'lower_case'),
        const AccountInputProblem('extraEnv', AccountInputFault.reserved, dialect: 'anthropic', value: 'ANTHROPIC_BASE_URL'),
        const AccountInputProblem('extraEnv', AccountInputFault.reserved, dialect: 'anthropic', value: 'GITHUB_TOKEN'),
        const AccountInputProblem('extraEnv', AccountInputFault.badName, dialect: 'anthropic', value: 'https_proxy'),
        const AccountInputProblem('baseUrl', AccountInputFault.notAddress, dialect: 'openai-responses'),
        const AccountInputProblem('models', AccountInputFault.missing, dialect: 'openai-responses'),
        const AccountInputProblem('baseUrl', AccountInputFault.notHttp, dialect: 'openai-chat'),
        const AccountInputProblem('dialect', AccountInputFault.duplicate, dialect: 'openai-chat', value: 'openai-chat'),
        const AccountInputProblem('baseUrl', AccountInputFault.notHttp, dialect: 'openai-chat'),
        const AccountInputProblem('baseUrl', AccountInputFault.notAddress, dialect: 'gemini'),
      ]);
    });

    test('none turned on, a protocol unknown; what the remote limits say is not said twice', () {
      expect(const AccountGroupInput(name: 'A').accountProblems, [const AccountInputProblem('endpoints', AccountInputFault.missing)]);
      expect(const AccountGroupInput(name: 'A', endpoints: [AccountEndpointInput(dialect: 'future', baseUrl: 'https://a.example')]).accountProblems,
          [const AccountInputProblem('dialect', AccountInputFault.invalid, dialect: 'future', value: 'future')]);
      const spaced = AccountGroupInput(name: 'A', endpoints: [
        AccountEndpointInput(dialect: 'anthropic', baseUrl: 'https://api.deepseek .com'),
        AccountEndpointInput(dialect: null, baseUrl: 'nowhere'),
      ]);
      expect(spaced.problems, [
        const AccountInputProblem('baseUrl', AccountInputFault.invalid, dialect: 'anthropic'),
        const AccountInputProblem('dialect', AccountInputFault.empty),
      ]);
      expect(spaced.accountProblems, isEmpty);
    });
  });

  group('answers', () {
    test('settings answers decode leniently', () {
      final snapshot = AccountsSnapshot.fromJson(jsonDecode('''{
        "providers": [{"id": "r1", "name": 5, "agents": ["claude", 3], "models": "x", "createdAt": 1.5e12,
                       "contextWindows": {"m": 128000.0, "n": "big"}, "extraEnv": {"A": "1", "B": 2}, "future": true}, 7],
        "active": {"claude": {"kind": "official"}, "codex": "cli", "gemini": {"kind": "telepathy"}},
        "harnesses": [{"agent": "claude"}],
        "revisions": {"g1": "r", "g2": 3}
      }''') as Map<String, Object?>);
      final row = snapshot.providers.single;
      expect(row.name, '');
      expect(row.agents, ['claude']);
      expect(row.models, isEmpty);
      expect(row.createdAt, 1500000000000);
      expect(row.contextWindows, {'m': 128000});
      expect(row.extraEnv, {'A': '1'});
      expect(row.source, 'byok');
      expect(row.legacy, isTrue);
      expect(snapshot.choiceFor('claude'), const AccountChoice.official());
      expect(snapshot.choiceFor('codex'), const AccountChoice.cli(), reason: 'not an object: the default');
      expect(snapshot.choiceFor('gemini').kind, 'telepathy');
      expect(snapshot.harnesses.single.installed, isFalse);
      expect(snapshot.revisions, {'g1': 'r'});

      final context = ModelContextList.fromJson(jsonDecode('''{
        "rows": [{"key": "provider:r1:m", "group": {"kind": "account", "id": "g1", "label": "DeepSeek"},
                  "window": 131072.0, "compactAt": null, "agents": [{"agent": "claude", "support": "native"}]}]
      }''') as Map<String, Object?>);
      expect(context.compactMin, 10000);
      expect(context.compactMax, 5000000);
      expect(context.rows.single.window, 131072);
      expect(context.rows.single.compactAt, isNull);
      expect(context.rows.single.group.label, 'DeepSeek');
      expect(context.rows.single.agents.single.support, 'native');

      final discovered = DiscoverResult.fromJson({
        'ok': false,
        'error': '密钥被拒绝（401），检查这个端点的 Key',
        'code': 'http',
        'status': 401,
      });
      expect((discovered.ok, discovered.code, discovered.status), (false, 'http', 401));
      expect(DiscoverResult.fromJson({'ok': false, 'error': 'x', 'code': 'brand-new'}).code, isNull,
          reason: 'an unknown code is no code');
      final found = DiscoverResult.fromJson({
        'ok': true,
        'models': [
          {'id': 'a', 'name': 'A', 'contextLength': 8192},
          {'id': 'b'},
          'c',
        ],
        'truncated': true,
      });
      expect(found.models.map((m) => (m.id, m.name, m.contextLength)), [('a', 'A', 8192), ('b', null, null)]);
      expect(found.truncated, isTrue);
      expect(SettingResult.fromJson(const {}).ok, isFalse);

      final presets = PresetCatalog.fromJson({
        'presets': [
          {
            'id': 'deepseek',
            'name': 'DeepSeek',
            'category': 'cn_official',
            'endpoints': [
              {'dialect': 'anthropic', 'baseUrl': 'https://api.deepseek.com/anthropic', 'models': ['deepseek-chat'], 'origin': 'cc-switch'},
            ],
          },
        ],
        'notice': 'MIT License',
      });
      expect(presets.presets.single.endpoints.single.origin, 'cc-switch');
      expect(presets.notice, 'MIT License');

      final command = SlashCommand.fromJson({'name': 'review', 'aliases': ['r'], 'source': 'skill', 'store': 'claude'});
      expect((command.name, command.source, command.store), ('review', 'skill', 'claude'));
      expect(command.aliases, ['r']);
    });

    test('an answer that is not an object is an error, not a value', () async {
      final calls = Calls()..answer = (_, _) => true;
      final config = HostConfigController(calls.call);
      await expectLater(config.setMode('local'), throwsA(isA<RcException>().having((e) => e.code, 'code', 'bad-response')));
      await config.loadAccounts();
      expect(config.accounts.value.value, isNull);
      expect(config.accounts.value.error, isA<RcException>());
    });

    test('models.list carries the provider and the group of each model', () {
      final catalog = ModelCatalog.fromJson({
        'agent': 'claude',
        'models': [
          {'id': 'deepseek-chat', 'label': 'deepseek-chat', 'live': false, 'providerId': 'r1', 'group': 'account'},
          {'id': 'opus', 'label': 'Opus', 'live': false},
        ],
        'route': {'kind': 'account', 'accountId': 'r1', 'accountName': 'DeepSeek', 'defaultModel': 'deepseek-chat'},
      });
      expect((catalog.models.first.providerId, catalog.models.first.group), ('r1', 'account'));
      expect((catalog.models.last.providerId, catalog.models.last.group), (null, null));
      expect((catalog.route?.kind, catalog.route?.accountId), ('account', 'r1'));
    });
  });

  group('the screens\' copies', () {
    test('a reconnect drops what the old connection brings back, and reads again', () async {
      final answers = <Completer<Object?>>[];
      final calls = Calls()
        ..answer = (_, _) {
          final answer = Completer<Object?>();
          answers.add(answer);
          return answer.future;
        };
      final config = HostConfigController(calls.call);
      final unwatch = config.watchAccounts();
      expect(config.accounts.value.loading, isTrue);
      config.reconnected();
      expect(calls.count('accounts.list'), 2, reason: 'what a screen shows is read again on the new connection');

      answers[1].complete(accounts('new'));
      await Future<void>.delayed(Duration.zero);
      expect(config.accounts.value.value?.revisions['g1'], 'rev-new');
      answers[0].complete(accounts('old'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(config.accounts.value.value?.revisions['g1'], 'rev-new', reason: 'the old connection\'s answer is not kept');

      unwatch();
      config.reset();
      expect(config.accounts.value.value, isNull, reason: 'another host: nothing of this one');
      config.onEvent(Events.accountsChanged, const {});
      expect(calls.count('accounts.list'), 2, reason: 'and no screen watches anything there yet');
    });

    test('a failure of the old connection does not show on the new one', () async {
      final answers = <Completer<Object?>>[];
      final calls = Calls()
        ..answer = (_, _) {
          final answer = Completer<Object?>();
          answers.add(answer);
          return answer.future;
        };
      final config = HostConfigController(calls.call);
      config.watchContext();
      config.reconnected();
      answers[0].completeError(const ConnectionClosed('peer-closed'));
      await Future<void>.delayed(Duration.zero);
      expect(config.context.value.error, isNull);
      expect(config.context.value.loading, isTrue);
      answers[1].complete({'rows': <Object?>[]});
      await Future<void>.delayed(Duration.zero);
      expect(config.context.value.value?.rows, isEmpty);
      expect(config.context.value.loading, isFalse);
    });

    // A screen can watch before the first connection is up — the tab opened
    // as the phone connects: its read fails `offline`, and nothing else would
    // read it again until a pull to refresh.
    test('what a screen watched but could not read before the first connection is read once it is up', () async {
      var online = false;
      final calls = Calls()
        ..answer = (method, _) => online ? (method == 'mode.get' ? {'mode': 'cloud'} : accounts('up')) : throw const RcException('offline');
      final config = HostConfigController(calls.call);
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      config.reset();
      final unwatch = config.watchAccounts();
      config.watchMode()();
      await settle();
      expect(config.accounts.value.error, isA<RcException>());
      await config.loadContext();
      expect(config.context.value.error, isA<RcException>());

      online = true;
      config.connected(['sessions']);
      await settle();
      expect(calls.count('accounts.list'), 2);
      expect(config.accounts.value.value?.revisions['g1'], 'rev-up');
      expect(config.accounts.value.error, isNull);
      expect(calls.count('mode.get'), 1, reason: 'no longer watched');
      expect(calls.count('models.context.list'), 1, reason: 'read once, never watched');
      unwatch();
    });

    test('what a screen kept watching across a reset is read on the next first connection, once', () async {
      final answers = <Completer<Object?>>[];
      final calls = Calls()
        ..answer = (_, _) {
          final answer = Completer<Object?>();
          answers.add(answer);
          return answer.future;
        };
      final config = HostConfigController(calls.call);
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      config.connected(['sessions']);
      config.watchAccounts();
      answers.last.complete(accounts('a'));
      await settle();
      expect(config.accounts.value.value?.revisions['g1'], 'rev-a');

      config.reset();
      expect(config.accounts.value.value, isNull);
      config.connected(['sessions']);
      expect(calls.count('accounts.list'), 2, reason: 'the screen still shows it: read for the new connection');
      config.reset();
      unawaited(config.loadAccounts());
      config.connected(['sessions']);
      expect(calls.count('accounts.list'), 3, reason: 'a read already out is not doubled');
      answers.last.complete(accounts('b'));
      await settle();
      expect(config.accounts.value.value?.revisions['g1'], 'rev-b');
    });

    test('the mode in an event wins over a read that left before it', () async {
      final answer = Completer<Object?>();
      final calls = Calls()..answer = (_, _) => answer.future;
      final config = HostConfigController(calls.call);
      final load = config.loadMode();
      config.onEvent(Events.modeChanged, {'mode': 'cloud'});
      expect(config.mode.value.value, 'cloud');
      answer.complete({'mode': 'local'});
      await load;
      expect(config.mode.value.value, 'cloud');
      expect(config.mode.value.loading, isFalse);
      expect(calls.count('mode.get'), 1, reason: 'the event carried the mode: nothing to read');
    });

    test('what nobody watches is only marked out of date, and read as it is watched again', () async {
      final calls = Calls();
      int reads() => calls.count('accounts.list');
      calls.answer = (_, _) => accounts('v${reads()}');
      final config = HostConfigController(calls.call);
      Future<void> settle() => Future<void>.delayed(Duration.zero);

      final first = config.watchAccounts();
      await settle();
      expect(reads(), 1);
      final second = config.watchAccounts();
      await settle();
      expect(reads(), 1, reason: 'what is held is current: a second screen reads nothing');

      first();
      config.onEvent(Events.accountsChanged, const {});
      await settle();
      expect(reads(), 2, reason: 'a screen still watches');
      second();
      second();
      config
        ..onEvent(Events.accountsChanged, const {})
        ..onEvent(Events.accountsChanged, const {});
      await settle();
      expect(reads(), 2, reason: 'nobody watches: over the relay a whole list is not read for nobody');
      expect(config.accounts.value.value?.revisions['g1'], 'rev-v2');

      final again = config.watchAccounts();
      await settle();
      expect(reads(), 3, reason: 'out of date: read as it is watched again');
      expect(config.accounts.value.value?.revisions['g1'], 'rev-v3');
      config.onEvent(Events.accountsChanged, const {});
      await settle();
      expect(reads(), 4, reason: 'one watch, counted once: closing the last one twice did not undo it');
      again();

      await config.loadAccounts();
      expect(reads(), 5);
      config.onEvent(Events.accountsChanged, const {});
      await settle();
      expect(reads(), 5, reason: 'a read asked for once is not a watch');
    });

    test('accounts.changed reads the context rows again: they come from the accounts', () async {
      final calls = Calls()..answer = (method, _) => method == 'models.context.list' ? {'rows': <Object?>[]} : accounts('x');
      final config = HostConfigController(calls.call);
      config.watchContext();
      await Future<void>.delayed(Duration.zero);
      expect(calls.count('models.context.list'), 1);
      config.onEvent(Events.accountsChanged, const {});
      await Future<void>.delayed(Duration.zero);
      expect(calls.count('models.context.list'), 2);
      expect(calls.count('accounts.list'), 0, reason: 'nobody watches the accounts');
    });

    // `mode.changed` carries the mode: once held it needs no screen to stay
    // current — until a reconnect, as the events of the time away reached
    // nobody.
    for (final (label, hold) in <(String, Future<void> Function(HostConfigController))>[
      ('an event', (config) async => config.onEvent(Events.modeChanged, {'mode': 'cloud'})),
      ('a mode.set', (config) => config.setMode('cloud')),
    ]) {
      test('a mode held from $label is read again after a reconnect', () async {
        final calls = Calls()..answer = (method, _) => method == 'mode.set' ? {'ok': true, 'mode': 'cloud'} : {'mode': 'local'};
        final config = HostConfigController(calls.call);
        await hold(config);
        expect(config.mode.value.value, 'cloud');
        expect(calls.count('mode.get'), 0);
        config.reconnected();
        await Future<void>.delayed(Duration.zero);
        expect(calls.count('mode.get'), 1);
        expect(config.mode.value.value, 'local', reason: 'switched back while the phone was away');
      });
    }

    test('a mode never held is not read on a reconnect', () async {
      final calls = Calls()..answer = (_, _) => {'mode': 'local'};
      final config = HostConfigController(calls.call);
      config.reconnected();
      await Future<void>.delayed(Duration.zero);
      expect(calls.count('mode.get'), 0);
    });

    // `accounts.list` hides the extra environment from a device without
    // `settings` (spec §7.1). Saved from such a copy — a save is whole — the
    // account would lose it.
    test('accounts read under other scopes are dropped on the reconnect', () async {
      final answers = <Completer<Object?>>[];
      final calls = Calls()
        ..answer = (_, _) {
          final answer = Completer<Object?>();
          answers.add(answer);
          return answer.future;
        };
      final config = HostConfigController(calls.call);
      Future<void> settle() => Future<void>.delayed(Duration.zero);
      String? shown() => config.accounts.value.value?.revisions['g1'];

      config.connected(['sessions', 'prompt']);
      final unwatch = config.watchAccounts();
      answers.last.complete(accounts('a'));
      await settle();
      expect(shown(), 'rev-a');

      config.connected(['prompt', 'sessions']);
      expect(calls.count('accounts.list'), 2);
      expect(shown(), 'rev-a', reason: 'the same scopes: shown while it is read again');
      answers.last.complete(accounts('b'));
      await settle();

      config.connected(['sessions', 'prompt', 'settings']);
      expect(calls.count('accounts.list'), 3);
      expect(config.accounts.value.value, isNull, reason: 'read without settings: not one to edit from');
      expect(config.accounts.value.loading, isTrue);
      answers.last.complete(accounts('c'));
      await settle();
      expect(shown(), 'rev-c');

      unwatch();
      config.connected(['sessions', 'prompt']);
      expect(config.accounts.value.value, isNull);
      expect(calls.count('accounts.list'), 3, reason: 'nobody watches: read when one does');
      config.watchAccounts();
      expect(calls.count('accounts.list'), 4);
    });

    test('the table models.context.set answers with is the one shown', () async {
      final calls = Calls()
        ..answer = (method, _) => {
              'rows': [
                {'key': method == 'models.context.set' ? 'after' : 'before'},
              ],
            };
      final config = HostConfigController(calls.call);
      await config.loadContext();
      await config.setContext('before', compactAt: const Change(100000));
      expect(config.context.value.value?.rows.single.key, 'after');
    });
  });

  group('the / menu', () {
    test('a list is shared while it comes, reused for 5 s, and a failure is not kept', () => runFake((_) async {
          var fail = false;
          final calls = Calls()
            ..answer = (method, params) async {
              await Future<void>.delayed(const Duration(seconds: 1));
              if (fail) throw const RemoteCallError('internal', 'boom');
              return [
                {'name': 'compact', 'source': 'builtin'},
              ];
            };
          final config = HostConfigController(calls.call);
          final both = await Future.wait([config.commands('claude', '/w'), config.commands('claude', '/w')]);
          expect(both.map((list) => list.single.name), ['compact', 'compact']);
          expect(calls.count('commands.list'), 1, reason: 'one query in flight per agent and workspace');

          await Future<void>.delayed(const Duration(seconds: 3));
          await config.commands('claude', '/w');
          expect(calls.count('commands.list'), 1, reason: 'within 5 s of the answer');
          await config.commands('codex', '/w');
          expect(calls.count('commands.list'), 2, reason: 'another agent is another list');

          await Future<void>.delayed(const Duration(seconds: 3));
          fail = true;
          await expectLater(config.commands('claude', '/w'), throwsA(isA<RemoteCallError>()));
          expect(calls.count('commands.list'), 3);
          fail = false;
          await config.commands('claude', '/w');
          expect(calls.count('commands.list'), 4, reason: 'a failure is asked again at once');

          config.reconnected();
          await config.commands('claude', '/w');
          expect(calls.count('commands.list'), 5, reason: 'a new connection asks afresh');
        }));

    test('eight lists are kept, the least recently used one goes', () => runFake((_) async {
          final calls = Calls()..answer = (_, _) => <Object?>[];
          final config = HostConfigController(calls.call);
          for (var index = 0; index < 8; index++) {
            await config.commands('claude', '/w$index');
          }
          await config.commands('claude', '/w0');
          expect(calls.count('commands.list'), 8, reason: '/w0 is still there, and now the most recent');
          await config.commands('claude', '/w8');
          await config.commands('claude', '/w0');
          expect(calls.count('commands.list'), 9);
          await config.commands('claude', '/w1');
          expect(calls.count('commands.list'), 10, reason: '/w1 was the least recently used');
        }));
  });

  group('through the app', () {
    Future<(TestApp, FakeHost)> rig({List<String>? features, FutureOr<Object?> Function(String method, Object? params)? handler}) async {
      final host = FakeHost(TestApp.newHostId(), Primitives.generateKeyPair())
        ..features = features
        ..handler = (method, params) async {
          final custom = await handler?.call(method, params);
          if (custom != null) return custom;
          return switch (method) {
            'workspaces.list' || 'sessions.list' => <Object?>[],
            'turn.prompt' => {'ok': true, 'sessionKey': 'claude:1', 'taskId': 't1'},
            _ => true,
          };
        };
      final app = TestApp();
      await app.connectTo(host);
      return (app, host);
    }

    test('welcome.features is read; absent, it is empty', () {
      final welcome = Welcome.fromJson({
        'methods': ['turn.prompt'],
        'features': ['prompt.providerId', 'later.thing', 3],
      });
      expect(welcome.features, ['prompt.providerId', 'later.thing']);
      expect(welcome.supports(Features.promptProviderId), isTrue);
      final old = Welcome.fromJson(const {'methods': <Object?>[]});
      expect(old.features, isEmpty);
      expect(old.supports(Features.promptProviderId), isFalse);
    });

    test('settings is a scope, never one a device gets by default', () {
      expect(Scopes.all.last, Scopes.settings);
      expect(Scopes.byDefault, isNot(contains(Scopes.settings)));
      expect(Scopes.byDefault, isNot(contains(Scopes.terminal)));
      expect(Scopes.legacy, isNot(contains(Scopes.settings)));
      expect(Methods.scope['mode.set'], Scopes.settings);
      expect(Methods.scope['accounts.list'], Scopes.sessions);
      expect(Methods.scope['commands.list'], Scopes.prompt);
    });

    Map<String, Object?>? sentPrompt(FakeHost host) =>
        host.calls.lastWhere((call) => call.$1 == 'turn.prompt', orElse: () => ('', null)).$2 as Map<String, Object?>?;
    final providerUnsupported = isA<PromptRefused>()
        .having((outcome) => outcome.reason, 'reason', isA<RcException>().having((error) => error.code, 'code', 'provider-unsupported'));

    test('providerId goes to a host that checks it', () => runFake((_) async {
          final (app, host) = await rig(features: [Features.promptProviderId]);
          final outcome = await app.controller.prompt('claude:1', 'hi', model: 'deepseek-chat', providerId: 'r1');
          expect(outcome, isA<PromptAccepted>());
          expect(sentPrompt(host), allOf(containsPair('providerId', 'r1'), containsPair('model', 'deepseek-chat')));
          app.controller.disconnect();
        }));

    // A host from before the feature ignores the parameter: the turn would
    // go its default way — another endpoint, maybe another payer (spec §6.1).
    test('a turn pinned to an endpoint is not sent to a host from before providerId', () => runFake((_) async {
          final (app, host) = await rig();
          final outcome = await app.controller.prompt('claude:1', 'hi', model: 'deepseek-chat', providerId: 'r1');
          expect(outcome, providerUnsupported);
          expect(sentPrompt(host), isNull);
          expect(await app.controller.prompt('claude:1', 'hi', model: 'opus'), isA<PromptAccepted>());
          expect(sentPrompt(host)!.containsKey('providerId'), isFalse);
          app.controller.disconnect();
        }));

    // The model is picked on one connection and sent on the next: what that
    // one's host can do decides, not what the last one's could.
    for (final (label, features) in [
      ('a host that checks it', [Features.promptProviderId]),
      ('a host from before it', null),
    ]) {
      test('a prompt sent across a reconnect onto $label', () => runFake((_) async {
            final (app, host) = await rig(features: [Features.promptProviderId]);
            final before = host.connections;
            host.features = features;
            final down = app.controller.states.firstWhere((state) => !state.connected);
            await host.drop();
            await down;
            final outcome = await app.controller.prompt('claude:1', 'hi', model: 'deepseek-chat', providerId: 'r1');
            expect(host.connections, greaterThan(before), reason: 'it waited for the new connection');
            if (features == null) {
              expect(outcome, providerUnsupported, reason: 'sent without it, the turn would go its default way');
              expect(sentPrompt(host), isNull);
            } else {
              expect(outcome, isA<PromptAccepted>());
              expect(sentPrompt(host), containsPair('providerId', 'r1'));
            }
            app.controller.disconnect();
          }));
    }

    test('a mode.set the desktop declines comes back as it said it', () => runFake((_) async {
          const refusal = '云端模式需要先分配模型 —— 到「API Key」里选一把 Key 分配模型';
          final (app, host) = await rig(handler: (method, _) => switch (method) {
                'mode.get' => {'mode': 'local'},
                'mode.set' => {'ok': false, 'error': refusal},
                _ => null,
              });
          final config = app.controller.config;
          await config.loadMode();
          final result = await config.setMode('cloud');
          expect(result.ok, isFalse);
          expect(result.error, refusal);
          expect(result.code, isNull);
          expect(config.mode.value.value, 'local');
          app.controller.disconnect();
        }));

    test('five change events in a burst cost at most two reads', () => runFake((_) async {
          var gate = Completer<void>();
          var version = 0;
          final (app, host) = await rig(handler: (method, _) async {
            if (method == 'accounts.list') {
              await gate.future;
              return accounts('v${++version}');
            }
            if (method == 'models.context.list') return {'rows': <Object?>[]};
            return null;
          });
          final config = app.controller.config;
          config
            ..watchAccounts()
            ..watchContext();
          await until(() => host.calls.any((call) => call.$1 == 'accounts.list') && config.context.value.value != null);
          final models = app.controller.modelsRevision.value;
          for (var index = 0; index < 5; index++) {
            host.emit(Events.accountsChanged, const {});
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          gate.complete();
          await until(() => config.accounts.value.value?.revisions['g1'] == 'rev-v2' && !config.accounts.value.loading);
          await Future<void>.delayed(const Duration(seconds: 1));
          expect(host.calls.where((call) => call.$1 == 'accounts.list'), hasLength(2));
          expect(app.controller.modelsRevision.value, greaterThan(models), reason: 'the catalogs may have changed');
          expect(host.calls.where((call) => call.$1 == 'models.context.list').length, lessThanOrEqualTo(3),
              reason: 'the context rows come from the accounts: read again too, coalesced');

          gate = Completer<void>()..complete();
          final contextReads = host.calls.where((call) => call.$1 == 'models.context.list').length;
          final beforeContext = app.controller.modelsRevision.value;
          host.emit(Events.modelsContextChanged, const {});
          await until(() => host.calls.where((call) => call.$1 == 'models.context.list').length == contextReads + 1);
          expect(app.controller.modelsRevision.value, beforeContext, reason: 'the context settings are not the catalog');

          host.emit(Events.modeChanged, {'mode': 'cloud'});
          await until(() => config.mode.value.value == 'cloud');
          expect(app.controller.modelsRevision.value, greaterThan(beforeContext));
          expect(host.calls.where((call) => call.$1 == 'mode.get'), isEmpty, reason: 'the event carried the mode');
          app.controller.disconnect();
        }));

    test('nothing is read for a screen nobody opened', () => runFake((_) async {
          final (app, host) = await rig();
          host
            ..emit(Events.accountsChanged, const {})
            ..emit(Events.modelsContextChanged, const {})
            ..emit(Events.modeChanged, const {});
          await Future<void>.delayed(const Duration(seconds: 1));
          expect(host.calls.map((call) => call.$1), isNot(anyOf(contains('accounts.list'), contains('models.context.list'), contains('mode.get'))));
          app.controller.disconnect();
        }));

    test('a kick for new scopes drops the accounts read under the old ones', () => runFake((_) async {
          var granted = false;
          final gate = Completer<void>();
          final (app, host) = await rig(handler: (method, _) async {
            if (method != 'accounts.list') return null;
            if (!granted) return accounts('sessions');
            await gate.future;
            return accounts('settings');
          });
          final config = app.controller.config;
          config.watchAccounts();
          await until(() => config.accounts.value.value?.revisions['g1'] == 'rev-sessions');
          final before = host.connections;
          granted = true;
          host.scopes = [...host.scopes, Scopes.settings];
          await host.kick('scopes-changed');
          await until(() => host.connections > before && app.controller.state.connected, timeout: const Duration(minutes: 2));
          await until(() => host.calls.where((call) => call.$1 == 'accounts.list').length == 2);
          expect(config.accounts.value.value, isNull, reason: 'read without settings: its extra environment is missing');
          gate.complete();
          await until(() => config.accounts.value.value?.revisions['g1'] == 'rev-settings');
          app.controller.disconnect();
        }));

    test('after a reconnect, what was on screen is read again', () => runFake((_) async {
          var version = 0;
          final (app, host) = await rig(handler: (method, _) => method == 'accounts.list' ? accounts('v${++version}') : null);
          final config = app.controller.config;
          config.watchAccounts();
          await until(() => config.accounts.value.value?.revisions['g1'] == 'rev-v1');
          final models = app.controller.modelsRevision.value;
          final before = host.connections;
          await host.drop();
          await until(() => host.connections > before && app.controller.state.connected, timeout: const Duration(minutes: 2));
          await until(() => config.accounts.value.value?.revisions['g1'] == 'rev-v2');
          expect(app.controller.modelsRevision.value, greaterThan(models), reason: 'a change said while away reached nobody');
          app.controller.disconnect();
          expect(config.accounts.value.value, isNull);
        }));
  });
}
