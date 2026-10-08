import 'dart:math' as math;

import 'package:flutter/physics.dart';

import '../material.dart';

/// The two design languages the app can wear.
enum DesignStyle {
  /// Material 3: baseline shapes, easing-and-duration motion, baseline type.
  material3,

  /// Material 3 Expressive: larger and morphing shapes, spring motion,
  /// emphasized type, the expressive component set.
  expressive,
}

/// Corner radii (M3 shape tokens; the "increased" steps are M3 Expressive's).
@immutable
class AppShapes {
  const AppShapes({
    required this.extraSmall,
    required this.small,
    required this.medium,
    required this.large,
    required this.largeIncreased,
    required this.extraLarge,
    required this.extraLargeIncreased,
    required this.extraExtraLarge,
  });

  static const baseline = AppShapes(
    extraSmall: 4,
    small: 8,
    medium: 12,
    large: 16,
    largeIncreased: 16,
    extraLarge: 28,
    extraLargeIncreased: 28,
    extraExtraLarge: 28,
  );

  static const expressive = AppShapes(
    extraSmall: 4,
    small: 8,
    medium: 12,
    large: 16,
    largeIncreased: 20,
    extraLarge: 28,
    extraLargeIncreased: 32,
    extraExtraLarge: 48,
  );

  final double extraSmall;
  final double small;
  final double medium;
  final double large;
  final double largeIncreased;
  final double extraLarge;
  final double extraLargeIncreased;
  final double extraExtraLarge;

  /// Cards and list groups.
  double get card => largeIncreased;

  /// Dialogs.
  double get dialog => extraLargeIncreased;

  /// Bottom sheets' top corners.
  double get sheet => extraLargeIncreased;

  static AppShapes lerp(AppShapes a, AppShapes b, double t) => AppShapes(
        extraSmall: lerpDouble(a.extraSmall, b.extraSmall, t),
        small: lerpDouble(a.small, b.small, t),
        medium: lerpDouble(a.medium, b.medium, t),
        large: lerpDouble(a.large, b.large, t),
        largeIncreased: lerpDouble(a.largeIncreased, b.largeIncreased, t),
        extraLarge: lerpDouble(a.extraLarge, b.extraLarge, t),
        extraLargeIncreased: lerpDouble(a.extraLargeIncreased, b.extraLargeIncreased, t),
        extraExtraLarge: lerpDouble(a.extraExtraLarge, b.extraExtraLarge, t),
      );

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// A spring as a [Curve], so implicit animations can move the M3 Expressive
/// way. It is the critically-or-under damped motion from 0 to 1 of a unit
/// mass, sampled over [settle] — the time it takes to come within 0.1 % of
/// rest — and pinned to exactly 1 at the end.
class SpringCurve extends Curve {
  SpringCurve({required double stiffness, required double damping})
      : _simulation = SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: stiffness, ratio: damping),
          0,
          1,
          0,
        ),
        settle = _settleTime(stiffness, damping);

  final SpringSimulation _simulation;

  /// Seconds until the spring is effectively at rest.
  final double settle;

  static double _settleTime(double stiffness, double damping) {
    final omega = math.sqrt(stiffness);
    // Envelope e^(-ζωt) under 0.001.
    return -math.log(0.001) / (damping * omega);
  }

  Duration get duration => Duration(microseconds: (settle * 1e6).round());

  @override
  double transformInternal(double t) => t >= 1 ? 1 : _simulation.x(t * settle);
}

/// Motion tokens. M3 moves on easing curves over fixed durations; M3
/// Expressive on springs — "spatial" ones (position, size, shape) may
/// overshoot, "effects" ones (colour, opacity) never do.
@immutable
class AppMotion {
  const AppMotion._({
    required this.spatialFast,
    required this.spatial,
    required this.spatialSlow,
    required this.effectsFast,
    required this.effects,
    required this.short,
    required this.medium,
    required this.long,
  });

