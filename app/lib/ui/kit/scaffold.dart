import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../layout/window.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// A screen whose content scrolls under a collapsing top app bar.
///
/// M3: the medium top app bar. M3 Expressive: the large flexible one, with
/// the emphasized headline and a subtitle line under it (where the
/// connection status lives).
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.floatingActionButton,
    this.bottom,
    this.onRefresh,
    this.automaticallyImplyLeading = true,
    this.maxContentWidth,
  });

  /// As wide as a form or a page of reading grows ([maxContentWidth]).
  static const readableWidth = 720.0;

  /// Bring [target], on an [AppPage], into view as [Scrollable.ensureVisible]
  /// does at [alignment] (from the top: clear of the bar pinned there) —
  /// but never to leave the top bar part-way collapsed, its headline and its
  /// collapsed title over each other (M3 Expressive's, at a large text
  /// size). What is near enough the top that it would goes to the top, the
  /// bar whole: it shows under it.
  static Future<void> reveal(BuildContext target, {double alignment = 0.2, Duration duration = Duration.zero, Curve curve = Curves.ease}) {
    final object = target.findRenderObject();
    final position = Scrollable.maybeOf(target)?.position;
    final viewport = object == null ? null : RenderAbstractViewport.maybeOf(object);
    if (object == null || position == null || viewport == null) return Future.value();
    var offset = viewport.getOffsetToReveal(object, alignment).offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    // The page's first sliver is its top bar: how far it collapses.
    final bar = viewport is RenderViewport ? viewport.firstChild : null;
    final collapse = bar is RenderSliverPersistentHeader ? bar.maxExtent - bar.minExtent : 0.0;
    if (offset < collapse) offset = position.minScrollExtent;
    if (offset == position.pixels) return Future.value();
    if (duration == Duration.zero) {
      position.jumpTo(offset);
      return Future.value();
    }
    return position.animateTo(offset, duration: duration, curve: curve);
  }

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  /// Pinned under the content (a composer).
  final Widget? bottom;

  /// Pull to refresh.
  final Future<void> Function()? onRefresh;
  final bool automaticallyImplyLeading;

  /// How wide the content grows: in a wider window (a tablet) it is centered
  /// under the top bar, which keeps the whole width — its headline and
  /// subtitle lined up with the content. Null fills the window.
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final expressive = context.design.expressive;
    final colors = context.colors;
    // The collapsed title sits after the back button when there is one.
    final inset = leading != null || (automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false));
    // [side]: the content's margin in a window wider than it — the
    // headline and its subtitle line up with the content under them.
    Widget appBar(double side) {
      final flexible = _FlexibleTitle(
        title: title,
        subtitle: subtitle,
        inset: inset,
        side: side,
        // M3 Expressive: the large bar's bigger, emphasized headline; M3: the
        // medium bar's.
        headline: expressive ? context.text.headlineMedium : context.text.headlineSmall,
      );
      if (expressive) {
        return SliverAppBar.large(
          // The title inside marks itself as the header; the whole bar would
          // be one oversized node.
          excludeHeaderSemantics: true,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: [...actions, const SizedBox(width: Gap.xs)],
          expandedHeight: subtitle == null ? 152 : 176,
          flexibleSpace: flexible,
          backgroundColor: colors.surface,
        );
      }
      return SliverAppBar(
        pinned: true,
        excludeHeaderSemantics: true,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        expandedHeight: subtitle == null ? 112 : 136,
        flexibleSpace: flexible,
      );
    }

    final limit = maxContentWidth;
    Widget scroll = LayoutBuilder(builder: (context, constraints) {
      final side = limit == null ? 0.0 : math.max(0.0, (constraints.maxWidth - limit) / 2);
      return CustomScrollView(slivers: [
        appBar(side),
        if (side == 0)
          ...slivers
        else
          SliverPadding(padding: EdgeInsets.symmetric(horizontal: side), sliver: SliverMainAxisGroup(slivers: slivers)),
        SliverPadding(padding: EdgeInsets.only(bottom: floatingActionButton == null ? Gap.xl : 96)),
      ]);
    });
    if (onRefresh != null) scroll = RefreshIndicator(onRefresh: onRefresh!, edgeOffset: 120, child: scroll);
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: bottom == null ? scroll : Column(children: [Expanded(child: scroll), bottom!]),
    );
  }
}

