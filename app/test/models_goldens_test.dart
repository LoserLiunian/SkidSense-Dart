import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/kit/actions.dart';
import 'package:skidsense_app/ui/kit/dialogs.dart';
import 'package:skidsense_app/ui/kit/forms.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_editor_screen.dart';
import 'package:skidsense_app/ui/screens/cloud_sheets.dart';
import 'package:skidsense_app/ui/screens/context_sheet.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/models_pane.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/harness.dart';

/// The models tab and what opens from it, against [DemoHost] over the real
/// protocol: local and cloud mode, a phone that may only look, an agent's
/// account choice, the account editor adding, editing, taking in an older
/// endpoint and refusing, and the key, assignment and context sheets — and
/// the tab and the editor on a tablet.
void main() {
  setUpAll(loadFonts);

  String name(String scene, DesignStyle style, Brightness brightness) =>
      'goldens/${scene}_${style == DesignStyle.expressive ? 'm3e' : 'm3'}_${brightness.name}.png';
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];
  const shot = ValueKey('shot');

  /// The whole window, sheets and dialogs over the page included.
  Widget framed(TestServices services, Widget child, DesignStyle style, Brightness brightness, {double textScale = 1}) =>
      RepaintBoundary(key: shot, child: harness(services, child, style: style, brightness: brightness, textScale: textScale));

  Future<void> openModels(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.layers_outlined).first);
    await settle(tester, rounds: 20);
  }

  /// The second of two choices: M3 Expressive's connected group lays its
  /// labels out apart from where it draws them.
  Future<void> pickSecond(WidgetTester tester, DesignStyle style, String label) async {
    if (style == DesignStyle.expressive) {
      final group = tester.getRect(find.byType(ChoiceGroup<String>));
      await tester.tapAt(Offset(group.right - group.width / 4, group.center.dy));
    } else {
      await tester.tap(find.descendant(of: find.byType(AssignSheet), matching: find.text(label)));
    }
    await settle(tester);
  }

  Future<void> sheet(WidgetTester tester, WidgetBuilder builder) async {
    final context = tester.element(find.byType(ModelsPane));
    unawaited(showAppSheet<void>(context, builder: builder));
    await settle(tester, rounds: 25);
  }

  /// Fields as they rest, not as the last one typed in looks focused.
  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
  }

  /// The editor on an account, read as the models tab reads it.
  Future<AccountGroup> account(WidgetTester tester, TestServices services, String name) async {
    final config = services.controller.config;
    unawaited(config.loadAccounts());
    await pumpUntil(tester, () => config.accounts.value.value != null);
    return config.accounts.value.value!.accounts.firstWhere((group) => group.name == name);
  }

  for (final style in DesignStyle.values) {
    for (final brightness in Brightness.values) {
      final variant = '${style.name} ${brightness.name}';

      testWidgets('models, local $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 2200));
        final (services, _) = await connect(tester, scopes: all);
        services.backend.scopes = Scopes.all;
        await tester.pumpWidget(framed(services, const HostShell(), style, brightness));
        await settle(tester);
        await openModels(tester);
        expect(find.text('Old relay'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('models', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('models, cloud $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 2320));
        final (services, demo) = await connect(tester, scopes: all);
        services.backend.scopes = Scopes.all;
        demo.mode = 'cloud';
        await tester.pumpWidget(framed(services, const HostShell(), style, brightness));
        await settle(tester);
        await openModels(tester);
        expect(find.text('Cloud mode is on: the agents go through the first-party account. These choices take effect when you switch back to local.'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('models_cloud', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('models, view only $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 2240));
        final (services, _) = await connect(tester);
        services.backend.scopes = Scopes.all;
        await tester.pumpWidget(framed(services, const HostShell(), style, brightness));
        await settle(tester);
        await openModels(tester);
        expect(find.text('View only'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('models_readonly', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('account editor, adding $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 3000));
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, const AccountEditorScreen(), style, brightness));
        await settle(tester, rounds: 20);
        await tester.tap(find.widgetWithText(ChoiceChip, 'DeepSeek'));
        await settle(tester);
        await tester.enterText(find.widgetWithText(TextField, 'API key'), 'sk-demo-key');
        await unfocus(tester);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_new', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('account editor, editing $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 2600));
        final (services, _) = await connect(tester, scopes: all);
        final config = services.controller.config;
        unawaited(config.loadAccounts());
        await pumpUntil(tester, () => config.accounts.value.value != null);
        final group = config.accounts.value.value!.accounts.first;
        await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, brightness));
        await settle(tester, rounds: 20);
        expect(find.text('One key for every protocol. A key is stored: leave this empty to keep it.'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_edit', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('create key $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, const ModelsPane(), style, brightness));
        await settle(tester);
        await sheet(tester, (_) => const CreateKeySheet(canAssign: true));
        await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Phone');
        await tester.tap(find.text('Unlimited quota'));
        await unfocus(tester);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('create_key', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('key shown once $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all, biometrics: TestUnlock(true));
        await tester.pumpWidget(framed(services, const ModelsPane(), style, brightness));
        await settle(tester);
        await sheet(tester, (_) => const CreateKeySheet(canAssign: true));
        await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Phone');
        await tester.tap(find.text('Create'));
        await settle(tester, rounds: 25);
        expect(find.text('Key created'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('key_shown', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('account choice $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, const ModelsPane(), style, brightness));
        await settle(tester, rounds: 20);
        await tester.tap(find.text('Claude Code').first);
        await settle(tester, rounds: 25);
        expect(find.text('Account for Claude Code'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('account_choice', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('taking in an older endpoint $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
          demo.providers.add({
            'id': 'old-2', 'name': 'Team gateway', 'note': '', 'kind': 'anthropic', 'agents': <String>[],
            'baseUrl': 'https://gateway.example.com/anthropic', 'models': ['claude-sonnet-5'], 'hasKey': false, 'source': 'byok', 'createdAt': 1,
          });
          demo.revisions['old-2'] = 'rev-old-2';
        });
        final group = await account(tester, services, 'DeepSeek');
        await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, brightness));
        await settle(tester, rounds: 20);
        await tester.scrollUntilVisible(find.text('Take in an older endpoint'), 400, scrollable: find.byType(Scrollable).first);
        // Scrolled there in the next frame.
        await tester.pump();
        await tester.tap(find.text('Take in an older endpoint'));
        await settle(tester, rounds: 25);
        expect(find.text('Take it in'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('adopt', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('account editor, what is wrong $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 2700));
        final (services, demo) = await connect(tester, scopes: all);
        final group = await account(tester, services, 'DeepSeek');
        await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, brightness));
        await settle(tester, rounds: 20);
        await tester.enterText(find.widgetWithText(TextField, 'Base URL').first, 'https://api.deepseek .com/anthropic');
        await tester.enterText(find.widgetWithText(TextField, 'Variables'), 'API_TIMEOUT_MS=600000\nNOEQUALS');
        // A fetch that failed: said under its button, apart from the fields.
        demo.answers['models.discover'] = {'ok': false, 'error': 'x', 'code': 'http', 'status': 401};
        await tester.tap(find.text('Fetch models').first);
        await settle(tester, rounds: 20);
        await unfocus(tester);
        await tester.tap(find.text('Save'));
        await settle(tester, rounds: 20);
        expect(find.text('2 fields need fixing'), findsOneWidget);
        expect(find.text("Couldn't fetch the models"), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_errors', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('account editor, changed elsewhere $variant', (tester) async {
        phoneSurface(tester);
        final (services, demo) = await connect(tester, scopes: all);
        final group = await account(tester, services, 'DeepSeek');
        await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, brightness));
        await settle(tester, rounds: 20);
        demo.revisions['g-ds'] = 'rev-ds-2';
        await tester.enterText(find.widgetWithText(TextField, 'Note'), 'Company key');
        await unfocus(tester);
        await tester.tap(find.text('Save'));
        await settle(tester, rounds: 20);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
        await settle(tester, rounds: 20);
        expect(find.text('Changed elsewhere'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_conflict', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('assign $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, const ModelsPane(), style, brightness));
        await settle(tester);
        await sheet(tester, (_) => const AssignSheet(keyId: 12, keyName: 'Laptop'));
        for (final model in ['claude-sonnet-5', 'claude-opus-5']) {
          await tester.tap(find.text(model));
          await settle(tester, rounds: 5);
        }
        await pickSecond(tester, style, 'Codex');
        await tester.tap(find.text('gpt-5.6-codex'));
        await tester.tap(find.text('claude-sonnet-5'));
        await settle(tester);
        expect(find.text('To Claude Code, Codex'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('assign', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('context $variant', (tester) async {
        phoneSurface(tester);
        final (services, demo) = await connect(tester, scopes: all);
        demo.context['provider:claude:ds-a:deepseek-v4-pro'] = {'compactAt': 100000};
        await tester.pumpWidget(framed(services, const ModelsPane(), style, brightness));
        await settle(tester);
        await sheet(tester, (_) => const ContextSheet());
        expect(find.text('deepseek-v4-pro'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('context', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);
    }

    // A 360dp phone: the two routes side by side at the normal text size,
    // one over the other at twice it.
    for (final scale in [1.0, 2.0]) {
      testWidgets('models on a 360dp phone at ${scale}x ${style.name}', (tester) async {
        phoneSurface(tester, size: const Size(360, 800));
        final (services, _) = await connect(tester, scopes: all);
        services.backend.scopes = Scopes.all;
        await tester.pumpWidget(framed(services, const HostShell(), style, Brightness.light, textScale: scale));
        await settle(tester);
        await openModels(tester);
        await expectLater(find.byKey(shot), matchesGoldenFile(name(scale == 1 ? 'models_narrow' : 'models_large', style, Brightness.light)));
        await leave(tester, services);
      }, skip: !goldensSupported);
    }

    testWidgets('account editor refused, at twice the text size ${style.name}', (tester) async {
      phoneSurface(tester, size: const Size(360, 740));
      final (services, demo) = await connect(tester, scopes: all);
      final group = await account(tester, services, 'DeepSeek');
      await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, Brightness.light, textScale: 2));
      await settle(tester, rounds: 20);
      demo.answers['accounts.saveGroup'] = {'ok': false, 'error': '某个新规则不允许这个账号'};
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(FormActionBar), matching: find.text('Save')));
      await settle(tester, rounds: 20);
      expect(find.text('某个新规则不允许这个账号'), findsOneWidget);
      await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_refused_large', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets("create key, the groups at twice the text size ${style.name}", (tester) async {
      phoneSurface(tester, size: const Size(360, 740));
      final (services, _) = await connect(tester, scopes: all);
      await tester.pumpWidget(framed(services, const ModelsPane(), style, Brightness.light, textScale: 2));
      await settle(tester);
      await sheet(tester, (_) => const CreateKeySheet(canAssign: true));
      await tester.ensureVisible(find.text("The account's default"));
      await settle(tester);
      await tester.tap(find.text("The account's default"));
      await settle(tester);
      expect(find.text('×1.5'), findsWidgets);
      await expectLater(find.byKey(shot), matchesGoldenFile(name('create_key_groups_large', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets("assign, the computer's agents not read ${style.name}", (tester) async {
      phoneSurface(tester);
      final (services, demo) = await connect(tester, scopes: all);
      demo.answers['agents.list'] = const RemoteCallError('internal', 'agents unavailable');
      await tester.pumpWidget(framed(services, const ModelsPane(), style, Brightness.light));
      await settle(tester);
      await sheet(tester, (_) => const AssignSheet(keyId: 12, keyName: ''));
      expect(find.text("Couldn't read the computer's agents"), findsOneWidget);
      await expectLater(find.byKey(shot), matchesGoldenFile(name('assign_agents_failed', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    // The rail beside the tab, and a form no wider than it reads well.
    testWidgets('models on a tablet ${style.name}', (tester) async {
      phoneSurface(tester, size: const Size(1280, 800));
      final (services, _) = await connect(tester, scopes: all);
      services.backend.scopes = Scopes.all;
      await tester.pumpWidget(framed(services, const HostShell(), style, Brightness.light));
      await settle(tester);
      await openModels(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(find.byKey(shot), matchesGoldenFile(name('models_tablet', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets('account editor on a tablet ${style.name}', (tester) async {
      phoneSurface(tester, size: const Size(1280, 800));
      final (services, _) = await connect(tester, scopes: all);
      final group = await account(tester, services, 'DeepSeek');
      await tester.pumpWidget(framed(services, AccountEditorScreen(group: group), style, Brightness.light));
      await settle(tester, rounds: 20);
      await expectLater(find.byKey(shot), matchesGoldenFile(name('account_editor_tablet', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);
  }
}
