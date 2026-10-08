import 'dart:convert';

import 'package:skidsense_core/skidsense_core.dart';

import '../describe.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'markdown.dart';

/// One turn: the prompt, then its segments in the order they happened —
/// text, thinking, tool calls, sub-agents, workflows — then what it ended
/// with. A turn with no segments (from an older desktop) reads as text then
/// tools, which is what those turns always were.
class TurnView extends StatelessWidget {
  const TurnView({super.key, required this.snapshot, this.error, this.live = false});

  final TurnSnapshot snapshot;
  final String? error;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final segments = snapshot.segments;
    final children = <Widget>[
      if (snapshot.prompt.trim().isNotEmpty) PromptBubble(snapshot.prompt),
    ];
    if (segments.isEmpty) {
      if (snapshot.reasoning.trim().isNotEmpty) children.add(ThinkingBlock(snapshot.reasoning));
      if (snapshot.text.trim().isNotEmpty) children.add(MarkdownText(snapshot.text));
      if (snapshot.toolCalls.isNotEmpty) children.add(ToolCallList(snapshot.toolCalls));
    } else {
      for (final segment in segments) {
        switch (segment.kind) {
          case 'text':
            final text = _slice(snapshot.text, segment.from, _next(segments, 'text', segment.from));
            if (text.trim().isNotEmpty) children.add(MarkdownText(text));
          case 'thinking':
            final text = _slice(snapshot.reasoning, segment.from, _next(segments, 'thinking', segment.from));
            if (text.trim().isNotEmpty) children.add(ThinkingBlock(text));
          case 'tools':
            final calls = [for (final call in snapshot.toolCalls) if (segment.ids.contains(call.id)) call];
            if (calls.isNotEmpty) children.add(ToolCallList(calls));
          case 'agents':
            for (final agent in snapshot.subAgents) {
              if (segment.ids.contains(agent.id)) children.add(SubAgentTile(agent));
            }
          case 'workflows':
            for (final run in snapshot.workflows) {
              if (segment.ids.contains(run.id)) children.add(WorkflowCard(run));
            }
        }
      }
    }
    final plan = snapshot.plan;
    if (plan != null && plan.steps.isNotEmpty) children.add(PlanCard(plan));
    final jobs = [for (final job in snapshot.backgroundJobs) if (job.status == 'running') job];
    if (jobs.isNotEmpty) {
      children.add(_Note(icon: Icons.schedule_rounded, text: '${l.backgroundTasks}: ${jobs.map((j) => j.label).join(', ')}'));
    }
    for (final steer in snapshot.steers) {
      children.add(_Note(icon: Icons.alt_route_rounded, text: l.steered(steer.text)));
    }
    final compaction = snapshot.compaction;
    if (compaction != null) {
      children.add(_Note(icon: Icons.compress_rounded, text: compaction.trigger == 'auto' ? l.compactedAuto : l.compactedManual));
    }
    final usage = snapshot.usage;
    if (usage != null && !live) {
      final parts = [
        if (usage.contextTokens != null) l.usageContext(formatTokens(usage.contextTokens!)),
        if (usage.outputTokens != null) l.usageOutput(formatTokens(usage.outputTokens!)),
        if ((usage.costUsd ?? 0) > 0) '≈\$${usage.costUsd!.toStringAsFixed(2)}',
      ];
      if (parts.isNotEmpty) children.add(_Note(icon: Icons.data_usage_rounded, text: parts.join(' · ')));
    }
    if (error != null && error!.trim().isNotEmpty) {
      children.add(InlineBanner(message: error!, tone: BannerTone.error));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(height: Gap.md),
        children[index],
      ],
    ]);
  }

  /// A stretch runs to the next segment of the same kind, or to the end.
  static int _next(List<Segment> segments, String kind, int from) {
    for (final segment in segments) {
      if (segment.kind == kind && segment.from > from) return segment.from;
    }
    return 1 << 31;
  }

  static String _slice(String text, int from, int to) =>
      from >= text.length ? '' : text.substring(from, to < text.length ? to : text.length);
}

