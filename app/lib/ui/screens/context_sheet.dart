import 'dart:async';
import 'dart:math' as math;

import 'package:skidsense_core/skidsense_core.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/scope.dart';
import '../../state/watch.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'cloud_sheets.dart';

// Token sizes as the desktop's 上下文与自动压缩 shows and reads them
// (`src/shared/model-windows.ts`).

/// 200000 → "200K", 1048576 → "1.05M".
String formatTokenSize(int tokens) {
  String trim(double value, int digits) {
    final text = value.toStringAsFixed(digits);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  if (tokens >= 1000000) return '${trim(tokens / 1000000, 2)}M';
  if (tokens >= 1000) return '${trim(tokens / 1000, 1)}K';
  return '$tokens';
}

/// `180k`, `1m`, `1.5M`, `200000`, `200,000` → tokens; null when it is not a size.
int? parseTokens(String text) {
  final match = RegExp(r'^\s*([\d.,_]+)\s*([km])?\s*$', caseSensitive: false).firstMatch(text);
  if (match == null) return null;
  final number = double.tryParse(match.group(1)!.replaceAll(RegExp('[,_]'), ''));
  if (number == null || !number.isFinite || number <= 0) return null;
  final unit = match.group(2)?.toLowerCase();
  return (unit == 'm' ? number * 1000000 : unit == 'k' ? number * 1000 : number).round();
}

/// The threshold slider runs on a log scale: 10K–5M is a factor of 500,
/// and on a linear track every model's whole window would be its first few
/// per cent. Positions snap to round figures, finer where they are small.
class CompactScale {
  const CompactScale(this.min, this.max);

  final int min;
  final int max;

  static const steps = 1000;

  double get _span => math.log(max / min);

  int clamp(num tokens) => tokens.round().clamp(min, max);

  int toTokens(double position) {
    final raw = min * math.exp(_span * position.clamp(0, steps) / steps);
    final grain = raw < 100000 ? 1000 : raw < 1000000 ? 5000 : 10000;
    return clamp((raw / grain).round() * grain);
  }

  double toPosition(int tokens) => (steps * math.log(clamp(tokens) / min) / _span).roundToDouble();
}

/// Per model, the size past which the context is compacted — and not
/// before (`models.context.list`/`set`): every model an agent of the
/// computer can run, by where it comes from — cloud assignments, local
/// accounts, what each CLI ships with.
class ContextSheet extends StatefulWidget {
  const ContextSheet({super.key});

  @override
  State<ContextSheet> createState() => _ContextSheetState();
}

class _ContextSheetState extends State<ContextSheet> {
  late final AppController _app = context.app;
  late final void Function() _unwatch;

  @override
  void initState() {
    super.initState();
    _unwatch = _app.config.watchContext();
  }

  @override
  void dispose() {
    _unwatch();
    super.dispose();
  }

  Future<void> _save(String key, {Change<int>? compactAt, Change<int>? window}) async {
    try {
      await _app.config.setContext(key, compactAt: compactAt, window: window);
    } catch (error) {
      if (mounted) showMessage(context, context.l10n.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Read as the grant and the connection change, not once: a phone given
    // settings, or gone offline, while the sheet shows.
    return WatchSelect(_app.states, select: (AppState s) => s.can('models.context.set') && s.connected, builder: (context, canSet) {
      return Watch(_app.config.context, builder: (context, loaded) {
        final list = loaded.value;
        final scale = CompactScale(list?.compactMin ?? 10000, list?.compactMax ?? 5000000);
        final groups = <(String, String), List<ModelContextRow>>{};
        for (final row in list?.rows ?? const <ModelContextRow>[]) {
          groups.putIfAbsent((row.group.kind, row.group.id), () => []).add(row);
        }
        const order = {'cloud': 0, 'account': 1, 'cli': 2};
        final sorted = groups.entries.toList()..sort((a, b) => (order[a.key.$1] ?? 3).compareTo(order[b.key.$1] ?? 3));
        return ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: Gap.xl), children: [
          SheetHeader(l.ctxTitle, subtitle: l.ctxHint(formatTokenSize(scale.min), formatTokenSize(scale.max))),
          if (list == null && loaded.error == null) LoadingRow(l.ctxLoading),
          if (list == null && loaded.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.sm),
              child: InlineBanner(
                message: l.error(loaded.error),
                action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, onPressed: _app.config.loadContext),
              ),
            ),
          if (list != null && list.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.sm),
              child: InlineBanner(tone: BannerTone.info, message: l.ctxEmpty),
            ),
          for (final MapEntry(value: rows) in sorted) ...[
            _GroupHeader(rows: rows),
            GroupedList(children: [
              for (final row in rows) _ContextRow(key: ValueKey(row.key), row: row, scale: scale, canSet: canSet, onSave: _save),
            ]),
          ],
        ]);
      });
    });
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.rows});

  final List<ModelContextRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final group = rows.first.group;
    final agents = rows.first.agents;
    // The computer heads a group in its own words: the CLI's and the cloud
    // assignment's are said here in the user's.
    final cloud = group.kind == 'cloud' ? cloudAssignmentOf(group.label) : null;
    final runner = agents.isEmpty ? null : (agents.first.label.isEmpty ? agents.first.agent : agents.first.label);
    final title = switch (group.kind) {
      'cli' when runner != null => l.ctxCliGroup(runner),
      'cloud' when cloud != null => l.ctxCloudGroup(runner ?? cloud.agent, assignedKeyName(l, cloud.key)),
      _ => group.label,
    };
    final by = <String, List<String>>{};
    for (final agent in agents) {
      by.putIfAbsent(agent.support, () => []).add(agent.label.isEmpty ? agent.agent : agent.label);
    }
    final join = l.localeName.startsWith('zh') ? '、' : ', ';
    final support = agents.isEmpty
        ? l.ctxNoAgents
        : [
            for (final kind in const ['native', 'managed', 'unsupported'])
              if (by[kind] != null)
                l.ctxSupportLine(by[kind]!.join(join), switch (kind) {
                  'native' => l.ctxSupportNative,
                  'managed' => l.ctxSupportManaged,
                  _ => l.ctxSupportUnsupported,
                }),
          ].join('\n');
    return SectionHeader(title, hint: support);
  }
}

