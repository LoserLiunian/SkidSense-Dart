import '../describe.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'feedback.dart';

// The pieces of a longer form — an account, a key: the theme's filled field,
// a label over a group of controls, a switch row and the bar its main action
// stays in — so every form reads as the same app, in either style.

/// Form controls stacked at the form's rhythm, inset like the page around
/// them: [Gap.lg] on a page, [Gap.xl] in a sheet (as [SheetHeader]).
class FormColumn extends StatelessWidget {
  const FormColumn({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const SizedBox(height: Gap.md),
            child,
          ],
        ]),
      );
}

/// The label over a control that has none of its own (a choice group, a
/// group of fields), with a line on what it is for and an action beside it
/// — under it when the two do not fit side by side (large text).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.title, {super.key, this.hint, this.trailing});

  final String title;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: [Text(title, style: context.text.labelLarge), ?trailing],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(hint!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
      ]);
}

/// A text field in the theme's look: a label, a line of help under it that
/// an error takes the place of, [mono] for addresses, model ids and keys
/// (no autocorrect there). Several lines with [maxLines] above one.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.mono = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.enabled = true,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;

  /// Shown in the empty field: an example.
  final String? hint;
  final String? helper;
  final String? error;
  final bool mono;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines != 1;
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (multiline ? TextInputType.multiline : null),
      autocorrect: !mono,
      enableSuggestions: !mono,
      style: mono ? context.text.bodyMedium?.mono : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // An example in words reads better in the text face.
        hintStyle: mono ? context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant) : null,
        // The example shows while the field is empty, the label over it.
        floatingLabelBehavior: hint == null ? null : FloatingLabelBehavior.always,
        helperText: helper,
        helperMaxLines: 4,
        errorText: error,
        errorMaxLines: 6,
        alignLabelWithHint: multiline,
        suffixIcon: suffix,
      ),
    );
  }
}

/// A key or password: hidden until asked, monospaced, never autocorrected
/// or offered to the keyboard's suggestions.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      style: context.text.bodyMedium?.mono,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelBehavior: widget.hint == null ? null : FloatingLabelBehavior.always,
        helperText: widget.helper,
        helperMaxLines: 4,
        errorText: widget.error,
        errorMaxLines: 6,
        suffixIcon: IconButton(
          tooltip: _hidden ? l.showPassword : l.hidePassword,
          onPressed: widget.enabled ? () => setState(() => _hidden = !_hidden) : null,
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
    );
  }
}

/// An on/off setting of a form, with a line on what it does. Inside a form
/// column it lines up with the fields; in a [GroupedList] it is a row of it.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.inset = false,
    this.heading = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  /// A row of a [GroupedList]: the list's own padding. Otherwise flush with
  /// the fields around it.
  final bool inset;

  /// The head of a card whose controls it turns on: titled as a card is,
  /// over the labels of the fields under it.
  final bool heading;

  @override
  Widget build(BuildContext context) {
    final row = SwitchListTile(
      secondary: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
      contentPadding: inset ? null : EdgeInsets.zero,
    );
    // Through the tile's theme, so it still dims when disabled.
    return heading ? ListTileTheme.merge(titleTextStyle: context.text.titleMedium?.copyWith(color: context.colors.onSurface), child: row) : row;
  }
}