  /// M3: emphasized easing (cubic-bezier .2,0,0,1) at the standard durations.
  static final standard = AppMotion._(
    spatialFast: const _Eased(Duration(milliseconds: 200), Easing.emphasizedDecelerate),
    spatial: const _Eased(Duration(milliseconds: 350), Easing.emphasizedDecelerate),
    spatialSlow: const _Eased(Duration(milliseconds: 500), Easing.emphasizedDecelerate),
    effectsFast: const _Eased(Duration(milliseconds: 150), Easing.standard),
    effects: const _Eased(Duration(milliseconds: 250), Easing.standard),
    short: const Duration(milliseconds: 150),
    medium: const Duration(milliseconds: 300),
    long: const Duration(milliseconds: 500),
  );

  /// M3 Expressive's expressive motion scheme: spatial springs at damping
  /// 0.6/0.8/0.8 and stiffness 800/380/200, effects critically damped.
  static final expressive = AppMotion._(
    spatialFast: _Sprung(SpringCurve(stiffness: 800, damping: 0.6)),
    spatial: _Sprung(SpringCurve(stiffness: 380, damping: 0.8)),
    spatialSlow: _Sprung(SpringCurve(stiffness: 200, damping: 0.8)),
    effectsFast: _Sprung(SpringCurve(stiffness: 3800, damping: 1)),
    effects: _Sprung(SpringCurve(stiffness: 1600, damping: 1)),
    short: const Duration(milliseconds: 150),
    medium: const Duration(milliseconds: 300),
    long: const Duration(milliseconds: 500),
  );

  final MotionSpec spatialFast;
  final MotionSpec spatial;
  final MotionSpec spatialSlow;
  final MotionSpec effectsFast;
  final MotionSpec effects;
  final Duration short;
  final Duration medium;
  final Duration long;
}

/// A duration and a curve, for implicit animations.
abstract class MotionSpec {
  const MotionSpec();
  Duration get duration;
  Curve get curve;
}

class _Eased extends MotionSpec {
  const _Eased(this.duration, this.curve);
  @override
  final Duration duration;
  @override
  final Curve curve;
}

class _Sprung extends MotionSpec {
  _Sprung(this._spring);
  final SpringCurve _spring;
  @override
  Duration get duration => _spring.duration;
  @override
  Curve get curve => _spring;
}

/// The design language in effect, as a theme extension: every kit component
/// reads it to choose its M3 or M3 Expressive form.
@immutable
class AppDesign extends ThemeExtension<AppDesign> {
  const AppDesign({required this.style, required this.shapes, required this.motion});

  factory AppDesign.of(DesignStyle style) => AppDesign(
        style: style,
        shapes: style == DesignStyle.expressive ? AppShapes.expressive : AppShapes.baseline,
        motion: style == DesignStyle.expressive ? AppMotion.expressive : AppMotion.standard,
      );

  final DesignStyle style;
  final AppShapes shapes;
  final AppMotion motion;

  bool get expressive => style == DesignStyle.expressive;

  static AppDesign read(BuildContext context) =>
      Theme.of(context).extension<AppDesign>() ?? AppDesign.of(DesignStyle.material3);

  @override
  AppDesign copyWith({DesignStyle? style, AppShapes? shapes, AppMotion? motion}) =>
      AppDesign(style: style ?? this.style, shapes: shapes ?? this.shapes, motion: motion ?? this.motion);

  @override
  AppDesign lerp(covariant AppDesign? other, double t) {
    if (other == null) return this;
    return AppDesign(
      style: t < 0.5 ? style : other.style,
      shapes: AppShapes.lerp(shapes, other.shapes, t),
      motion: t < 0.5 ? motion : other.motion,
    );
  }
}

/// Spacing steps on the 4 dp grid.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

extension DesignContext on BuildContext {
  AppDesign get design => AppDesign.read(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Monospace for code, paths and hashes: Android's `monospace`; iOS has no
/// such family and takes Menlo.
const monoFamilyFallback = <String>['Menlo', 'Courier'];

extension MonoText on TextStyle {
  TextStyle get mono => copyWith(fontFamily: 'monospace', fontFamilyFallback: monoFamilyFallback);
}