/// What the user sent.
class PromptBubble extends StatelessWidget {
  const PromptBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final design = context.design;
    final radius = Radius.circular(design.expressive ? design.shapes.largeIncreased : design.shapes.large);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          decoration: BoxDecoration(
            color: design.expressive ? colors.primaryContainer : colors.secondaryContainer,
            borderRadius: BorderRadiusDirectional.only(
              topStart: radius,
              topEnd: radius,
              bottomStart: radius,
              bottomEnd: Radius.circular(design.shapes.extraSmall),
            ),
          ),
          child: SelectableText(
            text,
            style: context.text.bodyMedium?.copyWith(
              color: design.expressive ? colors.onPrimaryContainer : colors.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// The model's reasoning, folded away until asked for.
class ThinkingBlock extends StatefulWidget {
  const ThinkingBlock(this.text, {super.key});

  final String text;

  @override
  State<ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<ThinkingBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final design = context.design;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(design.shapes.medium)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: AnimatedSize(
            duration: design.motion.spatial.duration,
            curve: design.motion.spatial.curve,
            alignment: Alignment.topCenter,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.psychology_alt_outlined, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
                Expanded(child: Text(context.l10n.thinking, style: context.text.labelLarge?.copyWith(color: colors.onSurfaceVariant))),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: design.motion.effects.duration,
                  child: Icon(Icons.expand_more_rounded, color: colors.onSurfaceVariant),
                ),
              ]),
              if (_open) ...[
                const SizedBox(height: Gap.sm),
                SelectableText(
                  widget.text,
                  style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(String status) => switch (status) {
      'ok' || 'done' || 'completed' => Icons.check_circle_rounded,
      'error' || 'failed' => Icons.error_rounded,
      'cancelled' || 'canceled' => Icons.remove_circle_outline_rounded,
      'running' => Icons.play_circle_outline_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };

Color _statusColor(BuildContext context, String status) {
  final colors = context.colors;
  return switch (status) {
    'ok' || 'done' || 'completed' => colors.primary,
    'error' || 'failed' => colors.error,
    'running' => colors.tertiary,
    _ => colors.onSurfaceVariant,
  };
}

/// Tool calls, compact: one row each — status, name, summary. A turn can
/// have dozens; the row opens a sheet with the input and the result.
class ToolCallList extends StatelessWidget {
  const ToolCallList(this.calls, {super.key});

  final List<ToolCall> calls;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final design = context.design;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(design.shapes.medium),
        side: design.expressive ? BorderSide.none : BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var index = 0; index < calls.length; index++) ...[
          if (index > 0) Divider(height: 1, indent: 44, color: colors.outlineVariant.withValues(alpha: 0.5)),
          _ToolRow(calls[index]),
        ],
      ]),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow(this.call);

  final ToolCall call;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final running = call.status == 'running' || call.status == 'pending';
    return InkWell(
      onTap: () => showAppSheet<void>(context, builder: (_) => ToolCallSheet(call)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        child: Row(children: [
          SizedBox(
            width: 20,
            child: running ? const InlineBusy(size: 16) : Icon(_statusIcon(call.status), size: 18, color: _statusColor(context, call.status)),
          ),
          const SizedBox(width: Gap.md),
          Text(call.name, style: context.text.labelLarge),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              call.summary ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.mono.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: colors.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// One tool call in full: its input and its result.
class ToolCallSheet extends StatelessWidget {
  const ToolCallSheet(this.call, {super.key});

  final ToolCall call;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(call.name, subtitle: call.summary),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StatusRow(status: call.status),
            const SizedBox(height: Gap.md),
            ToolIo(label: l.toolInput, value: call.input),
            const SizedBox(height: Gap.md),
            ToolIo(label: l.toolResult, value: call.result),
          ]),
        ),
      ]),
    );
  }
}

class StatusRow extends StatelessWidget {
  const StatusRow({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(_statusIcon(status), size: 18, color: _statusColor(context, status)),
        const SizedBox(width: Gap.sm),
        Text(context.l10n.runState(status), style: context.text.labelLarge),
      ]);
}

/// Everything a tool call's `input`/`result` can be, including the
/// truncated form `{"__truncated":true,"bytes":N,"preview":"…"}`.
class ToolIo extends StatelessWidget {
  const ToolIo({super.key, required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return const SizedBox.shrink();
    final l = context.l10n;
    String heading = label;
    String text;
    if (value is Map && value['__truncated'] == true) {
      final bytes = value['bytes'];
      heading = l.toolTruncated(label, bytes is num ? formatBytes(bytes.toInt()) : '?');
      text = value['preview'] is String ? value['preview'] as String : '';
    } else if (value is String) {
      text = value;
    } else if (value is List && value.every((item) => item is String)) {
      text = value.join('\n');
    } else {
      text = const JsonEncoder.withIndent('  ').convert(value);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
      const SizedBox(height: Gap.xs),
      MonoBlock(text, maxHeight: 360),
    ]);
  }
}

/// A sub-agent: what it was asked, what it is doing, what it found.
class SubAgentTile extends StatefulWidget {
  const SubAgentTile(this.agent, {super.key});

  final SubAgent agent;

  @override
  State<SubAgentTile> createState() => _SubAgentTileState();
}

