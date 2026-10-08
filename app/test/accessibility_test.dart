import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/gallery_screen.dart';
import 'package:skidsense_app/ui/screens/git_pane.dart';
import 'package:skidsense_app/ui/screens/host_shell.dart';
import 'package:skidsense_app/ui/screens/hosts_screen.dart';
import 'package:skidsense_app/ui/screens/login_screen.dart';
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
        await leave(tester, services);
        semantics.dispose();
      });
    }
  }
}
