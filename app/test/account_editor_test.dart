import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/kit/forms.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_editor_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// The account editor (spec §7.1, `AccountDialog` on the desktop): what it
/// sends for a new account and an edit, what it says before sending, and how
/// it takes the computer's refusals and a fetch of models.
void main() {
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];

  Map<String, Object?> sent(DemoHost demo, String method) => demo.settingsCalls.lastWhere((call) => call.$1 == method).$2;
  int count(DemoHost demo, String method) => demo.settingsCalls.where((call) => call.$1 == method).length;
  List<Map<String, Object?>> endpoints(Map<String, Object?> params) => [for (final e in params['endpoints']! as List) e as Map<String, Object?>];

  Finder field(String label, [int index = 0]) => find.widgetWithText(TextField, label).at(index);
  String text(WidgetTester tester, String label, [int index = 0]) => tester.widget<TextField>(field(label, index)).controller!.text;

  /// The editor, opened over a page for it to go back to.
  Future<(TestServices, DemoHost)> open(
    WidgetTester tester, {
    String? account,
    void Function(DemoHost demo)? prepare,
  }) async {
    phoneSurface(tester, size: const Size(412, 4400));
    final (services, demo) = await connect(tester, scopes: all, prepare: prepare);
    final config = services.controller.config;
    AccountGroup? group;
    if (account != null) {
      unawaited(config.loadAccounts());
      await pumpUntil(tester, () => config.accounts.value.value != null);
      group = config.accounts.value.value!.accounts.firstWhere((candidate) => candidate.name == account);
    }
    await tester.pumpWidget(harness(
      services,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountEditorScreen(group: group))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      style: DesignStyle.material3,
    ));
    await tester.tap(find.text('open'));
    await settle(tester, rounds: 20);
    return (services, demo);
  }

  Future<void> save(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await settle(tester, rounds: 20);
  }

  testWidgets('a preset fills the protocols; the name follows it only while empty or another preset\'s', (tester) async {
    final (services, _) = await open(tester);
    await tester.enterText(field('Name'), 'Mine');
    await tester.tap(find.widgetWithText(ChoiceChip, 'DeepSeek'));
    await settle(tester);
    expect(text(tester, 'Name'), 'Mine');
    expect(text(tester, 'Base URL'), 'https://api.deepseek.com/anthropic');
    expect(find.byType(Switch).evaluate().map((e) => (e.widget as Switch).value), [true, true, true, false]);

    await tester.enterText(field('Name'), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'DeepSeek'));
    await settle(tester);
    expect(text(tester, 'Name'), 'DeepSeek');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
    await settle(tester);
    expect(text(tester, 'Name'), 'DeepSeek', reason: 'custom names nothing');
    expect(find.byType(Switch).evaluate().map((e) => (e.widget as Switch).value), [false, false, false, false]);
    await leave(tester, services);
  });

  testWidgets('a new account goes out as the form shows it, with no revision', (tester) async {
    final (services, demo) = await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'DeepSeek'));
    await settle(tester);
    await tester.enterText(field('API key'), ' sk-typed ');
    await save(tester, 'Add');

    final params = sent(demo, 'accounts.saveGroup');
    expect(params.containsKey('groupId'), isFalse);
    expect(params.containsKey('revision'), isFalse);
    expect((params['name'], params['presetId'], params['apiKey'], params['note']), ('DeepSeek', 'deepseek', 'sk-typed', ''));
    expect([for (final e in endpoints(params)) e['dialect']], ['anthropic', 'openai-responses', 'openai-chat']);
    expect(endpoints(params).first['modelMap'], {'main': 'deepseek-v4-pro', 'sonnet': 'deepseek-v4-pro', 'opus': 'deepseek-v4-pro', 'haiku': 'deepseek-flash'});
    expect(endpoints(params)[1]['modelMap'], {'main': 'deepseek-flash'});
    expect(find.byType(AccountEditorScreen), findsNothing);
    expect(find.text('Added “DeepSeek”: choose it for an agent under Local accounts'), findsOneWidget);
    await leave(tester, services);
  });

  testWidgets('an edit carries the account back whole with its revision; an empty key keeps the stored one', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    expect(find.text('One key for every protocol. A key is stored: leave this empty to keep it.'), findsOneWidget);
    expect(text(tester, 'Variables'), 'API_TIMEOUT_MS=600000');
    await tester.enterText(field('Note'), 'Company key');
    await save(tester, 'Save');

    final params = sent(demo, 'accounts.saveGroup');
    expect((params['groupId'], params['revision'], params['note'], params['presetId']), ('g-ds', 'rev-ds-1', 'Company key', 'deepseek'));
    expect(params.containsKey('apiKey'), isFalse);
    expect(endpoints(params), [
      {
        'id': 'ds-a',
        'dialect': 'anthropic',
        'baseUrl': 'https://api.deepseek.com/anthropic',
        'models': ['deepseek-v4-pro', 'deepseek-flash'],
        'modelMap': {'main': 'deepseek-v4-pro', 'haiku': 'deepseek-flash'},
        'extraEnv': {'API_TIMEOUT_MS': '600000'},
      },
      {
        'id': 'ds-c',
        'dialect': 'openai-chat',
        'baseUrl': 'https://api.deepseek.com',
        'models': ['deepseek-v4-pro', 'deepseek-flash'],
        'modelMap': {'main': 'deepseek-v4-pro'},
      },
    ]);
    expect(find.text('Saved “DeepSeek”'), findsOneWidget);
    await leave(tester, services);
  });

  testWidgets('clearing the stored key sends an empty one', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    await tester.tap(find.text('Clear the stored key'));
    await settle(tester);
    expect(find.text('The stored key is cleared when you save.'), findsOneWidget);
    await save(tester, 'Save');
    expect(sent(demo, 'accounts.saveGroup')['apiKey'], '');
    await leave(tester, services);
  });

  testWidgets('what the computer would refuse is said beside its field, and nothing is sent', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    await tester.enterText(field('Name'), 'x' * 101);
    await tester.enterText(field('Variables'), 'API_TIMEOUT_MS=600000\nNOEQUALS');
    await tester.enterText(field('Model ids'), 'deepseek-v4-pro\nbad\u0007id');
    await save(tester, 'Save');
    expect(find.text('At most 100 characters'), findsOneWidget);
    expect(find.text('Not KEY=VALUE: NOEQUALS'), findsOneWidget);
    expect(find.text('bad\u0007id: No control characters'), findsOneWidget);
    expect(find.text('3 fields need fixing'), findsOneWidget);
    expect(count(demo, 'accounts.saveGroup'), 0);

    await tester.enterText(field('Name'), 'DeepSeek');
    await settle(tester);
    expect(find.text('At most 100 characters'), findsNothing, reason: 'cleared as the field is changed');
    await leave(tester, services);
  });

  testWidgets('a save over a change made elsewhere offers to start again from the account as it is', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    // Changed on the computer after the phone read it.
    for (final row in demo.providers.where((row) => row['groupId'] == 'g-ds')) {
      row['note'] = 'Changed on the computer';
    }
    demo.revisions['g-ds'] = 'rev-ds-2';
    await tester.enterText(field('Note'), 'Mine');
    await save(tester, 'Save');
    expect(sent(demo, 'accounts.saveGroup')['revision'], 'rev-ds-1');
    expect(find.text('Changed elsewhere'), findsOneWidget);
    expect(find.byType(AccountEditorScreen), findsOneWidget);

    await tester.tap(find.text('Reload'));
    await settle(tester, rounds: 20);
    expect(text(tester, 'Note'), 'Changed on the computer');
    expect(find.text('Changed elsewhere'), findsNothing);
    await save(tester, 'Save');
    expect(sent(demo, 'accounts.saveGroup')['revision'], 'rev-ds-2');
    expect(find.byType(AccountEditorScreen), findsNothing, reason: 'saved');
    await leave(tester, services);
  });

  testWidgets('an account read without settings is read again once settings is on, its extra environment with it', (tester) async {
    phoneSurface(tester, size: const Size(412, 4400));
    final (services, demo) = await connect(tester);
    final config = services.controller.config;
    unawaited(config.loadAccounts());
    await pumpUntil(tester, () => config.accounts.value.value != null);
    final shown = config.accounts.value.value!.accounts.firstWhere((group) => group.name == 'DeepSeek');
    expect(shown.rows.first.extraEnv, isNull, reason: 'not given to a phone that may only look');

    // Turned on at the computer: the phone connects again, the editor still
    // holding what it read before.
    demo.grant(all);
    services.controller.disconnect();
    await settle(tester, rounds: 5);
    unawaited(services.controller.connect(demo.host.hostId));
    await pumpUntil(tester, () => services.controller.state.connected);
    await tester.pumpWidget(harness(services, AccountEditorScreen(group: shown), style: DesignStyle.material3));
    await settle(tester, rounds: 20);
    expect(text(tester, 'Variables'), isEmpty);
    await tester.enterText(field('Note'), 'Mine');
    await save(tester, 'Save');
    expect(find.text('Changed elsewhere'), findsOneWidget, reason: 'saved, it would clear values it never saw');

    await tester.tap(find.text('Reload'));
    await settle(tester, rounds: 20);
    expect(text(tester, 'Variables'), 'API_TIMEOUT_MS=600000');
    await save(tester, 'Save');
    expect(sent(demo, 'accounts.saveGroup')['revision'], 'rev-ds-1');
    expect(endpoints(sent(demo, 'accounts.saveGroup')).first['extraEnv'], {'API_TIMEOUT_MS': '600000'});
    expect(demo.revisions['g-ds'], isNot('rev-ds-1'), reason: 'taken: the account moved on');
    await leave(tester, services);
  });

  testWidgets('a stored key that may not go to a new address is asked for again', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    demo.answers['accounts.saveGroup'] = {'ok': false, 'error': '换了服务器地址，需要重新填 API Key', 'code': 'key-required'};
    await tester.enterText(field('Base URL'), 'https://elsewhere.example/anthropic');
    await save(tester, 'Save');
    expect(find.text('New server address: enter the API key again'), findsNWidgets(3), reason: 'the banner, the key field, and the line over Save');
    expect(find.textContaining('Enter the key again, or clear the stored one'), findsOneWidget);
    // Typed again: the computer's asking is answered.
    await tester.enterText(field('API key'), 'sk-again');
    await settle(tester);
    expect(find.text('New server address: enter the API key again'), findsNothing);
    await leave(tester, services);
  });

  group("the desktop's own rules", () {
    testWidgets('each is said beside its field, in the phone\'s words, and nothing is sent', (tester) async {
      final (services, demo) = await open(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await settle(tester);
      await save(tester, 'Add');
      expect(find.text('Give the account a name'), findsOneWidget);
      expect(find.text('Turn on at least one protocol'), findsOneWidget);
      expect(find.text('2 fields need fixing'), findsOneWidget);

      await tester.enterText(field('Name'), 'Mine');
      for (final protocol in ['Anthropic', 'OpenAI Responses', 'Gemini']) {
        await tester.tap(find.widgetWithText(SwitchListTile, protocol));
        await settle(tester);
      }
      expect(find.text('Turn on at least one protocol'), findsNothing, reason: 'one is, now');
      await tester.enterText(field('Base URL', 0), 'https://api.example.com/anthropic');
      await tester.enterText(field('Variables'), 'lower=1\nGITHUB_TOKEN=x\nAPI_TIMEOUT_MS=600000');
      await tester.enterText(field('Base URL', 1), 'api.example.com/v1');
      await tester.enterText(field('Base URL', 2), 'ftp://files.example.com');
      await save(tester, 'Add');
      expect(find.text("lower isn't a variable name: capital letters, digits and underscores, starting with a letter\n"
          "GITHUB_TOKEN is set by the route itself and can't be overridden here"), findsOneWidget);
      expect(find.text('Not a valid address, like https://api.example.com/v1'), findsOneWidget);
      expect(find.text('Codex needs a model on this endpoint: list one, or set the default model'), findsOneWidget);
      expect(find.text('Must start with http:// or https://'), findsOneWidget);
      expect(find.text('4 fields need fixing'), findsOneWidget);
      expect(count(demo, 'accounts.saveGroup'), 0);

      await tester.enterText(field('Variables'), 'API_TIMEOUT_MS=600000');
      await tester.enterText(field('Base URL', 1), 'https://api.example.com/v1');
      await tester.enterText(field('Default model', 0), 'gpt-5.6');
      await tester.enterText(field('Base URL', 2), 'https://generativelanguage.googleapis.com');
      await save(tester, 'Add');
      expect(count(demo, 'accounts.saveGroup'), 1);
      expect(find.byType(AccountEditorScreen), findsNothing, reason: 'saved');
      await leave(tester, services);
    });

    testWidgets("what the computer still refuses is shown in its own words", (tester) async {
      final (services, demo) = await open(tester, account: 'DeepSeek');
      demo.answers['accounts.saveGroup'] = {'ok': false, 'error': '某个新规则不允许这个账号'};
      await save(tester, 'Save');
      expect(find.text('某个新规则不允许这个账号'), findsOneWidget);
      expect(find.text('Not saved: the reason is at the top'), findsOneWidget);
      await leave(tester, services);
    });
  });

  group('a refused save, from the bottom of a long form', () {
    /// The editor on a phone's height, where most of the form is off screen.
    Future<(TestServices, DemoHost)> phone(WidgetTester tester, {String? account}) async {
      final opened = await open(tester, account: account);
      phoneSurface(tester);
      await tester.pump();
      return opened;
    }

    bool onScreen(WidgetTester tester, Finder finder) {
      final rect = tester.getRect(finder);
      // Under the top bar, over the action bar.
      return rect.top >= 56 && rect.bottom <= tester.getRect(find.byType(FormActionBar)).top;
    }

    testWidgets('goes to the first field that is wrong, and says how many over the button', (tester) async {
      final (services, _) = await phone(tester, account: 'DeepSeek');
      await tester.enterText(field('Name'), '');
      // Down at the end of the form, by the button.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester);
      expect(onScreen(tester, field('Name')), isFalse);
      await tester.enterText(field('Base URL', 1), 'nowhere');
      await save(tester, 'Save');
      expect(onScreen(tester, find.text('Give the account a name')), isTrue);
      expect(find.descendant(of: find.byType(FormStatus), matching: find.text('2 fields need fixing')), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets("goes to the computer's refusal at the top, and says what it is over the button", (tester) async {
      final (services, demo) = await phone(tester, account: 'DeepSeek');
      demo.revisions['g-ds'] = 'rev-ds-2';
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester);
      await save(tester, 'Save');
      expect(onScreen(tester, find.text('Changed elsewhere')), isTrue);
      expect(find.descendant(of: find.byType(FormActionBar), matching: find.text('Changed elsewhere: reload it at the top')), findsOneWidget);
      await leave(tester, services);
    });
  });

  // M3 Expressive's large bar part-way collapsed shows its headline and
  // its collapsed title over each other: a refusal at the top is gone to
  // with the bar whole, in either style.
  for (final style in DesignStyle.values) {
    testWidgets('at twice the text size a refusal at the top is shown under the top bar left whole (${style.name})', (tester) async {
      phoneSurface(tester, size: const Size(360, 740));
      final (services, demo) = await connect(tester, scopes: all);
      final config = services.controller.config;
      unawaited(config.loadAccounts());
      await pumpUntil(tester, () => config.accounts.value.value != null);
      final group = config.accounts.value.value!.accounts.firstWhere((candidate) => candidate.name == 'DeepSeek');
      await tester.pumpWidget(harness(services, AccountEditorScreen(group: group), style: style, textScale: 2));
      await settle(tester, rounds: 20);
      demo.answers['accounts.saveGroup'] = {'ok': false, 'error': '某个新规则不允许这个账号'};
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      for (final from in [3000.0, 60.0]) {
        // From the bottom of the form, and from barely scrolled.
        position.jumpTo(math.min(from, position.maxScrollExtent));
        await settle(tester);
        await tester.tap(find.descendant(of: find.byType(FormActionBar), matching: find.text('Save')));
        await settle(tester, rounds: 20);
        expect(position.pixels, 0, reason: 'the bar whole, not part-way (${style.name}, from $from)');
        final banner = tester.getRect(find.text('某个新规则不允许这个账号'));
        expect(banner.top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar).first).bottom), reason: style.name);
        expect(banner.bottom, lessThanOrEqualTo(tester.getRect(find.byType(FormActionBar)).top), reason: style.name);
      }
      await leave(tester, services);
    });
  }

  testWidgets('a reload that fails says so, and keeps the refusal and what was typed', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    demo.revisions['g-ds'] = 'rev-ds-2';
    await tester.enterText(field('Note'), 'Mine');
    await save(tester, 'Save');
    expect(find.text('Changed elsewhere'), findsOneWidget);

    demo.answers['accounts.list'] = const RemoteCallError('internal', 'the store is busy');
    await tester.tap(find.text('Reload'));
    await settle(tester, rounds: 20);
    expect(find.text('Changed elsewhere'), findsOneWidget, reason: 'still to be answered');
    expect(find.textContaining("Couldn't read it again"), findsOneWidget);
    expect(text(tester, 'Note'), 'Mine', reason: 'not filled again from what was read before');

    demo.answers.remove('accounts.list');
    await tester.tap(find.text('Reload'));
    await settle(tester, rounds: 20);
    expect(find.text('Changed elsewhere'), findsNothing);
    expect(find.textContaining("Couldn't read it again"), findsNothing);
    expect(text(tester, 'Note'), 'Personal key, pay as you go');
    await leave(tester, services);
  });

  testWidgets('the extra environment keeps a short label, the format under it, whole at large text', (tester) async {
    phoneSurface(tester, size: const Size(360, 6000));
    final (services, _) = await connect(tester, scopes: all);
    final config = services.controller.config;
    unawaited(config.loadAccounts());
    await pumpUntil(tester, () => config.accounts.value.value != null);
    final group = config.accounts.value.value!.accounts.firstWhere((candidate) => candidate.name == 'DeepSeek');
    await tester.pumpWidget(harness(services, AccountEditorScreen(group: group), style: DesignStyle.material3, textScale: 2));
    await settle(tester, rounds: 20);
    final label = tester.renderObject<RenderParagraph>(find.descendant(of: field('Variables'), matching: find.text('Variables')));
    expect(label.didExceedMaxLines, isFalse);
    expect(label.size.width, greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity) - 0.5), reason: 'not cut off');
    expect(find.descendant(of: field('Variables'), matching: find.text('KEY=VALUE, one per line')), findsOneWidget);
    await leave(tester, services);
  });

  group('fetching models', () {
    testWidgets("what a fetch said stands apart from the list's own error, counts for nothing, and goes when the address changes", (tester) async {
      final (services, demo) = await open(tester, account: 'DeepSeek');
      demo.answers['models.discover'] = {'ok': false, 'error': 'x', 'code': 'http', 'status': 502};
      await tester.enterText(field('Model ids'), 'deepseek-v4-pro\nbad\u0007id');
      await tester.tap(find.text('Fetch models').first);
      await settle(tester, rounds: 20);
      await save(tester, 'Save');
      // Both shown: the fetch's under its button, the list's on the list.
      expect(find.text('The endpoint answered HTTP 502'), findsOneWidget);
      expect(find.text("Couldn't fetch the models"), findsOneWidget);
      expect(find.text('bad\u0007id: No control characters'), findsOneWidget);
      expect(tester.widget<TextField>(field('Model ids')).decoration!.errorText, 'bad\u0007id: No control characters');
      expect(find.text('1 field needs fixing'), findsOneWidget, reason: 'a fetch that failed is nothing to fix in the form');

      // The list changed: what the fetch said was of the old one.
      await tester.enterText(field('Model ids'), 'deepseek-v4-pro');
      await settle(tester);
      expect(find.text('The endpoint answered HTTP 502'), findsNothing);
      await tester.tap(find.text('Fetch models').first);
      await settle(tester, rounds: 20);
      expect(find.text('The endpoint answered HTTP 502'), findsOneWidget);
      await tester.enterText(field('Base URL'), 'https://api.deepseek.com/v2');
      await settle(tester);
      expect(find.text('The endpoint answered HTTP 502'), findsNothing, reason: 'another address');
      await leave(tester, services);
    });

    testWidgets('with the stored key, then a typed one; the list is filled, and how many said', (tester) async {
      final (services, demo) = await open(tester, account: 'DeepSeek');
      expect(find.text('One per line, or separated by commas'), findsNWidgets(2));
      await tester.tap(find.text('Fetch models').first);
      await settle(tester, rounds: 20);
      expect(sent(demo, 'models.discover'), {
        'dialect': 'anthropic',
        'baseUrl': 'https://api.deepseek.com/anthropic',
        'providerId': 'ds-a',
        'presetId': 'deepseek',
      });
      expect(text(tester, 'Model ids'), 'deepseek-v4-pro\ndeepseek-flash\ndeepseek-reasoner');
      expect(find.text('Got 3 models and filled in the list.'), findsOneWidget);

      await tester.enterText(field('API key'), 'sk-new');
      await tester.tap(find.text('Fetch models').last);
      await settle(tester, rounds: 20);
      expect(sent(demo, 'models.discover'), {'dialect': 'openai-chat', 'baseUrl': 'https://api.deepseek.com', 'apiKey': 'sk-new', 'presetId': 'deepseek'});

      // The windows it reported go with the save, for the models kept.
      await save(tester, 'Save');
      expect(endpoints(sent(demo, 'accounts.saveGroup')).first['contextWindows'], {'deepseek-v4-pro': 128000, 'deepseek-flash': 128000});
      await leave(tester, services);
    });

    testWidgets('while it runs, and each way it fails', (tester) async {
      final (services, demo) = await open(tester, account: 'DeepSeek');
      final pending = Completer<Object?>();
      demo.answers['models.discover'] = pending.future;
      await tester.tap(find.text('Fetch models').first);
      await settle(tester);
      expect(find.text('Asking the endpoint for its models…'), findsOneWidget);
      pending.complete({'ok': false, 'error': '密钥被拒绝（401），检查这个端点的 Key', 'code': 'http', 'status': 401});
      await settle(tester);
      expect(find.text('The key was rejected (401): check this endpoint\'s key'), findsOneWidget);

      for (final (answer, said) in <(Map<String, Object?>, String)>[
        ({'ok': false, 'error': 'x', 'code': 'http', 'status': 502}, 'The endpoint answered HTTP 502'),
        ({'ok': false, 'error': 'x', 'code': 'timeout'}, 'The endpoint didn\'t answer within 20 seconds'),
        ({'ok': false, 'error': 'x', 'code': 'network'}, 'Couldn\'t reach this address'),
        ({'ok': false, 'error': 'x', 'code': 'not-json'}, 'The endpoint\'s answer isn\'t JSON'),
        ({'ok': false, 'error': 'x', 'code': 'empty'}, 'The endpoint listed no models'),
        ({'ok': false, 'error': 'x', 'code': 'too-large'}, 'The endpoint\'s answer is too large (over 8 MiB)'),
        ({'ok': false, 'error': 'x', 'code': 'key-required'}, 'New server address: enter the API key again'),
        ({'ok': false, 'error': '后端出错了'}, '后端出错了'),
      ]) {
        demo.answers['models.discover'] = answer;
        await tester.tap(find.text('Fetch models').first);
        await settle(tester, rounds: 20);
        expect(find.text(said), findsOneWidget, reason: '$answer');
      }

      final before = count(demo, 'models.discover');
      await tester.enterText(field('Base URL'), '');
      await tester.tap(find.text('Fetch models').first);
      await settle(tester);
      expect(find.text('Enter the Base URL first'), findsOneWidget);
      await tester.enterText(field('Base URL'), 'https://api.example/v1?x=1');
      await tester.tap(find.text('Fetch models').first);
      await settle(tester);
      expect(find.textContaining('can\'t have ? or # in it'), findsOneWidget);
      expect(count(demo, 'models.discover'), before, reason: 'neither was sent');
      await leave(tester, services);
    });

    testWidgets('more than a protocol keeps: the first of them, said so', (tester) async {
      final (services, demo) = await open(tester, account: 'DeepSeek');
      demo.answers['models.discover'] = {
        'ok': true,
        'models': [for (var i = 0; i < 1200; i++) {'id': 'model-$i'}],
      };
      await tester.tap(find.text('Fetch models').first);
      await settle(tester, rounds: 20);
      expect(find.text('Got 1200 models; filled in the first 1000, as many as a protocol keeps.'), findsOneWidget);
      expect(text(tester, 'Model ids').split('\n').length, 1000);
      await leave(tester, services);
    });
  });

  group('older endpoints', () {
    testWidgets('editing one: the first protocol turned on takes it in, with its revision', (tester) async {
      final (services, demo) = await open(tester, account: 'Old relay');
      expect(find.text('An older endpoint'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Anthropic'));
      await tester.tap(find.widgetWithText(SwitchListTile, 'OpenAI Chat'));
      await settle(tester);
      await save(tester, 'Save');
      final params = sent(demo, 'accounts.saveGroup');
      expect(params.containsKey('groupId'), isFalse);
      expect(params['revision'], 'rev-old-1');
      expect(params.containsKey('apiKey'), isFalse);
      expect([for (final e in endpoints(params)) (e['id'], e['dialect'], e['baseUrl'])], [
        ('old-1', 'anthropic', 'https://relay.example.com/v1'),
        (null, 'openai-chat', 'https://relay.example.com/v1'),
      ], reason: 'an id claimed twice is refused');
      await leave(tester, services);
    });

    testWidgets('a new account taking in two sends both their revisions', (tester) async {
      final (services, demo) = await open(tester, prepare: (demo) {
        demo.providers.add({
          'id': 'old-2', 'name': 'Second relay', 'note': '', 'kind': 'anthropic', 'agents': <String>[],
          'baseUrl': 'https://relay2.example.com', 'models': ['m2'], 'hasKey': false, 'source': 'byok', 'createdAt': 1,
        });
        demo.revisions['old-2'] = 'rev-old-2';
      });
      await tester.enterText(field('Name'), 'Merged');

      Future<void> adopt(String row, String protocol) async {
        await tester.tap(find.text('Take in an older endpoint'));
        await settle(tester);
        await tester.tap(find.text(row));
        await tester.tap(find.widgetWithText(ChoiceChip, protocol));
        await settle(tester);
        await tester.tap(find.text('Take it in'));
        await settle(tester);
      }

      await adopt('Old relay', 'OpenAI Chat');
      expect(find.text('Takes in the older endpoint “Old relay”'), findsOneWidget);
      await adopt('Second relay', 'Anthropic');
      demo.answers['accounts.saveGroup'] = {'ok': false, 'error': '这个账号已在别处修改，请重新载入后再保存', 'code': 'conflict'};
      await save(tester, 'Add');
      final params = sent(demo, 'accounts.saveGroup');
      expect(params['revision'], unorderedEquals(['rev-old-1', 'rev-old-2']));
      expect([for (final e in endpoints(params)) (e['id'], e['dialect'])], [('old-2', 'anthropic'), ('old-1', 'openai-chat')]);

      // One of them changed meanwhile: read again, still taken in.
      demo.revisions['old-1'] = 'rev-old-1b';
      demo.answers.remove('accounts.saveGroup');
      await tester.tap(find.text('Reload'));
      await settle(tester, rounds: 20);
      expect(find.text('Takes in the older endpoint “Old relay”'), findsOneWidget);
      await save(tester, 'Add');
      expect(sent(demo, 'accounts.saveGroup')['revision'], unorderedEquals(['rev-old-1b', 'rev-old-2']));
      await leave(tester, services);
    });
  });

  testWidgets('an older endpoint taken into an account being edited: both revisions go, and a reload keeps it taken in', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    await tester.tap(find.text('Take in an older endpoint'));
    await settle(tester);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Anthropic')), findsNothing, reason: 'the account has its own');
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Gemini')));
    await settle(tester);
    await tester.tap(find.text('Take it in'));
    await settle(tester);
    expect(find.text('Takes in the older endpoint “Old relay”'), findsOneWidget);

    // Changed on the computer meanwhile: the group's revision alone would
    // be a conflict as well (spec §7).
    demo.revisions['old-1'] = 'rev-old-1b';
    await save(tester, 'Save');
    final refused = sent(demo, 'accounts.saveGroup');
    expect(refused['groupId'], 'g-ds');
    expect(refused['revision'], unorderedEquals(['rev-ds-1', 'rev-old-1']));
    expect([for (final e in endpoints(refused)) (e['id'], e['dialect'])], [('ds-a', 'anthropic'), ('ds-c', 'openai-chat'), ('old-1', 'gemini')]);
    expect(find.text('Changed elsewhere'), findsOneWidget);

    await tester.tap(find.text('Reload'));
    await settle(tester, rounds: 20);
    expect(find.text('Takes in the older endpoint “Old relay”'), findsOneWidget);
    await save(tester, 'Save');
    expect(sent(demo, 'accounts.saveGroup')['revision'], unorderedEquals(['rev-ds-1', 'rev-old-1b']));
    expect(find.byType(AccountEditorScreen), findsNothing, reason: 'saved');
    expect(demo.providers.firstWhere((row) => row['id'] == 'old-1')['groupId'], 'g-ds');
    await leave(tester, services);
  });

  testWidgets('an account with a protocol this build does not know is not saved from here', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek', prepare: (demo) {
      demo.providers.add({...demo.providers[1], 'id': 'ds-x', 'dialect': 'future-protocol'});
    });
    expect(find.textContaining('a protocol this version of the app doesn\'t know'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
    expect(count(demo, 'accounts.saveGroup'), 0);
    await leave(tester, services);
  });

  testWidgets('leaving with changes asks first', (tester) async {
    final (services, demo) = await open(tester, account: 'DeepSeek');
    await tester.enterText(field('Note'), 'Not saved');
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.byType(AccountEditorScreen), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await settle(tester);
    expect(find.byType(AccountEditorScreen), findsNothing);
    expect(count(demo, 'accounts.saveGroup'), 0);
    await leave(tester, services);
  });
}
