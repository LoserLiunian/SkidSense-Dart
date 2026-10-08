import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/git_pane.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/session_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';
import 'package:skidsense_core/testing.dart';

import 'support/demo_host.dart';
import 'support/harness.dart';

/// The screens behind a connection, against [DemoHost] over the real
/// protocol: what a paired phone shows.
void main() {
  setUpAll(loadFonts);

  String name(String scene, DesignStyle style, Brightness brightness) =>
      'goldens/${scene}_${style == DesignStyle.expressive ? 'm3e' : 'm3'}_${brightness.name}.png';

  Future<(TestServices, DemoHost)> connect(WidgetTester tester) async {
    final demo = DemoHost();
    final services = TestServices(carriers: FakeCarriers()..lan = (_) => demo.host);
    await services.signIn();
    await services.pair([demo.paired(server: testBase, userId: 7)]);
    // FakeHost and the in-memory carriers are plain Dart: the whole
    // connection runs on the test's fake clock.
    unawaited(services.controller.start().then((_) => services.controller.connect(demo.host.hostId)));
    await pumpUntil(tester, () => services.controller.state.connected);
    unawaited(services.controller.loadWorkspaces());
    unawaited(services.controller.loadSessions());
    await pumpUntil(tester, () => services.controller.state.sessions.isNotEmpty);
    return (services, demo);
  }

  /// Screens send `unsubscribe` and the like as they go; let those finish
  /// before the test does.
  Future<void> leave(WidgetTester tester, TestServices services) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester, rounds: 5);
    services.controller.disconnect();
    await settle(tester, rounds: 3);
  }

  for (final style in DesignStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('sessions ${style.name} ${brightness.name}', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester);
        await tester.pumpWidget(harness(services, const HostShell(), style: style, brightness: brightness));
        await settle(tester);
        expect(find.text('Refactor the relay reconnect'), findsOneWidget);
        await expectLater(find.byType(HostShell), matchesGoldenFile(name('sessions', style, brightness)));
      await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('session ${style.name} ${brightness.name}', (tester) async {
        phoneSurface(tester, size: const Size(412, 1400));
        final (services, _) = await connect(tester);
        await tester.pumpWidget(harness(
          services,
          SessionScreen(sessionKey: DemoHost.runningKey, onOpenFiles: (_) {}, onOpenGit: (_) {}),
          style: style,
          brightness: brightness,
        ));
        await settle(tester, rounds: 25);
        expect(find.text('Run a command?'), findsOneWidget);
        await expectLater(find.byType(SessionScreen), matchesGoldenFile(name('session', style, brightness)));
      await leave(tester, services);
      }, skip: !goldensSupported);
    }

    testWidgets('files ${style.name}', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester);
      await tester.pumpWidget(harness(services, const HostShell(), style: style));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.folder_outlined).first);
      await settle(tester);
      expect(find.text('pubspec.yaml'), findsOneWidget);
      await expectLater(find.byType(HostShell), matchesGoldenFile(name('files', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets('git ${style.name}', (tester) async {
      phoneSurface(tester, size: const Size(412, 1100));
      final (services, _) = await connect(tester);
      await tester.pumpWidget(harness(services, const HostShell(), style: style));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.merge_type_outlined).first);
      await settle(tester);
      expect(find.text('feature/reconnect'), findsWidgets);
      await expectLater(find.byType(HostShell), matchesGoldenFile(name('git', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets('diff ${style.name}', (tester) async {
      phoneSurface(tester);
      final (services, _) = await connect(tester);
      const file = GitFile(path: 'lib/src/app/app_controller.dart', status: 'modified', staged: true, insertions: 24, deletions: 6);
      await tester.pumpWidget(harness(services, const DiffScreen(root: DemoHost.root, file: file), style: style));
      await settle(tester);
      expect(find.textContaining('_resyncAfterReconnect'), findsOneWidget);
      await expectLater(find.byType(DiffScreen), matchesGoldenFile(name('diff', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);

    testWidgets('tablet ${style.name}', (tester) async {
      phoneSurface(tester, size: const Size(1280, 800));
      final (services, _) = await connect(tester);
      await tester.pumpWidget(harness(services, const HostShell(), style: style));
      await settle(tester);
      await tester.tap(find.text('Refactor the relay reconnect'));
      await settle(tester, rounds: 25);
      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(find.byType(HostShell), matchesGoldenFile(name('tablet', style, Brightness.light)));
      await leave(tester, services);
    }, skip: !goldensSupported);
  }
}
