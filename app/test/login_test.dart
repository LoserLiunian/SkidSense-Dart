import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/screens/login_screen.dart';

import 'support/harness.dart';

void main() {
  testWidgets('a cleartext public server is refused, with the reason', (tester) async {
    phoneSurface(tester);
    final services = TestServices();
    await tester.runAsync(services.controller.start);
    await tester.pumpWidget(harness(services, const LoginScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'http://ai.surise.cn');
    // The server is asked once typing pauses.
    await settle(tester, rounds: 20);
    expect(find.textContaining('is plain http://'), findsOneWidget);

    // A development server on the local network is fine.
    await tester.enterText(find.byType(TextField).first, 'http://192.168.1.20:3000');
    await settle(tester, rounds: 20);
    expect(find.textContaining('is plain http://'), findsNothing);
  });
}
