import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../state/scope.dart';
import '../../state/watch.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../layout/window.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';
import 'session_screen.dart';

/// Every session in the computer's workspaces, newest first, with live
/// status. On a wide window the list sits beside the open session.
class SessionsPane extends StatefulWidget {
  const SessionsPane({super.key, required this.onOpenFiles, required this.onOpenGit});

  final ValueChanged<String> onOpenFiles;
  final ValueChanged<String> onOpenGit;

  @override
  State<SessionsPane> createState() => _SessionsPaneState();
}

class _SessionsPaneState extends State<SessionsPane> {
  final TextEditingController _query = TextEditingController();
  Timer? _searchDelay;
  String? _selected;

  @override
  void dispose() {
    _searchDelay?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String query) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 300), () => context.app.searchSessions(query));
  }

  void _open(BuildContext context, SessionRow row) {
    if (WindowClass.of(context).isExpanded) {
      setState(() => _selected = row.key);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SessionScreen(sessionKey: row.key, onOpenFiles: widget.onOpenFiles, onOpenGit: widget.onOpenGit),
    ));
  }

  Future<void> _newSession() async {
    final row = await showAppSheet<SessionRow>(context, builder: (_) => const _NewSessionSheet());
    if (row != null && mounted) _open(context, row);
  }

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    final list = _list(context);
    if (!window.isExpanded) return list;
    final selected = _selected;
    return Row(children: [
      SizedBox(width: 400, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: selected == null
            ? Center(
                child: EmptyState(icon: Icons.forum_outlined, title: context.l10n.tabSessions, body: context.l10n.noSessionsBody),
              )
            : SessionScreen(
                key: ValueKey(selected),
                sessionKey: selected,
                embedded: true,
                onOpenFiles: widget.onOpenFiles,
                onOpenGit: widget.onOpenGit,
              ),
      ),
    ]);
  }

  Widget _list(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    return Watch(app.states, builder: (context, state) {
      final canPrompt = state.canScope(Scopes.prompt);
      final workspaceNames = {for (final w in state.workspaces) w.path: w.name.isEmpty ? w.path : w.name};
      final sessions = [...state.sessions]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return AppPage(
        title: hostTitle(context),
        subtitle: const ConnectionSubtitle(),
        leading: WindowClass.of(context).isCompact
            ? IconButton(
                tooltip: l.backToComputers,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [settingsAction(context)],
        onRefresh: state.connected ? app.loadSessions : null,
        floatingActionButton: canPrompt && state.connected && state.workspaces.isNotEmpty
            ? AppFab(actions: [FabAction(icon: Icons.add_comment_outlined, label: l.newSession, onPressed: _newSession)])
            : null,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
              child: SearchBar(
                controller: _query,
                hintText: l.searchSessions,
                leading: const Icon(Icons.search_rounded),
                elevation: const WidgetStatePropertyAll(0),
                onChanged: _search,
                trailing: [
                  if (_query.text.isNotEmpty)
                    IconButton(
                      tooltip: l.clear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _query.clear();
                        _search('');
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
          if (!state.connected) const SliverToBoxAdapter(child: OfflineCard()),
          if (state.notice != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                child: InlineBanner(message: l.notice(state.notice!), onDismiss: app.clearNotice),
              ),
            ),
          if (state.sessionsError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                child: InlineBanner(message: l.error(state.sessionsError), onDismiss: app.clearNotice),
              ),
            ),
          if (state.sessionsLoading && sessions.isEmpty) SliverToBoxAdapter(child: LoadingRow(l.loadingSessions)),
          if (sessions.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: Gap.sm),
              sliver: SliverToBoxAdapter(
                child: GroupedList(children: [
                  for (final row in sessions)
                    _SessionTile(
                      row: row,
                      workspace: workspaceNames[row.workdir] ?? row.workdir,
                      selected: row.key == _selected && WindowClass.of(context).isExpanded,
                      canPrompt: canPrompt,
                      onOpen: () => _open(context, row),
                    ),
                ]),
              ),
            ),
          if (sessions.isEmpty && state.connected && !state.sessionsLoading)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: _query.text.isEmpty ? l.noSessionsTitle : l.noSearchResults(_query.text),
                body: _query.text.isNotEmpty ? null : (canPrompt ? l.noSessionsBody : l.noSessionsNoPrompt),
                action: canPrompt && _query.text.isEmpty && state.workspaces.isNotEmpty
                    ? AppButton(label: l.newSession, icon: Icons.add_rounded, onPressed: _newSession)
                    : null,
              ),
            ),
        ],
      );
    });
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.row,
    required this.workspace,
    required this.selected,
    required this.canPrompt,
    required this.onOpen,
  });

  final SessionRow row;
  final String workspace;
  final bool selected;
  final bool canPrompt;
  final VoidCallback onOpen;

  Future<void> _rename(BuildContext context) async {
    final l = context.l10n;
    final title = await promptText(
      context,
      title: l.renameSession,
      label: l.sessionTitle,
      action: l.save,
      initial: row.title,
    );
    if (title != null && context.mounted) {
      try {
        await context.app.renameSession(row.key, title);
      } catch (error) {
        if (context.mounted) showMessage(context, l.error(error));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.deleteSessionTitle(row.title.isEmpty ? row.key : row.title),
      body: l.deleteSessionBody,
      action: l.delete,
      destructive: true,
    );
    if (ok && context.mounted) {
      try {
        await context.app.deleteSession(row.key);
      } catch (error) {
        if (context.mounted) showMessage(context, l.error(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final active = row.runState.isNotEmpty && row.runState != 'idle';
    final tone = switch (runTone(row.runState)) {
      RunTone.running => StatusTone.running,
      RunTone.waiting => StatusTone.waiting,
      RunTone.done => StatusTone.done,
      RunTone.failed => StatusTone.failed,
      RunTone.neutral => StatusTone.neutral,
    };
    final updated = row.updatedAt > 0 ? l.ago(DateTime.fromMillisecondsSinceEpoch(row.updatedAt)) : null;
    return ListTile(
      selected: selected,
      selectedTileColor: colors.secondaryContainer,
      onTap: onOpen,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(Gap.lg, Gap.xs, Gap.xs, Gap.xs),
      title: Text(row.title.isEmpty ? row.key : row.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.preview.isNotEmpty) Text(row.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Wrap(spacing: Gap.sm, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (active) StatusBadge(l.runState(row.runState), tone: tone),
          if (row.backgroundJobs.isNotEmpty) StatusBadge(l.backgroundJobs(row.backgroundJobs.length), tone: StatusTone.running),
          Text(
            [row.agent, workspace, ?updated].where((part) => part.isNotEmpty).join(' · '),
            style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ]),
      ]),
      trailing: canPrompt
          ? PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (value) => value == 'rename' ? _rename(context) : _delete(context),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.rename))),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: colors.error),
                    title: Text(l.delete, style: TextStyle(color: colors.error)),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// Start a session from the phone: a workspace, an agent, a title.
class _NewSessionSheet extends StatefulWidget {
  const _NewSessionSheet();

  @override
  State<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<_NewSessionSheet> {
  final TextEditingController _title = TextEditingController();
  String? _workdir;
  String _agent = 'claude';
  List<AgentStatus> _agents = const [];
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final workspaces = context.app.state.workspaces;
    _workdir = workspaces.firstOrNull?.path;
    unawaited(_loadAgents());
  }

  Future<void> _loadAgents() async {
    try {
      final agents = await context.app.agents();
      if (!mounted) return;
      setState(() {
        _agents = agents.where((a) => a.installed && a.driven).toList();
        if (_agents.isNotEmpty && !_agents.any((a) => a.id == _agent)) _agent = _agents.first.id;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final workdir = _workdir;
    if (workdir == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await context.app.newSession(_agent, workdir, title: _title.text);
      if (mounted) Navigator.of(context).pop(row);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final workspaces = context.app.state.workspaces;
    final agents = _agents.isEmpty ? [const AgentStatus(id: 'claude', label: 'Claude'), const AgentStatus(id: 'codex', label: 'Codex')] : _agents;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(l.newSession),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.workspace, style: context.text.labelLarge),
            const SizedBox(height: Gap.sm),
            ChoiceGroup<String>(
              items: [for (final w in workspaces) GroupItem(value: w.path, label: w.name.isEmpty ? w.path : w.name)],
              selected: _workdir,
              onSelected: (value) => setState(() => _workdir = value),
            ),
            const SizedBox(height: Gap.lg),
            Text(l.agent, style: context.text.labelLarge),
            const SizedBox(height: Gap.sm),
            ChoiceGroup<String>(
              items: [for (final a in agents) GroupItem(value: a.id, label: a.label.isEmpty ? a.id : a.label)],
              selected: _agent,
              onSelected: (value) => setState(() => _agent = value ?? _agent),
            ),
            const SizedBox(height: Gap.lg),
            TextField(controller: _title, decoration: InputDecoration(labelText: l.titleOptional)),
            if (_error != null) ...[
              const SizedBox(height: Gap.md),
              InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
            ],
            const SizedBox(height: Gap.xl),
            AppButton(label: l.create, icon: Icons.add_rounded, busy: _busy, expand: true, onPressed: _workdir == null ? null : _create),
          ]),
        ),
      ]),
    );
  }
}
