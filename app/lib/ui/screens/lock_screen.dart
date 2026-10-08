import 'dart:async';

import '../../state/scope.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/feedback.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// Covers the whole app while it is locked; asks for the system prompt at
/// once and again on the button.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_unlock()));
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final services = context.services;
    final ok = await services.biometrics.authenticate(context.l10n.unlockReason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) services.controller.unlock();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              EmptyState(icon: Icons.lock_rounded, title: l.lockedTitle),
              const SizedBox(height: Gap.xl),
              AppButton(label: l.unlock, icon: Icons.fingerprint_rounded, large: true, busy: _busy, onPressed: _unlock),
            ]),
          ),
        ),
      ),
    );
  }
}
