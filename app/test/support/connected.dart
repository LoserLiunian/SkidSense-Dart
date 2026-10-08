import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_core/testing.dart';

import 'demo_host.dart';
import 'harness.dart';

/// Signed in, paired with [DemoHost] and connected to it, sessions loaded.
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
