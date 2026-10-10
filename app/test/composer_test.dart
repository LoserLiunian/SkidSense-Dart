import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/models_pane.dart';
import 'package:skidsense_app/ui/screens/session_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// The composer against [DemoHost] over the real protocol: the model menu
/// grouped by where each model runs and the endpoint sent with a pick
/// (spec §6.1, §7), the account menu, and the `/` menu (§7.1).
void main() {
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];
  const idle = 'claude:s-idle';
  const tall = Size(412, 1400);

  Widget session(TestServices services, [String key = idle]) =>
      harness(services, SessionScreen(sessionKey: key, onOpenFiles: (_) {}, onOpenGit: (_) {}), style: DesignStyle.material3);

  /// The parameters of every request of [method] the phone sent.
  List<Map<String, Object?>> sent(DemoHost demo, String method) =>
      [for (final (name, params) in demo.host.calls) if (name == method) params! as Map<String, Object?>];

  Future<void> open(WidgetTester tester, TestServices services, [String key = idle]) async {
    await tester.pumpWidget(session(services, key));
    await settle(tester, rounds: 25);
  }

  Future<void> options(WidgetTester tester) => openOptions(tester, DesignStyle.material3);

  Future<void> done(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Done'));
    await settle(tester, rounds: 5);
    await tester.tap(find.text('Done'));
    await settle(tester, rounds: 20);
  }

  /// An option of a choice group: a chip, or a row where a label would not
  /// fit on one (the test font is a wide one).
  Widget choice(WidgetTester tester, String label) => tester.widget(
        find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is ChoiceChip || widget is ListTile)).first,
      );
  bool picked(WidgetTester tester, String label) => switch (choice(tester, label)) {
        ChoiceChip(:final selected) || ListTile(:final selected) => selected,
        _ => false,
      };
  bool enabled(WidgetTester tester, String label) => switch (choice(tester, label)) {
        ChoiceChip(:final onSelected) => onSelected != null,
        ListTile(:final enabled, :final onTap) => enabled && onTap != null,
        _ => false,
      };

  Future<void> sendText(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await settle(tester, rounds: 20);
  }

  group('the model menu', () {
    testWidgets("local mode on an account: the account's models, then other accounts of its protocol", (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all);
      await open(tester, services);
      await options(tester);
      expect(find.text('Local account: DeepSeek'), findsOneWidget);
      expect(find.text('Models on DeepSeek'), findsOneWidget);
      // The host decides the default here: it says which.
      expect(find.text('Default (deepseek-v4-pro)'), findsOneWidget);
      expect(find.text('deepseek-flash'), findsOneWidget);
      expect(find.text('Other accounts (this conversation only)'), findsOneWidget);
      expect(find.text('gpt-4.1 · Old relay'), findsOneWidget);
      expect(find.text('Opus'), findsNothing, reason: "the CLI's aliases do not run on an account");
      expect(find.text('Cloud models'), findsNothing);
      await leave(tester, services);
    });

    testWidgets("local mode on the CLI's own: its models, then the other endpoints", (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all);
      await open(tester, services, 'codex:s-done');
      await options(tester);
      expect(find.text("Local: the agent's own configuration"), findsOneWidget);
      expect(find.text("The CLI's own models"), findsOneWidget);
      expect(find.text('Default'), findsNWidgets(2), reason: 'the model and the effort, neither decided here');
      expect(find.text('Opus'), findsOneWidget);
      expect(find.text('Other endpoints (this conversation only)'), findsOneWidget);
      expect(find.text('gpt-4.1 · Old relay'), findsOneWidget);
      expect(find.text('deepseek-flash · DeepSeek'), findsNothing, reason: 'another protocol than Codex speaks');
      await leave(tester, services);
    });

    testWidgets('cloud mode: only what is assigned to the agent, and no account menu', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all, prepare: (demo) => demo.mode = 'cloud');
      await open(tester, services);
      await options(tester);
      expect(find.text('Cloud: through your first-party account'), findsOneWidget);
      expect(find.text('Cloud models'), findsOneWidget);
      expect(find.text('Default (claude-sonnet-5)'), findsOneWidget);
      // By id: the heading says they are assigned, the computer's name for
      // the assignment is in its words.
      expect(find.text('claude-opus-5'), findsOneWidget);
      expect(find.textContaining('第一方'), findsNothing);
      expect(find.text('gpt-5.6-codex'), findsNothing, reason: "Codex's assignment");
      expect(find.text('Opus'), findsNothing);
      expect(find.text('Other accounts (this conversation only)'), findsNothing);
      expect(find.text('Account'), findsNothing);
      await leave(tester, services);
    });

    testWidgets('cloud mode: two keys offering one model are told apart by the key, on the chip too', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all, prepare: (demo) {
        demo.mode = 'cloud';
        demo.providers.add({
          ...demo.providers.firstWhere((row) => row['id'] == 'fp-1'),
          'id': 'fp-3', 'name': '第一方 · Claude Code · Desk', 'note': '云端 Key「Desk」', 'models': ['claude-sonnet-5'],
        });
      });
      await open(tester, services);
      await options(tester);
      expect(find.text('claude-sonnet-5 · Laptop'), findsOneWidget);
      expect(find.text('claude-sonnet-5 · Desk'), findsOneWidget);
      expect(find.text('claude-opus-5'), findsOneWidget, reason: 'offered once: its id alone');
      await tester.tap(find.text('claude-sonnet-5 · Desk'));
      await settle(tester);
      await done(tester);
      expect(find.widgetWithText(ActionChip, 'claude-sonnet-5 · Desk'), findsOneWidget);
      await sendText(tester, 'Hello');
      expect(sent(demo, 'turn.prompt').single, allOf(containsPair('model', 'claude-sonnet-5'), containsPair('providerId', 'fp-3')));

      await options(tester);
      await tester.tap(find.text('claude-opus-5'));
      await settle(tester);
      await done(tester);
      expect(find.widgetWithText(ActionChip, 'claude-opus-5'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a pick goes with its endpoint, and its chip says its name', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await open(tester, services);
      await options(tester);
      await tester.tap(find.text('gpt-4.1 · Old relay'));
      await settle(tester);
      await done(tester);
      expect(find.widgetWithText(ActionChip, 'gpt-4.1 · Old relay'), findsOneWidget);
      await sendText(tester, 'Hello');
      final prompt = sent(demo, 'turn.prompt').single;
      expect(prompt['model'], 'gpt-4.1');
      expect(prompt['providerId'], 'old-1');
      await leave(tester, services);
    });

    testWidgets('a computer that does not check providerId: no other endpoints, and none sent', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all, prepare: (demo) => demo.host.features = null);
      await open(tester, services);
      await options(tester);
      expect(find.text('Other accounts (this conversation only)'), findsNothing);
      expect(find.text('gpt-4.1 · Old relay'), findsNothing);
      await tester.tap(find.text('deepseek-flash'));
      await settle(tester);
      await done(tester);
      await sendText(tester, 'Hello');
      final prompt = sent(demo, 'turn.prompt').single;
      expect(prompt['model'], 'deepseek-flash');
      expect(prompt.containsKey('providerId'), isFalse);
      await leave(tester, services);
    });

    testWidgets("the agent's account switched elsewhere: the pick goes back to the default", (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await open(tester, services);
      await options(tester);
      await tester.tap(find.text('deepseek-flash'));
      await settle(tester);
      await done(tester);
      expect(find.widgetWithText(ActionChip, 'deepseek-flash · DeepSeek'), findsOneWidget);
      final reads = sent(demo, 'models.list').length;

      // On the computer: Claude Code back on its own configuration.
      demo.active['claude'] = {'kind': 'cli'};
      demo.host.emit(Events.accountsChanged, const {});
      await settle(tester, rounds: 20);
      expect(sent(demo, 'models.list'), hasLength(reads + 1), reason: 'read again: a pick may be gone');
      expect(find.byType(ActionChip), findsNothing);
      await sendText(tester, 'Hello');
      final prompt = sent(demo, 'turn.prompt').single;
      expect(prompt.containsKey('model'), isFalse);
      expect(prompt.containsKey('providerId'), isFalse);
      await leave(tester, services);
    });

    testWidgets('a pick the menu no longer offers goes back to the default; one it still does stays', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await open(tester, services);
      await options(tester);
      await tester.tap(find.text('deepseek-flash'));
      await settle(tester);
      await done(tester);

      // The routing changed and changed back: same route, same model.
      demo.host.emit(Events.modeChanged, const {'mode': 'local'});
      await settle(tester, rounds: 20);
      expect(find.widgetWithText(ActionChip, 'deepseek-flash · DeepSeek'), findsOneWidget);

      await options(tester);
      await tester.tap(find.text('gpt-4.1 · Old relay'));
      await settle(tester);
      await done(tester);
      demo.providers.removeWhere((row) => row['id'] == 'old-1');
      demo.host.emit(Events.accountsChanged, const {});
      await settle(tester, rounds: 20);
      expect(find.byType(ActionChip), findsNothing);
      await leave(tester, services);
    });

    testWidgets('switching the account in the options resets the pick and shows its models', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all);
      await open(tester, services);
      await options(tester);
      await tester.tap(find.text('deepseek-flash'));
      await settle(tester);
      expect(find.text('Set on the computer: every conversation with Claude Code uses it from its next turn.'), findsOneWidget);
      await tester.tap(find.text("Follow the CLI's own configuration"));
      await settle(tester, rounds: 25);
      final change = sent(demo, 'accounts.setActive').single;
      expect(change, {'agent': 'claude', 'choice': {'kind': 'cli'}});
      expect(find.text("The CLI's own models"), findsOneWidget);
      expect(find.text('Opus'), findsOneWidget);
      expect(find.text('Other accounts (this conversation only)'), findsNothing);
      expect(find.text('Other endpoints (this conversation only)'), findsOneWidget);
      expect(find.text('deepseek-flash · DeepSeek'), findsOneWidget, reason: 'DeepSeek is another endpoint now');
      expect(find.text("Local: the agent's own configuration"), findsOneWidget);
      await done(tester);
      expect(find.byType(ActionChip), findsNothing, reason: 'the pick was on the account switched away from');
      await leave(tester, services);
    });

    testWidgets("a refused switch says the computer's reason and keeps the choice", (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester, scopes: all, prepare: (demo) {
        demo.answers['accounts.setActive'] = {'ok': false, 'error': '账号不存在'};
      });
      await open(tester, services);
      await options(tester);
      await tester.tap(find.text("Follow the CLI's own configuration"));
      await settle(tester, rounds: 20);
      expect(find.text('账号不存在'), findsOneWidget);
      expect(picked(tester, 'DeepSeek'), isTrue);
      expect(demo.active['claude'], {'kind': 'account', 'providerId': 'ds-a'});
      await leave(tester, services);
    });

    testWidgets('without settings the account menu only shows', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, demo) = await connect(tester);
      services.backend.scopes = Scopes.all;
      await open(tester, services);
      await options(tester);
      // In the models tab's words.
      expect(find.text('To change models and accounts from this phone, turn on “Models & accounts” for it under Remote access on the computer.'), findsOneWidget);
      const cli = "Follow the CLI's own configuration";
      expect(enabled(tester, cli), isFalse);
      await tester.tap(find.text(cli));
      await settle(tester);
      expect(sent(demo, 'accounts.setActive'), isEmpty);
      // The model is this conversation's own: still picked here.
      await tester.tap(find.text('deepseek-flash'));
      await settle(tester);
      await done(tester);
      expect(find.widgetWithText(ActionChip, 'deepseek-flash · DeepSeek'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('the account menu says why it is locked, as the models tab does, and as it changes', (tester) async {
      phoneSurface(tester, size: tall);
      // A backend that knows no settings: nothing to turn on anywhere.
      final (services, _) = await connect(tester);
      await open(tester, services);
      await options(tester);
      expect(find.text("The server this computer uses can't let a phone change models and accounts yet: here they can only be viewed."), findsOneWidget);
      // Gone offline while the menu shows.
      services.controller.disconnect();
      await settle(tester, rounds: 10);
      expect(find.text('Not connected to the computer'), findsWidgets);
      expect(find.textContaining('can only be viewed'), findsNothing);
      await leave(tester, services);

      // Granted settings, by a computer that takes no account switch from a phone.
      final (granted, _) = await connect(tester, scopes: all, prepare: (demo) {
        demo.host.methods = [for (final method in demo.host.methods) if (method != 'accounts.setActive') method];
      });
      granted.backend.scopes = Scopes.all;
      await open(tester, granted);
      await options(tester);
      expect(find.textContaining('SkidSense on this computer can\'t take these changes from a phone yet'), findsOneWidget);
      expect(find.textContaining('turn on'), findsNothing, reason: 'it is on');
      await leave(tester, granted);
    });

    testWidgets('one pick over two groups: both lists once an option of either would not fit a chip', (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
        demo.providers.add({
          'id': 'old-9', 'name': 'The team gateway in the Frankfurt office, on the second floor', 'note': '', 'kind': 'openai-compatible',
          'agents': <String>[], 'baseUrl': 'https://gateway.example.com/v1', 'models': ['gpt-5.6'], 'hasKey': true, 'source': 'byok', 'createdAt': 1,
        });
      });
      await open(tester, services, 'codex:s-done');
      await options(tester);
      // The CLI's own would fit chips; the endpoint beside them would not.
      expect(find.widgetWithText(ListTile, 'gpt-5.6 · The team gateway in the Frankfurt office, on the second floor'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Opus'), findsOneWidget, reason: 'the same pick: the same form');
      expect(find.widgetWithText(ChoiceChip, 'Opus'), findsNothing);
      expect(find.widgetWithText(ListTile, 'gpt-4.1 · Old relay'), findsOneWidget);
      await tester.tap(find.text('Opus'));
      await settle(tester);
      expect(picked(tester, 'Opus'), isTrue);
      expect(picked(tester, 'gpt-4.1 · Old relay'), isFalse);
      await leave(tester, services);
    });

    // A connected group of one would fill the row, picked: Done's look.
    testWidgets("menus of one — Codex's accounts, the approvals of a phone that may not approve — are options in M3 Expressive too, not a group as wide as the row", (tester) async {
      phoneSurface(tester, size: tall);
      final (services, _) = await connect(tester, scopes: [for (final scope in all) if (scope != Scopes.approve) scope]);
      await tester.pumpWidget(harness(
        services,
        SessionScreen(sessionKey: 'codex:s-done', onOpenFiles: (_) {}, onOpenGit: (_) {}),
        style: DesignStyle.expressive,
      ));
      await settle(tester, rounds: 25);
      await openOptions(tester, DesignStyle.expressive);
      expect(find.text('Set on the computer: every conversation with Codex uses it from its next turn.'), findsOneWidget);
      expect(find.text('Approvals (this phone may not approve: default only)'), findsOneWidget);
      for (final only in ["Follow the CLI's own configuration", 'Ask each time']) {
        expect(find.ancestor(of: find.text(only), matching: find.byType(M3EButtonGroup)), findsNothing, reason: only);
        expect(picked(tester, only), isTrue, reason: only);
      }
      await leave(tester, services);
    });

    testWidgets('cloud mode with nothing assigned leads to the models tab', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
        demo.mode = 'cloud';
        demo.providers.removeWhere((row) => row['source'] == 'first-party');
      });
      await tester.pumpWidget(harness(services, const HostShell(), style: DesignStyle.material3));
      await settle(tester);
      await tester.tap(find.text('Why does the LAN probe time out?'));
      await settle(tester, rounds: 25);
      await options(tester);
      expect(find.text('No cloud models yet'), findsOneWidget);
      // A note under the models' heading, as the sheets' other empty lists:
      // no page-sized empty state inside a sheet.
      expect(find.text('Cloud models'), findsOneWidget);
      expect(find.ancestor(of: find.text('No cloud models yet'), matching: find.byType(InlineBanner)), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.textContaining('Default'), findsOneWidget, reason: "only the effort's: no default model to offer");
      await tester.tap(find.text('Assign in Models'));
      await settle(tester, rounds: 25);
      expect(find.byType(SessionScreen), findsNothing);
      expect(find.byType(ModelsPane), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a computer without the models tab: the empty cloud says so, and leads nowhere', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
        demo.mode = 'cloud';
        demo.providers.removeWhere((row) => row['source'] == 'first-party');
        demo.host.methods = [for (final method in demo.host.methods) if (!method.startsWith('accounts.')) method];
      });
      await open(tester, services);
      await options(tester);
      expect(find.text('No cloud models yet'), findsOneWidget);
      expect(find.text('Assign in Models'), findsNothing);
      await leave(tester, services);
    });
  });

  testWidgets("a session opened on a phone reaches its computer's tabs from its menu", (tester) async {
    phoneSurface(tester);
    final (services, _) = await connect(tester);
    await tester.pumpWidget(harness(services, const HostShell(), style: DesignStyle.material3));
    await settle(tester);
    await tester.tap(find.text('Why does the LAN probe time out?'));
    await settle(tester, rounds: 25);
    await tester.tap(find.descendant(of: find.byType(SessionScreen), matching: find.byTooltip('More')));
    await settle(tester);
    await tester.tap(find.text('Files').last);
    await settle(tester, rounds: 25);
    expect(find.byType(SessionScreen), findsNothing);
    expect(find.text('pubspec.yaml'), findsOneWidget);
    await leave(tester, services);
  });

  group('the / menu', () {
    Finder menu() => find.text('Commands');
    Finder row(String name) => find.ancestor(of: find.textContaining('/$name'), matching: find.byType(ListTile));
    List<String> names(WidgetTester tester) => [
          for (final tile in tester.widgetList<ListTile>(find.descendant(of: find.byType(ListView).last, matching: find.byType(ListTile))))
            ((tile.title! as Text).textSpan!.toPlainText()).split(' ').first,
        ];

    int count(WidgetTester tester) =>
        (tester.widget<ListView>(find.byType(ListView).last).childrenDelegate as SliverChildBuilderDelegate).childCount!;

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).last, text);
      await settle(tester, rounds: 10);
    }

    TextEditingValue value(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).last).controller!.value;

    testWidgets('opens on a / at the start or after a space, and closes after the name', (tester) async {
      phoneSurface(tester);
      final (services, demo) = await connect(tester);
      await open(tester, services);
      await type(tester, '/');
      expect(menu(), findsOneWidget);
      // Every command, in the harness's order: as many rows as fit, the rest a scroll away.
      expect(count(tester), 6);
      expect(names(tester), ['/compact', '/clear', '/review', '/release-notes']);
      expect(sent(demo, 'commands.list'), [
        {'agent': 'claude', 'workdir': DemoHost.root},
      ]);
      await type(tester, 'and/or');
      expect(menu(), findsNothing, reason: 'inside a word');
      await type(tester, 'Then /cl');
      expect(menu(), findsOneWidget);
      await type(tester, 'Then /clear ');
      expect(menu(), findsNothing);
      expect(sent(demo, 'commands.list'), hasLength(1), reason: 'the list of a moment ago is kept');
      await leave(tester, services);
    });

    testWidgets('best match first: a name, a name it starts, an alias, then a description', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester);
      await open(tester, services);
      await type(tester, '/re');
      // /clear is also /reset; /pdf's description reads "Read…".
      expect(count(tester), 4);
      expect(names(tester), ['/clear', '/review', '/release-notes', '/pdf']);
      expect(find.text('Built-in · Also /reset, /new'), findsOneWidget);
      expect(find.text('This workspace'), findsOneWidget);
      expect(find.text('Skill · Claude Code'), findsOneWidget);
      expect(find.text('/review  <pr>'), findsOneWidget);
      await leave(tester, services);
    });

    testWidgets('a tap fills in the command where it was typed, ready for its arguments', (tester) async {
      phoneSurface(tester);
      final (services, demo) = await connect(tester);
      await open(tester, services);
      await type(tester, 'Please /rev now');
      // The caret back after "/rev", as if typed there.
      final field = tester.widget<TextField>(find.byType(TextField).last).controller!;
      field.selection = const TextSelection.collapsed(offset: 11);
      await settle(tester);
      await tester.tap(row('review'));
      await settle(tester);
      expect(value(tester).text, 'Please /review now');
      expect(value(tester).selection, const TextSelection.collapsed(offset: 15));
      expect(menu(), findsNothing);
      expect(sent(demo, 'turn.prompt'), isEmpty, reason: 'filled in, not sent');
      await leave(tester, services);
    });

    testWidgets('the keys: down and up through it, Enter to pick, Esc to close', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester);
      await open(tester, services);
      await type(tester, '/re');
      expect(tester.widget<ListTile>(row('clear')).selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester, rounds: 3);
      expect(tester.widget<ListTile>(row('review')).selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester, rounds: 3);
      expect(tester.widget<ListTile>(row('pdf')).selected, isTrue, reason: 'round to the last');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(value(tester).text, '/pdf ');

      await type(tester, '/pdf and /co');
      expect(menu(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester, rounds: 3);
      expect(menu(), findsNothing);
      expect(value(tester).text, '/pdf and /co', reason: 'Esc closes the menu, nothing else');
      await type(tester, '/pdf and /com');
      expect(menu(), findsOneWidget, reason: 'open again once the text changes');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle(tester);
      expect(value(tester).text, '/pdf and /compact ');
      await leave(tester, services);
    });

    testWidgets('a computer from before the menu, or a turn running: no menu', (tester) async {
      phoneSurface(tester);
      final (services, demo) = await connect(tester, prepare: (demo) {
        demo.host.methods = [for (final method in demo.host.methods) if (method != 'commands.list') method];
      });
      await open(tester, services);
      await type(tester, '/');
      expect(menu(), findsNothing);
      expect(sent(demo, 'commands.list'), isEmpty);
      await leave(tester, services);

      final (current, demo2) = await connect(tester);
      await open(tester, current, DemoHost.runningKey);
      await type(tester, '/');
      expect(menu(), findsNothing, reason: 'what steers a running turn is no command');
      expect(sent(demo2, 'commands.list'), isEmpty);
      await leave(tester, current);
    });

    testWidgets('while the first list comes it says so; a failed one leaves the text alone', (tester) async {
      phoneSurface(tester);
      final (services, demo) = await connect(tester);
      final answer = Completer<Object?>();
      final served = demo.host.handler;
      demo.host.handler = (method, params) => method == 'commands.list' ? answer.future : served(method, params);
      await open(tester, services);
      await type(tester, '/re');
      expect(menu(), findsOneWidget);
      expect(find.text('Reading the commands…'), findsOneWidget);
      answer.completeError(const RemoteCallError('internal', 'boom'));
      await settle(tester);
      expect(menu(), findsNothing);
      expect(value(tester).text, '/re');
      await leave(tester, services);
    });
  });
}
