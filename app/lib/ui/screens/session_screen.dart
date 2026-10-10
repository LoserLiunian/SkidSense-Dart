import 'dart:async';
import 'dart:math' as math;

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
import '../kit/forms.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'cloud_sheets.dart';
import 'host_shell.dart';
import 'models_pane.dart';
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

  /// The models tab, where cloud models are assigned.
  void _openModels() {
    if (!widget.embedded) Navigator.of(context).pop();
    context.showInShell(4);
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
          Composer(
            sessionKey: widget.sessionKey,
            agent: row?.agent ?? '',
            workdir: workdir,
            onSent: _jumpToLatest,
            onOpenModels: state.can('accounts.list') ? _openModels : null,
          ),
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
  /// The model picked from the menu, null for the default — and what its
  /// chip says: the menu's label, not the raw id.
  String? model;
  String? modelLabel;

  /// The account or assignment serving it (`ModelOption.providerId`), sent
  /// with it — kept only from a host that checks it ([_pinning]).
  String? providerId;
  String? effort;
  String? approvalMode;

  /// [label] in place of the option's own (a cloud model's, [cloudModelLabel]).
  void pick(ModelOption? option, {required bool pinning, String? label}) {
    model = option?.id;
    modelLabel = label ?? (option == null || option.label.isEmpty ? option?.id : option.label);
    providerId = pinning ? option?.providerId : null;
  }
}

/// Whether the host takes and checks `turn.prompt`'s `providerId` (spec
/// §6.1). Only then is a pick pinned to its endpoint, and another endpoint's
/// model offered: a host before it would run that model on the default one.
bool _pinning(AppController app) => app.state.welcome?.supports(Features.promptProviderId) ?? false;

/// A model as the menu tells two apart: two accounts serve the same id.
typedef _ModelKey = ({String? providerId, String id});

_ModelKey _keyOf(ModelOption option, bool pinning) => (providerId: pinning ? option.providerId : null, id: option.id);

/// A cloud model as the menu and its chip call it: its id — the heading
/// says it is assigned — and the key's name only where two assignments offer
/// the same id. Its label names the assignment in the computer's words
/// (`{id} · 第一方 · {agent} · {key}`).
String cloudModelLabel(L10n l, ModelOption option, List<ModelOption> offered) {
  if (offered.where((other) => other.id == option.id).length < 2) return option.id;
  final prefix = '${option.id} · ';
  final name = option.label.startsWith(prefix) ? option.label.substring(prefix.length) : option.label;
  final key = cloudAssignmentOf(name)?.key;
  return '${option.id} · ${key == null ? name : assignedKeyName(l, key)}';
}

/// What the menu offers of [catalog].
List<ModelOption> _offered(ModelCatalog catalog, bool pinning) =>
    [for (final option in catalog.models) if (pinning || option.group != 'other') option];