class _SubAgentTileState extends State<SubAgentTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final agent = widget.agent;
    final colors = context.colors;
    final design = context.design;
    final running = agent.status == 'running';
    return Material(
      color: colors.tertiaryContainer.withValues(alpha: design.expressive ? 0.6 : 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(design.shapes.medium)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: AnimatedSize(
            duration: design.motion.spatial.duration,
            curve: design.motion.spatial.curve,
            alignment: Alignment.topCenter,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                running
                    ? const InlineBusy(size: 18)
                    : Icon(_statusIcon(agent.status), size: 18, color: _statusColor(context, agent.status)),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    agent.description ?? agent.kind ?? l.subAgent,
                    style: context.text.labelLarge?.copyWith(color: colors.onTertiaryContainer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (agent.durationMs != null)
                  Text('${(agent.durationMs! / 1000).round()}s', style: context.text.labelSmall),
              ]),
              if (agent.activity?.trim().isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Text(agent.activity!, style: context.text.bodySmall, maxLines: _open ? null : 1),
                ),
              if (_open) ...[
                if (agent.prompt != null) ...[const SizedBox(height: Gap.md), ToolIo(label: l.subAgentTask, value: agent.prompt)],
                if (agent.text?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: Gap.md),
                  ToolIo(label: l.subAgentLatest, value: agent.text),
                ],
                if (agent.report != null) ...[const SizedBox(height: Gap.md), ToolIo(label: l.subAgentReport, value: agent.report)],
                if (agent.toolCalls.isNotEmpty) ...[
                  const SizedBox(height: Gap.md),
                  ToolCallList(agent.toolCalls.take(30).toList()),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class WorkflowCard extends StatelessWidget {
  const WorkflowCard(this.run, {super.key});

  final WorkflowRun run;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.account_tree_outlined, size: 18, color: context.colors.primary),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(run.name ?? run.summary ?? l.workflow, style: context.text.titleSmall)),
          StatusBadge(l.runState(run.status), tone: _tone(run.status)),
        ]),
        for (final phase in run.phases)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Row(children: [
              Icon(_statusIcon(phase.status), size: 16, color: _statusColor(context, phase.status)),
              const SizedBox(width: Gap.sm),
              Expanded(child: Text(phase.title, style: context.text.bodySmall)),
            ]),
          ),
        for (final agent in run.agents.take(12))
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 24),
            child: Text('${agent.label} · ${l.runState(agent.status)}', style: context.text.bodySmall),
          ),
        if (run.result?.trim().isNotEmpty ?? false) ...[const SizedBox(height: Gap.sm), MonoBlock(run.result!, maxHeight: 200)],
      ]),
    );
  }
}

StatusTone _tone(String status) => switch (runTone(status)) {
      RunTone.running => StatusTone.running,
      RunTone.waiting => StatusTone.waiting,
      RunTone.done => StatusTone.done,
      RunTone.failed => StatusTone.failed,
      RunTone.neutral => StatusTone.neutral,
    };

class PlanCard extends StatelessWidget {
  const PlanCard(this.plan, {super.key});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.plan, style: context.text.titleSmall),
        if (plan.explanation?.trim().isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(plan.explanation!, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ),
        const SizedBox(height: Gap.sm),
        for (final step in plan.steps)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                switch (step.status) {
                  'completed' => Icons.check_circle_rounded,
                  'in_progress' => Icons.timelapse_rounded,
                  _ => Icons.radio_button_unchecked_rounded,
                },
                size: 18,
                color: step.status == 'completed'
                    ? colors.primary
                    : step.status == 'in_progress'
                        ? colors.tertiary
                        : colors.outline,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  step.text,
                  style: context.text.bodyMedium?.copyWith(
                    decoration: step.status == 'completed' ? TextDecoration.lineThrough : null,
                    color: step.status == 'completed' ? colors.onSurfaceVariant : null,
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurfaceVariant;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: Gap.sm),
      Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: color))),
    ]);
  }
}

/// What the turn is doing right now, in one line.
class ActivityLine extends StatelessWidget {
  const ActivityLine(this.snapshot, {super.key});

  final TurnSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    SubAgent? agent;
    for (final candidate in snapshot.subAgents.reversed) {
      if (candidate.status == 'running' && candidate.background != true) {
        agent = candidate;
        break;
      }
    }
    ToolCall? tool;
    for (final candidate in snapshot.toolCalls.reversed) {
      if (candidate.status == 'running' || candidate.status == 'pending') {
        tool = candidate;
        break;
      }
    }
    final text = agent != null
        ? '${context.l10n.subAgent} ${agent.kind ?? ''}${agent.description == null ? '' : ': ${agent.description}'}'
        : tool != null
            ? (tool.summary ?? tool.name)
            : snapshot.activity;
    return Row(children: [
      const InlineBusy(size: 20),
      const SizedBox(width: Gap.md),
      Expanded(
        child: Text(
          text?.trim().isNotEmpty ?? false ? text! : context.l10n.runState(snapshot.phase),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ),
    ]);
  }
}
