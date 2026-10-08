import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ui/material.dart';
import '../ui/theme/tokens.dart';

/// The languages the app speaks. [system] follows the phone.
enum AppLanguage {
  system,
  simplifiedChinese,
  traditionalChinese,
  english;

  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.simplifiedChinese => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        AppLanguage.traditionalChinese => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        AppLanguage.english => const Locale('en'),
      };
}

enum AppContrast {
  standard(0),
  medium(0.5),
  high(1);

  const AppContrast(this.value);
  final double value;
}

/// The seed colours offered; the first is the app's own.
const seedChoices = <Color>[
  Color(0xFF3D5AFE),
  Color(0xFF00897B),
  Color(0xFF7B5BD6),
  Color(0xFFE0592A),
  Color(0xFFC2185B),
  Color(0xFF5D7A2E),
];

/// How the app looks: the design language, light/dark, colour and language.
@immutable
class Appearance {
  const Appearance({
    this.style = DesignStyle.expressive,
    this.mode = ThemeMode.system,
    this.dynamicColor = true,
    this.seed = const Color(0xFF3D5AFE),
    this.variant = DynamicSchemeVariant.tonalSpot,
    this.contrast = AppContrast.standard,
    this.language = AppLanguage.system,
  });

  factory Appearance.fromJson(Map<String, Object?> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((value) => value.name == name).firstOrNull ?? fallback;
    const defaults = Appearance();
    final seed = json['seed'];
    return Appearance(
      style: pick(DesignStyle.values, json['style'], defaults.style),
      mode: pick(ThemeMode.values, json['mode'], defaults.mode),
      dynamicColor: json['dynamicColor'] is bool ? json['dynamicColor']! as bool : defaults.dynamicColor,
      seed: seed is int ? Color(seed) : defaults.seed,
      variant: pick(DynamicSchemeVariant.values, json['variant'], defaults.variant),
      contrast: pick(AppContrast.values, json['contrast'], defaults.contrast),
      language: pick(AppLanguage.values, json['language'], defaults.language),
    );
  }

  final DesignStyle style;
  final ThemeMode mode;

  /// Android 12+ wallpaper colours, when the platform has them.
  final bool dynamicColor;
  final Color seed;
  final DynamicSchemeVariant variant;
  final AppContrast contrast;
  final AppLanguage language;

  Map<String, Object?> toJson() => {
        'style': style.name,
        'mode': mode.name,
        'dynamicColor': dynamicColor,
        'seed': seed.toARGB32(),
        'variant': variant.name,
        'contrast': contrast.name,
        'language': language.name,
      };

  Appearance copyWith({
    DesignStyle? style,
    ThemeMode? mode,
    bool? dynamicColor,
    Color? seed,
    DynamicSchemeVariant? variant,
    AppContrast? contrast,
    AppLanguage? language,
  }) =>
      Appearance(
        style: style ?? this.style,
        mode: mode ?? this.mode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        seed: seed ?? this.seed,
        variant: variant ?? this.variant,
        contrast: contrast ?? this.contrast,
        language: language ?? this.language,
      );

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.style == style &&
      other.mode == mode &&
      other.dynamicColor == dynamicColor &&
      other.seed == seed &&
      other.variant == variant &&
      other.contrast == contrast &&
      other.language == language;

  @override
  int get hashCode => Object.hash(style, mode, dynamicColor, seed, variant, contrast, language);
}

/// [Appearance], remembered across launches. Changes apply at once.
class AppearanceController extends ValueNotifier<Appearance> {
  AppearanceController(this._prefs) : super(_load(_prefs));

  static const _key = 'appearance';
  final SharedPreferencesAsync? _prefs;

  static Appearance _load(SharedPreferencesAsync? prefs) => const Appearance();

  /// Read the stored choice; until it arrives the defaults show.
  Future<void> restore() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final text = await prefs.getString(_key);
      if (text == null) return;
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) value = Appearance.fromJson(json);
    } catch (_) {}
  }

  Future<void> update(Appearance next) async {
    value = next;
    try {
      await _prefs?.setString(_key, jsonEncode(next.toJson()));
    } catch (_) {}
  }
}
