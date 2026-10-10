import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart' show M3ETooltip;
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/platform/device.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/session_screen.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';
import 'package:skidsense_core/testing.dart';

import 'demo_host.dart';
import 'harness.dart';

/// Signed in, paired with [DemoHost] and connected to it, sessions loaded.
/// [scopes]: what the host grants, in place of the demo's own — and the
/// methods they reach. [prepare] changes the demo before it says `welcome`;
/// [biometrics] stands in for the phone's unlock.
Future<(TestServices, DemoHost)> connect(
  WidgetTester tester, {
  List<String>? scopes,
  void Function(DemoHost demo)? prepare,
  Biometrics? biometrics,
}) async {
  final demo = DemoHost();
  if (scopes != null) demo.grant(scopes);
  prepare?.call(demo);
  final services = TestServices(carriers: FakeCarriers()..lan = (_) => demo.host, biometrics: biometrics);
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

/// The composer's send options: in M3 Expressive's split button menu, in
/// M3 a button of their own — in the language shown.
Future<void> openOptions(WidgetTester tester, DesignStyle style) async {
  final l = L10n.of(tester.element(find.byType(Composer)));
  if (style == DesignStyle.expressive) {
    await tester.tap(find.byWidgetPredicate((widget) => widget is M3ETooltip && widget.message == l.composerOptions));
    await settle(tester);
    await tester.tap(find.text(l.options).last);
  } else {
    await tester.tap(find.byTooltip(l.options));
  }
  await settle(tester, rounds: 25);
}
