import 'package:flutter/services.dart';

import '../material.dart';
import 'feedback.dart';
import '../theme/tokens.dart';

/// A group of related rows. M3: one surface, rows divided by hairlines. M3
/// Expressive: separate rounded segments with a small gap, the outer
/// corners large and the inner ones small — the expressive list.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.margin = const EdgeInsets.symmetric(horizontal: Gap.lg)});

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final colors = context.colors;
    if (children.isEmpty) return const SizedBox.shrink();
    if (design.expressive) {
      final outer = Radius.circular(design.shapes.largeIncreased);
      const inner = Radius.circular(4);
      return Padding(
        padding: margin,
        child: Column(children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 2),
            Material(
              color: colors.surfaceContainer,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? outer : inner,
                  bottom: index == children.length - 1 ? outer : inner,
                ),
              ),
              child: children[index],
            ),
          ],
        ]),
      );
    }
    return Padding(
      padding: margin,
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(design.shapes.medium),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Column(children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: Gap.lg),
            children[index],
          ],
        ]),
      ),
    );
  }
}

/// A heading over a group, with an optional hint under it.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.hint, this.trailing});

  final String title;
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.lg, Gap.sm),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: (context.design.expressive ? context.text.titleMedium : context.text.titleSmall)
                    ?.copyWith(color: context.colors.primary),
              ),
              if (hint != null)
                Text(hint!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

enum StatusTone { running, waiting, done, failed, neutral }

/// A short state word — running, waiting for you, done. M3 Expressive puts a
/// living shape before it while something is under way.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, required this.tone, this.filled = false});

  final String label;
  final StatusTone tone;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final design = context.design;
    final (background, foreground) = switch (tone) {
      StatusTone.running => (colors.primaryContainer, colors.onPrimaryContainer),
      StatusTone.waiting => (colors.tertiaryContainer, colors.onTertiaryContainer),
      StatusTone.done => (colors.secondaryContainer, colors.onSecondaryContainer),
      StatusTone.failed => (colors.errorContainer, colors.onErrorContainer),
      StatusTone.neutral => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    final dot = design.expressive && (tone == StatusTone.running || tone == StatusTone.waiting)
        ? InlineBusy(size: 14, color: foreground)
        : Container(width: 8, height: 8, decoration: BoxDecoration(color: foreground, shape: BoxShape.circle));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled || design.expressive ? background : Colors.transparent,
        border: filled || design.expressive ? null : Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(design.expressive ? design.shapes.small : 100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        dot,
        const SizedBox(width: 6),
        Text(label, style: context.text.labelMedium?.copyWith(color: filled || design.expressive ? foreground : colors.onSurfaceVariant)),
      ]),
    );
  }
}

/// A label and its value, on one line; [mono] for keys and addresses.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.mono = false, this.copyable = false});

  final String label;
  final String value;
  final bool mono;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final body = context.text.bodyMedium;
    final style = mono ? body?.mono.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) : body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 88,
          child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        Expanded(
          child: copyable
              ? GestureDetector(
                  onLongPress: () => Clipboard.setData(ClipboardData(text: value)),
                  child: SelectableText(value, style: style),
                )
              : Text(value, style: style),
        ),
      ]),
    );
  }
}

/// Monospaced text in a quiet box — commands, tool input, diffs. Scrolls
/// sideways rather than wrapping, and caps its height.
class MonoBlock extends StatelessWidget {
  const MonoBlock(this.text, {super.key, this.maxHeight = 240, this.spans});

  final String text;
  final double maxHeight;

  /// Pre-styled spans in place of [text] (a coloured diff).
  final List<InlineSpan>? spans;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.bodySmall?.mono.copyWith(height: 1.45, color: colors.onSurface);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(context.design.shapes.medium),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText.rich(TextSpan(style: style, children: spans ?? [TextSpan(text: text)])),
        ),
      ),
    );
  }
}

/// A raised group of content: a card in the theme's shape.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Gap.lg), this.tone});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// A container colour for a card that must stand out (an approval).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: tone,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// The M3 search bar's look — a 56dp pill on the high container — as a
/// plain text field, so the whole bar is one target for touch and for
/// screen readers (the library's SearchBar exposes only its 24dp line).
/// The clear button comes built in.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
            if (trailing != null) Padding(padding: const EdgeInsetsDirectional.only(end: Gap.sm), child: trailing),
          ]),
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          constraints: const BoxConstraints(minHeight: 56),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