class _ContextRow extends StatefulWidget {
  const _ContextRow({super.key, required this.row, required this.scale, required this.canSet, required this.onSave});

  final ModelContextRow row;
  final CompactScale scale;
  final bool canSet;
  final Future<void> Function(String key, {Change<int>? compactAt, Change<int>? window}) onSave;

  @override
  State<_ContextRow> createState() => _ContextRowState();
}

/// How wide a row's figure beside its slider is: the widest of the
/// default's word and the sizes the scale stops at — the same in every row,
/// so that the sliders all end in one line.
double _figureWidth(BuildContext context, L10n l, TextStyle? style) {
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final text in [l.ctxDefault, '999.5K', '4.99M']) {
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
      ..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest.ceilToDouble();
}

class _ContextRowState extends State<_ContextRow> {
  /// The threshold while it is dragged; what the computer saved otherwise.
  int? _dragging;

  ModelContextRow get row => widget.row;

  String _source(L10n l) => switch (row.windowSource) {
        'custom' => l.ctxSourceCustom,
        'discovered' => l.ctxSourceDiscovered,
        'preset' => l.ctxSourcePreset,
        'known' => l.ctxSourceKnown,
        'estimate' => l.ctxSourceEstimate,
        final other => other,
      };

  Future<void> _editWindow() async {
    final l = context.l10n;
    final text = await promptText(
      context,
      title: l.ctxEditWindow,
      label: l.ctxWindowField,
      action: l.save,
      initial: formatTokenSize(row.window),
    );
    if (text == null || !mounted) return;
    final value = parseTokens(text);
    if (value == null || value < SettingLimits.windowMin || value > SettingLimits.windowMax) {
      showMessage(context, l.ctxWindowInvalid);
      return;
    }
    await widget.onSave(row.key, window: Change(value));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final scale = widget.scale;
    final compactAt = _dragging ?? row.compactAt;
    final custom = compactAt != null;
    final label = row.modelId.isEmpty ? l.ctxDefaultModel : row.label;
    // Unset, the thumb rests at the window: where the agent compacts on its own.
    final position = scale.toPosition(compactAt ?? row.window);
    final figure = context.text.labelLarge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.xs, Gap.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: row.modelId.isEmpty ? context.text.bodyMedium : context.text.bodyMedium?.mono),
              Text(
                l.ctxWindow(formatTokenSize(row.window), _source(l)),
                style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ]),
          ),
          if (widget.canSet)
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (action) => switch (action) {
                'window' => _editWindow(),
                'window-reset' => widget.onSave(row.key, window: const Change(null)),
                _ => widget.onSave(row.key, compactAt: const Change(null)),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'window', child: Text(l.ctxEditWindow)),
                if (row.windowSource == 'custom') PopupMenuItem(value: 'window-reset', child: Text(l.ctxResetWindow)),
                if (row.compactAt != null) PopupMenuItem(value: 'reset', child: Text(l.ctxReset)),
              ],
            ),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: Row(children: [
            Expanded(
              // Read out as this model's: in a sheet of them, a slider that
              // says only a size leaves which one it is to guess.
              child: MergeSemantics(
                child: Semantics(
                  label: l.ctxSliderLabel(label),
                  child: Slider(
                    value: position,
                    max: CompactScale.steps.toDouble(),
                    // The track lines up with the text above it; the height
                    // stays a full touch target.
                    padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                    // Unset, the thumb only marks the window: quieter.
                    activeColor: custom ? null : colors.outline,
                    thumbColor: custom ? null : colors.outline,
                    semanticFormatterCallback: (value) => formatTokenSize(scale.toTokens(value)),
                    onChanged: widget.canSet ? (value) => setState(() => _dragging = scale.toTokens(value)) : null,
                    // Saved once the drag settles, not on every step of it.
                    onChangeEnd: widget.canSet
                        ? (value) async {
                            final tokens = scale.toTokens(value);
                            await widget.onSave(row.key, compactAt: Change(tokens));
                            if (mounted) setState(() => _dragging = null);
                          }
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Gap.md),
            SizedBox(
              width: _figureWidth(context, l, figure),
              child: Text(
                custom ? formatTokenSize(compactAt) : l.ctxDefault,
                textAlign: TextAlign.end,
                style: figure?.copyWith(color: custom ? colors.primary : colors.onSurfaceVariant),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: Gap.md),
          child: Text(
            [
              custom ? l.ctxCustom(formatTokenSize(compactAt)) : l.ctxDefaultState,
              // Allowed, the window may be the wrong one; said, as until it
              // is corrected the agent compacts when the window fills.
              if (custom && compactAt > row.window) l.ctxOverWindow(formatTokenSize(row.window)),
            ].join(' '),
            style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}
