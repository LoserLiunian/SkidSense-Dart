import 'dart:async';

import 'package:flutter/services.dart';
import 'package:skidsense_core/skidsense_core.dart';

import '../../platform/device.dart';
import '../../state/scope.dart';
import '../../state/watch.dart';
import '../../l10n/gen/app_localizations.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';
import 'terminal_screen.dart';
import 'transcript.dart';

/// One session: the transcript with live patches as they arrive, the
/// approval card when the agent is waiting, and the composer.
///
/// Everything that needs a scope is hidden or explained when the device
/// lacks it — and the scopes that count are the host's
/// `welcome.device.scopes`, the grant already capped by the host (§8.3).
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.sessionKey,
    required this.onOpenFiles,
    required this.onOpenGit,
    this.embedded = false,
  });

  final String sessionKey;
  final ValueChanged<String> onOpenFiles;
  final ValueChanged<String> onOpenGit;

  /// Shown beside the list on a wide window, not as its own route.
  final bool embedded;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  OpenSessionResponse? _opened;
  bool _loading = true;
  Object? _error;
  StreamSubscription<AppState>? _connection;
  bool _wasConnected = false;
  late final AppController _app;
  final ScrollController _scroll = ScrollController();
  bool _awayFromLatest = false;

  @override
  void initState() {
    super.initState();
    _app = context.app;
    _wasConnected = _app.state.connected;
    if (_wasConnected) unawaited(_open());
    // Opened when the line comes up — or again after it comes back.
    _connection = _app.states.changes.listen((state) {
      if (state.connected && !_wasConnected) unawaited(_open());
      _wasConnected = state.connected;
    });
    _scroll.addListener(() {
      final away = _scroll.hasClients && _scroll.offset > 400;
      if (away != _awayFromLatest) setState(() => _awayFromLatest = away);
    });
  }

  @override
  void dispose() {
    unawaited(_connection?.cancel());
    _scroll.dispose();
    // Leaving drops what this session staged (S29), and stops following it.
    unawaited(_app.detachAll(widget.sessionKey));
    if (_app.openSessionKey == widget.sessionKey) unawaited(_app.closeSession());
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opened = await _app.openSession(widget.sessionKey);
      if (!mounted) return;
      setState(() {
        _opened = opened;
        if (opened == null) _error = 'not-found';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _jumpToLatest() {
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0, duration: context.design.motion.spatial.duration, curve: context.design.motion.spatial.curve));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final row = _opened?.row;
    final title = (row?.title.isNotEmpty ?? false) ? row!.title : widget.sessionKey;
    final workdir = row?.workdir ?? '';
    return WatchSelect(_app.states, select: (AppState s) => (s.connected, s.welcome), builder: (context, value) {
      final state = _app.state;
      final canFiles = state.canScope(Scopes.files) && workdir.isNotEmpty;
      final canGit = state.canScope(Scopes.git) && workdir.isNotEmpty;
      final canTerminal = state.canScope(Scopes.terminal);
      return FixedPage(
        title: title,
        subtitle: const ConnectionSubtitle(),
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          PopupMenuButton<String>(
            tooltip: l.more,
            onSelected: (value) {
              switch (value) {
                case 'files':
                  if (widget.embedded) {
                    widget.onOpenFiles(workdir);
                  } else {
                    Navigator.of(context).pop();
                    context.showInShell(1, root: workdir);
                  }
                case 'git':
                  if (widget.embedded) {
                    widget.onOpenGit(workdir);
                  } else {
                    Navigator.of(context).pop();
                    context.showInShell(2, root: workdir);
                  }
                case 'terminal':
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TerminalScreen(sessionKey: widget.sessionKey)));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'files', enabled: canFiles, child: ListTile(leading: const Icon(Icons.folder_outlined), title: Text(l.openFiles))),
              PopupMenuItem(value: 'git', enabled: canGit, child: ListTile(leading: const Icon(Icons.merge_type_rounded), title: Text(l.openGit))),
              PopupMenuItem(
                value: 'terminal',
                enabled: canTerminal,
                child: ListTile(leading: const Icon(Icons.terminal_rounded), title: Text(l.openTerminal)),
              ),
            ],
          ),
        ],
        body: LayoutBuilder(builder: (context, body) => Column(children: [
          if (!state.connected) const OfflineCard(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              child: InlineBanner(
                message: _error == 'not-found' ? l.sessionNotFound : l.error(_error),
                onDismiss: () => setState(() => _error = null),
              ),
            ),
          Expanded(
            child: Stack(children: [
              Watch(_app.liveRevision, builder: (context, _) => _transcript(context)),
              if (_loading && _opened == null) Center(child: BusyIndicator(semanticsLabel: l.openingSession)),
              if (_awayFromLatest)
                Positioned(
                  bottom: Gap.md,
                  right: Gap.lg,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: l.jumpToLatest,
                    onPressed: _jumpToLatest,
                    child: const Icon(Icons.arrow_downward_rounded),
                  ),
                ),
            ]),
          ),
          // Its natural height when it fits; never more than 45% of the
          // screen, scrolling inside, so the transcript and the composer
          // keep their room at large text sizes.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: body.maxHeight * 0.45),
            child: Watch(_app.liveRevision, builder: (context, _) {
            final interaction = _app.liveTurn.snapshot?.openInteraction;
            return AnimatedSwitcher(
              duration: context.design.motion.spatial.duration,
              switchInCurve: context.design.motion.spatial.curve,
              transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, alignment: Alignment.bottomCenter, child: child),
              child: interaction == null
                  ? const SizedBox.shrink()
                  : ApprovalCard(
                      key: ValueKey(interaction.id),
                      interaction: interaction,
                      sessionKey: widget.sessionKey,
                      canApprove: state.canScope(Scopes.approve),
                    ),
            );
          }),
          ),
          Composer(sessionKey: widget.sessionKey, agent: row?.agent ?? '', onSent: _jumpToLatest),
        ])),
      );
    });
  }

  /// Finished turns never change: the same widget each time lets the
  /// framework skip them while the live turn streams (theme and locale
  /// changes still reach them through their dependencies).
  final Expando<Widget> _recordViews = Expando();

  Widget _transcript(BuildContext context) {
    final records = _app.liveTurn.history;
    final live = _app.liveTurn.snapshot;
    final showLive = live != null && !records.any((record) => record.taskId == live.taskId && live.taskId.isNotEmpty);
    // Newest first in a reversed list: the bottom is where a chat lives, and
    // a growing reply stays in view while the reader is there.
    final items = <Widget>[
      if (live != null && live.running)
        Padding(padding: const EdgeInsets.only(top: Gap.md), child: ActivityLine(live)),
      if (showLive) TurnView(snapshot: live, error: live.error, live: live.running),
      for (final record in records.reversed) _recordViews[record] ??= TurnView(snapshot: record.snapshot, error: record.error),
    ];
    return ListView.separated(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
      itemCount: items.length,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 && live?.running == true ? Gap.sm : Gap.xxl),
      itemBuilder: (_, index) => items[index],
    );
  }
}