/// Send, steer or stop. `approvalMode` is offered only when the device may
/// approve at all — a device that cannot approve must not be able to turn
/// approval off (spec §7).
///
/// A `/` typed at the start or after a space opens the agent's commands over
/// the input, as on the desktop (`Composer.tsx`): a pick fills in `/name `,
/// and nothing is sent until Send.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.sessionKey,
    required this.agent,
    required this.workdir,
    required this.onSent,
    this.onOpenModels,
  });

  final String sessionKey;
  final String agent;

  /// The session's workspace: where its commands are read.
  final String workdir;
  final VoidCallback onSent;

  /// To the models tab, where cloud models are assigned; null where there
  /// is none.
  final VoidCallback? onOpenModels;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final AppController _app = context.app;
  final TextEditingController _text = TextEditingController();
  late final FocusNode _focus = FocusNode(debugLabel: 'composer', onKeyEvent: _onKey);
  final _SendOptions _options = _SendOptions();
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = true;

  /// The agent's model menu (`models.list`): read when the options open, and
  /// again when the host says the routing or the accounts changed (spec
  /// §6.4) — while they are open, or while a model is picked that the menu
  /// may no longer offer.
  final StateValue<Loaded<ModelCatalog>> _catalog = StateValue<Loaded<ModelCatalog>>(const Loaded<ModelCatalog>());

  /// The agent [_catalog] is current for; null once it may be behind.
  String? _catalogFor;
  int _catalogReads = 0;
  bool _optionsOpen = false;
  StreamSubscription<int>? _modelsChanged;

  /// Where the agent's calls went at the last read: `kind:accountId`.
  String? _route;

  /// The `/` menu. Always up: it draws nothing while there is no menu.
  final OverlayPortalController _slash = OverlayPortalController(debugLabel: 'slash');
  List<SlashCommand> _commands = const [];
  bool _commandsLoading = false;

  /// What the last build made of the text: the command name typed at the
  /// caret, the commands it matches and the one Enter would pick.
  String? _slashQuery;
  List<SlashCommand> _shown = const [];
  int _slashIndex = 0;
  bool _slashOpen = false;

  /// The text the menu was closed on (Esc, a pick): shut until it changes.
  String? _slashClosedOn;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
    _modelsChanged = _app.modelsRevision.changes.listen((_) => _modelsMayHaveChanged());
    _slash.show();
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.agent != widget.agent) {
      // Another agent's menu and pick are not this one's.
      _catalogFor = null;
      _route = null;
      _catalog.value = const Loaded<ModelCatalog>();
      _options.pick(null, pinning: false);
    }
    if (old.agent != widget.agent || old.workdir != widget.workdir) _commands = const [];
  }

  @override
  void dispose() {
    unawaited(_modelsChanged?.cancel());
    unawaited(_catalog.close());
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  // --- models -------------------------------------------------------------------------

  void _modelsMayHaveChanged() {
    _catalogFor = null;
    if (_optionsOpen || _options.model != null) unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    final agent = widget.agent;
    if (agent.isEmpty || _catalogFor == agent) return;
    _catalogFor = agent;
    final read = ++_catalogReads;
    _catalog.value = Loaded<ModelCatalog>(value: _catalog.value.value, loading: true);
    try {
      final catalog = await _app.models(agent);
      if (!mounted || read != _catalogReads) return;
      if (catalog != null) setState(() => _follow(catalog));
      _catalog.value = Loaded<ModelCatalog>(value: catalog);
    } catch (error) {
      if (!mounted || read != _catalogReads) return;
      _catalogFor = null;
      _catalog.value = Loaded<ModelCatalog>(value: _catalog.value.value, error: error);
    }
  }

  /// The pick is kept while the menu still offers it, on the route it was
  /// picked on. A switch of the agent's account (here or anywhere) makes a
  /// pick from the old account's list meaningless — and kept, it would read
  /// as a deliberate pick of the old account: back to the default, as on the
  /// desktop (`SessionPane.tsx`).
  void _follow(ModelCatalog catalog) {
    final route = catalog.route;
    final now = route == null ? null : '${route.kind}:${route.accountId ?? ''}';
    final moved = _route != null && now != null && now != _route;
    if (now != null) _route = now;
    final model = _options.model;
    if (model == null) return;
    final pinning = _pinning(_app);
    final picked = (providerId: _options.providerId, id: model);
    if (moved || !_offered(catalog, pinning).any((option) => _keyOf(option, pinning) == picked)) {
      _options.pick(null, pinning: pinning);
    }
  }

  void _pickModel(ModelOption? option) {
    final catalog = _catalog.value.value;
    final pinning = _pinning(_app);
    final label = option != null && catalog != null && catalog.route?.kind == 'cloud' ? cloudModelLabel(context.l10n, option, _offered(catalog, pinning)) : null;
    if (mounted) setState(() => _options.pick(option, pinning: pinning, label: label));
  }

  // --- sending ------------------------------------------------------------------------

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
        providerId: _options.providerId,
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
    _optionsOpen = true;
    await showAppSheet<void>(context, builder: (_) => _OptionsSheet(
          options: _options,
          catalog: _catalog,
          agent: widget.agent,
          canApprove: _app.state.canScope(Scopes.approve),
          onModel: _pickModel,
          onOpenModels: widget.onOpenModels,
        ));
    _optionsOpen = false;
    if (mounted) setState(() {});
  }

  // --- the `/` menu -------------------------------------------------------------------

  /// Offered by a host that lists the commands (one from before does not),
  /// on a live connection, before a turn runs: what steers it is no command.
  bool _slashOffered(AppState state, bool running) =>
      state.connected &&
      !running &&
      state.canScope(Scopes.prompt) &&
      state.can('commands.list') &&
      widget.agent.isNotEmpty &&
      widget.workdir.isNotEmpty;

  /// The command name being typed at the caret, or null.
  String? _typedCommand() {
    final text = _text.text;
    final selection = _text.selection;
    if (!_focus.hasFocus || text == _slashClosedOn || (selection.isValid && !selection.isCollapsed)) return null;
    return slashQuery(text, selection.isValid ? selection.baseOffset : null);
  }

  /// Read when the menu opens, not on each key: listing them can start the
  /// CLI (spec §7.1). A failure leaves the menu shut and the text as typed.
  Future<void> _loadCommands() async {
    final (agent, workdir) = (widget.agent, widget.workdir);
    setState(() => _commandsLoading = true);
    try {
      final commands = await _app.config.commands(agent, workdir);
      if (mounted && agent == widget.agent && workdir == widget.workdir) setState(() => _commands = commands);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _commandsLoading = false);
    }
  }

  void _pickCommand(SlashCommand command) {
    final selection = _text.selection;
    final next = insertCommand(_text.text, command.name, selection.isValid ? selection.baseOffset : null);
    _slashClosedOn = next.text;
    _text.value = TextEditingValue(text: next.text, selection: TextSelection.collapsed(offset: next.caret));
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  /// ↑ ↓ through the commands, Enter or Tab to pick, Esc to close — the keys
  /// a hardware keyboard has on the desktop.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_slashOpen || (event is! KeyDownEvent && event is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _slashClosedOn = _text.text);
      return KeyEventResult.handled;
    }
    if (_shown.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      setState(() => _slashIndex = stepIndex(_shown.length, _slashIndex, key == LogicalKeyboardKey.arrowDown ? 1 : -1));
      return KeyEventResult.handled;
    }
    final enter = (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) && !HardwareKeyboard.instance.isShiftPressed;
    if (enter || key == LogicalKeyboardKey.tab) {
      _pickCommand(_shown[_slashIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The menu over the composer: inset from its edges, as high as the
  /// window allows up to a few rows.
  static Widget _placeMenu(BuildContext context, OverlayChildLayoutInfo info, Widget? menu) {
    if (menu == null || info.childPaintTransform.determinant() == 0) return const SizedBox.shrink();
    final composer = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final room = composer.top - MediaQuery.paddingOf(context).top - Gap.xl;
    return Positioned(
      left: composer.left + Gap.sm,
      width: composer.width - Gap.sm * 2,
      bottom: info.overlaySize.height - composer.top + Gap.xs,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(kMinInteractiveDimension, math.min(room, 320))),
        child: menu,
      ),
    );
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

        final query = _slashOffered(app.state, running) ? _typedCommand() : null;
        if (query != _slashQuery) _slashIndex = 0;
        if (query != null && _slashQuery == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_loadCommands());
          });
        }
        _slashQuery = query;
        _shown = query == null ? const [] : rankCommands(_commands, query);
        _slashIndex = _shown.isEmpty ? 0 : math.min(_slashIndex, _shown.length - 1);
        // While the first list is on its way the menu says so, rather than
        // appearing a moment after the `/` as if from nowhere.
        _slashOpen = query != null && (_shown.isNotEmpty || (_commandsLoading && _commands.isEmpty));
        final menu = _slashOpen ? _SlashMenu(items: _shown, active: _slashIndex, onPick: _pickCommand) : null;

        final field = TextField(
          controller: _text,
          focusNode: _focus,
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
                if (_options.model != null) _OptionChip(label: _options.modelLabel ?? _options.model!, onTap: _showOptions),
                if (_options.effort != null) _OptionChip(label: l.effortLevel(_options.effort!), onTap: _showOptions),
                if (_options.approvalMode != null) _OptionChip(label: _approvalLabel(l, _options.approvalMode!), onTap: _showOptions),
              ]),
            ),
        ]);
        final Widget bar;
        if (design.expressive) {
          // M3 Expressive: the composer floats, a rounded toolbar over the transcript.
          bar = SafeArea(
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
        } else {
          bar = Material(
            color: colors.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.sm, Gap.sm), child: content),
            ),
          );
        }
        return OverlayPortal.overlayChildLayoutBuilder(
          controller: _slash,
          overlayChildBuilder: (context, info) => _placeMenu(context, info, menu),
          child: bar,
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

/// Where a catalog's calls go, said under the options' heading — as the
/// desktop's model chip says it (`RunPickers.tsx`).
String _routeLine(L10n l, CatalogRoute route) => switch (route.kind) {
      'cloud' => l.composerRouteCloud,
      'account' => l.composerRouteAccount(route.accountName ?? ''),
      'official' => l.composerRouteOfficial,
      _ => l.composerRouteCli,
    };

/// A labelled group of the options sheet.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.below});

  final Widget label;
  final Widget child;
  final Widget? below;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        label,
        const SizedBox(height: Gap.sm),
        child,
        if (below != null) ...[const SizedBox(height: Gap.sm), below!],
      ]);
}

