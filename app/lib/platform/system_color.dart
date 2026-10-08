import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';

/// The wallpaper colour on Android 12+ (the accent colour on desktops), or
/// null. Only the colour is taken — `dynamic_color`'s schemes are
/// `flutter/material` types, and the app builds its own from a seed.
Future<Color?> systemSeedColor() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) return Color(palette.primary.get(40));
    return await DynamicColorPlugin.getAccentColor();
  } catch (_) {
    return null;
  }
}
