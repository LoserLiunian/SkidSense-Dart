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
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';

/// A workspace's Git: branch and sync, the changes staged and not, their
/// diffs, and a commit — the write half only with `git.write`.
class GitPane extends StatefulWidget {
  const GitPane({super.key, required this.workspace});

  final ValueNotifier<String?> workspace;

  @override
  State<GitPane> createState() => _GitPaneState();
}

class _GitPaneState extends State<GitPane> {
  late final AppController _app = context.app;
  GitSnapshot? _snapshot;
  bool _loading = false;
  bool _busy = false;
  Object? _error;
  final TextEditingController _message = TextEditingController();

  String? get _root => widget.workspace.value;

  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(_refresh);
    _message.addListener(() => setState(() {}));
    if (_root != null) unawaited(_refresh());
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_refresh);
    _message.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final root = _root;
    if (root == null) return;
    setState(() => _loading = true);
    try {
      final snapshot = await _app.gitSnapshot(root);
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(String op, {List<String>? paths, String? message, String? branch, String? done}) async {
    final root = _root;
    if (root == null) return;
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _app.gitMutate(root, op, paths: paths, message: message, branch: branch);
      if (!mounted) return;
      if (result != null && !result.ok) {
        setState(() => _error = l.gitOperationFailed(result.detail ?? result.error ?? result.reason ?? op));
      } else if (done != null) {
        showMessage(context, done);
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _branches() async {
    final root = _root;
    if (root == null) return;
    final branch = await showAppSheet<String>(context, builder: (_) => _BranchSheet(root: root));
    if (branch != null && mounted) await _mutate('switchBranch', branch: branch);
  }

  Future<void> _discard(GitFile file) async {
    final l = context.l10n;
    final ok = await confirm(context, title: l.discardTitle(file.path), body: l.discardBody, action: l.discard, destructive: true);
    if (ok) await _mutate(file.status == 'untracked' ? 'discardUntracked' : 'discard', paths: [file.path]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Watch(_app.states, builder: (context, state) {
      final canWrite = state.canScope(Scopes.gitWrite);
      final snapshot = _snapshot;
      final repo = snapshot?.repo;
      final staged = [for (final f in snapshot?.files ?? const <GitFile>[]) if (f.staged) f];
      final unstaged = [for (final f in snapshot?.files ?? const <GitFile>[]) if (!f.staged) f];
      return AppPage(
        title: l.gitTitle,
        subtitle: const ConnectionSubtitle(),
        automaticallyImplyLeading: false,
        actions: [
          WorkspacePicker(workspace: widget.workspace),
          IconButton(tooltip: l.refresh, icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _refresh),
        ],
        onRefresh: _refresh,
        slivers: [
          if (!state.connected) const SliverToBoxAdapter(child: OfflineCard()),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                child: InlineBanner(message: _error is String ? _error! as String : l.error(_error), onDismiss: () => setState(() => _error = null)),
              ),
            ),
          if (_loading && snapshot == null)
            const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(Gap.xl), child: BusyIndicator()))),
          if (snapshot != null && repo == null)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.merge_type_rounded,
                title: l.notARepo,
                body: snapshot.error,
                action: canWrite ? AppButton(label: l.initRepo, busy: _busy, onPressed: () => _mutate('init')) : null,
              ),
            ),
          if (repo != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // The branch is where branches are switched: tapping it
                    // opens the list.
                    InkWell(
                      onTap: canWrite ? _branches : null,
                      borderRadius: BorderRadius.circular(context.design.shapes.small),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                        child: Row(children: [
                          Icon(Icons.call_split_rounded, color: context.colors.primary),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Row(children: [
                              Flexible(
                                child: Text(
                                  repo.detached ? l.detached(repo.shortSha ?? '') : (repo.branch ?? l.none),
                                  style: context.text.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (canWrite) Icon(Icons.arrow_drop_down_rounded, color: context.colors.onSurfaceVariant),
                            ]),
                          ),
                          if (repo.ahead > 0 || repo.behind > 0) StatusBadge(l.aheadBehind(repo.ahead, repo.behind), tone: StatusTone.neutral),
                        ]),
                      ),
                    ),
                    if (repo.upstream != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.xs, left: 32),
                        child: Text(l.upstream(repo.upstream!), style: context.text.bodySmall),
                      ),
                    if (canWrite) ...[
                      const SizedBox(height: Gap.lg),
                      ActionGroup(busy: _busy, items: [
                        GroupItem(label: l.fetch, icon: Icons.cloud_sync_outlined, onPressed: () => _mutate('fetch')),
                        GroupItem(label: l.pull, icon: Icons.download_rounded, onPressed: () => _mutate('pull')),
                        GroupItem(label: l.push, icon: Icons.upload_rounded, onPressed: () => _mutate('push')),
                      ]),
                    ],
                  ]),
                ),
              ),
            ),
            if (snapshot!.conflicted.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                  child: InlineBanner(message: l.conflictsBanner(snapshot.conflicted.length), tone: BannerTone.warning),
                ),
              ),
            if (staged.isEmpty && unstaged.isEmpty)
              SliverToBoxAdapter(child: EmptyState(icon: Icons.check_circle_outline_rounded, title: l.noChanges)),
            if (staged.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(l.staged)),
              SliverToBoxAdapter(child: GroupedList(children: [for (final f in staged) _fileTile(context, f, canWrite)])),
            ],
            if (unstaged.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  l.unstaged,
                  trailing: canWrite
                      ? AppButton(label: l.stageAll, emphasis: ActionEmphasis.quiet, onPressed: _busy ? null : () => _mutate('stageAll'))
                      : null,
                ),
              ),
              SliverToBoxAdapter(child: GroupedList(children: [for (final f in unstaged) _fileTile(context, f, canWrite)])),
            ],
            if (canWrite && staged.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(l.commit)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(controller: _message, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.commitMessage)),
                    const SizedBox(height: Gap.md),
                    AppButton(
                      label: l.commitStaged,
                      icon: Icons.check_rounded,
                      busy: _busy,
                      expand: true,
                      onPressed: _message.text.trim().isEmpty
                          ? null
                          : () async {
                              await _mutate('commit', message: _message.text.trim(), done: l.committed);
                              if (_error == null) _message.clear();
                            },
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ],
      );
    });
  }

  Widget _fileTile(BuildContext context, GitFile file, bool canWrite) {
    final l = context.l10n;
    final colors = context.colors;
    final changes = file.binary == true ? l.binaryDiff : '+${file.insertions ?? 0} −${file.deletions ?? 0}';
    return ListTile(
      leading: _StatusGlyph(status: file.status),
      title: Text(file.path, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [l.gitStatus(file.status), changes, if (file.from != null) l.renamedFrom(file.from!)].join(' · '),
        style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      onTap: () {
        final root = _root;
        if (root == null) return;
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DiffScreen(root: root, file: file)));
      },
      trailing: canWrite
          ? PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (action) => action == 'stage'
                  ? _mutate(file.staged ? 'unstage' : 'stage', paths: [file.path])
                  : _discard(file),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'stage', child: Text(file.staged ? l.unstage : l.stage)),
                if (!file.staged) PopupMenuItem(value: 'discard', child: Text(l.discardChanges, style: TextStyle(color: colors.error))),
              ],
            )
          : null,
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (letter, color) = switch (status) {
      'added' || 'untracked' => ('A', colors.primary),
      'deleted' => ('D', colors.error),
      'renamed' => ('R', colors.tertiary),
      'conflicted' => ('!', colors.error),
      _ => ('M', colors.secondary),
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.design.expressive ? 10 : 6),
      ),
      child: Text(letter, style: context.text.labelLarge?.mono.copyWith(color: color)),
    );
  }
}

