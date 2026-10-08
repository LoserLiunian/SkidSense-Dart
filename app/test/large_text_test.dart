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

/// The largest system font sizes, in both styles and all three languages:
/// nothing may overflow (an overflow is a test failure), on a small phone.
void main() {
  const scale = 2.0;
  const small = Size(360, 740);
  const locales = [Locale('en'), Locale('zh'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')];

  for (final style in DesignStyle.values) {
    for (final locale in locales) {
      final variant = '${style.name} ${locale.toLanguageTag()}';
      Widget at(TestServices services, Widget child) =>
          harness(services, child, style: style, locale: locale, textScale: scale);

      testWidgets('signed-out screens $variant', (tester) async {
        phoneSurface(tester, size: small);
        final services = TestServices();
        await tester.runAsync(services.controller.start);
        await tester.pumpWidget(at(services, const LoginScreen()));
        await settle(tester);
        await tester.pumpWidget(at(services, const GalleryScreen()));
        await settle(tester);
      });

      testWidgets('signed-in screens $variant', (tester) async {
        phoneSurface(tester, size: small);
        final services = TestServices();
        services.backend.hosts.add(const HostRow(hostId: 'h-lab', name: 'Lab Linux', platform: 'linux', online: true));
        await services.signIn();
        await tester.runAsync(services.controller.start);
        await tester.runAsync(services.controller.refreshHosts);
        await tester.pumpWidget(at(services, const HostsScreen()));
        await settle(tester);
        await tester.pumpWidget(at(services, const SettingsScreen()));
        await settle(tester);
      });

      testWidgets('connected screens $variant', (tester) async {
        phoneSurface(tester, size: small);
        final (services, _) = await connect(tester);
        await tester.pumpWidget(at(services, const HostShell()));
        await settle(tester);
        for (final tab in [Icons.folder_outlined, Icons.merge_type_outlined, Icons.history_outlined]) {
          await tester.tap(find.byIcon(tab).first);
          await settle(tester);
        }
        await tester.pumpWidget(at(
          services,
          SessionScreen(sessionKey: DemoHost.runningKey, onOpenFiles: (_) {}, onOpenGit: (_) {}),
        ));
        await settle(tester, rounds: 25);
        const file = GitFile(path: 'lib/src/app/app_controller.dart', status: 'modified', staged: true);
        await tester.pumpWidget(at(services, const DiffScreen(root: DemoHost.root, file: file)));
        await settle(tester);
        await leave(tester, services);
      });
    }
  }
}
