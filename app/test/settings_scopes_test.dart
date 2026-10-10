import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/settings_screen.dart';
import 'package:skidsense_core/skidsense_core.dart';

import 'support/connected.dart';
import 'support/harness.dart';

/// The permissions on the settings screen (spec §8.5, §9): only what the
/// backend knows is shown or sent — an old backend refuses a whole `PATCH`
/// naming `settings` — and `settings`, as much as the terminal, is opened
/// on the computer alone: here it can only be closed.
void main() {
  const label = 'Models & accounts';
  const offNote = 'Models & accounts is off by default and only the computer can turn it on: '
      'it can point the agents at any server and set their environment — as much as the terminal.';
  const onWarning = 'This phone may change models and accounts: it can point the agents at any server '
      'and set their environment, enough to run anything on the computer — as much as the terminal.';

  Map<String, Object?> device(List<String> scopes) =>
      {'device_id': 'dev-demo', 'name': 'Pixel 9 Pro XL', 'platform': 'android', 'scopes': scopes, 'status': 'active'};

  Future<void> openPermissions(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Permissions').last);
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save permissions'));
    await tester.tap(find.text('Save permissions'));
    await settle(tester);
  }

  CheckboxListTile box(WidgetTester tester, String title) => tester.widget(find.widgetWithText(CheckboxListTile, title));

  testWidgets('a backend that lists no scopes: no settings to see, none to send', (tester) async {
    phoneSurface(tester, size: const Size(412, 2400));
    final (services, _) = await connect(tester);
    services.backend.devices.add(device(Scopes.legacy));
    await tester.pumpWidget(harness(services, const SettingsScreen()));
    await settle(tester);

    expect(find.byType(FilterChip), findsNWidgets(Scopes.legacy.length));
    expect(find.text(Scopes.settings), findsNothing);
    expect(find.text(label), findsNothing);
    expect(find.text(offNote), findsNothing);

    await openPermissions(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(Scopes.legacy.length));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Git writes'));
    await save(tester);
    expect(services.backend.scopePatches, [
      [for (final scope in Scopes.legacy) if (scope != Scopes.gitWrite) scope],
    ]);
    await leave(tester, services);
  });

  testWidgets('a backend that knows settings: shown, with the warning, and not to be opened here', (tester) async {
    phoneSurface(tester, size: const Size(412, 2400));
    final (services, _) = await connect(tester);
    services.backend
      ..scopes = Scopes.all
      ..devices.add(device(Scopes.byDefault));
    await tester.pumpWidget(harness(services, const SettingsScreen()));
    await settle(tester);

    expect(find.byType(FilterChip), findsNWidgets(Scopes.all.length));
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected, isFalse);
    expect(find.text(offNote), findsOneWidget);
    expect(find.text(onWarning), findsNothing);

    await openPermissions(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(Scopes.all.length));
    expect(box(tester, label).onChanged, isNull, reason: 'the computer alone opens it (§8.5)');
    await tester.tap(find.widgetWithText(CheckboxListTile, label));
    await settle(tester);
    expect(box(tester, label).value, isFalse);
    await save(tester);
    expect(services.backend.scopePatches, [Scopes.byDefault]);
    await leave(tester, services);
  });

  testWidgets('a device that has settings is warned, may close it, and keeps what this build does not know', (tester) async {
    phoneSurface(tester, size: const Size(412, 2400));
    final (services, _) = await connect(tester, scopes: [...Scopes.byDefault, Scopes.settings]);
    services.backend
      ..scopes = [...Scopes.all, 'later']
      ..devices.add(device([...Scopes.byDefault, Scopes.settings, 'later']));
    await tester.pumpWidget(harness(services, const SettingsScreen()));
    await settle(tester);

    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected, isTrue);
    expect(find.text(onWarning), findsOneWidget);
    expect(find.text(offNote), findsNothing);

    await openPermissions(tester);
    expect(box(tester, label).value, isTrue);
    expect(box(tester, label).onChanged, isNotNull);
    await tester.tap(find.widgetWithText(CheckboxListTile, label));
    await settle(tester);
    expect(box(tester, label).value, isFalse);
    await save(tester);
    expect(services.backend.scopePatches, [
      [...Scopes.byDefault, 'later'],
    ], reason: 'a scope this build has no switch for is the device\'s still (§8.5)');
    await leave(tester, services);
  });
}
