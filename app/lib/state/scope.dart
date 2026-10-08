import 'package:flutter/widgets.dart';
import 'package:skidsense_core/skidsense_core.dart';

import '../platform/device.dart';
import 'appearance.dart';

/// Everything the screens reach for, built once at startup.
class AppServices {
  AppServices({
    required this.controller,
    required this.appearance,
    required this.biometrics,
    required this.links,
    required this.device,
  });

  final AppController controller;
  final AppearanceController appearance;
  final Biometrics biometrics;
  final DeepLinks links;
  final DeviceFacts device;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope old) => !identical(old.services, services);
}

extension ScopeContext on BuildContext {
  AppServices get services => AppScope.of(this);
  AppController get app => AppScope.of(this).controller;
}
