import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/account_screen.dart';
import 'package:skidsense_app/ui/screens/gallery_screen.dart';
import 'package:skidsense_app/ui/screens/hosts_screen.dart';
import 'package:skidsense_app/ui/screens/login_screen.dart';
import 'package:skidsense_app/ui/screens/settings_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/harness.dart';

/// Every screen here in both styles and both brightnesses. Run with
/// `--update-goldens` to redraw them, then look at the images.
void main() {
  setUpAll(loadFonts);

  final variants = [
    for (final style in DesignStyle.values)
      for (final brightness in Brightness.values) (style, brightness),
  ];
  String name(String scene, DesignStyle style, Brightness brightness, [String suffix = '']) =>
      'goldens/${scene}_${style == DesignStyle.expressive ? 'm3e' : 'm3'}_${brightness.name}$suffix.png';

  Future<TestServices> signedIn(WidgetTester tester) async {
    final services = TestServices();
    services.backend.hosts.addAll(const [
      HostRow(hostId: 'h-studio', name: 'Studio Mac', platform: 'darwin', online: true, lanAddrs: ['192.168.1.20'], lanPort: 47290),
      HostRow(hostId: 'h-office', name: 'Office PC', platform: 'win32', online: false),
      HostRow(hostId: 'h-lab', name: 'Lab Linux', platform: 'linux', online: true),
    ]);
    await services.signIn();
    await services.pair(const [
      PairedHost(hostId: 'h-studio', hostKey: 'AAAA', deviceId: 'dev-1', name: 'Studio Mac', machine: 'studio', lanAddrs: ['192.168.1.20'], lanPort: 47290, server: testBase, userId: 7, pairedAt: 1),
      PairedHost(hostId: 'h-office', hostKey: 'BBBB', deviceId: 'dev-2', name: 'Office PC', machine: 'office', server: testBase, userId: 7, pairedAt: 1),
    ]);
    await tester.runAsync(services.controller.start);
    await tester.runAsync(services.controller.refreshHosts);
    return services;
  }

  for (final (style, brightness) in variants) {
    testWidgets('gallery ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester, size: const Size(412, 2300));
      final services = TestServices();
      await tester.pumpWidget(harness(services, const GalleryScreen(), style: style, brightness: brightness));
      await settle(tester);
      expect(find.text('Send'), findsWidgets);
      expect(find.text('Connect'), findsOneWidget);
      await expectLater(find.byType(GalleryScreen), matchesGoldenFile(name('gallery', style, brightness)));
    }, skip: !goldensSupported);

    testWidgets('login ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester);
      final services = TestServices();
      await tester.runAsync(services.controller.start);
      await tester.pumpWidget(harness(services, const LoginScreen(), style: style, brightness: brightness));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await settle(tester);
      expect(find.text('Sign in'), findsWidgets);
      await expectLater(find.byType(LoginScreen), matchesGoldenFile(name('login', style, brightness)));
    }, skip: !goldensSupported);

    testWidgets('hosts ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester);
      final services = await signedIn(tester);
      await tester.pumpWidget(harness(services, const HostsScreen(), style: style, brightness: brightness));
      await settle(tester);
      expect(find.text('Studio Mac'), findsWidgets);
      await expectLater(find.byType(HostsScreen), matchesGoldenFile(name('hosts', style, brightness)));
    }, skip: !goldensSupported);

    testWidgets('settings ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester, size: const Size(412, 1800));
      final services = await signedIn(tester);
      await tester.pumpWidget(harness(services, const SettingsScreen(), style: style, brightness: brightness));
      await settle(tester);
      await expectLater(find.byType(SettingsScreen), matchesGoldenFile(name('settings', style, brightness)));
    }, skip: !goldensSupported);

    testWidgets('account ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester);
      final services = await signedIn(tester);
      await tester.pumpWidget(harness(services, const AccountScreen(), style: style, brightness: brightness));
      await settle(tester);
      expect(find.text(r'$1,234.56'), findsOneWidget);
      await expectLater(find.byType(AccountScreen), matchesGoldenFile(name('account', style, brightness)));
    }, skip: !goldensSupported);

    testWidgets('account, read failed ${style.name} ${brightness.name}', (tester) async {
      phoneSurface(tester);
      final services = await signedIn(tester);
      services.backend.failures['/api/user/self'] = 1;
      await tester.pumpWidget(harness(services, const AccountScreen(), style: style, brightness: brightness));
      await settle(tester);
      expect(find.text('Retry'), findsOneWidget);
      await expectLater(find.byType(AccountScreen), matchesGoldenFile(name('account_error', style, brightness)));
    }, skip: !goldensSupported);
  }

  testWidgets('account out of reach', (tester) async {
    phoneSurface(tester);
    final services = await signedIn(tester);
    services.backend.offline = true;
    await tester.pumpWidget(harness(services, const AccountScreen()));
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    await expectLater(find.byType(AccountScreen), matchesGoldenFile('goldens/account_offline_m3e_light.png'));
  }, skip: !goldensSupported);

  // On a tablet the figures stay beside their labels: the page grows no
  // wider than it reads well.
  testWidgets('account on a tablet', (tester) async {
    phoneSurface(tester, size: const Size(1280, 800));
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(services, const AccountScreen()));
    await settle(tester);
    await expectLater(find.byType(AccountScreen), matchesGoldenFile('goldens/account_tablet_m3e_light.png'));
  }, skip: !goldensSupported);

  testWidgets('account in Traditional Chinese', (tester) async {
    phoneSurface(tester);
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(
      services,
      const AccountScreen(),
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ));
    await settle(tester);
    await expectLater(find.byType(AccountScreen), matchesGoldenFile('goldens/account_m3e_light_zh_hant.png'));
  }, skip: !goldensSupported);

  testWidgets('hosts in Simplified Chinese', (tester) async {
    phoneSurface(tester);
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(services, const HostsScreen(), locale: const Locale('zh')));
    await settle(tester);
    await expectLater(find.byType(HostsScreen), matchesGoldenFile('goldens/hosts_m3e_light_zh_hans.png'));
  }, skip: !goldensSupported);

  testWidgets('settings in Traditional Chinese', (tester) async {
    phoneSurface(tester, size: const Size(412, 1800));
    final services = await signedIn(tester);
    await tester.pumpWidget(harness(
      services,
      const SettingsScreen(),
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ));
    await settle(tester);
    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/settings_m3e_light_zh_hant.png'));
  }, skip: !goldensSupported);
}