/// One of a few values, picked from a menu, as a field of a form. An option
/// may say more than its name: what it is for ([details]) under the name,
/// and a short value ([trailing], a group's ratio) at the end — in the menu
/// as a list row says them (wrapping at a large text size, never cut off),
/// and under the field, for the one picked.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
    this.details = const {},
    this.trailing = const {},
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T>? onChanged;

  /// Under the field, in place of what [details] and [trailing] say of the
  /// option picked (the options still loading).
  final String? helper;
  final Map<T, String> details;
  final Map<T, String> trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodyLarge?.copyWith(color: colors.onSurface);
    final picked = [?details[value], ?trailing[value]];
    return DropdownButtonFormField<T>(
      // The menu shows what was picked last, wherever it was picked.
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      // As tall as each option needs: one may wrap.
      itemHeight: null,
      // The value in the face the text fields type in.
      style: style,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper ?? (picked.isEmpty ? null : picked.join(' · ')),
        // A description from elsewhere (a backend's), whole at any size.
        helperMaxLines: 8,
      ),
      // In the field, the name alone: what else it says goes under it.
      selectedItemBuilder: (context) => [
        for (final text in options.values) Align(alignment: AlignmentDirectional.centerStart, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
      items: [
        for (final MapEntry(key: option, value: text) in options.entries)
          DropdownMenuItem(
            value: option,
            // The value beside the name, what it is for under both: the
            // whole width for that, however wide the value at a large size.
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(text)),
                  if (trailing[option] case final end?) ...[
                    const SizedBox(width: Gap.md),
                    Text(end, style: context.text.titleMedium?.copyWith(color: colors.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
                  ],
                ]),
                if (details[option] case final detail?)
                  Text(detail, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
              ]),
            ),
          ),
      ],
      onChanged: onChanged == null
          ? null
          : (picked) {
              if (picked is T) onChanged!(picked);
            },
    );
  }
}

/// One item of a list, ticked or not (a model to assign), as a row of the
/// list: dimmed whole while it cannot be changed, as [SwitchRow] is — its
/// title takes the tile's style, monospaced with [mono] (an id).
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.mono = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Null: it cannot be changed now, and looks it.
  final ValueChanged<bool>? onChanged;
  final bool mono;

  /// The list's own inset by default; a sheet's, [Gap.xl].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    final row = CheckboxListTile(
      contentPadding: padding,
      value: value,
      onChanged: change == null ? null : (ticked) => change(ticked ?? false),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
    );
    // Through the tile's theme, so it still dims when disabled.
    return mono ? ListTileTheme.merge(titleTextStyle: context.text.bodyMedium?.mono.copyWith(color: context.colors.onSurface), child: row) : row;
  }
}

/// What became of a form's action, on a line over its [FormActionBar]
/// button — why it did not go through, where to look: an icon of its
/// [tone] before it, a line of the text tall at any text size. Read out as
/// it changes.
class FormStatus extends StatelessWidget {
  const FormStatus(this.message, {super.key, this.tone = BannerTone.error});

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, glyph) = switch (tone) {
      BannerTone.error => (colors.error, Icons.error_outline_rounded),
      BannerTone.warning => (colors.tertiary, Icons.warning_amber_rounded),
      // [InlineBanner]'s roles: secondary for what went through.
      BannerTone.success => (colors.secondary, Icons.check_circle_outline_rounded),
      BannerTone.info => (colors.onSurfaceVariant, Icons.info_outline_rounded),
    };
    // In the bar's face ([FormActionBar.above]), or the body's elsewhere.
    final style = DefaultTextStyle.of(context).style.copyWith(color: color);
    final line = (style.fontSize ?? 14) * (style.height ?? 1.2);
    return Semantics(
      liveRegion: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Icon(glyph, size: MediaQuery.textScalerOf(context).scale(line), color: color)),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(message, style: style)),
      ]),
    );
  }
}

/// The bar a long form's main action stays in, under the content that
/// scrolls: the composer's surface, the safe area kept.
class FormActionBar extends StatelessWidget {
  const FormActionBar({
    super.key,
    required this.child,
    this.above,
    this.padding = const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
    this.maxContentWidth,
  });

  /// [Gap.lg] at the sides on a page; [Gap.xl] in a sheet, as its content.
  final EdgeInsetsGeometry padding;

  /// The page's own ([AppPage.maxContentWidth]): the action lines up with
  /// the content over it, the bar keeps the whole width.
  final double? maxContentWidth;

  /// The action — usually one [AppButton] that fills the width.
  final Widget child;

  /// A line over it: what the action will do, why it cannot yet.
  final Widget? above;

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth ?? double.infinity),
              child: Padding(
                padding: padding,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (above != null) ...[
                    DefaultTextStyle.merge(style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant), child: above!),
                    const SizedBox(height: Gap.sm),
                  ],
                  child,
                ]),
              ),
            ),
          ),
        ),
      );
}