/// The question the agent is waiting on (spec §6.2, `Interaction`). The
/// choices are the agent's own, in its order; `allow` kinds lead and deny
/// kinds are drawn as such; free text only when the question allows it.
class ApprovalCard extends StatefulWidget {
  const ApprovalCard({super.key, required this.interaction, required this.sessionKey, required this.canApprove});

  final Interaction interaction;
  final String sessionKey;
  final bool canApprove;

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  final TextEditingController _answer = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final colors = context.colors;
    final design = context.design;
    final question = widget.interaction.question;
    final subject = question.subject;
    final id = widget.interaction.id;
    final heading = switch (question.kind) {
      'permission' => l.approvalPermission,
      'question' => l.approvalQuestion,
      'input' => l.approvalInput,
      _ => l.approvalOther,
    };
    final choices = question.choices;
    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.sm),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(design.expressive ? design.shapes.extraLarge : design.shapes.large),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.front_hand_outlined, color: colors.onTertiaryContainer),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(heading, style: context.text.titleMedium?.copyWith(color: colors.onTertiaryContainer)),
                if (question.allowFreeText) ...[
                  const SizedBox(height: Gap.xs),
                  StatusBadge(l.approvalFreeText, tone: StatusTone.waiting),
                ],
              ]),
            ),
          ]),
          if (question.title.trim().isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            Text(question.title, style: context.text.bodyLarge?.copyWith(color: colors.onTertiaryContainer)),
          ],
          if (question.detail?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: Gap.xs),
            Text(question.detail!, style: context.text.bodyMedium?.copyWith(color: colors.onTertiaryContainer)),
          ],
          if (subject != null) ...[
            const SizedBox(height: Gap.md),
            switch (subject.type) {
              'command' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MonoBlock(subject.command ?? ''),
                  if (subject.cwd?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: Text(l.approvalCwd(subject.cwd!), style: context.text.bodySmall),
                    ),
                ]),
              'fileChange' => MonoBlock(subject.diff ?? subject.path ?? '', spans: _diffSpans(context, subject.diff)),
              'permissions' => Text(l.approvalScopes(subject.scopes.join(', ')), style: context.text.bodyMedium),
              _ => ToolIo(label: subject.name ?? l.toolInput, value: subject.input),
            },
          ],
          const SizedBox(height: Gap.lg),
          if (!widget.canApprove)
            InlineBanner(message: l.approvalNoPermission, tone: BannerTone.info)
          else ...[
            if (_error != null) ...[
              InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
              const SizedBox(height: Gap.md),
            ],
            if (choices.isEmpty)
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: l.allow,
                    icon: Icons.check_rounded,
                    expand: true,
                    busy: _busy,
                    onPressed: () => _run(() => app.selectChoice(widget.sessionKey, id, 'allow')),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: AppButton(
                    label: l.deny,
                    emphasis: ActionEmphasis.outlined,
                    destructive: true,
                    expand: true,
                    onPressed: _busy ? null : () => _run(() => app.selectChoice(widget.sessionKey, id, 'deny')),
                  ),
                ),
              ])
            else
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final choice in choices) ...[
                  AppButton(
                    label: choice.label,
                    expand: true,
                    emphasis: switch (choice.kind) {
                      'allow' => ActionEmphasis.primary,
                      'allow_always' => ActionEmphasis.tonal,
                      'deny' || 'deny_always' => ActionEmphasis.outlined,
                      _ => ActionEmphasis.tonal,
                    },
                    destructive: choice.kind.startsWith('deny'),
                    onPressed: _busy ? null : () => _run(() => app.selectChoice(widget.sessionKey, id, choice.id)),
                  ),
                  if (choice.description?.trim().isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
                      child: Text(choice.description!, style: context.text.bodySmall?.copyWith(color: colors.onTertiaryContainer)),
                    ),
                  const SizedBox(height: Gap.sm),
                ],
              ]),
            if (question.allowFreeText) ...[
              const SizedBox(height: Gap.sm),
              TextField(
                controller: _answer,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: question.placeholder ?? l.answerPlaceholder),
              ),
              const SizedBox(height: Gap.sm),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                ValueListenableBuilder(
                  valueListenable: _answer,
                  builder: (context, value, _) => AppButton(
                    label: l.sendAnswer,
                    icon: Icons.send_rounded,
                    onPressed: value.text.trim().isEmpty || _busy
                        ? null
                        : () => _run(() => app.answerText(widget.sessionKey, id, value.text.trim())),
                  ),
                ),
                AppButton(
                  label: l.skip,
                  emphasis: ActionEmphasis.outlined,
                  onPressed: _busy ? null : () => _run(() => app.skipQuestion(widget.sessionKey, id)),
                ),
                AppButton(
                  label: l.cancelTurn,
                  emphasis: ActionEmphasis.quiet,
                  destructive: true,
                  onPressed: _busy ? null : () => _run(() => app.cancelQuestion(widget.sessionKey, id)),
                ),
              ]),
            ],
          ],
        ]),
      ),
    );
  }

  static List<InlineSpan>? _diffSpans(BuildContext context, String? diff) {
    if (diff == null) return null;
    final colors = context.colors;
    return [
      for (final line in diff.split('\n'))
        TextSpan(
          text: '$line\n',
          style: TextStyle(
            color: line.startsWith('+') && !line.startsWith('+++')
                ? colors.primary
                : line.startsWith('-') && !line.startsWith('---')
                    ? colors.error
                    : line.startsWith('@@')
                        ? colors.tertiary
                        : null,
          ),
        ),
    ];
  }
}