class _BranchSheet extends StatefulWidget {
  const _BranchSheet({required this.root});

  final String root;

  @override
  State<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends State<_BranchSheet> {
  List<GitBranchInfo>? _branches;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(context.app.gitBranches(widget.root).then((branches) {
      if (mounted) setState(() => _branches = branches);
    }, onError: (Object error) {
      if (mounted) setState(() => _error = error);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final branches = _branches;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader(l.branches),
      if (_error != null) Padding(padding: const EdgeInsets.all(Gap.lg), child: InlineBanner(message: l.error(_error))),
      if (branches == null && _error == null) const Padding(padding: EdgeInsets.all(Gap.xl), child: Center(child: BusyIndicator())),
      if (branches != null)
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final branch in branches)
              ListTile(
                leading: Icon(branch.remote ? Icons.cloud_outlined : Icons.call_split_rounded),
                title: Text(branch.name),
                subtitle: branch.upstream == null ? null : Text(branch.upstream!),
                trailing: branch.current ? StatusBadge(l.currentBranch, tone: StatusTone.done) : null,
                onTap: branch.current ? null : () => Navigator.of(context).pop(branch.name),
              ),
          ]),
        ),
      const SizedBox(height: Gap.lg),
    ]);
  }
}

/// One file's unified diff, coloured by line kind.
class DiffScreen extends StatefulWidget {
  const DiffScreen({super.key, required this.root, required this.file});

