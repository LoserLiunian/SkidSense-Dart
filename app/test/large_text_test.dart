import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/ui/kit/containers.dart';
import 'package:skidsense_app/ui/kit/dialogs.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
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

/// The largest system font sizes, in both styles and all three languages:
/// nothing may overflow (an overflow is a test failure), on a small phone.
void main() {
  const scale = 2.0;
  const small = Size(360, 740);
  const locales = [Locale('en'), Locale('zh'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')];

  /// Every chip shows its label whole: a chip's label is one line, and what
  /// does not fit is cut off without an overflow — a choice group too long
  /// for chips lists its options instead.
  void expectChipsWhole(WidgetTester tester) {
    for (final element in find.descendant(of: find.byType(RawChip), matching: find.byType(RichText)).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text.toPlainText();
      expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" cut off');
      expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5), reason: '"$text" cut off');
    }
  }

  /// The bottom bar's labels each on one line, in the window — smaller,
  /// shown only picked or cut short as the bar must, never broken (in
  /// these tests' font, far wider than the real ones: the real ones are
  /// held to more in `navigation_bar_test.dart`).
  void expectBarLabelsOnOneLine(WidgetTester tester) {
    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final element in find.descendant(of: bar, matching: find.byType(RichText)).evaluate()) {
      if (element.findAncestorWidgetOfExactType<Icon>() != null) continue;
      final paragraph = element.renderObject! as RenderParagraph;
      final text = paragraph.text.toPlainText();
      final lines = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)).map((box) => box.top.round()).toSet();
      expect(lines, hasLength(1), reason: '"$text" on one line');
      final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
      expect(rect.left >= 0 && rect.right <= small.width, isTrue, reason: '"$text" in the window: $rect');
    }
  }

  /// Down the whole of [scrollable], so every part of it is laid out.
  Future<void> scrollThrough(WidgetTester tester, Finder scrollable) async {
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var i = 0; i < 60 && position.pixels < position.maxScrollExtent; i++) {
      await tester.drag(scrollable, const Offset(0, -400), warnIfMissed: false);
      await settle(tester, rounds: 3);
    }
  }

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
        await scrollThrough(tester, find.byType(Scrollable).first);
        // The account read, then a read that failed, with its retry.
        await tester.pumpWidget(at(services, const AccountScreen()));
        await settle(tester);
        expect(find.byType(InlineBanner), findsNothing);
        await scrollThrough(tester, find.byType(Scrollable).first);
        services.backend.failures['/api/user/self'] = 1;
        await tester.pumpWidget(at(services, AccountScreen(key: UniqueKey())));
        await settle(tester);
        expect(find.byType(InlineBanner), findsOneWidget);
        await scrollThrough(tester, find.byType(Scrollable).first);
      });

      testWidgets('connected screens $variant', (tester) async {
        phoneSurface(tester, size: small);
        final (services, _) = await connect(tester);
        await tester.pumpWidget(at(services, const HostShell()));
        await settle(tester);
        expectBarLabelsOnOneLine(tester);
        for (final tab in [Icons.folder_outlined, Icons.merge_type_outlined, Icons.history_outlined]) {
          await tester.tap(find.byIcon(tab).first);
          await settle(tester);
          expectBarLabelsOnOneLine(tester);
        }
        await tester.pumpWidget(at(
          services,
          SessionScreen(sessionKey: DemoHost.runningKey, onOpenFiles: (_) {}, onOpenGit: (_) {}),
        ));
        await settle(tester, rounds: 25);
        const file = GitFile(path: 'lib/src/app/app_controller.dart', status: 'modified', staged: true);
        await tester.pumpWidget(at(services, const DiffScreen(root: DemoHost.root, file: file)));
        await settle(tester);
        // The permissions, with models & accounts among them, of another phone.
        services.backend
          ..scopes = Scopes.all
          ..devices.add({'device_id': 'dev-other', 'name': 'iPad', 'platform': 'ios', 'scopes': Scopes.byDefault, 'status': 'active'});
        await tester.pumpWidget(at(services, const SettingsScreen()));
        await settle(tester);
        await tester.scrollUntilVisible(find.byType(PopupMenuButton<String>), 300, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await settle(tester);
        await tester.tap(find.byType(PopupMenuItem<String>).at(1));
        await settle(tester);
        expect(find.byType(CheckboxListTile), findsWidgets);
        await leave(tester, services);
      });

      testWidgets('models screens $variant', (tester) async {
        phoneSurface(tester, size: small);
        final (services, _) = await connect(tester, scopes: [...Scopes.byDefault, Scopes.terminal, Scopes.settings]);
        await tester.pumpWidget(at(services, const HostShell()));
        await settle(tester);
        await tester.tap(find.byIcon(Icons.layers_outlined));
        await settle(tester, rounds: 20);
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        expectBarLabelsOnOneLine(tester);
        await scrollThrough(tester, find.byType(Scrollable).first);
        for (final sheet in <WidgetBuilder>[
          (_) => const CreateKeySheet(canAssign: true),
          (_) => const KeyRevealSheet(name: 'Laptop', secret: 'sk-${FakeBackend.revealedKey}'),
          (_) => const AssignSheet(keyId: 12, keyName: 'Laptop'),
          (_) => const ContextSheet(),
        ]) {
          unawaited(showAppSheet<void>(tester.element(find.byType(ModelsPane)), builder: sheet));
          await settle(tester, rounds: 20);
          expectChipsWhole(tester);
          await scrollThrough(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
          await tester.tapAt(const Offset(180, 20));
          await settle(tester, rounds: 20);
        }
        // An agent's account choice.
        await tester.pumpWidget(at(services, const ModelsPane()));
        await settle(tester, rounds: 20);
        await tester.scrollUntilVisible(find.text('Claude Code'), 300, scrollable: find.byType(Scrollable).first);
        // Scrolled there in the next frame.
        await tester.pump();
        await tester.tap(find.text('Claude Code').first);
        await settle(tester, rounds: 20);
        await scrollThrough(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
        await tester.tapAt(const Offset(180, 20));
        await settle(tester, rounds: 20);
        final group = services.controller.config.accounts.value.value!.accounts.first;
        for (final editing in [null, group]) {
          await tester.pumpWidget(at(services, AccountEditorScreen(group: editing)));
          await settle(tester, rounds: 20);
          if (editing == null) {
            await tester.tap(find.text('DeepSeek').first);
            await settle(tester);
          }
          expectChipsWhole(tester);
          await scrollThrough(tester, find.byType(Scrollable).first);
        }
        // Taking in an older endpoint, the editor scrolled to its end.
        await tester.tap(find.text(L10n.of(tester.element(find.byType(AccountEditorScreen))).editorAdopt));
        await settle(tester, rounds: 20);
        expectChipsWhole(tester);
        await scrollThrough(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
        await leave(tester, services);
      });

      testWidgets('composer options and commands $variant', (tester) async {
        phoneSurface(tester, size: small);
        final (services, demo) = await connect(tester, scopes: [...Scopes.byDefault, Scopes.terminal, Scopes.settings]);
        await tester.pumpWidget(at(services, SessionScreen(sessionKey: 'claude:s-idle', onOpenFiles: (_) {}, onOpenGit: (_) {})));
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
          expectChipsWhole(tester);
          await scrollThrough(tester, find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
          await tester.tapAt(const Offset(180, 20));
          await settle(tester, rounds: 20);
        }
        await tester.enterText(find.byType(TextField).last, '/');
        await settle(tester, rounds: 20);
        expect(find.byType(FloatingPanel), findsOneWidget);
        await scrollThrough(tester, find.descendant(of: find.byType(FloatingPanel), matching: find.byType(Scrollable)));
        await leave(tester, services);
      });
    }
  }
}
