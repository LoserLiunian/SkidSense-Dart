import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;

import '../../state/appearance.dart';
import '../material.dart';
import 'tokens.dart';

/// The two themes, built from the same colour scheme.
///
/// Material 3 is the library's own Material 3, lightly tuned. Material 3
/// Expressive raises the shape scale (cards 20, dialogs and sheets 32), uses
/// the emphasized type scale for titles and labels, opts icon buttons into
/// the library's Expressive variant, and moves on springs (see [AppMotion]);
/// the components that have no Expressive form in the library come from the
/// app's kit.
abstract final class AppTheme {
  /// [systemSeed] is the platform's wallpaper colour (Android 12+), used in
  /// place of the chosen seed when dynamic colour is on. It goes through the
  /// same generator, so the variant and contrast still apply.
  static ColorScheme scheme(Appearance appearance, Brightness brightness, {Color? systemSeed}) => ColorScheme.fromSeed(
        seedColor: appearance.dynamicColor && systemSeed != null ? systemSeed : appearance.seed,
        brightness: brightness,
        dynamicSchemeVariant: appearance.variant,
        contrastLevel: appearance.contrast.value,
      );

  /// [fontFamilyFallback] is for tests, which have no system fallback for
  /// CJK; on devices the platform picks the right Han glyphs by locale.
  static ThemeData build(DesignStyle style, ColorScheme colors, {List<String>? fontFamilyFallback}) {
    final design = AppDesign.of(style);
    final expressive = style == DesignStyle.expressive;
    final shapes = design.shapes;
    final base = ThemeData(colorScheme: colors, useMaterial3: true, fontFamilyFallback: fontFamilyFallback);
    final text = expressive ? _emphasized(base.textTheme) : base.textTheme;
    RoundedRectangleBorder rounded(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    return base.copyWith(
      textTheme: text,
      extensions: [design],
      splashFactory: expressive ? InkSparkle.splashFactory : InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: expressive ? 0 : 3,
        titleTextStyle: (expressive ? text.titleLarge : base.textTheme.titleLarge)?.copyWith(color: colors.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: expressive ? colors.surfaceContainer : colors.surfaceContainerLow,
        shape: rounded(shapes.card),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        shape: rounded(expressive ? shapes.large : 0),
        titleTextStyle: text.bodyLarge?.copyWith(color: colors.onSurface),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
      dialogTheme: DialogThemeData(
        shape: rounded(shapes.dialog),
        backgroundColor: colors.surfaceContainerHigh,
        titleTextStyle: (expressive ? text.headlineSmall : base.textTheme.headlineSmall)?.copyWith(color: colors.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(shapes.sheet))),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: expressive ? 1 : 3,
        shape: rounded(expressive ? shapes.largeIncreased : shapes.large),
        extendedTextStyle: text.labelLarge,
      ),
      iconButtonTheme: IconButtonThemeData(
        variant: expressive ? StyleVariant.material3Expressive : StyleVariant.material3,
      ),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(expressive, text)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(expressive, text)),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle(expressive, text)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buttonStyle(expressive, text)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(textStyle: WidgetStatePropertyAll(text.labelLarge)),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(expressive ? shapes.medium : shapes.small),
        labelStyle: text.labelLarge,
      ),
      inputDecorationTheme: expressive ? _expressiveFields(colors, shapes) : InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: const UnderlineInputBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: expressive ? colors.surfaceContainer : colors.surfaceContainer,
        indicatorColor: expressive ? colors.secondaryContainer : colors.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
        height: expressive ? 64 : 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded(expressive ? shapes.large : shapes.extraSmall),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(expressive ? shapes.small : shapes.extraSmall),
        ),
      ),
    );
  }

  /// M3 Expressive's filled field: a rounded box with no line until it is
  /// focused or wrong, when one runs along its foot inside the corners. An
  /// underline border in every state, so the floating label stays inside the
  /// box (as M3's) — an outline one would set it on an edge that is not drawn.
  static InputDecorationTheme _expressiveFields(ColorScheme colors, AppShapes shapes) {
    final radius = BorderRadius.circular(shapes.large);
    UnderlineInputBorder line([BorderSide side = BorderSide.none]) => UnderlineInputBorder(borderRadius: radius, borderSide: side);
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      border: line(),
      enabledBorder: line(),
      disabledBorder: line(),
      focusedBorder: line(BorderSide(color: colors.primary, width: 2)),
      errorBorder: line(BorderSide(color: colors.error)),
      focusedErrorBorder: line(BorderSide(color: colors.error, width: 2)),
    );
  }

  static ButtonStyle _buttonStyle(bool expressive, TextTheme text) => ButtonStyle(
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        shape: WidgetStatePropertyAll(expressive ? const StadiumBorder() : const StadiumBorder()),
        minimumSize: WidgetStatePropertyAll(Size(64, expressive ? 44 : 40)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: expressive ? 20 : 24)),
      );

  /// The M3 Expressive emphasized type scale: the same sizes, heavier for
  /// the roles that carry hierarchy.
  static TextTheme _emphasized(TextTheme base) => base.copyWith(
        displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w500),
        displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w500),
        displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w500),
        headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
        headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      );
}
