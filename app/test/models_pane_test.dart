import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/kit/containers.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_editor_screen.dart';
import 'package:skidsense_app/ui/screens/context_sheet.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/models_pane.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// The models tab (spec §7.1): where it shows, what a phone without
/// `settings` may do there, and what each control sends the computer.
void main() {
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];
  const tall = Size(412, 2600);

  Map<String, Object?> sent(DemoHost demo, String method) => demo.settingsCalls.lastWhere((call) => call.$1 == method).$2;
  int count(DemoHost demo, String method) => demo.settingsCalls.where((call) => call.$1 == method).length;

  Future<void> tapMenu(WidgetTester tester, String row, String item) async {
    await tester.tap(find.descendant(of: find.widgetWithText(ListTile, row), matching: find.byTooltip('More')).first);
    await settle(tester);
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  group('the tab', () {
    testWidgets('shows for a computer that lists accounts.list, in fifth place; an older one keeps four', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester, prepare: (demo) {
        demo.host.methods = [for (final method in demo.host.methods) if (!method.startsWith('accounts.') && !method.startsWith('mode.')) method];
      });
      await tester.pumpWidget(harness(services, const HostShell()));
      await settle(tester);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.byIcon(Icons.layers_outlined), findsNothing);
      await leave(tester, services);

      final (current, _) = await connect(tester);
      await tester.pumpWidget(harness(current, const HostShell()));
      await settle(tester);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      await tester.tap(find.byIcon(Icons.history_outlined));
      await settle(tester);
      expect(find.text('History'), findsWidgets, reason: 'the other tabs keep their places');
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await settle(tester, rounds: 20);
      expect(find.byType(ModelsPane), findsOneWidget);
      expect(find.text('DeepSeek'), findsWidgets);
      await leave(tester, current);
    });

    testWidgets('without settings it only shows, and says where to turn it on', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester);
      services.backend.scopes = Scopes.all;
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      expect(find.text('View only'), findsOneWidget);
      expect(find.textContaining('turn on “Models & accounts” for it'), findsOneWidget);
      expect(find.text('Add account'), findsNothing);
      expect(find.text('The provider accounts on the computer. Their keys stay in its keychain.'), findsOneWidget,
          reason: 'no word of adding one here');
      // The keys are this phone's sign-in's own (spec §7): still its to manage.
      expect(find.text('New key'), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more_rounded), findsNothing);
      expect(find.byIcon(Icons.link_off_rounded), findsNothing);
      await tester.tap(find.text('Cloud'));
      await settle(tester);
      expect(find.text('Switch to cloud?'), findsNothing);
      expect(demo.settingsCalls.where((call) => !call.$1.endsWith('.list') && !call.$1.endsWith('.get') && call.$1 != 'accounts.presets'), isEmpty);
      await leave(tester, services);
    });

    testWidgets('a backend that knows no settings scope sends nobody to turn on a switch the computer has not got', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      expect(find.text('View only'), findsOneWidget);
      expect(find.textContaining('turn on'), findsNothing);
      expect(find.textContaining('can only be viewed'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('what the backend knows, not read (yet, or the read failed), is not taken for a backend without settings', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester);
      services.backend
        ..scopes = Scopes.all
        ..failures['/api/companion/config'] = 1;
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      expect(services.controller.state.serverScopes, isNull, reason: 'the read failed');
      expect(find.text('View only'), findsOneWidget);
      expect(find.textContaining('can only be viewed'), findsNothing, reason: 'nothing is known of the backend');
      expect(find.textContaining('turn on “Models & accounts” for it'), findsOneWidget);

      // Read at last — a backend from before settings — and said so.
      services.backend.scopes = null;
      unawaited(services.controller.loadServerScopes());
      await settle(tester, rounds: 10);
      expect(services.controller.state.serverScopes, Scopes.legacy);
      expect(find.textContaining('can only be viewed'), findsOneWidget);
      expect(find.textContaining('turn on'), findsNothing);
      await leave(tester, services);
    });

    testWidgets("a phone granted settings is told of its computer first, whatever is known of the backend", (tester) async {
      phoneSurface(tester, size: tall);
      // Granted, by a computer that lists no settings method to a phone.
      for (final listed in <List<String>?>[null, Scopes.legacy, Scopes.all]) {
        final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
          demo.host.methods = [for (final method in demo.host.methods) if (Methods.scope[method] != Scopes.settings) method];
        });
        if (listed == null) {
          services.backend.failures['/api/companion/config'] = 1;
        } else {
          services.backend.scopes = listed == Scopes.legacy ? null : listed;
        }
        await tester.pumpWidget(harness(services, const ModelsPane()));
        await settle(tester, rounds: 20);
        expect(services.controller.state.serverScopes, listed, reason: '$listed');
        expect(find.text('View only'), findsOneWidget, reason: '$listed');
        expect(find.textContaining("SkidSense on this computer can't take these changes from a phone yet"), findsOneWidget, reason: '$listed');
        expect(find.textContaining('can only be viewed'), findsNothing, reason: '$listed');
        await leave(tester, services);
      }
    });
  });

  group('the route', () {
    testWidgets('a switch is asked about first; the computer\'s refusal is shown as it said it', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all, prepare: (demo) => demo.providers.removeWhere((row) => row['source'] == 'first-party'));
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);

      await tester.tap(find.text('Cloud'));
      await settle(tester);
      expect(find.text('Switch to cloud?'), findsOneWidget);
      expect(find.textContaining('affects every conversation on this computer'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(count(demo, 'mode.set'), 0);

      await tester.tap(find.text('Cloud'));
      await settle(tester);
      await tester.tap(find.text('Switch'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'mode.set'), {'mode': 'cloud'});
      expect(find.text('The computer didn\'t switch'), findsOneWidget);
      expect(find.text('云端模式需要先分配模型 —— 到「API Key」里选一把 Key 分配模型'), findsOneWidget);
      expect(services.controller.config.mode.value.value, 'local');
      await leave(tester, services);
    });

    testWidgets('a switch made shows at once, with what it means for the local choices', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      await tester.tap(find.text('Cloud'));
      await settle(tester);
      await tester.tap(find.text('Switch'));
      await settle(tester, rounds: 20);
      expect(demo.mode, 'cloud');
      expect(find.text('Switched to cloud'), findsOneWidget);
      expect(find.textContaining('Cloud mode is on'), findsOneWidget);
      // What the route uses now comes first; the local choices wait under it.
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Cloud API keys'), lessThan(top('Local accounts')));
      expect(top('Assigned to agents'), lessThan(top('Local accounts')));
      await leave(tester, services);
    });

    testWidgets('the two routes side by side on any common phone, one over the other only where large text leaves either too narrow', (tester) async {
      Future<(Rect, Rect)> cards(double width, double scale) async {
        phoneSurface(tester, size: Size(width, 1600));
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(harness(services, const ModelsPane(), textScale: scale));
        await settle(tester, rounds: 20);
        Rect card(String title) => tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(Card)).first);
        final both = (card('Local'), card('Cloud'));
        await leave(tester, services);
        return both;
      }

      // 360dp (the narrowest common phone) to 412dp, at the normal size and
      // a little over it.
      for (final (width, scale) in [(360.0, 1.0), (360.0, 1.2), (393.0, 1.0), (412.0, 1.0), (412.0, 1.3)]) {
        final (local, cloud) = await cards(width, scale);
        expect(cloud.top, local.top, reason: '$width dp at $scale×');
        expect(cloud.left, greaterThan(local.right), reason: '$width dp at $scale×');
      }
      for (final (width, scale) in [(360.0, 1.5), (360.0, 2.0), (412.0, 2.0)]) {
        final (big, below) = await cards(width, scale);
        expect(below.top, greaterThan(big.bottom), reason: '$width dp at $scale×');
        expect(below.width, big.width, reason: '$width dp at $scale×');
        expect(big.width, width - 2 * 16, reason: 'each the whole width');
      }
    });
  });

  group('local accounts', () {
    testWidgets('an agent picks from its own protocol\'s accounts; the choice goes to the computer', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      // Claude Code runs on DeepSeek's Anthropic endpoint.
      expect(find.text('→ api.deepseek.com/anthropic · deepseek-v4-pro'), findsOneWidget);
      expect(find.text('→ 192.168.1.20:11434/v1 · qwen3-coder:30b · no key stored'), findsOneWidget);
      // What the CLI's own configuration means is said once, where it is picked.
      const cliRoute = "Decided by the CLI's own configuration (for example the file cc-switch writes)";
      expect(find.text("Follow the CLI's own configuration"), findsNWidgets(4), reason: 'ZCode, Codex, dsh, Gemini CLI');
      expect(find.text(cliRoute), findsNothing);

      await tester.tap(find.text('Claude Code').first);
      await settle(tester);
      expect(find.text('Account for Claude Code'), findsOneWidget);
      expect(find.text(cliRoute), findsOneWidget);
      expect(find.text('Official subscription (forced)'), findsWidgets);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Ollama on the Mac Studio')), findsNothing,
          reason: 'another protocol');
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('DeepSeek')), findsOneWidget);
      await tester.tap(find.text('Official subscription (forced)').last);
      await settle(tester, rounds: 20);
      expect(sent(demo, 'accounts.setActive'), {
        'agent': 'claude',
        'choice': {'kind': 'official'},
      });
      expect(find.text('Official subscription (forced)'), findsOneWidget, reason: 'read again after accounts.changed');

      await tester.tap(find.text('Codex').first);
      await settle(tester);
      expect(find.text('Official subscription (forced)'), findsOneWidget, reason: 'Codex cannot be forced');
      expect(find.text('No OpenAI Responses account yet.'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Follow the CLI\'s own configuration').last);
      await settle(tester);
      expect(count(demo, 'accounts.setActive'), 1, reason: 'unchanged: nothing sent');
      await leave(tester, services);
    });

    testWidgets('an account is deleted with the revision it was read with; one changed meanwhile is read again', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      demo.answers['accounts.removeGroup'] = {'ok': false, 'error': '这个账号已在别处修改，请重新载入后再保存', 'code': 'conflict'};
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      final reads = count(demo, 'accounts.list');

      await tapMenu(tester, 'Ollama on the Mac Studio', 'Delete');
      expect(find.text('Delete “Ollama on the Mac Studio”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'accounts.removeGroup'), {'groupId': 'g-ol', 'revision': 'rev-ol-1'});
      expect(find.textContaining('was changed elsewhere and has been read again'), findsOneWidget);
      expect(count(demo, 'accounts.list'), greaterThan(reads));

      demo.answers.remove('accounts.removeGroup');
      await tapMenu(tester, 'Old relay', 'Delete');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'accounts.remove'), {'providerId': 'old-1'}, reason: 'an endpoint from before accounts');
      expect(find.text('Old relay'), findsNothing);
      await leave(tester, services);
    });

    testWidgets('an account shows its note, then what it is made of; an older endpoint its address', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      expect(find.text('Personal key, pay as you go'), findsOneWidget);
      expect(find.text('DeepSeek preset · Key stored · Anthropic (2 models) · OpenAI Chat (2 models)'), findsOneWidget);
      expect(find.text('No key · OpenAI Chat (2 models)'), findsOneWidget, reason: 'a custom one names no preset');
      expect(find.text('relay.example.com/v1'), findsOneWidget);
      expect(find.text('Key stored · Pick its protocol to make it an account'), findsOneWidget);
      // Waiting on the user, not working: no living shape.
      final badge = tester.widget<StatusBadge>(find.ancestor(of: find.text('Older endpoint'), matching: find.byType(StatusBadge)));
      expect(badge.tone, StatusTone.neutral);
      // The computer's own name for an assignment is in its words.
      expect(find.text('Claude Code · Laptop'), findsOneWidget);
      expect(find.textContaining('第一方'), findsNothing);
      await leave(tester, services);
    });

    testWidgets('editing opens the account in the editor; adding opens an empty one', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      await tester.tap(find.text('Ollama on the Mac Studio').last);
      await settle(tester, rounds: 20);
      expect(find.text('Edit account'), findsWidgets);
      expect(find.text('http://192.168.1.20:11434/v1'), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Add account'));
      await settle(tester, rounds: 20);
      expect(find.byType(AccountEditorScreen), findsOneWidget);
      expect(find.text('Add account'), findsWidgets);
      await leave(tester, services);
    });
  });

  group('cloud', () {
    testWidgets('the keys come from the phone\'s own sign-in, masked; the whole key only after an unlock', (tester) async {
      phoneSurface(tester, size: tall);
      final unlock = TestUnlock(false);
      final (services, _) = await connect(tester, scopes: all, biometrics: unlock);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      expect(find.text('Xq7f**********u2Lw'), findsOneWidget);
      expect(find.text('Unlimited quota'), findsOneWidget);
      expect(find.text('\$5.00 left · group vip'), findsOneWidget);
      expect(find.text('Disabled'), findsOneWidget);

      await tapMenu(tester, 'Laptop', 'Show the whole key');
      expect(unlock.reasons, ['Unlock to show the whole key']);
      expect(find.textContaining(FakeBackend.revealedKey), findsNothing, reason: 'not unlocked');
      await leave(tester, services);
    });

    testWidgets('unlocked, the whole key is shown with sk- and a copy button', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      await tapMenu(tester, 'Laptop', 'Show the whole key');
      await settle(tester);
      expect(find.text('Key “Laptop”'), findsOneWidget);
      // A real key's 51 characters, every one of them on screen.
      const key = 'sk-${FakeBackend.revealedKey}';
      expect(key.length, 51);
      expect(tester.widget<MonoBlock>(find.byType(MonoBlock)).text, key);
      final shown = tester.widget<Text>(find.descendant(of: find.byType(MonoBlock), matching: find.byType(Text))).data!;
      expect(shown.replaceAll('\n', ''), key);
      expect(find.text('Copy'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a key is deleted after asking; an assignment is taken back after asking', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await tester.pumpWidget(harness(services, const ModelsPane()));
      await settle(tester, rounds: 20);
      await tapMenu(tester, 'Old test', 'Delete');
      expect(find.text('Delete the key “Old test”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, rounds: 20);
      expect(services.backend.tokens.map((row) => row['id']), isNot(contains(4)));
      expect(find.text('Old test'), findsNothing);

      await tester.tap(find.byTooltip('Unassign').first);
      await settle(tester);
      expect(find.text('Unassign “Claude Code · Laptop”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unassign'));
      await settle(tester, rounds: 20);
      expect(sent(demo, 'cloud.unassign'), {'providerId': 'fp-1'});
      await leave(tester, services);
    });
  });

  testWidgets('the context sizes open from the tab, read only while shown', (tester) async {
    phoneSurface(tester, size: tall);
    final (services, demo) = await connect(tester, scopes: all);
    await tester.pumpWidget(harness(services, const ModelsPane()));
    await settle(tester, rounds: 20);
    expect(count(demo, 'models.context.list'), 0, reason: 'nobody shows it yet');
    await tester.scrollUntilVisible(find.text('When each model compacts'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('When each model compacts'));
    await settle(tester, rounds: 20);
    expect(find.byType(ContextSheet), findsOneWidget);
    expect(count(demo, 'models.context.list'), 1);
    await leave(tester, services);
  });
}
