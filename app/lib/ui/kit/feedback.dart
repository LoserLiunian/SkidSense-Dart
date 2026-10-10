import 'package:material_3_expressive/material_3_expressive.dart';

import '../material.dart';
import '../theme/tokens.dart';

/// "Working on it." M3: the circular indicator. M3 Expressive: the
/// shape-morphing loading indicator.
class BusyIndicator extends StatelessWidget {
  const BusyIndicator({super.key, this.size = 40, this.contained = false, this.semanticsLabel});

  final double size;

  /// M3 Expressive's contained variant: the shape inside a filled container,
  /// for a spinner that floats over content.
  final bool contained;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final indicator = context.design.expressive
        ? _expressiveIndicator(
            size,
            variant: contained ? M3ELoadingIndicatorVariant.contained : M3ELoadingIndicatorVariant.defaultStyle,
          )
        : SizedBox.square(
            dimension: size * 0.8,
            child: CircularProgressIndicator(strokeWidth: size < 32 ? 3 : 4),
          );
    return Semantics(label: semanticsLabel, child: SizedBox.square(dimension: size, child: Center(child: indicator)));
  }
}

/// The loading indicator's spec starts at 24dp; smaller ones (inside a
/// button) are drawn at 24 and scaled down.
Widget _expressiveIndicator(double size, {M3ELoadingIndicatorVariant variant = M3ELoadingIndicatorVariant.defaultStyle, Color? color}) {
  final indicator = M3ELoadingIndicator(variant: variant, size: size < 24 ? 24 : size, color: color);
  return size < 24 ? SizedBox.square(dimension: size, child: FittedBox(child: indicator)) : indicator;
}

/// A small inline spinner for buttons and status lines.
class InlineBusy extends StatelessWidget {
  const InlineBusy({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: context.design.expressive
            ? _expressiveIndicator(size, color: color)
            : CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

/// Progress along a line. [value] null is indeterminate. M3 Expressive draws
/// the wavy form while work is under way.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, this.value, this.semanticsLabel});

  final double? value;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (context.design.expressive) {
      return M3EProgressIndicator.linearWavy(value: value, semanticsLabel: semanticsLabel);
    }
    return LinearProgressIndicator(value: value, semanticsLabel: semanticsLabel, borderRadius: BorderRadius.circular(4));
  }
}

/// A full-width status line with a spinner.
class LoadingRow extends StatelessWidget {
  const LoadingRow(this.label, {super.key, this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md)});

  final String label;

  /// A page's inset by default; inside content that has its own, less.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          const InlineBusy(),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))),
        ]),
      );
}

enum BannerTone { info, warning, error, success }

/// A message that belongs to the screen, not a moment: an error that
/// explains why something is missing, a warning to read before acting.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.error,
    this.icon,
    this.onDismiss,
    this.action,
  });

  final String message;
  final String? title;
  final BannerTone tone;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final design = context.design;
    final (background, foreground, glyph) = switch (tone) {
      BannerTone.error => (colors.errorContainer, colors.onErrorContainer, Icons.error_outline_rounded),
      BannerTone.warning => (colors.tertiaryContainer, colors.onTertiaryContainer, Icons.warning_amber_rounded),
      BannerTone.success => (colors.secondaryContainer, colors.onSecondaryContainer, Icons.check_circle_outline_rounded),
      BannerTone.info => (colors.surfaceContainerHighest, colors.onSurfaceVariant, Icons.info_outline_rounded),
    };
    // Its icons grow with its text, as a form's status line's do: 20dp, a
    // line of the text, at the normal size.
    final iconSize = MediaQuery.textScalerOf(context).scale(20);
    return Semantics(
      liveRegion: tone == BannerTone.error,
      child: AnimatedSize(
        duration: design.motion.spatial.duration,
        curve: design.motion.spatial.curve,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(design.expressive ? design.shapes.large : design.shapes.medium),
          ),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: EdgeInsets.only(top: iconSize / 10), child: Icon(icon ?? glyph, color: foreground, size: iconSize)),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(title!, style: context.text.titleSmall?.copyWith(color: foreground)),
                  ),
                Text(message, style: context.text.bodyMedium?.copyWith(color: foreground)),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.sm),
                    child: tone == BannerTone.info ? action : _inked(context, action!, background, foreground),
                  ),
              ]),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: foreground, size: iconSize),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              )
            else
              const SizedBox(width: Gap.sm),
          ]),
        ),
      ),
    );
  }
}

/// [action] in a tinted banner's own ink: the app's button colours clash
/// with an error's or a warning's container, so its buttons take the
/// banner's foreground — a tonal one that at 12 % over the banner. A banner
/// on the neutral surface keeps the app's.
Widget _inked(BuildContext context, Widget action, Color background, Color foreground) {
  final theme = Theme.of(context);
  final tonal = Color.alphaBlend(foreground.withValues(alpha: 0.12), background);
  return Theme(
    data: theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: foreground,
        onPrimary: background,
        secondaryContainer: tonal,
        onSecondaryContainer: foreground,
        onSurfaceVariant: foreground,
        outline: foreground,
        outlineVariant: foreground.withValues(alpha: 0.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: foreground),
    ),
    child: action,
  );
}

/// Nothing to show yet, and what to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final expressive = context.design.expressive;
    final colors = context.colors;
    final glyph = Icon(icon, size: 40, color: expressive ? colors.onPrimaryContainer : colors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (expressive)
          // M3 Expressive puts the glyph in one of its shapes.
          M3EShapeContainer(
            kind: M3EShapeKind.cookie9Sided,
            width: 96,
            height: 96,
            color: colors.primaryContainer,
            child: Center(child: glyph),
          )
        else
          glyph,
        const SizedBox(height: Gap.lg),
        Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
        if (body != null) ...[
          const SizedBox(height: Gap.sm),
          Text(body!, style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant), textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: Gap.xl), action!],
      ]),
    );
  }
}

/// A transient message at the bottom of the screen.
void showMessage(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
}
