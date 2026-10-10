import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/ui/kit/scaffold.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';

import 'support/harness.dart';

/// The phone's navigation bar, in the real fonts: its labels on one line
/// at every text size, in both styles and all three languages, whether the
/// computer has the models tab or not — as Material sets them where they
/// keep apart and inside the window, made smaller only as far as they must
/// be, shown only picked only where even 0.8 of their size would not do,
/// never broken inside a word.
void main() {
  setUpAll(loadFonts);

  const locales = [Locale('en'), Locale('zh'), Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')];

  /// The shell's tabs, in [context]'s language; the models tab with [models].
  List<NavItem> tabs(BuildContext context, {bool models = true}) {
    final l = L10n.of(context);
    return [
      NavItem(icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, label: l.tabSessions),
      NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder_rounded, label: l.tabFiles),
      NavItem(icon: Icons.merge_type_outlined, selectedIcon: Icons.merge_type_rounded, label: l.tabGit),
      NavItem(icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: l.tabHistory),
      if (models) NavItem(icon: Icons.layers_outlined, selectedIcon: Icons.layers_rounded, label: l.tabModels),
    ];
  }

  Future<void> pumpBar(
    WidgetTester tester, {
    required DesignStyle style,
    required Locale locale,
    required double width,
    required double scale,
    bool models = true,
    int selected = 0,
    List<NavItem> Function(BuildContext context)? items,
    ValueChanged<int>? onSelected,
    bool settle = true,
  }) async {
    phoneSurface(tester, size: Size(width, 800));
    await tester.pumpWidget(harness(
      TestServices(),
      Builder(
        builder: (context) => AdaptiveNavigation(
          items: items?.call(context) ?? tabs(context, models: models),
          selected: selected,
          onSelected: onSelected ?? (_) {},
          body: const SizedBox.expand(),
        ),
      ),
      style: style,
      locale: locale,
      textScale: scale,
    ));
    // Past the theme's change from the last style, and the labels' fades.
    if (settle) await tester.pump(const Duration(seconds: 1));
  }

  /// Each label's paragraph in the bar, with its text.
  Map<String, RenderParagraph> labels(WidgetTester tester) => {
        for (final element in find.descendant(of: find.byType(NavigationBar), matching: find.byType(RichText)).evaluate())
          if ((element.renderObject! as RenderParagraph).text.toPlainText() case final text when text.trim().isNotEmpty && !_isIcon(element))
            text: element.renderObject! as RenderParagraph,
      };

  /// How much of [label] shows: its fade in the bar.
  double opacity(WidgetTester tester, String label) =>
      tester.widget<FadeTransition>(find.ancestor(of: find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), matching: find.byType(FadeTransition)).first).opacity.value;

  /// One line, the whole of it.
  void expectWhole(RenderParagraph paragraph, String reason) {
    final text = paragraph.text.toPlainText();
    expect(_lines(paragraph), 1, reason: '"$text" on one line: $reason');
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" cut short: $reason');
    expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5), reason: '"$text" cut short: $reason');
  }

  /// The size the bar sets its labels in at the normal text size, in
  /// [style] and [locale] — what "no smaller than 0.8 of it" is of.
  Future<double> normalSize(WidgetTester tester, DesignStyle style, Locale locale) async {
    await pumpBar(tester, style: style, locale: locale, width: 412, scale: 1);
    final sizes = {for (final paragraph in labels(tester).values) paragraph.textScaler.scale(paragraph.text.style!.fontSize!)};
    expect(sizes, hasLength(1), reason: 'one size for every label');
    return sizes.single;
  }

  /// The labels that show in a [width]dp bar with tab [selected] picked —
  /// every one, or only the picked one's — each whole on one line, no
  /// smaller than 0.8 of [normal] at the bar's text size, under its own
  /// icon, half [Gap.sm] inside the window, and [Gap.sm] clear of the other
  /// icons and labels. An end tab's label too long to sit centred moves in
  /// from the window's edge just that far. Returns where they are.
  Map<int, Rect> expectPlaced(WidgetTester tester, {required double width, required int selected, required double normal, required String reason}) {
    final context = tester.element(find.byType(NavigationBar));
    final names = [for (final destination in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination))) destination.label];
    final icons = [for (var i = 0; i < names.length; i++) tester.getRect(find.descendant(of: find.byType(NavigationDestination).at(i), matching: find.byType(Icon)))];
    final full = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(normal);
    final paragraphs = labels(tester);
    final shown = <int, Rect>{};
    for (final (index, name) in names.indexed) {
      if (opacity(tester, name) == 0) continue;
      final paragraph = paragraphs[name]!;
      final why = '"$name" $reason';
      expect(opacity(tester, name), 1, reason: why);
      expectWhole(paragraph, reason);
      expect(paragraph.textScaler.scale(paragraph.text.style!.fontSize!), greaterThanOrEqualTo(full * 0.8 - 0.01), reason: '$why: no smaller than 0.8 of ${full}px');
      final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
      expect(rect.left, greaterThanOrEqualTo(Gap.sm / 2 - 0.01), reason: '$why: inside the window at $rect');
      expect(rect.right, lessThanOrEqualTo(width - Gap.sm / 2 + 0.01), reason: '$why: inside the window at $rect');
      // Centred under its icon; at an end, moved in no further than it must.
      final end = index == 0 || index == names.length - 1;
      final centred = (rect.center.dx - icons[index].center.dx).abs() <= 0.5;
      final movedIn = end && (index == 0 ? rect.left - Gap.sm / 2 : width - Gap.sm / 2 - rect.right).abs() <= 0.01;
      expect(centred || movedIn, isTrue, reason: '$why: under its icon at ${icons[index]}, at $rect');
      expect(rect.left < icons[index].center.dx && rect.right > icons[index].center.dx, isTrue, reason: '$why: under its icon');
      for (final (other, icon) in icons.indexed) {
        if (other == index) continue;
        expect(rect.left >= icon.right + Gap.sm - 0.01 || rect.right <= icon.left - Gap.sm + 0.01, isTrue, reason: '$why: clear of icon $other at $icon, at $rect');
      }
      shown[index] = rect;
    }
    expect(shown.keys, contains(selected), reason: 'the picked label shows: $reason');
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    if (bar.labelBehavior == NavigationDestinationLabelBehavior.onlyShowSelected) {
      expect(shown.keys, [selected], reason: 'only the picked label: $reason');
    } else {
      expect(shown, hasLength(names.length), reason: 'every label: $reason');
    }
    // Apart.
    final rects = shown.values.toList()..sort((a, b) => a.left.compareTo(b.left));
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left - rects[i - 1].right, greaterThanOrEqualTo(Gap.sm - 0.01), reason: reason);
    }
    return shown;
  }

  /// The rule the bar holds labels [widths] side by side to, each centred
  /// in its [share]: the ones at the ends half [Gap.sm] inside the window,
  /// neighbours [Gap.sm] apart, each within its share (where Material lays
  /// it out) — given [slack] more room, or less.
  bool sideBySide(List<double> widths, double share, {double slack = 0}) {
    final room = share - Gap.sm + slack;
    if (widths.first > room || widths.last > room) return false;
    for (var i = 1; i < widths.length; i++) {
      if ((widths[i - 1] + widths[i]) / 2 > room) return false;
    }
    return widths.every((width) => width <= share + slack);
  }

  /// The labels no smaller than [sideBySide] needs, in a [width]dp bar:
  /// made smaller together only where they would not fit as they are, and
  /// only as far as they must be — 1% bigger would not fit; only the picked
  /// one shown only where even 0.8 of their [normal] size would not fit.
  void expectNeeded(WidgetTester tester, {required double width, required double normal, required String reason}) {
    final context = tester.element(find.byType(NavigationBar));
    final full = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(normal);
    final names = [for (final destination in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination))) destination.label];
    final paragraphs = labels(tester);
    final size = paragraphs[names.first]!.textScaler.scale(paragraphs[names.first]!.text.style!.fontSize!);
    final widths = [for (final name in names) paragraphs[name]!.getMaxIntrinsicWidth(double.infinity)];
    List<double> times(double factor) => [for (final label in widths) label * factor];
    final share = width / names.length;
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    if (bar.labelBehavior == NavigationDestinationLabelBehavior.onlyShowSelected) {
      expect(sideBySide(times(full * 0.8 / size), share, slack: -0.1), isFalse, reason: 'only the picked label, though all of them fit at 0.8 of ${full}px: $reason');
    } else if (bar.labelTextStyle != null) {
      expect(size, lessThan(full - 0.01), reason: 'smaller: $reason');
      expect(sideBySide(times(1.01), share), isFalse, reason: 'smaller than they must be, at ${size}px of ${full}px: $reason');
    } else {
      expect(size, closeTo(full, 0.01), reason: reason);
    }
  }

  for (final style in DesignStyle.values) {
    testWidgets('every label whole on one line, all of them shown, at 1–2× text on 360 and 412dp phones ${style.name}', (tester) async {
      for (final locale in locales) {
        final normal = await normalSize(tester, style, locale);
        for (final width in [360.0, 412.0]) {
          for (final models in [true, false]) {
            for (final scale in [1.0, 1.1, 1.2, 1.25, 1.3, 1.5, 1.75, 2.0]) {
              final reason = '${locale.toLanguageTag()} ${width.toInt()}dp ${scale}x ${models ? 5 : 4} tabs';
              await pumpBar(tester, style: style, locale: locale, width: width, scale: scale, models: models);
              final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
              expect(bar.labelBehavior, isNull, reason: 'every label shown: $reason');
              expect(labels(tester), hasLength(models ? 5 : 4), reason: reason);
              expectPlaced(tester, width: width, selected: 0, normal: normal, reason: reason);
              // At the normal size nothing changes.
              if (scale == 1) expect(bar.labelTextStyle, isNull, reason: reason);
            }
          }
        }
      }
    });

    // Narrower phones, each tab picked in turn: the labels as they are, made
    // smaller, or only the picked one shown — no further than they must
    // be, and what shows whole, never at the window's edge or over another
    // icon.
    testWidgets('the picked label whole, inside the window and clear of the other icons, and no smaller than it must be, on 300–359dp phones at 1–2× text ${style.name}', (tester) async {
      for (final locale in locales) {
        final normal = await normalSize(tester, style, locale);
        for (var width = 300.0; width < 360; width += 3) {
          for (final scale in [1.0, 1.15, 1.2, 1.25, 1.3, 1.5, 2.0]) {
            for (final models in [true, false]) {
              for (var selected = 0; selected < (models ? 5 : 4); selected++) {
                final reason = '${locale.toLanguageTag()} ${width.toInt()}dp ${scale}x ${models ? 5 : 4} tabs, tab $selected picked';
                await pumpBar(tester, style: style, locale: locale, width: width, scale: scale, models: models, selected: selected);
                expectPlaced(tester, width: width, selected: selected, normal: normal, reason: reason);
                expectNeeded(tester, width: width, normal: normal, reason: reason);
              }
            }
          }
        }
      }
    });

    // "歷史記錄" is wider than the others: at a larger text size it fits its
    // share only a little smaller, its neighbours clear of it — not only
    // picked.
    testWidgets('traditional Chinese at 1.15–1.3× text on 300–333dp phones: every label shown, smaller together, not only the picked one ${style.name}', (tester) async {
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      final normal = await normalSize(tester, style, hant);
      var seen = 0;
      for (final (scale, widest) in [(1.15, 300.0), (1.25, 321.0), (1.3, 333.0)]) {
        for (var width = 300.0; width <= widest; width += 3) {
          final reason = '${width.toInt()}dp ${scale}x';
          await pumpBar(tester, style: style, locale: hant, width: width, scale: scale);
          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.labelBehavior, isNull, reason: 'every label shown: $reason');
          expect(bar.labelTextStyle, isNotNull, reason: 'smaller: $reason');
          expectPlaced(tester, width: width, selected: 0, normal: normal, reason: reason);
          expectNeeded(tester, width: width, normal: normal, reason: reason);
          seen++;
        }
      }
      expect(seen, 21);
    });

    // Where Material's own bar keeps its labels apart and inside the window
    // at the normal text size, it is left as it is: on a 300dp phone, say,
    // "歷史記錄" 57dp wide in its 60dp is not made smaller.
    testWidgets("at the normal text size, Material's own bar, pixel for pixel, wherever it keeps its labels apart and inside the window ${style.name}", (tester) async {
      const shot = ValueKey('bar');
      final services = TestServices();
      Future<Uint8List> pump(Locale locale, double width, bool models, {required bool material}) async {
        phoneSurface(tester, size: Size(width, 160));
        await tester.pumpWidget(RepaintBoundary(
          key: shot,
          child: harness(
            services,
            Builder(
              builder: (context) => material
                  // The bar as Material lays it out, nothing set.
                  ? Scaffold(
                      body: const SizedBox.expand(),
                      bottomNavigationBar: NavigationBar(
                        selectedIndex: 0,
                        onDestinationSelected: (_) {},
                        destinations: [
                          for (final item in tabs(context, models: models))
                            NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
                        ],
                      ),
                    )
                  : AdaptiveNavigation(items: tabs(context, models: models), selected: 0, onSelected: (_) {}, body: const SizedBox.expand()),
            ),
            style: style,
            locale: locale,
          ),
        ));
        await tester.pump(const Duration(seconds: 1));
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2.625);
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
          image.dispose();
          return bytes;
        }))!;
      }

      var compared = 0;
      for (final locale in locales) {
        for (final width in [for (var width = 300.0; width <= 330; width += 3) width, 360.0, 412.0]) {
          for (final models in [true, false]) {
            final reason = '${locale.toLanguageTag()} ${width.toInt()}dp ${models ? 5 : 4} tabs';
            final material = await pump(locale, width, models, material: true);
            final names = [for (final destination in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination))) destination.label];
            final paragraphs = labels(tester);
            final keeps = sideBySide([for (final name in names) paragraphs[name]!.getMaxIntrinsicWidth(double.infinity)], width / names.length);
            if (locale == locales.last && models) expect(keeps, isTrue, reason: '"歷史記錄" in its share, clear of its neighbours: $reason');
            if (!keeps) continue;
            final ours = await pump(locale, width, models, material: false);
            final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
            expect((bar.labelBehavior, bar.labelTextStyle, bar.height), (null, null, null), reason: reason);
            var differ = ours.length == material.length ? 0 : -1;
            for (var i = 0; differ >= 0 && i < ours.length; i++) {
              if (ours[i] != material[i]) differ++;
            }
            expect(differ, 0, reason: 'bytes differing from Material\'s own: $reason');
            compared++;
          }
        }
      }
      expect(compared, greaterThan(20));
    });
  }

  testWidgets("past the smallest size, only the picked tab's label shows — whole — and every tab keeps its name for screen readers and in its tooltip", (tester) async {
    final semantics = tester.ensureSemantics();
    for (final style in DesignStyle.values) {
      // At 2×, "Sessions" on a 320dp phone and "歷史記錄" on a 280dp one
      // would need under 0.8 of their size side by side; "歷史記錄" picked
      // has more than its share.
      for (final (locale, width, selected) in [(const Locale('en'), 320.0, 0), (const Locale('en'), 320.0, 3), (locales.last, 280.0, 3)]) {
        final normal = await normalSize(tester, style, locale);
        final tapped = <int>[];
        await pumpBar(tester, style: style, locale: locale, width: width, scale: 2, selected: selected, onSelected: tapped.add);
        final reason = '${style.name} ${locale.toLanguageTag()} ${width.toInt()}dp, tab $selected picked';
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.labelBehavior, NavigationDestinationLabelBehavior.onlyShowSelected, reason: reason);
        final context = tester.element(find.byType(NavigationBar));
        final names = [for (final item in tabs(context)) item.label];
        final shown = labels(tester);
        // The picked label in full, no smaller than 0.8 of its size, under
        // its own icon, clear of the others.
        final rect = expectPlaced(tester, width: width, selected: selected, normal: normal, reason: reason)[selected]!;
        expectNeeded(tester, width: width, normal: normal, reason: reason);
        if (locale == locales.last) expect(rect.width, greaterThan(width / 5), reason: '$reason: more than its share');
        // "Sessions", at the bar's start, too long to sit centred under its
        // icon half the gap inside the window even at 0.8 of its size: moved
        // in from the window's edge, up to that and no further.
        if (selected == 0) {
          final icon = tester.getRect(find.descendant(of: find.byType(NavigationDestination).first, matching: find.byType(Icon)));
          expect(rect.left, closeTo(Gap.sm / 2, 0.01), reason: reason);
          expect(rect.center.dx, greaterThan(icon.center.dx + 0.5), reason: '$reason: moved in');
        }
        for (final (index, name) in names.indexed) {
          // The others hidden, but every one named, and on one line.
          final opacity = tester.widget<FadeTransition>(find.ancestor(of: find.text(name), matching: find.byType(FadeTransition)).first).opacity.value;
          expect(opacity, index == selected ? 1 : 0, reason: '$name: $reason');
          expect(_lines(shown[name]!), 1, reason: '$name: $reason');
          expect(tester.getSemantics(find.byType(NavigationDestination).at(index)).label, startsWith('$name\n'), reason: '$name: $reason');
          // (Material UI's tooltip, not the one `find.byTooltip` knows.)
          expect(find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == name), findsOneWidget, reason: '$name: $reason');
        }
        // Each tab's taps go to it, the picked one's wider label over its
        // neighbours or not.
        for (final icon in [Icons.merge_type_outlined, Icons.layers_outlined]) {
          await tester.tap(find.byIcon(icon));
          await tester.pump(const Duration(seconds: 1));
        }
        expect(tapped, [2, 4], reason: reason);
      }
      // A long press shows a hidden label in full.
      expect(find.text('檔案'), findsOneWidget);
      await tester.longPress(find.byIcon(Icons.folder_outlined));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('檔案'), findsNWidgets(2), reason: '${style.name}: the tooltip over the bar');
      await tester.pump(const Duration(seconds: 3));
    }
    semantics.dispose();
  });

  testWidgets('past the smallest size, a label fading out stays whole, as does the one fading in', (tester) async {
    for (final style in DesignStyle.values) {
      // 280dp at 2×: "歷史記錄" picked is wider than its share; 300dp at 2×:
      // "Sessions" picked moves in from the window's edge.
      for (final (locale, width, from, to) in [(locales.last, 280.0, 3, 4), (locales.last, 280.0, 3, 2), (const Locale('en'), 300.0, 0, 1)]) {
        final reason = '${style.name} ${locale.toLanguageTag()} ${width.toInt()}dp, tab $from to $to';
        var selected = from;
        await pumpBar(
          tester,
          style: style,
          locale: locale,
          width: width,
          scale: 2,
          selected: from,
          onSelected: (index) => selected = index,
        );
        final context = tester.element(find.byType(NavigationBar));
        final names = [for (final item in tabs(context)) item.label];
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior, NavigationDestinationLabelBehavior.onlyShowSelected, reason: reason);
        final before = MatrixUtils.transformRect(labels(tester)[names[from]]!.getTransformTo(null), Offset.zero & labels(tester)[names[from]]!.size);
        // Picked anew, as the shell does: rebuilt with the tapped tab.
        await tester.tap(find.byIcon(tabs(context)[to].icon));
        expect(selected, to, reason: reason);
        await pumpBar(tester, style: style, locale: locale, width: width, scale: 2, selected: to, settle: false);
        // Halfway through the fades.
        await tester.pump(const Duration(milliseconds: 200));
        final out = opacity(tester, names[from]), into = opacity(tester, names[to]);
        expect(out, inExclusiveRange(0, 1), reason: '${names[from]} fading out: $reason');
        expect(into, inExclusiveRange(0, 1), reason: '${names[to]} fading in: $reason');
        final paragraphs = labels(tester);
        expectWhole(paragraphs[names[from]]!, 'fading out: $reason');
        expectWhole(paragraphs[names[to]]!, 'fading in: $reason');
        // Where it was, not moved as it goes.
        final during = MatrixUtils.transformRect(paragraphs[names[from]]!.getTransformTo(null), Offset.zero & paragraphs[names[from]]!.size);
        expect(during.left, closeTo(before.left, 0.01), reason: reason);
        expect(during.width, closeTo(before.width, 0.01), reason: reason);
        await tester.pump(const Duration(seconds: 1));
        expect(opacity(tester, names[from]), 0, reason: reason);
      }
    }
  });

  testWidgets('past the smallest size, a label fading in or out stays inside the bar — taller for it — and the bar keeps its height otherwise', (tester) async {
    List<NavItem> long(BuildContext context) => [
          for (final label in ['One', 'A destination whose name goes on and on and on', 'Three'])
            NavItem(icon: Icons.circle_outlined, selectedIcon: Icons.circle, label: label),
        ];
    for (final style in DesignStyle.values) {
      final themed = style == DesignStyle.expressive ? 64.0 : 80.0;
      // Every label shown, as they are or smaller: the theme's height.
      for (final (width, scale) in [(412.0, 1.0), (360.0, 2.0), (300.0, 1.0)]) {
        await pumpBar(tester, style: style, locale: const Locale('en'), width: width, scale: scale);
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior, isNull);
        expect(tester.getSize(find.byType(NavigationBar)).height, themed, reason: '${style.name} ${width.toInt()}dp ${scale}x');
      }
      // Only the picked one: at 2× ("Sessions", "歷史記錄"), and at the
      // normal size (a name too long even alone).
      for (final (locale, width, scale, from, to, items) in <(Locale, double, double, int, int, List<NavItem> Function(BuildContext)?)>[
        (const Locale('en'), 300.0, 2.0, 0, 1, null),
        (const Locale('en'), 320.0, 2.0, 3, 0, null),
        (locales.last, 280.0, 2.0, 3, 4, null),
        (locales.last, 280.0, 2.0, 4, 3, null),
        (const Locale('en'), 360.0, 1.0, 1, 0, long),
        (const Locale('en'), 360.0, 1.0, 0, 1, long),
      ]) {
        final reason = '${style.name} ${locale.toLanguageTag()} ${width.toInt()}dp ${scale}x, tab $from to $to';
        await pumpBar(tester, style: style, locale: locale, width: width, scale: scale, selected: from, items: items);
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior, NavigationDestinationLabelBehavior.onlyShowSelected, reason: reason);
        final bar = tester.getRect(find.byType(NavigationBar));
        // As tall as a label under its icon at rest, hidden, needs: no
        // taller.
        final paragraph = labels(tester).values.first;
        final needs = 32 + 2 * (4 + paragraph.size.height);
        expect(bar.height, inInclusiveRange(themed, math.max(themed, needs + 1)), reason: reason);
        await pumpBar(tester, style: style, locale: locale, width: width, scale: scale, selected: to, items: items, settle: false);
        var between = 0;
        for (var t = 0; t <= 600; t += 20) {
          await tester.pump(Duration(milliseconds: t == 0 ? 1 : 20));
          expect(tester.getRect(find.byType(NavigationBar)), bar, reason: '$reason: the bar holds still');
          for (final element in find.descendant(of: find.byType(NavigationBar), matching: find.byType(RichText)).evaluate()) {
            if (_isIcon(element)) continue;
            final shown = element.findAncestorWidgetOfExactType<FadeTransition>()!.opacity.value;
            if (shown == 0) continue;
            if (shown < 1) between++;
            final label = element.renderObject! as RenderParagraph;
            final rect = MatrixUtils.transformRect(label.getTransformTo(null), Offset.zero & label.size);
            final why = '"${label.text.toPlainText()}" at ${shown.toStringAsFixed(2)} at ${t}ms, at $rect in the bar at $bar: $reason';
            expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 1), reason: why);
            expect(rect.top, greaterThanOrEqualTo(bar.top - 1), reason: why);
          }
        }
        expect(between, greaterThan(0), reason: '$reason: a label part-way faded');
      }
    }
  });

  testWidgets('a label too long even alone is cut short on its one line, never broken', (tester) async {
    await pumpBar(
      tester,
      style: DesignStyle.material3,
      locale: const Locale('en'),
      width: 360,
      scale: 1,
      selected: 1,
      items: (context) => [
        for (final label in ['One', 'A destination whose name goes on and on and on', 'Three'])
          NavItem(icon: Icons.circle_outlined, selectedIcon: Icons.circle, label: label),
      ],
    );
    final paragraph = labels(tester)['A destination whose name goes on and on and on']!;
    expect(_lines(paragraph), 1);
    expect(paragraph.didExceedMaxLines, isTrue, reason: 'cut short with an ellipsis');
    final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
    expect(rect.width, greaterThan(360 / 3), reason: 'over its neighbours\' hidden labels');
    // Within the room up to its neighbours' icons, centred under its own.
    final icon = tester.getRect(find.byIcon(Icons.circle));
    expect(rect.center.dx, closeTo(icon.center.dx, 0.5));
    for (var i = 0; i < 2; i++) {
      final glyph = tester.getRect(find.byIcon(Icons.circle_outlined).at(i));
      expect(rect.left >= glyph.right || rect.right <= glyph.left, isTrue, reason: 'clear of the icon at $glyph');
    }
  });

  testWidgets("a tablet's rail keeps its labels as they are", (tester) async {
    for (final style in DesignStyle.values) {
      phoneSurface(tester, size: const Size(1280, 800));
      await tester.pumpWidget(harness(
        TestServices(),
        Builder(
          builder: (context) => AdaptiveNavigation(items: tabs(context), selected: 0, onSelected: (_) {}, body: const SizedBox.expand()),
        ),
        style: style,
        textScale: 2,
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(OverflowBox), findsNothing, reason: style.name);
      expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).labelType, isNull, reason: "${style.name}: the theme's");
    }
  });
}

bool _isIcon(Element element) => element.findAncestorWidgetOfExactType<Icon>() != null;

/// How many lines [paragraph] is laid out on.
int _lines(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length))
    .map((box) => box.top.round())
    .toSet()
    .length;