/// The send options chosen for the next prompt.
class _SendOptions {
  String? model;
  String? effort;
  String? approvalMode;
}

/// Send, steer or stop. `approvalMode` is offered only when the device may
/// approve at all — a device that cannot approve must not be able to turn
/// approval off (spec §7).
class Composer extends StatefulWidget {
  const Composer({super.key, required this.sessionKey, required this.agent, required this.onSent});

  final String sessionKey;
  final String agent;
  final VoidCallback onSent;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _text = TextEditingController();
  final _SendOptions _options = _SendOptions();
  ModelCatalog? _catalog;
  String? _catalogFor;
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = true;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (widget.agent.isEmpty || _catalogFor == widget.agent) return;
    _catalogFor = widget.agent;
    try {
      final catalog = await context.app.models(widget.agent);
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {}
  }

  void _say(String message, {bool error = true}) => setState(() {
        _notice = message;
        _noticeIsError = error;
      });

  Future<void> _send() async {
    final l = context.l10n;
    final app = context.app;
    final text = _text.text.trim();
    if (text.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final outcome = await app.prompt(
        widget.sessionKey,
        text,
        model: _options.model,
        effort: _options.effort,
        approvalMode: _options.approvalMode,
      );
      if (!mounted) return;
      switch (outcome) {
        case PromptAccepted():
          _text.clear();
          widget.onSent();
        case PromptRefused(:final reason):
          _say(reason == null
              ? l.promptRefusedPlain
              : l.promptRefused(reason is String ? reason : l.error(reason)));
        case PromptUncertain(:final droppedAttachments):
          _say(droppedAttachments ? l.promptUncertainDropped : l.promptUncertain);
        case PromptBlocked(:final error):
          _say(l.error(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _steer() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.app.steer(widget.sessionKey, text);
      _text.clear();
    } catch (error) {
      if (mounted) _say(context.l10n.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    final l = context.l10n;
    final app = context.app;
    try {
      final picked = await pickFile();
      if (picked == null || !mounted) return;
      await app.attach(picked.name, picked.mimeType, picked.bytes, sessionKey: widget.sessionKey);
    } catch (error) {
      if (mounted) _say(l.error(error));
    }
  }

  Future<void> _showOptions() async {
    unawaited(_loadCatalog());
    await showAppSheet<void>(context, builder: (_) => _OptionsSheet(
          options: _options,
          catalog: () => _catalog,
          agent: widget.agent,
          canApprove: context.app.state.canScope(Scopes.approve),
          reload: _loadCatalog,
        ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final design = context.design;
    final colors = context.colors;
    return WatchSelect(app.states, select: (AppState s) => (s.canScope(Scopes.prompt), s.can('turn.prompt'), s.connected),
        builder: (context, permissions) {
      final (canPrompt, canCall, connected) = permissions;
      if (!canPrompt || (!canCall && app.state.welcome != null)) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(l.noPromptPermission, style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          ),
        );
      }
      return Watch(app.liveRevision, builder: (context, _) {
        final running = app.liveTurn.snapshot?.running ?? false;
        final hasText = _text.text.trim().isNotEmpty;
        final field = TextField(
          controller: _text,
          minLines: 1,
          maxLines: 6,
          enabled: connected,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: running ? l.steerHint : l.messageHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
          ),
        );
        final actions = running
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton.filledTonal(
                  tooltip: l.stop,
                  onPressed: () => app.stopTurn(widget.sessionKey),
                  icon: const Icon(Icons.stop_rounded),
                ),
                const SizedBox(width: Gap.xs),
                AppButton(label: l.steer, icon: Icons.alt_route_rounded, busy: _busy, onPressed: hasText && connected ? _steer : null),
              ])
            : SendButton(
                label: l.send,
                busy: _busy,
                onSend: hasText && connected ? _send : null,
                menuTooltip: l.composerOptions,
                menu: [
                  SendMenuItem(value: 'attach', label: l.attach, icon: Icons.attach_file_rounded),
                  SendMenuItem(value: 'options', label: l.options, icon: Icons.tune_rounded),
                ],
                onMenu: (value) => value == 'attach' ? _attach() : _showOptions(),
              );
        final content = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: InlineBanner(
                message: _notice!,
                tone: _noticeIsError ? BannerTone.warning : BannerTone.info,
                onDismiss: () => setState(() => _notice = null),
              ),
            ),
          Watch(app.uploads.drafts, builder: (context, drafts) {
            final mine = [for (final d in drafts) if (d.sessionKey == null || d.sessionKey == widget.sessionKey) d];
            if (mine.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
                for (final draft in mine)
                  InputChip(
                    avatar: draft.progress < 1
                        ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(value: draft.progress, strokeWidth: 2))
                        : const Icon(Icons.description_outlined, size: 18),
                    label: Text('${draft.name} · ${formatBytes(draft.size)}', overflow: TextOverflow.ellipsis),
                    onDeleted: () => app.detach(draft.id),
                    deleteButtonTooltipMessage: l.remove,
                  ),
              ]),
            );
          }),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Padding(padding: const EdgeInsets.only(bottom: Gap.sm), child: field)),
            const SizedBox(width: Gap.sm),
            actions,
          ]),
          if (_options.model != null || _options.effort != null || _options.approvalMode != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Wrap(spacing: Gap.xs, children: [
                if (_options.model != null) _OptionChip(label: _options.model!, onTap: _showOptions),
                if (_options.effort != null) _OptionChip(label: l.effortLevel(_options.effort!), onTap: _showOptions),
                if (_options.approvalMode != null) _OptionChip(label: _approvalLabel(l, _options.approvalMode!), onTap: _showOptions),
              ]),
            ),
        ]);
        if (design.expressive) {
          // M3 Expressive: the composer floats, a rounded toolbar over the transcript.
          return SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.sm),
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(design.shapes.extraLarge),
                boxShadow: [BoxShadow(color: colors.shadow.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: content,
            ),
          );
        }
        return Material(
          color: colors.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm), child: content),
          ),
        );
      });
    });
  }
}

