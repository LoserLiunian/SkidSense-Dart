import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart' as legacy show GlobalMaterialLocalizations;
import 'package:skidsense_core/skidsense_core.dart';

import 'l10n/gen/app_localizations.dart';
import 'platform/device.dart';
import 'platform/system_color.dart';
import 'state/scope.dart';
import 'state/watch.dart';
import 'ui/kit/feedback.dart';
import 'ui/material.dart';
import 'ui/screens/hosts_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/pairing_screen.dart';
import 'ui/theme/app_theme.dart';

class SkidSenseApp extends StatefulWidget {
  const SkidSenseApp({super.key, required this.services});

  final AppServices services;

  @override
  State<SkidSenseApp> createState() => _SkidSenseAppState();
}

class _SkidSenseAppState extends State<SkidSenseApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigator = GlobalKey();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Color? _systemSeed;

  AppController get _app => widget.services.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(systemSeedColor().then((seed) {
      if (mounted && seed != null) setState(() => _systemSeed = seed);
    }));
    _subscriptions
      ..add(watchNetwork(_app.networkChanged))
      // Signed out — by the user, by the server, or because the store could
      // not be read: whatever was pushed belongs to the old account.
      ..add(_app.states.changes.map((s) => s.signedIn).distinct().where((signedIn) => !signedIn).listen((_) {
        _navigator.currentState?.popUntil((route) => route.isFirst);
      }))
      // A deep link waits until it can be acted on: signed in and unlocked.
      ..add(_app.states.changes.map((s) => s.signedIn && !s.locked).distinct().listen((_) => _takeLink()));
    widget.services.links.pending.addListener(_takeLink);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.links.pending.removeListener(_takeLink);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // `inactive` also covers the system's own biometric prompt; locking
      // there would lock the app the moment it is unlocked.
      case AppLifecycleState.paused:
        _app.lock();
      case AppLifecycleState.resumed:
        // Back from the background: the network may have changed under a
        // suspended socket.
        _app.networkChanged();
      default:
    }
  }

  /// Opens a `skidsense://` link at most once (S32).
  void _takeLink() {
    final link = widget.services.links.pending.value;
    final state = _app.state;
    final navigator = _navigator.currentState;
    if (link == null || !state.ready || !state.signedIn || state.locked || navigator == null) return;
    widget.services.links.consume(link);
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => PairingScreen(initialLink: link.text))));
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AppScope(
      services: services,
      child: ValueListenableBuilder(
        valueListenable: services.appearance,
        builder: (context, appearance, _) => MaterialApp(
          navigatorKey: _navigator,
          onGenerateTitle: (context) => L10n.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(appearance.style, AppTheme.scheme(appearance, Brightness.light, systemSeed: _systemSeed)),
          darkTheme: AppTheme.build(appearance.style, AppTheme.scheme(appearance, Brightness.dark, systemSeed: _systemSeed)),
          themeMode: appearance.mode,
          themeAnimationCurve: Curves.easeOutCubic,
          locale: appearance.language.locale,
          supportedLocales: L10n.supportedLocales,
          localeListResolutionCallback: resolveLocale,
          localizationsDelegates: appLocalizationsDelegates,
          builder: (context, child) => _LockGate(child: child ?? const SizedBox.shrink()),
          home: const _Root(),
        ),
      ),
    );
  }
}

const appLocalizationsDelegates = <LocalizationsDelegate<Object?>>[
  L10n.delegate,
  ...GlobalMaterialLocalizations.delegates,
  // For the few `flutter/material` widgets inside the bridge.
  legacy.GlobalMaterialLocalizations.delegate,
];

/// The system's language list → one of ours. Chinese is told apart by
/// script first, then by region: Taiwan, Hong Kong and Macau read
/// Traditional; everything else Chinese reads Simplified.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    switch (locale.languageCode) {
      case 'zh':
        final script = locale.scriptCode;
        final traditional = script == 'Hant' || (script == null && const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
        return traditional ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant') : const Locale('zh');
      case 'en':
        return const Locale('en');
    }
  }
  return const Locale('en');
}

/// Splash until the stores are read, then login or the computers.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) => WatchSelect(
        context.app.states,
        select: (AppState s) => (s.ready, s.signedIn),
        builder: (context, gate) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (gate) {
            (false, _) => const Scaffold(key: ValueKey('splash'), body: Center(child: BusyIndicator())),
            (true, false) => const LoginScreen(key: ValueKey('login')),
            (true, true) => const HostsScreen(key: ValueKey('hosts')),
          },
        ),
      );
}

/// The lock sits above the navigator, so whatever was open stays open — and
/// out of sight, out of reach and out of the accessibility tree.
class _LockGate extends StatelessWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => WatchSelect(
        context.app.states,
        select: (AppState s) => s.locked,
        builder: (context, locked) => Stack(fit: StackFit.expand, children: [
          ExcludeSemantics(excluding: locked, child: TickerMode(enabled: !locked, child: child)),
          if (locked) const LockScreen(),
        ]),
      );
}