  final String root;
  final GitFile file;

  @override
  State<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends State<DiffScreen> {
  GitDiffResult? _diff;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(context.app.gitDiff(widget.root, widget.file.path, against: widget.file.staged ? 'head' : 'index').then((diff) {
      if (mounted) setState(() => _diff = diff);
    }, onError: (Object error) {
      if (mounted) setState(() => _error = error);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final diff = _diff;
    final mono = context.text.bodySmall?.mono.copyWith(height: 1.5);
    return FixedPage(
      title: widget.file.path.split('/').last,
      subtitle: Text(widget.file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(Gap.lg), child: InlineBanner(message: l.error(_error)))
          : diff == null
              ? const Center(child: BusyIndicator())
              : diff.binary
                  ? Center(child: Text(l.binaryDiff))
                  : ListView(padding: const EdgeInsets.symmetric(vertical: Gap.md), children: [
                      if (diff.truncated)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                          child: InlineBanner(message: l.diffTruncated, tone: BannerTone.info),
                        ),
                      if (diff.error != null)
                        Padding(padding: const EdgeInsets.all(Gap.lg), child: InlineBanner(message: diff.error!)),
                      for (final hunk in diff.hunks) ...[
                        Container(
                          color: colors.surfaceContainerHigh,
                          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.xs),
                          child: Text(hunk.header, style: mono?.copyWith(color: colors.tertiary)),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            for (final line in hunk.lines)
                              Container(
                                color: switch (line.kind) {
                                  'add' => colors.primaryContainer.withValues(alpha: 0.45),
                                  'del' => colors.errorContainer.withValues(alpha: 0.45),
                                  _ => null,
                                },
                                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                                child: Row(children: [
                                  SizedBox(
                                    width: 36,
                                    child: Text('${line.oldLine ?? ''}', textAlign: TextAlign.end, style: mono?.copyWith(color: colors.outline)),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    child: Text('${line.newLine ?? ''}', textAlign: TextAlign.end, style: mono?.copyWith(color: colors.outline)),
                                  ),
                                  const SizedBox(width: Gap.sm),
                                  Text(
                                    '${switch (line.kind) {
                                      'add' => '+',
                                      'del' => '-',
                                      _ => ' ',
                                    }} ${line.text}',
                                    style: mono,
                                  ),
                                ]),
                              ),
                          ]),
                        ),
                      ],
                    ]),
    );
  }
}
