import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/platform/device.dart';
import 'package:skidsense_app/ui/kit/containers.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/cloud_sheets.dart';
import 'package:skidsense_app/ui/screens/context_sheet.dart';
import 'package:skidsense_app/ui/screens/models_pane.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// The sheets of the models tab: a cloud key made with the phone's own
/// sign-in and shown once, its models assigned to the computer's agents
/// (spec §7.1, by the key's id alone), and the context sizes.
void main() {
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];

  Map<String, Object?> sent(DemoHost demo, String method) => demo.settingsCalls.lastWhere((call) => call.$1 == method).$2;
  int count(DemoHost demo, String method) => demo.settingsCalls.where((call) => call.$1 == method).length;

  Future<(TestServices, DemoHost)> pane(WidgetTester tester, {List<String> scopes = all, Biometrics? unlock}) async {
    phoneSurface(tester, size: const Size(412, 2600));
    final (services, demo) = await connect(tester, scopes: scopes, biometrics: unlock ?? TestUnlock(true));
    await tester.pumpWidget(harness(services, const ModelsPane(), style: DesignStyle.material3));
    await settle(tester, rounds: 20);
    return (services, demo);
  }

  Finder inSheet(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);

  group('a new key', () {
    testWidgets('is made as filled in, after an unlock; shown whole once, and goes on to its models', (tester) async {
      final unlock = TestUnlock(true);
      final (services, demo) = await pane(tester, unlock: unlock);
      await tester.tap(find.text('New key'));
      await settle(tester);
      expect(find.text('New API key'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester);
      expect(find.text('Give the key a name'), findsOneWidget);
      expect(services.backend.createdTokens, isEmpty);

      await tester.enterText(inSheet(find.widgetWithText(TextField, 'Name')), 'Phone');
      await tester.tap(find.widgetWithText(SwitchListTile, 'Unlimited quota'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Quota (USD)'), '0');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester);
      expect(find.text('Enter an amount above 0'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Quota (USD)'), '2.5');

      await tester.tap(find.text('The account\'s default'));
      await settle(tester);
      await tester.tap(find.text('vip').last);
      await settle(tester);
      // What the group picked is for, and its price, under the field.
      expect(find.text('Faster, pricier · ×1.5'), findsOneWidget);
      await tester.tap(inSheet(find.text('7 days')));
      await settle(tester);
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);

      expect(unlock.reasons, ['Unlock to show the whole key'], reason: 'it is shown whole once made');
      final body = services.backend.createdTokens.single;
      expect((body['name'], body['unlimited_quota'], body['remain_quota'], body['group']), ('Phone', false, 1250000, 'vip'));
      expect(body['expired_time'], inInclusiveRange(before + 604800, before + 604800 + 60));
      expect(find.text('Key created'), findsOneWidget);
      expect(find.text('This is the whole key, shown only this once.'), findsOneWidget);
      // A real key's 51 characters, every one of them on screen — broken
      // over lines, none cut off at the edge — and copied whole.
      const key = 'sk-${FakeBackend.revealedKey}';
      expect(tester.widget<MonoBlock>(find.byType(MonoBlock)).text, key);
      final shown = find.descendant(of: find.byType(MonoBlock), matching: find.byType(Text));
      expect(tester.widget<Text>(shown).data!.replaceAll('\n', ''), key);
      final box = tester.getRect(find.byType(MonoBlock));
      final text = tester.getRect(shown);
      expect((text.left >= box.left, text.right <= box.right, text.bottom <= box.bottom), (true, true, true));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      await tester.tap(find.text('Copy'));
      await settle(tester);
      expect(copied, key);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);

      await tester.tap(find.text('Assign models'));
      await settle(tester, rounds: 20);
      expect(find.byType(AssignSheet), findsOneWidget);
      expect(find.textContaining('“agent · Phone”'), findsOneWidget);
      expect(sent(demo, 'cloud.keys.models'), {'keyId': 13});
      await leave(tester, services);
    });

    testWidgets('a phone left locked makes no key, and shows none', (tester) async {
      final (services, _) = await pane(tester, unlock: TestUnlock(false));
      await tester.tap(find.text('New key'));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextField, 'Name')), 'Phone');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(services.backend.createdTokens, isEmpty);
      expect(find.text('Key created'), findsNothing);
      expect(find.byType(CreateKeySheet), findsOneWidget, reason: 'to try again');
      await leave(tester, services);
    });

    testWidgets('the keys are the phone\'s own: made and deleted with the computer offline, or without settings', (tester) async {
      final (services, _) = await pane(tester, scopes: Scopes.byDefault);
      services.controller.disconnect();
      await settle(tester, rounds: 10);
      expect(find.text('Not connected to the computer'), findsOneWidget);
      await tester.tap(find.text('New key'));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextField, 'Name')), 'Phone');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(services.backend.createdTokens.single['name'], 'Phone');
      expect(find.text('Assign models'), findsNothing, reason: 'assigning is the computer\'s');
      await tester.tap(find.text('Done'));
      await settle(tester, rounds: 20);

      await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Old test'), matching: find.byTooltip('More')).first);
      await settle(tester);
      expect(find.text('Assign models'), findsNothing);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, rounds: 20);
      expect(services.backend.tokens.map((row) => row['id']), isNot(contains(4)));
      await leave(tester, services);
    });

    testWidgets("a name is as long as new-api takes it, in bytes; the groups' ratios as the account page says them", (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
      services.backend.tokenGroups = {
        'default': {'desc': 'default', 'ratio': 1},
        'auto': {'desc': 'Picks a group per call', 'ratio': '自动'},
      };
      await tester.pumpWidget(harness(services, const Scaffold(body: CreateKeySheet(canAssign: false)), style: DesignStyle.material3));
      await settle(tester);
      // 17 Chinese characters are 51 bytes: one over.
      await tester.enterText(find.widgetWithText(TextField, 'Name'), '我' * 17);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(find.text('Too long: at most 50 letters, or 16 Chinese characters'), findsOneWidget);
      expect(services.backend.createdTokens, isEmpty);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'x' * 51);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(services.backend.createdTokens, isEmpty);

      await tester.tap(find.text('The account\'s default'));
      await settle(tester);
      // As the account page lists them: the name, what it is for under it
      // — a description that only repeats the name left out — and the
      // ratio at the end, no figure being "Auto".
      final menu = find.byWidgetPredicate((widget) => widget is DropdownMenuItem<String> && widget.value == 'auto').last;
      expect(find.descendant(of: menu, matching: find.text('Picks a group per call')), findsOneWidget);
      expect(find.descendant(of: menu, matching: find.text('Auto')), findsOneWidget);
      final plain = find.byWidgetPredicate((widget) => widget is DropdownMenuItem<String> && widget.value == 'default').last;
      expect(find.descendant(of: plain, matching: find.text('×1')), findsOneWidget);
      expect(find.descendant(of: plain, matching: find.byType(Text)), findsNWidgets(2), reason: 'no description under it');
      expect(find.textContaining('自动'), findsNothing);
      await tester.tap(find.text('default').last);
      await settle(tester);
      expect(find.text('×1'), findsOneWidget, reason: 'its ratio under the field');

      await tester.enterText(find.widgetWithText(TextField, 'Name'), '我' * 16);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(services.backend.createdTokens.single['name'], '我' * 16);
      await leave(tester, services);
    });

    for (final style in DesignStyle.values) {
      testWidgets("at twice the text size a group's ratio shows whole, in the menu and under the field (${style.name})", (tester) async {
        phoneSurface(tester, size: const Size(360, 740));
        final (services, _) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
        services.backend.tokenGroups = {
          'default': {'desc': 'Default', 'ratio': 1},
          'vip': {'desc': 'Faster, pricier, for long agent runs', 'ratio': 1.5},
        };
        await tester.pumpWidget(harness(services, const Scaffold(body: CreateKeySheet(canAssign: false)), style: style, textScale: 2));
        await settle(tester);
        void whole(String text) {
          for (final element in find.text(text).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" cut off (${style.name})');
            expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMinIntrinsicWidth(double.infinity) - 0.5), reason: '"$text" cut off (${style.name})');
          }
        }

        await tester.ensureVisible(find.text("The account's default"));
        await settle(tester);
        await tester.tap(find.text("The account's default"));
        await settle(tester);
        expect(find.text('×1.5'), findsWidgets);
        whole('×1.5');
        whole('Faster, pricier, for long agent runs');
        await tester.tap(find.text('vip').last);
        await settle(tester);
        expect(find.text('Faster, pricier, for long agent runs · ×1.5'), findsOneWidget);
        whole('Faster, pricier, for long agent runs · ×1.5');
        await leave(tester, services);
      });
    }

    testWidgets('a phone that may not assign gets the key, and no way on to assigning it', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
      await tester.pumpWidget(harness(services, const Scaffold(body: CreateKeySheet(canAssign: false)), style: DesignStyle.material3));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Phone');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await settle(tester, rounds: 20);
      expect(find.text('Key created'), findsOneWidget);
      expect(find.text('Assign models'), findsNothing);
      expect(services.backend.createdTokens.single['unlimited_quota'], true);
      expect(services.backend.createdTokens.single['expired_time'], -1);
      await leave(tester, services);
    });
  });

  test("an assignment's agent and key, out of the computer's name for it", () {
    expect(cloudAssignmentOf('第一方 · Claude Code · Laptop'), (agent: 'Claude Code', key: 'Laptop'));
    expect(cloudAssignmentOf('云端 · 第一方 · Codex · Home · office'), (agent: 'Codex', key: 'Home · office'));
    expect(cloudAssignmentOf('DeepSeek'), isNull);
    expect(cloudAssignmentOf('第一方 · Codex'), isNull);
    final en = lookupL10n(const Locale('en'));
    expect([cloudAssignmentName(en, '第一方 · Codex · Laptop'), cloudAssignmentName(en, 'Mine')], ['Codex · Laptop', 'Mine']);
    // A key with no name, as the computer names it (`第一方 Key`), in the
    // user's words — the same name, said in theirs.
    expect(cloudAssignmentName(en, '第一方 · Codex · 第一方 Key'), 'Codex · First-party key');
    expect(cloudAssignmentName(lookupL10n(const Locale('zh')), '第一方 · Codex · 第一方 Key'), 'Codex · 第一方 Key');
  });

  group('assigning', () {
    testWidgets('each model is ticked for the agents it goes to, and all go in one call', (tester) async {
      final (services, demo) = await pane(tester);
      await tester.tap(find.text('Laptop'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'cloud.keys.models'), {'keyId': 12});
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(tester);
      expect(find.text('Tick at least one model'), findsOneWidget);

      for (final model in ['claude-sonnet-5', 'claude-opus-5']) {
        await tester.tap(inSheet(find.text(model)));
        await settle(tester, rounds: 3);
      }
      await tester.tap(inSheet(find.text('Codex')));
      await settle(tester);
      for (final model in ['claude-sonnet-5', 'gpt-5.6-codex']) {
        await tester.tap(inSheet(find.text(model)));
        await settle(tester, rounds: 3);
      }
      // As many as the list shows ticked — Codex's — and all of them.
      expect(find.text('Codex: 2 models ticked · 4 assignments in all'), findsOneWidget);
      await tester.tap(inSheet(find.text('Claude Code')));
      await settle(tester);
      expect(find.text('Claude Code: 2 models ticked · 4 assignments in all'), findsOneWidget);
      expect(find.text('To Claude Code, Codex'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'cloud.assign'), {
        'keyId': 12,
        'keyName': 'Laptop',
        'assignments': [
          {'agent': 'claude', 'models': ['claude-sonnet-5', 'claude-opus-5']},
          {'agent': 'codex', 'models': ['claude-sonnet-5', 'gpt-5.6-codex']},
        ],
      });
      expect(find.byType(AssignSheet), findsNothing);
      expect(find.text('Set up 2 agents'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a call that failed part way says what was made, and a second confirm makes only the rest', (tester) async {
      final (services, demo) = await pane(tester);
      demo.answers['cloud.assign'] = {'ok': false, 'error': '后端出错了', 'providers': ['第一方 · Claude Code · Laptop']};
      await tester.tap(find.text('Laptop'));
      await settle(tester, rounds: 20);
      await tester.tap(inSheet(find.text('claude-sonnet-5')));
      await settle(tester);
      await tester.tap(inSheet(find.text('Codex')));
      await settle(tester);
      await tester.tap(inSheet(find.text('gpt-5.6-codex')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(tester, rounds: 20);
      expect(find.text('Only partly done. Made: Claude Code · Laptop. Then: 后端出错了'), findsOneWidget);
      expect(find.byType(AssignSheet), findsOneWidget);
      // Claude Code's is made: no longer ticked, the rest still is.
      expect(find.text('To Claude Code'), findsNothing);
      expect(find.text('To Codex'), findsOneWidget);
      expect(find.text('Codex: 1 model ticked · 1 assignment in all'), findsOneWidget);

      demo.answers.remove('cloud.assign');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'cloud.assign')['assignments'], [
        {'agent': 'codex', 'models': ['gpt-5.6-codex']},
      ], reason: "Claude Code's again would be a second one");
      expect(find.byType(AssignSheet), findsNothing);
      await leave(tester, services);
    });

    for (final style in DesignStyle.values) {
      testWidgets('a computer with one agent: it is the one picked, a chip, and nothing says to pick another (${style.name})', (tester) async {
        phoneSurface(tester, size: const Size(412, 2600));
        final (services, demo) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
        demo.answers['agents.list'] = [
          {'id': 'claude', 'label': 'Claude Code', 'driven': true, 'installed': true, 'tui': true},
          // Not one the computer can drive: not offered.
          {'id': 'codex', 'label': 'Codex', 'driven': false, 'installed': true, 'tui': true},
        ];
        await tester.pumpWidget(harness(services, const ModelsPane(), style: style));
        await settle(tester, rounds: 20);
        await tester.tap(find.text('Laptop'));
        await settle(tester, rounds: 20);
        final only = inSheet(find.widgetWithText(ChoiceChip, 'Claude Code'));
        expect(only, findsOneWidget, reason: style.name);
        expect(tester.widget<ChoiceChip>(only).selected, isTrue, reason: style.name);
        expect(inSheet(find.text('Codex')), findsNothing, reason: style.name);
        expect(find.text('Models ticked now go to this agent, the only one on this computer.'), findsOneWidget, reason: style.name);
        expect(find.text('Models ticked now go to this agent; pick another to give them to several.'), findsNothing, reason: style.name);

        await tester.tap(inSheet(find.text('claude-sonnet-5')));
        await settle(tester);
        expect(find.text('Claude Code: 1 model ticked · 1 assignment in all'), findsOneWidget, reason: style.name);
        await leave(tester, services);
      });
    }

    testWidgets("the computer's agents not read: said so with a retry, not as none there", (tester) async {
      final (services, demo) = await pane(tester);
      demo.answers['agents.list'] = const RemoteCallError('internal', 'agents unavailable');
      await tester.tap(find.text('Laptop'));
      await settle(tester, rounds: 20);
      expect(find.text("Couldn't read the computer's agents"), findsOneWidget);
      expect(find.text('No agent on this computer is installed and supported.'), findsNothing);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm')).onPressed, isNull);
      // Nothing to tick them for: each model's row looks it, whole — its
      // id as dimmed as its box, as every disabled row of the app.
      final context = tester.element(find.byType(AssignSheet));
      Color? ink(String text) => tester.renderObject<RenderParagraph>(inSheet(find.text(text))).text.style?.color;
      expect(tester.widget<CheckboxListTile>(inSheet(find.widgetWithText(CheckboxListTile, 'claude-sonnet-5'))).onChanged, isNull);
      expect(ink('claude-sonnet-5'), Theme.of(context).disabledColor);
      expect(tester.renderObject<RenderParagraph>(inSheet(find.text('claude-sonnet-5'))).text.style?.fontFamily, 'monospace');

      demo.answers.remove('agents.list');
      await tester.tap(find.descendant(of: find.widgetWithText(InlineBanner, "Couldn't read the computer's agents"), matching: find.text('Retry')));
      await settle(tester, rounds: 20);
      expect(find.text("Couldn't read the computer's agents"), findsNothing);
      expect(inSheet(find.text('Codex')), findsOneWidget);
      expect(ink('claude-sonnet-5'), Theme.of(context).colorScheme.onSurface, reason: 'to be ticked now');
      await leave(tester, services);
    });

    testWidgets('a key with no name is sent with none, and named beforehand as the computer will name it', (tester) async {
      phoneSurface(tester, size: const Size(412, 2600));
      // Assigned before from a key with no name: the computer named it.
      final (services, demo) = await connect(tester, scopes: all, prepare: (demo) {
        demo.providers.firstWhere((row) => row['id'] == 'fp-1')['name'] = '第一方 · Claude Code · 第一方 Key';
      });
      services.backend.tokens.first['name'] = '';
      await tester.pumpWidget(harness(services, const ModelsPane(), style: DesignStyle.material3));
      await settle(tester, rounds: 20);
      // Listed in the user's words: the same name the sheet will promise.
      expect(find.text('Claude Code · First-party key'), findsOneWidget);
      expect(find.textContaining('第一方'), findsNothing);

      await tester.tap(find.text('Unnamed'));
      await settle(tester, rounds: 20);
      // Not the phone's word for a key with none: the computer's name for
      // what it makes of one (`第一方 Key`).
      expect(find.textContaining('“agent · First-party key”'), findsOneWidget);
      expect(find.textContaining('Unnamed”'), findsNothing);
      await tester.tap(inSheet(find.text('claude-sonnet-5')));
      await settle(tester);
      demo.answers['cloud.assign'] = {'ok': false, 'error': '后端出错了', 'providers': ['第一方 · Claude Code · 第一方 Key']};
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'cloud.assign').containsKey('keyName'), isFalse);
      expect(find.text('Only partly done. Made: Claude Code · First-party key. Then: 后端出错了'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a key the computer cannot list says why, and is asked again on retry', (tester) async {
      final (services, demo) = await pane(tester);
      demo.answers['cloud.keys.models'] = {'ok': false, 'error': '电脑还没有登录'};
      await tester.tap(find.text('Laptop'));
      await settle(tester, rounds: 20);
      expect(find.text('电脑还没有登录'), findsOneWidget);
      demo.answers.remove('cloud.keys.models');
      await tester.tap(inSheet(find.text('Retry')));
      await settle(tester, rounds: 20);
      expect(find.text('gemini-3.6-pro'), findsOneWidget);
      expect(count(demo, 'cloud.keys.models'), 2);
      await leave(tester, services);
    });
  });

  group('context', () {
    Future<void> open(WidgetTester tester) async {
      await tester.scrollUntilVisible(find.text('When each model compacts'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('When each model compacts'));
      await settle(tester, rounds: 20);
    }

    testWidgets('a threshold is set by dragging, reset from the menu; a window corrected', (tester) async {
      final (services, demo) = await pane(tester);
      demo.context['provider:claude:ds-a:deepseek-v4-pro'] = {'compactAt': 100000};
      await open(tester);
      expect(find.text('Compacts once the context passes 100K, not before.'), findsOneWidget);
      expect(find.text('Default: the agent decides.'), findsNWidgets(3));
      expect(find.text('Default model'), findsOneWidget);
      expect(find.text('Claude Code, built in'), findsOneWidget);
      // The computer's headings are in its words: said in the user's.
      expect(find.text('Claude Code, cloud key “Laptop”'), findsOneWidget);
      expect(find.textContaining('云端'), findsNothing);
      // What each agent does with the size, a line each.
      expect(
        find.text("Claude Code: compacts at the size\nCodex: checked between turns; past it, compacted before the next message\nQwen Code: can't be set; it decides itself"),
        findsOneWidget,
      );

      await tester.drag(find.byType(Slider).first, const Offset(-60, 0));
      await settle(tester, rounds: 20);
      final set = sent(demo, 'models.context.set');
      expect(set['key'], 'provider:claude:fp-1:claude-sonnet-5');
      expect(set['compactAt'], allOf(greaterThanOrEqualTo(10000), lessThanOrEqualTo(5000000)));
      expect(set.containsKey('window'), isFalse);

      await tester.tap(inSheet(find.byTooltip('More')).at(2));
      await settle(tester);
      await tester.tap(find.text('Reset to default'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'models.context.set'), {'key': 'provider:claude:ds-a:deepseek-v4-pro', 'compactAt': null});

      await tester.tap(inSheet(find.byTooltip('More')).at(1));
      await settle(tester);
      await tester.tap(find.text('Correct the window'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '12');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text('Write the window like 200k, 1m or 200000 (1K–100M)'), findsOneWidget);
      await tester.tap(inSheet(find.byTooltip('More')).at(1));
      await settle(tester);
      await tester.tap(find.text('Correct the window'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '300k');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'models.context.set'), {'key': 'provider:claude:fp-1:claude-opus-5', 'window': 300000});
      expect(find.text('Window 300K · set by you'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('every slider ends in one line, named for its model; what may be set follows the connection', (tester) async {
      final semantics = tester.ensureSemantics();
      final (services, demo) = await pane(tester);
      demo.context['provider:claude:ds-a:deepseek-v4-pro'] = {'compactAt': 100000};
      await open(tester);
      // "Default" beside some, "100K" beside another: the tracks end alike.
      final ends = {for (final slider in find.byType(Slider).evaluate()) tester.getRect(find.byWidget(slider.widget)).right};
      expect(ends, hasLength(1));
      expect(find.byType(Slider).evaluate().length, greaterThan(2));
      // One node: the slider, named for its model.
      expect(tester.getSemantics(find.byType(Slider).first), isSemantics(label: 'Compaction size for claude-sonnet-5', isSlider: true, hasIncreaseAction: true));

      // Offline while it shows: nothing to set, as without settings.
      services.controller.disconnect();
      await settle(tester, rounds: 10);
      expect(tester.widgetList<Slider>(find.byType(Slider)).every((slider) => slider.onChanged == null), isTrue);
      expect(inSheet(find.byTooltip('More')), findsNothing);
      semantics.dispose();
      await leave(tester, services);
    });

    testWidgets('without settings it only shows', (tester) async {
      final (services, _) = await pane(tester, scopes: Scopes.byDefault);
      await open(tester);
      expect(find.byType(ContextSheet), findsOneWidget);
      expect(inSheet(find.byTooltip('More')), findsNothing);
      expect(tester.widgetList<Slider>(find.byType(Slider)).every((slider) => slider.onChanged == null), isTrue);
      await leave(tester, services);
    });

    test('sizes read and written as the desktop does', () {
      expect([formatTokenSize(200000), formatTokenSize(1048576), formatTokenSize(1500000), formatTokenSize(999)], ['200K', '1.05M', '1.5M', '999']);
      expect([parseTokens('180k'), parseTokens('1m'), parseTokens('1.5M'), parseTokens('200,000'), parseTokens('big')], [180000, 1000000, 1500000, 200000, null]);
      const scale = CompactScale(10000, 5000000);
      expect([scale.toTokens(0), scale.toTokens(1000)], [10000, 5000000]);
      expect(scale.toTokens(scale.toPosition(200000)), closeTo(200000, 5000));
    });
  });
}
