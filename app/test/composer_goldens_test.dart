import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/session_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/demo_host.dart';
import 'support/harness.dart';

/// The composer's send options and `/` menu, against [DemoHost] over the
/// real protocol: local mode with the account menu, cloud mode, cloud mode
/// with nothing assigned, and the commands over the input.
void main() {
  setUpAll(loadFonts);

  String name(String scene, DesignStyle style, Brightness brightness) =>
      'goldens/${scene}_${style == DesignStyle.expressive ? 'm3e' : 'm3'}_${brightness.name}.png';
  const all = [...Scopes.byDefault, Scopes.terminal, Scopes.settings];
  const shot = ValueKey('shot');
  const idle = 'claude:s-idle';

  /// The whole window, the sheet and the menu over the page included.
  Widget framed(TestServices services, DesignStyle style, Brightness brightness) => RepaintBoundary(
        key: shot,
        child: harness(
          services,
          SessionScreen(sessionKey: idle, onOpenFiles: (_) {}, onOpenGit: (_) {}),
          style: style,
          brightness: brightness,
        ),
      );

  for (final style in DesignStyle.values) {
    for (final brightness in Brightness.values) {
      final variant = '${style.name} ${brightness.name}';

      testWidgets('options, local $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 1240));
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, style, brightness));
        await settle(tester, rounds: 25);
        await openOptions(tester, style);
        await tester.tap(find.text('deepseek-flash'));
        await settle(tester);
        expect(find.text('Models on DeepSeek'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('options_local', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('options, cloud $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 1000));
        final (services, _) = await connect(tester, scopes: all, prepare: (demo) => demo.mode = 'cloud');
        await tester.pumpWidget(framed(services, style, brightness));
        await settle(tester, rounds: 25);
        await openOptions(tester, style);
        expect(find.text('Cloud models'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('options_cloud', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('options, cloud with nothing assigned $variant', (tester) async {
        phoneSurface(tester, size: const Size(412, 1000));
        final (services, _) = await connect(tester, scopes: all, prepare: (demo) {
          demo.mode = 'cloud';
          demo.providers.removeWhere((row) => row['source'] == 'first-party');
        });
        await tester.pumpWidget(framed(services, style, brightness));
        await settle(tester, rounds: 25);
        await openOptions(tester, style);
        expect(find.text('No cloud models yet'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('options_cloud_empty', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);

      testWidgets('slash menu $variant', (tester) async {
        phoneSurface(tester);
        final (services, _) = await connect(tester, scopes: all);
        await tester.pumpWidget(framed(services, style, brightness));
        await settle(tester, rounds: 25);
        await tester.enterText(find.byType(TextField).last, 'Then /re');
        await settle(tester, rounds: 20);
        expect(find.text('Commands'), findsOneWidget);
        await expectLater(find.byKey(shot), matchesGoldenFile(name('slash', style, brightness)));
        await leave(tester, services);
      }, skip: !goldensSupported);
    }
  }
}