/// What the next prompt goes with: in local mode the agent's account (the
/// computer's setting, for all its conversations), the model — grouped by
/// where it runs, as the desktop's menu — the effort and the approval mode.
class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({
    required this.options,
    required this.catalog,
    required this.agent,
    required this.canApprove,
    required this.onModel,
    required this.onOpenModels,
  });

  final _SendOptions options;
  final StateValue<Loaded<ModelCatalog>> catalog;
  final String agent;
  final bool canApprove;
  final ValueChanged<ModelOption?> onModel;
  final VoidCallback? onOpenModels;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late final AppController _app = context.app;
  void Function()? _unwatch;

  /// A choice sent and not read back yet: shown over the accounts it was
  /// sent over, until they are read again.
  AccountChoice? _sent;
  AccountsSnapshot? _sentOver;
  bool _sending = false;
  String? _accountError;

  @override
  void initState() {
    super.initState();
    // The account menu is current while it shows (spec §6.4).
    if (_app.state.can('accounts.list')) _unwatch = _app.config.watchAccounts();
    // Whether the backend knows `settings` decides why the menu is locked.
    if (_app.state.serverScopes == null) unawaited(_app.loadServerScopes());
  }

  @override
  void dispose() {
    _unwatch?.call();
    super.dispose();
  }

  Future<void> _setAccount(String agent, AccountChoice choice, AccountsSnapshot over) async {
    if (_sending || choice == over.choiceFor(agent)) return;
    final l = context.l10n;
    setState(() {
      _sending = true;
      _sent = choice;
      _sentOver = over;
      _accountError = null;
    });
    try {
      final result = await _app.config.setActive(agent, choice);
      if (mounted && !result.ok) {
        setState(() {
          _sent = null;
          _accountError = result.error ?? l.errUnknown('');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _sent = null;
          _accountError = l.error(error);
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Local mode, an agent that takes an account: which one — the same
  /// setting as the models tab's, made on the computer.
  Widget? _account(BuildContext context, CatalogRoute? route, AccountsSnapshot? snapshot) {
    if (route == null || route.kind == 'cloud' || snapshot == null) return null;
    final harness = snapshot.harnesses.where((candidate) => candidate.agent == widget.agent).firstOrNull;
    if (harness == null) return null;
    final l = context.l10n;
    final state = _app.state;
    final writable = state.can('accounts.setActive') && state.connected;
    final enabled = writable && !_sending;
    final shown = _sent != null && identical(snapshot, _sentOver) ? _sent : snapshot.choiceFor(harness.agent);
    return _Section(
      label: FieldLabel(
        l.composerAccount,
        // Why it cannot be switched from here, as the models tab says it.
        hint: writable
            ? l.composerAccountHint(harness.label.isEmpty ? harness.agent : harness.label)
            : !state.connected
                ? l.offlineTitle
                : settingsReadOnlyReason(l, state),
      ),
      below: _accountError == null ? null : InlineBanner(message: _accountError!, onDismiss: () => setState(() => _accountError = null)),
      child: ChoiceGroup<AccountChoice>(
        items: [
          GroupItem(value: const AccountChoice.cli(), label: l.modelsChoiceCli, enabled: enabled),
          if (harness.official) GroupItem(value: const AccountChoice.official(), label: l.modelsChoiceOfficial, enabled: enabled),
          for (final row in accountsFor(harness, snapshot)) GroupItem(value: AccountChoice.account(row.id), label: row.name, enabled: enabled),
        ],
        selected: shown,
        onSelected: (choice) {
          if (choice != null && enabled) unawaited(_setAccount(harness.agent, choice, snapshot));
        },
      ),
    );
  }

  /// The models, grouped by where they run: in cloud mode only what is
  /// assigned; in local mode the account's (or the CLI's own), then — from a
  /// host that takes it — another endpoint's, for this conversation alone.
  List<Widget> _models(BuildContext context, Loaded<ModelCatalog> loaded) {
    final l = context.l10n;
    final catalog = loaded.value;
    if (catalog == null) {
      return [
        _Section(
          label: FieldLabel(l.model),
          child: loaded.error == null
              ? LoadingRow(l.composerModelsLoading, padding: const EdgeInsets.symmetric(vertical: Gap.xs))
              : Text(l.noModels, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ];
    }
    final pinning = _pinning(_app);
    final offered = _offered(catalog, pinning);
    final route = catalog.route;
    final cloud = route?.kind == 'cloud';
    final options = widget.options;
    final picked = options.model == null ? null : (providerId: options.providerId, id: options.model!);
    final named = route?.defaultModel;
    // On an account and in cloud mode even the default is the host's to
    // decide — the account's main model, the first assigned: say which.
    final byDefault = named != null && named.isNotEmpty && (cloud || route?.kind == 'account') ? l.modelDefaultNamed(named) : l.modelDefault;
    // The account's own models go by their ids — the heading names the account.
    List<GroupItem<_ModelKey?>> itemsOf(List<ModelOption> models, {bool withDefault = false}) => [
          if (withDefault) GroupItem(value: null, label: byDefault),
          for (final option in models)
            GroupItem(
              value: _keyOf(option, pinning),
              label: cloud
                  ? cloudModelLabel(l, option, offered)
                  : option.label.isEmpty || option.group == 'account'
                      ? option.id
                      : option.label,
            ),
        ];
    // One pick over several groups: all of them chips, or — where any one
    // option of any of them would not fit on a chip — all of them rows.
    Widget group(List<GroupItem<_ModelKey?>> items, {List<GroupItem<_ModelKey?>> alongside = const []}) => ChoiceGroup<_ModelKey?>(
          wrap: true,
          items: items,
          alongside: alongside,
          selected: picked,
          onSelected: (key) {
            widget.onModel(key == null ? null : offered.firstWhere((option) => _keyOf(option, pinning) == key));
            setState(() {});
          },
        );

    if (cloud) {
      if (offered.isEmpty) {
        final open = widget.onOpenModels;
        // Inside a sheet, an empty list is a note under its heading, as
        // the sheets' other empty lists are — not a page's empty state.
        return [
          _Section(
            label: FieldLabel(l.composerModelsCloud),
            child: InlineBanner(
              tone: BannerTone.info,
              // Not `cloud_off`: that is a computer out of reach.
              icon: Icons.cloud_queue_outlined,
              title: l.composerCloudEmptyTitle,
              message: l.composerCloudEmptyBody,
              action: open == null
                  ? null
                  : AppButton(
                      label: l.composerOpenModels,
                      icon: Icons.layers_rounded,
                      emphasis: ActionEmphasis.tonal,
                      onPressed: () {
                        Navigator.of(context).pop();
                        open();
                      },
                    ),
            ),
          ),
        ];
      }
      return [_Section(label: FieldLabel(l.composerModelsCloud), child: group(itemsOf(offered, withDefault: true)))];
    }
    final account = route?.kind == 'account';
    final own = itemsOf([for (final option in offered) if (option.group != 'other') option], withDefault: true);
    final others = itemsOf([for (final option in offered) if (option.group == 'other') option]);
    return [
      _Section(
        label: FieldLabel(route == null
            ? l.model
            : account
                ? l.composerModelsAccount(route.accountName ?? '')
                : l.composerModelsCli),
        child: group(own, alongside: others),
      ),
      if (others.isNotEmpty)
        _Section(
          label: FieldLabel(account ? l.composerModelsOtherAccounts : l.composerModelsOtherEndpoints, hint: l.composerModelsOtherHint),
          child: group(others, alongside: own),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final levels = effortLevels(widget.agent);
    final options = widget.options;
    // The connection and the grant decide whether the account can be
    // switched: current while the sheet shows.
    return Watch(_app.states, builder: (context, _) => Watch(widget.catalog, builder: (context, loaded) => Watch(_app.config.accounts, builder: (context, accounts) {
          final route = loaded.value?.route;
          final sections = [
            ?_account(context, route, accounts.value),
            ..._models(context, loaded),
            if (levels.isNotEmpty)
              _Section(
                label: FieldLabel(l.effort),
                child: ChoiceGroup<String?>(
                  items: [
                    GroupItem(value: null, label: l.modelDefault),
                    for (final level in levels) GroupItem(value: level, label: l.effortLevel(level)),
                  ],
                  selected: options.effort,
                  onSelected: (value) => setState(() => options.effort = value),
                ),
              ),
            _Section(
              label: FieldLabel(widget.canApprove ? l.approvalMode : l.approvalModeLocked),
              child: ChoiceGroup<String?>(
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
            ),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Gap.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SheetHeader(l.options, subtitle: route == null ? null : _routeLine(l, route)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final section in sections) ...[section, const SizedBox(height: Gap.xl)],
                  AppButton(label: l.done, expand: true, onPressed: () => Navigator.of(context).pop()),
                ]),
              ),
            ]),
          );
        })));
  }
}

/// What a command's source is called — or, for a command file, where it is
/// kept — as the desktop's menu tags it.
String _commandSource(L10n l, SlashCommand command) => switch (command.scope) {
      'workspace' => l.slashScopeWorkspace,
      'global' => l.slashScopeGlobal,
      _ => switch (command.source) {
          'skill' => l.slashSourceSkill,
          'command' => l.slashSourceCommand,
          _ => l.slashSourceBuiltin,
        },
    };

/// Where a skill listed beside the CLI's own comes from (SkidSense's own
/// go untagged).
const _commandStores = {'claude': 'Claude Code', 'agents': '.agents', 'codex': 'Codex'};

/// The `/` menu over the composer, best match first: each command's name
/// and what it takes, what it does, where it comes from and its other
/// names. Empty while the first list is on its way.
class _SlashMenu extends StatefulWidget {
  const _SlashMenu({required this.items, required this.active, required this.onPick});

  final List<SlashCommand> items;

  /// The one Enter or Tab picks.
  final int active;
  final ValueChanged<SlashCommand> onPick;

  @override
  State<_SlashMenu> createState() => _SlashMenuState();
}

class _SlashMenuState extends State<_SlashMenu> {
  final ScrollController _scroll = ScrollController();
  BuildContext? _activeContext;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SlashMenu old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    // The keys move the highlight: keep it in view, or Enter picks a row
    // nobody sees.
    final down = widget.active > old.active;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(down, retry: true));
  }

  void _reveal(bool down, {required bool retry}) {
    if (!mounted) return;
    final target = _activeContext;
    if (target != null && target.mounted) {
      unawaited(Scrollable.ensureVisible(
        target,
        alignmentPolicy: down ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ));
    } else if (retry && _scroll.hasClients) {
      // Wrapped round to a row not built yet: go to its end first.
      _scroll.jumpTo(widget.active == 0 ? 0 : _scroll.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(down, retry: false));
    }
  }

  Widget _row(BuildContext context, int index) {
    final l = context.l10n;
    final colors = context.colors;
    final command = widget.items[index];
    final active = index == widget.active;
    final quiet = active ? null : colors.onSurfaceVariant;
    final hint = command.argumentHint?.trim() ?? '';
    final description = command.description?.trim() ?? '';
    final meta = [
      _commandSource(l, command),
      ?_commandStores[command.store],
      if (command.aliases.isNotEmpty) l.slashAliases(command.aliases.map((alias) => '/$alias').join(', ')),
    ].join(' · ');
    final tile = ListTile(
      selected: active,
      selectedColor: colors.onSecondaryContainer,
      selectedTileColor: colors.secondaryContainer,
      onTap: () => widget.onPick(command),
      title: Text.rich(TextSpan(children: [
        TextSpan(text: '/${command.name}'),
        if (hint.isNotEmpty) TextSpan(text: '  $hint', style: context.text.bodyMedium?.mono.copyWith(color: quiet)),
      ])),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(meta, style: context.text.bodySmall?.copyWith(color: quiet)),
      ]),
    );
    if (!active) return tile;
    return Builder(builder: (context) {
      _activeContext = context;
      return tile;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = widget.items;
    // M3 Expressive's rows are rounded: inset, so the highlight keeps clear
    // of the panel's corners.
    final inset = context.design.expressive ? Gap.xs : 0.0;
    // Taps keep the input's focus and caret; Tab stays the input's.
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: FloatingPanel(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: items.isEmpty ? l.slashLoading : l.slashCount(items.length),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(Gap.lg + inset, Gap.md, Gap.lg + inset, Gap.xs),
                child: ExcludeSemantics(
                  child: Text(l.slashTitle, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                ),
              ),
              if (items.isEmpty)
                LoadingRow(l.slashLoading, padding: EdgeInsets.fromLTRB(Gap.lg + inset, Gap.sm, Gap.lg + inset, Gap.lg))
              else
                Flexible(
                  child: ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, Gap.sm),
                    itemCount: items.length,
                    itemBuilder: _row,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