class _FlexibleTitle extends StatelessWidget {
  const _FlexibleTitle({required this.title, this.subtitle, required this.inset, required this.side, required this.headline});

  final String title;
  final Widget? subtitle;
  final bool inset;

  /// The content's margin at each side ([AppPage.maxContentWidth]): the
  /// expanded headline keeps to the content's column.
  final double side;
  final TextStyle? headline;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final range = settings == null ? 1.0 : (settings.maxExtent - settings.minExtent);
    final t = settings == null || range <= 0 ? 0.0 : ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
    final colors = context.colors;
    final big = headline?.copyWith(color: colors.onSurface);
    final small = context.text.titleLarge?.copyWith(color: colors.onSurface);
    return SafeArea(
      bottom: false,
      child: Stack(children: [
        // Collapsed: the title in the bar itself, next to the back button.
        Positioned(
          left: inset ? 72 : Gap.lg,
          right: 96,
          top: 0,
          height: kToolbarHeight,
          // Only the visible one of the two titles is read out.
          child: ExcludeSemantics(
            excluding: t >= 0.5,
            child: Opacity(
              opacity: (1 - t * 3).clamp(0.0, 1.0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(header: true, child: Text(title, style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ),
            ),
          ),
        ),
        // Expanded: the headline, and the subtitle under it.
        Positioned(
          left: side + Gap.lg,
          right: side + Gap.lg,
          bottom: Gap.lg,
          child: Opacity(
            opacity: t,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(
                excluding: t < 0.5,
                child: Semantics(header: true, child: Text(title, style: big, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Gap.xs),
                DefaultTextStyle.merge(
                  style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  child: subtitle!,
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A screen with a fixed body (a transcript, a terminal), whose top bar does
/// not collapse.
class FixedPage extends StatelessWidget {
  const FixedPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;
  final Widget? bottom;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expressive = context.design.expressive;
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        toolbarHeight: subtitle == null ? kToolbarHeight : 64,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            DefaultTextStyle.merge(
              style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              child: subtitle!,
            ),
        ]),
        titleTextStyle: (expressive ? context.text.titleLarge : context.text.titleLarge)?.copyWith(color: colors.onSurface),
      ),
      body: bottom == null ? body : Column(children: [Expanded(child: body), bottom!]),
    );
  }
}

class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Top-level destinations, where the window puts them: a navigation bar at
/// the bottom of a phone, a rail down the side of anything wider. The bar's
/// labels keep to one line at any text size, made smaller first and then
/// shown only picked where they would not ([_BarLabels]).
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.body,
    this.railLeading,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? railLeading;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    if (window.isCompact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: LayoutBuilder(builder: (context, constraints) {
          final fit = _BarLabels.fit(context, items, constraints.maxWidth);
          return NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: onSelected,
            labelBehavior: fit.onlySelected ? NavigationDestinationLabelBehavior.onlyShowSelected : null,
            labelTextStyle: fit.labelTextStyle,
            height: fit.height,
            destinations: [
              for (final (index, item) in items.indexed)
                // Wider than its share where its label, picked, needs the
                // room its neighbours' hidden labels leave — picked or not,
                // so one fading out stays whole.
                OverflowBox(
                  minWidth: fit.widths[index],
                  maxWidth: fit.widths[index],
                  child: fit.inward(
                    context,
                    index,
                    // One line, whatever the text size: never broken inside
                    // a word, cut short only past every other measure.
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      child: NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
                    ),
                  ),
                ),
            ],
          );
        }),
      );
    }
    return Scaffold(
      body: Row(children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: onSelected,
            leading: railLeading,
            groupAlignment: context.design.expressive ? -0.6 : -1,
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}

/// How a navigation bar's labels fit the width each destination has, at the
/// text size the bar sets them in (the reader's, up to Material's cap of
/// 1.3 times). Side by side, each centred in its destination's share of the
/// bar, they fit where the ones at the bar's ends are half [Gap.sm] inside
/// the window's edges, each two neighbours [Gap.sm] apart, and each within
/// its share (where Material lays it out). They are
/// - as they are, where they fit so;
/// - else all of them smaller by one factor, the largest at which they fit,
///   no smaller than [minScale] of their size;
/// - else only the picked destination's label shows (Material's
///   `onlyShowSelected`), as big as every one would fit picked, centred
///   under its icon — over its neighbours' hidden labels up to their icons,
///   at the bar's ends within its share as side by side — and no smaller
///   than [minScale]. One at an end too long even so moves in from the
///   window's edge, up to the next icon; one too long past that is cut
///   short. Each destination keeps its label for screen readers and in its
///   tooltip. The bar is as tall as a label fading in or out needs to stay
///   inside it ([height]).
///
/// What measures the labels is what draws them: one style, picked and not,
/// its size and letter spacing set out.
class _BarLabels {
  const _BarLabels._({
    required this.scale,
    required this.onlySelected,
    required this.picked,
    required this.unpicked,
    required this.widths,
    required this.shifts,
    this.height,
  });

  /// The labels' size, as a share of the theme's.
  final double scale;
  final bool onlySelected;

  /// The labels' styles, picked and not: the bar's own at [scale].
  final TextStyle picked, unpicked;

  /// Each destination's width where its label, picked, needs more than its
  /// share; null at its share.
  final List<double?> widths;

  /// How far each label sits in from under its icon, toward the bar's
  /// middle: at an end of the bar, where it would not fit centred.
  final List<double> shifts;

  /// The bar's height where only the picked label shows, null where the
  /// theme's. Material moves a label down under its icon as it fades out,
  /// and up from there as it fades in: hidden, it rests under the icon
  /// centred in the bar. The bar is tall enough for it to stay inside
  /// there — the icon's height and twice the label's — or the theme's
  /// height where that is more.
  final double? height;

  static const minScale = 0.8;

  /// Material's cap on the text scale of a navigation bar's labels.
  static const _maxTextScale = 1.3;

  /// Material 3's own label padding, where the theme sets none.
  static const _labelPadding = EdgeInsets.only(top: 4);

  /// Material 3's own bar height, where the theme sets none.
  static const _barHeight = 80.0;

  /// The height of Material 3's indicator behind the icon, which Material
  /// lays out as the icon.
  static const _indicatorHeight = 32.0;

  /// For the bar: null where the labels are as the theme sets them.
  WidgetStateProperty<TextStyle?>? get labelTextStyle => scale == 1 && !onlySelected
      ? null
      : WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? picked : unpicked);

  /// [destination], its label moved in by [shifts] — as padding on its outer
  /// side, so it stays inside its destination's width.
  Widget inward(BuildContext context, int index, Widget destination) {
    final shift = shifts[index];
    if (shift == 0) return destination;
    final bar = NavigationBarTheme.of(context);
    final outer = index == 0 ? EdgeInsetsDirectional.only(start: 2 * shift) : EdgeInsetsDirectional.only(end: 2 * shift);
    return NavigationBarTheme(data: bar.copyWith(labelPadding: (bar.labelPadding ?? _labelPadding).add(outer)), child: destination);
  }

  static _BarLabels fit(BuildContext context, List<NavItem> items, double width) {
    final theme = Theme.of(context);
    final bar = NavigationBarTheme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxTextScale);
    final locale = Localizations.maybeLocaleOf(context);
    final padding = (bar.labelPadding ?? _labelPadding).resolve(direction);
    // Picked and not, as the bar sets them: its theme's label style over the
    // body text of its Material (Material 3's own, where the theme has none).
    TextStyle style(Set<WidgetState> states) => (theme.textTheme.bodyMedium ?? const TextStyle()).merge(
          bar.labelTextStyle?.resolve(states) ??
              theme.textTheme.labelMedium?.copyWith(
                color: states.contains(WidgetState.selected) ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              ),
        );
    final styles = (picked: style(const {WidgetState.selected}), unpicked: style(const {}));
    // Smaller by [scale], letter spacing with it.
    TextStyle scaled(TextStyle style, double scale) => style.copyWith(
          fontSize: (style.fontSize ?? kDefaultFontSize) * scale,
          letterSpacing: (style.letterSpacing ?? 0) * scale,
        );
    // [label] at [scale], picked or not, whichever is larger: its padding
    // round it.
    Size measure(String label, double scale) {
      var widest = 0.0, tallest = 0.0;
      for (final style in [styles.picked, styles.unpicked]) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: scaled(style, scale)),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        tallest = math.max(tallest, painter.height);
        painter.dispose();
      }
      return Size(widest + padding.horizontal, tallest + padding.vertical);
    }

    List<double> widthsAt(double scale) => [for (final item in items) measure(item.label, scale).width];

    final count = items.length;
    _BarLabels result(double scale, {bool onlySelected = false, List<double?>? widths, List<double>? shifts, double? height}) => _BarLabels._(
          scale: scale,
          onlySelected: onlySelected,
          picked: scaled(styles.picked, scale),
          unpicked: scaled(styles.unpicked, scale),
          widths: widths ?? List.filled(count, null),
          shifts: shifts ?? List.filled(count, 0),
          height: height,
        );

    // The largest scale from [from] down to [minScale] at which [fits]:
    // [from] where they do, else halved down to a thousandth.
    double? settle(double from, bool Function(double scale) fits) {
      var high = from.clamp(minScale, 1.0);
      if (fits(high)) return high;
      var low = minScale;
      if (high == low || !fits(low)) return null;
      while (high - low > 0.001) {
        final middle = (low + high) / 2;
        if (fits(middle)) {
          low = middle;
        } else {
          high = middle;
        }
      }
      return low;
    }

    const gap = Gap.sm;
    final share = (width - MediaQuery.paddingOf(context).horizontal) / count;
    // Side by side, each centred in its share: at the ends half the gap
    // inside the window's edges, neighbours the gap apart, each within its
    // share.
    bool sideBySide(List<double> labels) {
      if (labels.first > share - gap || labels.last > share - gap) return false;
      for (var i = 1; i < count; i++) {
        if ((labels[i - 1] + labels[i]) / 2 > share - gap) return false;
      }
      return labels.every((label) => label <= share);
    }

    final natural = widthsAt(1);
    if (sideBySide(natural)) return result(1);
    // Smaller together: from where they would fit were their text's width
    // to go with its size, down to where they do.
    final text = [for (final label in natural) label - padding.horizontal];
    double upTo(double room, double label) => label > 0 ? (room - padding.horizontal) / label : double.infinity;
    var largest = [upTo(share - gap, text.first), upTo(share - gap, text.last), for (final label in text) upTo(share, label)].reduce(math.min);
    for (var i = 1; i < count; i++) {
      largest = math.min(largest, upTo(share - gap, (text[i - 1] + text[i]) / 2));
    }
    final together = settle(largest, (scale) => sideBySide(widthsAt(scale)));
    if (together != null) return result(together);
    // One at a time, centred under its icon: up to the glyphs of the icons
    // either side, which sit a share away; at an end of the bar, its share
    // less half the gap at each side, as side by side.
    final icon = bar.iconTheme?.resolve(const {})?.size ?? 24;
    bool end(int index) => index == 0 || index == count - 1;
    double room(int index) => end(index) ? share - gap : math.max(share, 2 * (share - icon / 2 - gap));
    // At an end, moved in: from half the gap inside the window's edge to the
    // gap short of the next icon.
    final reach = count == 1 ? share - gap : 1.5 * share - icon / 2 - 1.5 * gap;
    final most = [for (final (index, label) in natural.indexed) room(index) / label].reduce(math.min);
    final scale = settle(most, (scale) => items.indexed.every((entry) => measure(entry.$2.label, scale).width <= room(entry.$1))) ?? minScale;
    final sizes = [for (final item in items) measure(item.label, scale)];
    final widths = <double?>[];
    final shifts = <double>[];
    for (final (index, size) in sizes.indexed) {
      final label = size.width;
      if (end(index) && label > room(index)) {
        final shown = math.min(label, reach);
        final shift = (shown - room(index)) / 2;
        widths.add(shown + 2 * shift);
        shifts.add(shift);
      } else {
        widths.add(label > share ? math.min(label, room(index)) : null);
        shifts.add(0);
      }
    }
    // Tall enough for a hidden label under its icon centred in the bar —
    // to a whole dp, past a rounding error.
    final tallest = sizes.map((size) => size.height).reduce(math.max);
    final needs = (math.max(_indicatorHeight, icon) + 2 * tallest - 0.01).ceilToDouble();
    final height = math.max(bar.height ?? _barHeight, needs);
    return result(scale, onlySelected: true, widths: widths, shifts: shifts, height: height);
  }
}