String _approvalLabel(L10n l, String mode) => switch (mode) {
      'acceptEdits' => l.approvalAcceptEdits,
      'plan' => l.approvalPlan,
      'dontAsk' => l.approvalDontAsk,
      'bypassPermissions' => l.approvalBypass,
      _ => l.approvalDefault,
    };

class _OptionChip extends StatelessWidget {
  const _OptionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.options, required this.catalog, required this.agent, required this.canApprove, required this.reload});

  final _SendOptions options;
  final ModelCatalog? Function() catalog;
  final String agent;
  final bool canApprove;
  final Future<void> Function() reload;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.reload().then((_) {
      if (mounted) setState(() {});
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = widget.catalog();
    final levels = effortLevels(widget.agent);
    final options = widget.options;
    final account = catalog?.route?.accountName;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(l.options),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(account == null ? l.model : l.modelAccount(account), style: context.text.labelLarge),
            const SizedBox(height: Gap.sm),
            if (catalog == null || catalog.models.isEmpty)
              Text(l.noModels, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))
            else
              ChoiceGroup<String?>(
                items: [
                  GroupItem(value: null, label: l.modelDefault),
                  for (final model in catalog.models) GroupItem(value: model.id, label: model.label.isEmpty ? model.id : model.label),
                ],
                selected: options.model,
                onSelected: (value) => setState(() => options.model = value),
              ),
            if (levels.isNotEmpty) ...[
              const SizedBox(height: Gap.xl),
              Text(l.effort, style: context.text.labelLarge),
              const SizedBox(height: Gap.sm),
              ChoiceGroup<String?>(
                items: [
                  GroupItem(value: null, label: l.modelDefault),
                  for (final level in levels) GroupItem(value: level, label: l.effortLevel(level)),
                ],
                selected: options.effort,
                onSelected: (value) => setState(() => options.effort = value),
              ),
            ],
            const SizedBox(height: Gap.xl),
            Text(widget.canApprove ? l.approvalMode : l.approvalModeLocked, style: context.text.labelLarge),
            const SizedBox(height: Gap.sm),
            ChoiceGroup<String?>(
              items: [
                GroupItem(value: null, label: l.approvalDefault),
                if (widget.canApprove) ...[
                  GroupItem(value: 'acceptEdits', label: l.approvalAcceptEdits),
                  GroupItem(value: 'plan', label: l.approvalPlan),
                  GroupItem(value: 'dontAsk', label: l.approvalDontAsk),
                  GroupItem(value: 'bypassPermissions', label: l.approvalBypass),
                ],
              ],
              selected: options.approvalMode,
              onSelected: (value) => setState(() => options.approvalMode = value),
            ),
            const SizedBox(height: Gap.xl),
            AppButton(label: l.done, expand: true, onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
      ]),
    );
  }
}
