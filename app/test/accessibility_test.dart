import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/kit/containers.dart';
import 'package:skidsense_app/ui/kit/dialogs.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_editor_screen.dart';
import 'package:skidsense_app/ui/screens/account_screen.dart';
import 'package:skidsense_app/ui/screens/cloud_sheets.dart';
import 'package:skidsense_app/ui/screens/context_sheet.dart';
import 'package:skidsense_app/ui/screens/gallery_screen.dart';
import 'package:skidsense_app/ui/screens/git_pane.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/hosts_screen.dart';
import 'package:skidsense_app/ui/screens/login_screen.dart';
import 'package:skidsense_app/ui/screens/models_pane.dart';
import 'package:skidsense_app/ui/screens/session_screen.dart';
import 'package:skidsense_app/ui/screens/settings_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// Every screen, in both styles and both brightnesses, against the platform
/// guidelines: tap targets big enough to hit (48dp on Android, 44pt on
/// iOS), every tappable thing named for screen readers, and text with
/// enough contrast to read.
void main() {
  /// All four guidelines, every violation reported at once.
  Future<void> check(WidgetTester tester) async {
    final problems = <String>[];
    for (final guideline in [androidTapTargetGuideline, iOSTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline]) {
      final result = await guideline.evaluate(tester);
      if (!result.passed) problems.add('${guideline.description}:\n${result.reason}');
    }
    expect(problems, isEmpty, reason: problems.join('\n\n'));
  }

  for (final style in DesignStyle.values) {
    for (final brightness in Brightness.values) {
      final variant = '${style.name} ${brightness.name}';

      testWidgets('login $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final services = TestServices();
        await tester.runAsync(services.controller.start);
        await tester.pumpWidget(harness(services, const LoginScreen(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        semantics.dispose();
      });

      testWidgets('hosts and settings $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final services = TestServices();
        services.backend.hosts.add(const HostRow(hostId: 'h-lab', name: 'Lab Linux', platform: 'linux', online: true));
        await services.signIn();
        await tester.runAsync(services.controller.start);
        await tester.runAsync(services.controller.refreshHosts);
        await tester.pumpWidget(harness(services, const HostsScreen(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        await tester.pumpWidget(harness(services, const SettingsScreen(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        semantics.dispose();
      });

      testWidgets('account $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        // Read; a read refused, with its retry; the server out of reach.
        for (final setUp in <void Function(FakeBackend)>[
          (_) {},
          (backend) => backend.failures['/api/user/self'] = 1,
          (backend) => backend.offline = true,
        ]) {
          final services = TestServices();
          setUp(services.backend);
          await services.signIn();
          await tester.runAsync(services.controller.start);
          await tester.pumpWidget(harness(services, AccountScreen(key: UniqueKey()), style: style, brightness: brightness));
          await settle(tester);
          await check(tester);
        }
        semantics.dispose();
      });

      testWidgets('gallery $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester, size: const Size(412, 2300));
        await tester.pumpWidget(harness(TestServices(), const GalleryScreen(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        semantics.dispose();
      });

      testWidgets('connected screens $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final (services, _) = await connect(tester);
        await tester.pumpWidget(harness(services, const HostShell(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        for (final tab in [Icons.folder_outlined, Icons.merge_type_outlined]) {
          await tester.tap(find.byIcon(tab).first);
          await settle(tester);
          await check(tester);
        }
        await tester.pumpWidget(harness(
          services,
          SessionScreen(sessionKey: DemoHost.runningKey, onOpenFiles: (_) {}, onOpenGit: (_) {}),
          style: style,
          brightness: brightness,
        ));
        await settle(tester, rounds: 25);
        await check(tester);
        const file = GitFile(path: 'lib/src/app/app_controller.dart', status: 'modified', staged: true);
        await tester.pumpWidget(harness(services, const DiffScreen(root: DemoHost.root, file: file), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        services.backend
          ..scopes = Scopes.all
          ..devices.add({'device_id': 'dev-demo', 'name': 'Pixel 9 Pro XL', 'platform': 'android', 'scopes': Scopes.byDefault, 'status': 'active'});
        await tester.pumpWidget(harness(services, const SettingsScreen(), style: style, brightness: brightness));
        await settle(tester);
        await check(tester);
        await leave(tester, services);
        semantics.dispose();
      });

      testWidgets('models screens $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final (services, demo) = await connect(tester, scopes: [...Scopes.byDefault, Scopes.terminal, Scopes.settings]);
        services.backend.scopes = Scopes.all;
        await tester.pumpWidget(harness(services, const HostShell(), style: style, brightness: brightness));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.layers_outlined));
        await settle(tester, rounds: 20);
        await check(tester);
        // Cloud mode: the local choices quieter, still legible.
        demo.mode = 'cloud';
        await services.controller.config.loadMode();
        await settle(tester);
        await check(tester);
        for (final sheet in <WidgetBuilder>[
          (_) => const CreateKeySheet(canAssign: true),
          (_) => const KeyRevealSheet(name: 'Laptop', secret: 'sk-${FakeBackend.revealedKey}'),
          (_) => const AssignSheet(keyId: 12, keyName: 'Laptop'),
          (_) => const ContextSheet(),
        ]) {
          unawaited(showAppSheet<void>(tester.element(find.byType(ModelsPane)), builder: sheet));
          await settle(tester, rounds: 20);
          await check(tester);
          await tester.tapAt(const Offset(200, 40));
          await settle(tester, rounds: 20);
        }
        // An agent's account choice.
        await tester.scrollUntilVisible(find.text('Claude Code'), 300, scrollable: find.byType(Scrollable).first);
        // Scrolled there in the next frame.
        await tester.pump();
        await tester.tap(find.text('Claude Code').first);
        await settle(tester, rounds: 20);
        await check(tester);
        await tester.tapAt(const Offset(200, 40));
        await settle(tester, rounds: 20);
        final config = services.controller.config;
        final group = config.accounts.value.value!.accounts.first;
        for (final editing in [null, group]) {
          await tester.pumpWidget(harness(services, AccountEditorScreen(group: editing), style: style, brightness: brightness));
          await settle(tester, rounds: 20);
          await check(tester);
        }
        // Taking in an older endpoint.
        await tester.scrollUntilVisible(find.text('Take in an older endpoint'), 400, scrollable: find.byType(Scrollable).first);
        await tester.pump();
        await tester.tap(find.text('Take in an older endpoint'));
        await settle(tester, rounds: 20);
        await check(tester);
        await leave(tester, services);
        semantics.dispose();
      });

      testWidgets('models, view only $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final (services, _) = await connect(tester);
        await tester.pumpWidget(harness(services, const ModelsPane(), style: style, brightness: brightness));
        await settle(tester, rounds: 20);
        await check(tester);
        await leave(tester, services);
        semantics.dispose();
      });

      testWidgets('composer options and commands $variant', (tester) async {
        final semantics = tester.ensureSemantics();
        phoneSurface(tester);
        final (services, demo) = await connect(tester, scopes: [...Scopes.byDefault, Scopes.terminal, Scopes.settings]);
        await tester.pumpWidget(harness(
          services,
          SessionScreen(sessionKey: 'claude:s-idle', onOpenFiles: (_) {}, onOpenGit: (_) {}),
          style: style,
          brightness: brightness,
        ));
        await settle(tester, rounds: 25);
        // Local mode with the account menu; cloud mode; cloud with nothing assigned.
        for (final change in <void Function()>[
          () {},
          () => demo.mode = 'cloud',
          () => demo.providers.removeWhere((row) => row['source'] == 'first-party'),
        ]) {
          change();
          demo.host.emit(Events.accountsChanged, const {});
          await settle(tester);
          await openOptions(tester, style);
          await check(tester);
          await tester.tapAt(const Offset(200, 40));
          await settle(tester, rounds: 20);
        }
        await tester.enterText(find.byType(TextField).last, '/');
        await settle(tester, rounds: 20);
        expect(find.byType(FloatingPanel), findsOneWidget);
        await check(tester);
        await leave(tester, services);
        semantics.dispose();
      });
    }
  }
}
