import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/kit/actions.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_screen.dart';
import 'package:skidsense_app/ui/screens/settings_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';

import 'support/harness.dart';

/// The account page: the phone's own sign-in read from the backend — who,
/// where, the balance in dollars, the groups — with no computer involved;
/// what it shows when the read fails or the backend is out of reach; and
/// signing out, which moved here from the settings.
void main() {
  Future<TestServices> signedIn(WidgetTester tester) async {
    phoneSurface(tester, size: const Size(412, 1400));
    final services = TestServices();
    await services.signIn();
    await tester.runAsync(services.controller.start);
    return services;
  }

  Future<void> open(WidgetTester tester, TestServices services) async {
    await tester.pumpWidget(harness(services, const AccountScreen(), style: DesignStyle.material3));
    await settle(tester);
  }

  Finder retry() => find.widgetWithText(AppButton, 'Retry');

  testWidgets('shows who is signed in and where, the balance in dollars, and the groups with their ratios', (tester) async {
    final semantics = tester.ensureSemantics();
    final services = await signedIn(tester);
    await open(tester, services);

    expect(find.text('liunian'), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text(testBase), findsOneWidget);
    // 617280000 and 43105000 quota units, at 500000 to the dollar.
    expect(find.text(r'$1,234.56'), findsOneWidget);
    expect(find.text(r'$86.21'), findsOneWidget);

    // The account's own group first, marked; a description that only
    // repeats the name is left out.
    final groups = find.descendant(of: find.byType(ListTile), matching: find.byType(Text));
    final names = [for (final text in tester.widgetList<Text>(groups)) text.data].whereType<String>().toList();
    expect(names.indexOf('default'), lessThan(names.indexOf('vip')));
    expect(find.widgetWithText(ListTile, 'Your group'), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(ListTile, 'default'), matching: find.text('Your group')), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.text('×1'), findsOneWidget);
    expect(find.text('Faster, pricier'), findsOneWidget);
    expect(find.text('×1.5'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Ratio ×1\.5')), findsOneWidget);
    expect(find.byType(InlineBanner), findsNothing);
    semantics.dispose();
  });

  testWidgets('says it is reading until the figures come', (tester) async {
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(services, const AccountScreen(), style: DesignStyle.material3));
    expect(find.text('Reading your account…'), findsOneWidget);
    expect(find.text('liunian'), findsOneWidget);
    await settle(tester);
    expect(find.text('Reading your account…'), findsNothing);
    expect(find.text(r'$1,234.56'), findsOneWidget);
  });

  testWidgets('counts the quota as the desktop does: a string of units, and less than a cent', (tester) async {
    final services = await signedIn(tester);
    services.backend.self = {...services.backend.self, 'quota': '2500000', 'used_quota': 2000};
    await open(tester, services);

    expect(find.text(r'$5.00'), findsOneWidget);
    expect(find.text(r'$0.0040'), findsOneWidget);
  });

  testWidgets('a group the list lacks is still the account\'s; auto has no one ratio', (tester) async {
    final services = await signedIn(tester);
    services.backend
      ..self = {...services.backend.self, 'group': 'svip'}
      ..tokenGroups = {
        'auto': {'desc': 'Picks a group per call', 'ratio': '自动'},
        'default': {'desc': 'Default', 'ratio': 1},
      };
    await open(tester, services);

    expect(find.descendant(of: find.widgetWithText(ListTile, 'svip'), matching: find.text('Your group')), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(ListTile, 'auto'), matching: find.text('Auto')), findsOneWidget);
    expect(find.text('自动'), findsNothing);
    expect(find.text('×1'), findsOneWidget);
  });

  testWidgets('a failed read says why, and the retry reads again', (tester) async {
    final services = await signedIn(tester);
    services.backend.failures['/api/user/self'] = 1;
    await open(tester, services);

    expect(find.text('Couldn\'t read your account'), findsOneWidget);
    expect(find.textContaining('Database is busy'), findsOneWidget);
    // Who and where come with the sign-in; the figures are not made up.
    expect(find.text('liunian'), findsOneWidget);
    expect(find.text(testBase), findsOneWidget);
    expect(find.text('Balance'), findsNothing);

    await tester.tap(retry());
    await settle(tester);
    expect(find.text('Couldn\'t read your account'), findsNothing);
    expect(find.text(r'$1,234.56'), findsOneWidget);
  });

  testWidgets('out of reach: said as such, and a pull reads again', (tester) async {
    final services = await signedIn(tester);
    services.backend.offline = true;
    await open(tester, services);

    expect(find.text('Can\'t reach the server'), findsOneWidget);
    expect(find.text('Check this phone\'s network connection, then try again.'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('liunian'), findsOneWidget);

    services.backend.offline = false;
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await settle(tester, rounds: 30);
    expect(find.text('Can\'t reach the server'), findsNothing);
    expect(find.text(r'$86.21'), findsOneWidget);
  });

  testWidgets('a refresh that fails keeps what was read, and says so', (tester) async {
    final services = await signedIn(tester);
    await open(tester, services);
    expect(find.text(r'$1,234.56'), findsOneWidget);

    services.backend
      ..failures['/api/user/self/groups'] = 1
      ..self = {...services.backend.self, 'quota': 500000};
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await settle(tester, rounds: 30);
    // The balance read again; the groups as they were — said to be what
    // was not read, not the account.
    expect(find.text(r'$1.00'), findsOneWidget);
    expect(find.text('Couldn\'t read the groups'), findsOneWidget);
    expect(find.text('Couldn\'t read your account'), findsNothing);
    expect(find.text('×1.5'), findsOneWidget);
    // Said under the groups' heading, not over the account's figures.
    expect(tester.getRect(find.text('Couldn\'t read the groups')).top, greaterThan(tester.getRect(find.text('Groups')).top));
  });

  testWidgets('signing out is here, behind the settings\' account row, and asks first', (tester) async {
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(services, const SettingsScreen(), style: DesignStyle.material3));
    await settle(tester);
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'liunian'));
    await settle(tester);
    expect(find.byType(AccountScreen), findsOneWidget);

    Future<void> ask() async {
      await tester.scrollUntilVisible(find.text('Sign out'), 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Sign out'));
      await settle(tester);
      expect(find.text('Sign out?'), findsOneWidget);
    }

    await ask();
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(services.controller.state.user, 'liunian');
    expect(find.byType(AccountScreen), findsOneWidget);

    await ask();
    // The action in the dialog is the destructive one.
    final action = find.widgetWithText(FilledButton, 'Sign out');
    final context = tester.element(action);
    expect(tester.widget<FilledButton>(action).style?.backgroundColor?.resolve({}), Theme.of(context).colorScheme.error);
    await tester.tap(action);
    await settle(tester);
    expect(services.controller.state.user, isNull);
    expect(find.byType(AccountScreen), findsNothing);
    expect(await tester.runAsync(() => services.secrets.get('auth-session')), isNull);
  });
}
