import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:skidsense_app/ui/kit/actions.dart';
import 'package:skidsense_app/ui/kit/containers.dart';
import 'package:skidsense_app/ui/kit/feedback.dart';
import 'package:skidsense_app/ui/kit/forms.dart';
import 'package:skidsense_app/ui/kit/scaffold.dart';
import 'package:skidsense_app/ui/material.dart';
import 'package:skidsense_app/ui/theme/tokens.dart';

import 'support/harness.dart';

/// The kit's own rules, the ones a screen's test would only see by chance:
/// what each component turns into where its usual form would not do.
void main() {
  Future<BuildContext> pump(WidgetTester tester, Widget child, {DesignStyle style = DesignStyle.expressive, Size size = const Size(412, 915)}) async {
    phoneSurface(tester, size: size);
    await tester.pumpWidget(harness(TestServices(), Scaffold(body: child), style: style));
    // Past the theme's change from the last style.
    await tester.pump(const Duration(seconds: 1));
    return tester.element(find.byType(Scaffold));
  }

  group('fields', () {
    // An outline border sets the floating label on its edge, which a filled
    // field without a drawn edge leaves half outside the box.
    testWidgets('in both styles the label floats inside the box; M3 Expressive draws a line only focused or wrong', (tester) async {
      for (final style in DesignStyle.values) {
        final context = await pump(tester, const SizedBox(), style: style);
        final fields = Theme.of(context).inputDecorationTheme;
        expect(fields.border, isA<UnderlineInputBorder>(), reason: style.name);
        if (style == DesignStyle.expressive) {
          final colors = context.colors;
          final radius = BorderRadius.circular(context.design.shapes.large);
          for (final border in [fields.border, fields.enabledBorder, fields.disabledBorder]) {
            expect(border, isA<UnderlineInputBorder>().having((b) => b.borderSide, 'side', BorderSide.none).having((b) => b.borderRadius, 'radius', radius));
          }
          expect((fields.focusedBorder! as UnderlineInputBorder).borderSide, BorderSide(color: colors.primary, width: 2));
          expect((fields.errorBorder! as UnderlineInputBorder).borderSide.color, colors.error);
          expect((fields.focusedErrorBorder! as UnderlineInputBorder).borderSide, BorderSide(color: colors.error, width: 2));
        }
      }
    });

    testWidgets("a select field's value is in the text fields' face", (tester) async {
      final context = await pump(
        tester,
        SelectField<String>(label: 'Group', value: 'a', options: const {'a': 'Picked'}, onChanged: (_) {}),
      );
      final shown = tester.renderObject<RenderParagraph>(find.text('Picked')).text.style!;
      final body = context.text.bodyLarge!;
      expect((shown.fontSize, shown.fontWeight), (body.fontSize, body.fontWeight));
    });

    testWidgets("a form's status line: an icon of its tone a line of its text tall, at any text size; read out as it changes", (tester) async {
      final semantics = tester.ensureSemantics();
      final heights = <double>[];
      for (final scale in [1.0, 2.0]) {
        phoneSurface(tester);
        await tester.pumpWidget(harness(
          TestServices(),
          Scaffold(bottomNavigationBar: FormActionBar(above: const FormStatus('Not saved'), child: AppButton(label: 'Save', onPressed: () {}))),
          textScale: scale,
        ));
        await tester.pump(const Duration(seconds: 1));
        final context = tester.element(find.byType(FormStatus));
        final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
        final line = tester.renderObject<RenderParagraph>(find.text('Not saved'));
        expect(icon.color, context.colors.error);
        expect(line.text.style?.color, context.colors.error);
        expect(line.text.style?.fontSize, context.text.bodySmall?.fontSize, reason: "the bar's face");
        expect(tester.getSize(find.byIcon(Icons.error_outline_rounded)).height, closeTo(line.size.height, 0.5), reason: 'one line, at $scale×');
        heights.add(line.size.height);
        expect(tester.getSemantics(find.byType(FormStatus)), isSemantics(label: 'Not saved', isLiveRegion: true));
      }
      expect(heights.last, closeTo(heights.first * 2, 0.5));
      semantics.dispose();
    });

    testWidgets("a switch heading a card is titled as a card is, above its fields' labels", (tester) async {
      final context = await pump(
        tester,
        Column(children: [
          SwitchRow(title: 'Anthropic', heading: true, value: true, onChanged: (_) {}),
          SwitchRow(title: 'Plain', value: true, onChanged: (_) {}),
        ]),
      );
      TextStyle style(String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!;
      final title = context.text.titleMedium!;
      expect((style('Anthropic').fontSize, style('Anthropic').fontWeight), (title.fontSize, title.fontWeight));
      expect(style('Anthropic').fontSize, greaterThan(context.text.labelLarge!.fontSize!));
      expect(style('Plain').fontWeight, isNot(title.fontWeight));
    });
  });

  group('a choice group', () {
    List<GroupItem<String>> items(List<String> labels) => [for (final label in labels) GroupItem(value: label, label: label)];

    testWidgets('chips while every option fits on one; a list of radio rows once one would be cut off', (tester) async {
      String? picked;
      await pump(
        tester,
        Center(
          child: SizedBox(
            width: 240,
            child: Column(children: [
              ChoiceGroup<String>(wrap: true, items: items(['Never', '7 days']), selected: 'Never', onSelected: (_) {}),
              ChoiceGroup<String>(
                wrap: true,
                items: items(['Short', 'A label far too long for any chip']),
                selected: 'Short',
                onSelected: (value) => picked = value,
              ),
            ]),
          ),
        ),
        style: DesignStyle.material3,
      );
      expect(find.widgetWithText(ChoiceChip, '7 days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Short'), findsNothing, reason: 'the whole group turns, not the one option');
      expect(find.widgetWithText(ListTile, 'A label far too long for any chip'), findsOneWidget);
      expect(tester.getSize(find.widgetWithText(ListTile, 'Short')).height, greaterThanOrEqualTo(48));
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      await tester.tap(find.text('A label far too long for any chip'));
      expect(picked, 'A label far too long for any chip');
    });

    testWidgets('one choice over several groups: all of them rows once an option of any one would not fit a chip', (tester) async {
      final short = items(['Default', 'Opus']);
      final long = items(['An endpoint whose name is far too long for a chip']);
      await pump(
        tester,
        Center(
          child: SizedBox(
            width: 240,
            child: Column(children: [
              ChoiceGroup<String>(wrap: true, items: short, alongside: long, selected: 'Default', onSelected: (_) {}),
              ChoiceGroup<String>(wrap: true, items: long, alongside: short, selected: 'Default', onSelected: (_) {}),
              // Another choice: its own options alone decide.
              ChoiceGroup<String>(wrap: true, items: items(['Low', 'High']), selected: 'Low', onSelected: (_) {}),
            ]),
          ),
        ),
        style: DesignStyle.material3,
      );
      expect(find.widgetWithText(ListTile, 'Opus'), findsOneWidget, reason: 'its own fit, the group beside it does not');
      expect(find.widgetWithText(ListTile, 'An endpoint whose name is far too long for a chip'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'High'), findsOneWidget);
    });

    // A connected group of one fills the width, picked: the look of the
    // page's main action.
    testWidgets('a lone option is a chip in either style; two or more, M3 Expressive connects them', (tester) async {
      for (final style in DesignStyle.values) {
        String? picked;
        await pump(
          tester,
          Column(children: [
            ChoiceGroup<String>(items: items(['Only']), selected: 'Only', onSelected: (value) => picked = value),
            ChoiceGroup<String>(items: items(['Low', 'High']), selected: 'Low', onSelected: (_) {}),
          ]),
          style: style,
        );
        final only = find.widgetWithText(ChoiceChip, 'Only');
        expect(only, findsOneWidget, reason: style.name);
        expect(tester.widget<ChoiceChip>(only).selected, isTrue, reason: style.name);
        expect(tester.getSize(only).width, lessThan(412 / 2), reason: '${style.name}: as wide as its label, not the row');
        expect(find.byType(M3EButtonGroup), style == DesignStyle.expressive ? findsOneWidget : findsNothing, reason: style.name);
        expect(find.widgetWithText(ChoiceChip, 'High'), style == DesignStyle.expressive ? findsNothing : findsOneWidget, reason: style.name);
        await tester.tap(only);
        expect(picked, 'Only', reason: style.name);
      }
    });
  });

  testWidgets('a whole key is broken at the width, every character on screen and as many on a line as fit', (tester) async {
    const key = 'sk-Xq7fJd02nRkVb5Tq9PwYc3LmHa8Ze1UsGs4Nc6Kp0Rt7u2Lw';
    for (final scale in [1.0, 2.0]) {
      phoneSurface(tester, size: const Size(412, 915));
      await tester.pumpWidget(harness(
        TestServices(),
        const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: MonoBlock(key, whole: true))),
        style: DesignStyle.material3,
        textScale: scale,
      ));
      await tester.pump();
      final text = find.descendant(of: find.byType(MonoBlock), matching: find.byType(Text));
      final lines = tester.widget<Text>(text).data!.split('\n');
      expect(lines.join(), key, reason: 'at ${scale}x');
      expect(lines.length, greaterThan(1), reason: 'at ${scale}x');
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: text, matching: find.byType(RichText)));
      // Laid out on just the lines it was broken into: none wrapped again.
      final laid = TextPainter(text: paragraph.text, textDirection: TextDirection.ltr, textScaler: paragraph.textScaler)
        ..layout(maxWidth: paragraph.size.width);
      expect(laid.computeLineMetrics().length, lines.length, reason: 'at ${scale}x');
      laid.dispose();
      final box = tester.getRect(find.byType(MonoBlock));
      expect(tester.getRect(text).right, lessThanOrEqualTo(box.right));
      // Each line but the last full: one more character would not have fit.
      final style = paragraph.text.style;
      for (final (index, line) in lines.indexed.take(lines.length - 1)) {
        final next = lines[index + 1][0];
        final painter = TextPainter(text: TextSpan(text: '$line$next', style: style), textDirection: TextDirection.ltr, textScaler: paragraph.textScaler)
          ..layout();
        expect(painter.width, greaterThan(paragraph.size.width), reason: '"$line" at ${scale}x');
        painter.dispose();
      }
    }
  });

  group('a banner', () {
    Color fill(WidgetTester tester, String label) =>
        tester.widget<Material>(find.descendant(of: find.widgetWithText(FilledButton, label), matching: find.byType(Material)).first).color!;

    testWidgets("a tinted one's action takes its ink; one on the neutral surface keeps the app's", (tester) async {
      final context = await pump(
        tester,
        Column(children: [
          InlineBanner(message: 'Failed', action: AppButton(label: 'Retry', emphasis: ActionEmphasis.tonal, onPressed: () {})),
          InlineBanner(tone: BannerTone.info, message: 'Offline', action: AppButton(label: 'Again', emphasis: ActionEmphasis.tonal, onPressed: () {})),
        ]),
        style: DesignStyle.material3,
      );
      final colors = context.colors;
      expect(fill(tester, 'Retry'), Color.alphaBlend(colors.onErrorContainer.withValues(alpha: 0.12), colors.errorContainer));
      expect(tester.renderObject<RenderParagraph>(find.text('Retry')).text.style!.color, colors.onErrorContainer);
      expect(fill(tester, 'Again'), colors.secondaryContainer);
    });

    testWidgets("its icon and its close button's grow with its text, as a form's status line's do: 20dp at the normal size", (tester) async {
      final banner = <double, (double, double)>{};
      final status = <double, double>{};
      for (final scale in [1.0, 2.0]) {
        phoneSurface(tester);
        await tester.pumpWidget(harness(
          TestServices(),
          Scaffold(
            body: InlineBanner(message: 'Not saved', onDismiss: () {}),
            bottomNavigationBar: FormActionBar(above: const FormStatus('Not saved'), child: AppButton(label: 'Save', onPressed: () {})),
          ),
          textScale: scale,
        ));
        await tester.pump(const Duration(seconds: 1));
        final icons = find.descendant(of: find.byType(InlineBanner), matching: find.byType(Icon));
        banner[scale] = (tester.getSize(icons.first).height, tester.getSize(find.byIcon(Icons.close_rounded)).height);
        status[scale] = tester.getSize(find.descendant(of: find.byType(FormStatus), matching: find.byType(Icon))).height;
        // The close button stays a touch target at any size.
        expect(tester.getSize(find.byType(IconButton)).shortestSide, greaterThanOrEqualTo(48));
      }
      expect(banner[1.0], (20.0, 20.0));
      expect(banner[2.0], (40.0, 40.0));
      expect(status[2.0]! / status[1.0]!, closeTo(2, 0.01), reason: 'the two grow alike');
    });
  });

  testWidgets("a form's status line takes the banners' roles: secondary for what went through", (tester) async {
    phoneSurface(tester);
    await tester.pumpWidget(harness(
      TestServices(),
      Scaffold(bottomNavigationBar: FormActionBar(above: const FormStatus('Saved', tone: BannerTone.success), child: AppButton(label: 'Save', onPressed: () {}))),
    ));
    await tester.pump(const Duration(seconds: 1));
    final colors = tester.element(find.byType(FormStatus)).colors;
    expect(tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded)).color, colors.secondary);
    expect(tester.renderObject<RenderParagraph>(find.text('Saved')).text.style?.color, colors.secondary);
    expect(colors.secondary, isNot(colors.primary));
  });

  testWidgets('a picked card is ringed in the primary colour in M3 Expressive too', (tester) async {
    final context = await pump(
      tester,
      const Row(children: [
        Expanded(child: AppCard(selected: true, child: Text('Local'))),
        Expanded(child: AppCard(selected: false, child: Text('Cloud'))),
      ]),
    );
    ShapeBorder? shape(String text) => tester.widget<Card>(find.widgetWithText(Card, text)).shape;
    expect((shape('Local')! as RoundedRectangleBorder).side, BorderSide(color: context.colors.primary, width: 2));
    expect(shape('Cloud'), isNull, reason: "M3 Expressive's others stay filled");
  });

  testWidgets("in a wide window a page's content and its action bar stay readable, centred under the full-width bar", (tester) async {
    phoneSurface(tester, size: const Size(1280, 800));
    await tester.pumpWidget(harness(
      TestServices(),
      AppPage(
        title: 'Edit account',
        maxContentWidth: AppPage.readableWidth,
        bottom: FormActionBar(
          maxContentWidth: AppPage.readableWidth,
          child: AppButton(label: 'Save', expand: true, onPressed: () {}),
        ),
        slivers: const [SliverToBoxAdapter(child: SizedBox(key: ValueKey('content'), height: 40))],
      ),
      style: DesignStyle.material3,
    ));
    await tester.pump();
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect((content.left, content.width), (280, 720));
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    expect((save.left, save.width), (280 + Gap.lg, 720 - Gap.lg * 2));
    expect(tester.getSize(find.byType(FormActionBar)).width, 1280);
    // The headline over the content, lined up with what is in it — not at
    // the window's edge.
    expect(tester.getRect(find.text('Edit account').last).left, 280 + Gap.lg);
  });

  testWidgets('a page that fills the window keeps its headline at the edge, in either style', (tester) async {
    for (final style in DesignStyle.values) {
      phoneSurface(tester, size: const Size(1280, 800));
      await tester.pumpWidget(harness(
        TestServices(),
        const AppPage(title: 'Sessions', slivers: [SliverToBoxAdapter(child: SizedBox(key: ValueKey('content'), height: 40))]),
        style: style,
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getRect(find.text('Sessions').last).left, Gap.lg, reason: style.name);
      expect(tester.getRect(find.byKey(const ValueKey('content'))).width, 1280);
    }
  });
}
