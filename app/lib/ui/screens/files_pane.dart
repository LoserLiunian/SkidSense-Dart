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

/// Browse a workspace, search its contents, read a file, and — with
/// `files.write` — edit and save it. Saving sends the etag the text was
/// loaded from, so an edit made outside the app is a conflict, never a
/// silent overwrite.
class FilesPane extends StatefulWidget {
  const FilesPane({super.key, required this.workspace});

  final ValueNotifier<String?> workspace;

  @override
  State<FilesPane> createState() => _FilesPaneState();
}

class _FilesPaneState extends State<FilesPane> {
  late final AppController _app = context.app;
  String _path = '';
  ListDirResult? _listing;
  bool _loading = false;
  Object? _error;
  bool _showIgnored = false;
  bool _searching = false;
  final TextEditingController _query = TextEditingController();
  bool _regex = false;

  String? get _root => widget.workspace.value;

  @override
  void initState() {
    super.initState();
    widget.workspace.addListener(_rootChanged);
    if (_root != null) unawaited(_load(''));
  }

  @override
  void dispose() {
    widget.workspace.removeListener(_rootChanged);
    _query.dispose();
    // The desktop streams progress until told otherwise.
    _app.clearSearch();
    super.dispose();
  }

  void _rootChanged() {
    _path = '';
    _app.clearSearch();
    unawaited(_load(''));
  }

  Future<void> _load(String path) async {
    final root = _root;
    if (root == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listing = await _app.listDir(root, path, showIgnored: _showIgnored);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _path = path;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parent(String path) {
    final index = path.lastIndexOf('/');
    return index <= 0 ? '' : path.substring(0, index);
  }

  void _openFile(String path, {int? line}) {
    final root = _root;
    if (root == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FileViewer(root: root, path: path, line: line)));
  }

  Future<void> _createEntry(String kind) async {
    final l = context.l10n;
    final root = _root;
    if (root == null) return;
    final name = await promptText(context, title: kind == 'mkdir' ? l.newFolder : l.newFile, label: l.name, action: l.create);
    if (name == null || !mounted) return;
    final path = _path.isEmpty ? name : '$_path/$name';
    try {
      final result = await _app.fileOp(root, kind, path: path);
      if (result != null && !result.ok && mounted) showMessage(context, result.error ?? l.errUnknown(kind));
      await _load(_path);
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  Future<void> _entryAction(DirEntry entry, String action) async {
    final l = context.l10n;
    final root = _root;
    if (root == null) return;
    try {
      if (action == 'rename') {
        final name = await promptText(context, title: l.rename, label: l.name, action: l.save, initial: entry.name);
        if (name == null || !mounted) return;
        final to = _path.isEmpty ? name : '$_path/$name';
        final result = await _app.fileOp(root, 'rename', path: entry.path, to: to);
        if (result != null && !result.ok && mounted) showMessage(context, result.error ?? l.errUnknown('rename'));
      } else {
        final ok = await confirm(context, title: l.deleteItemTitle(entry.name), body: l.deleteItemBody, action: l.delete, destructive: true);
        if (!ok || !mounted) return;
        final result = await _app.fileOp(root, 'delete', path: entry.path);
        if (result != null && !result.ok && mounted) showMessage(context, result.error ?? l.errUnknown('delete'));
      }
      await _load(_path);
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Watch(_app.states, builder: (context, state) {
      final canWrite = state.canScope(Scopes.filesWrite);
      final listing = _listing;
      final crumbs = _path.isEmpty ? <String>[] : _path.split('/');
      return PopScope(
        canPop: _path.isEmpty && !_searching,
        onPopInvokedWithResult: (popped, _) {
          if (popped) return;
          if (_searching) {
            setState(() => _searching = false);
          } else {
            unawaited(_load(_parent(_path)));
          }
        },
        child: AppPage(
          title: l.filesTitle,
          subtitle: const ConnectionSubtitle(),
          automaticallyImplyLeading: false,
          actions: [
            WorkspacePicker(workspace: widget.workspace),
            IconButton(
              tooltip: l.searchContent,
              icon: Icon(_searching ? Icons.folder_open_rounded : Icons.manage_search_rounded),
              onPressed: () => setState(() => _searching = !_searching),
            ),
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (value) {
                switch (value) {
                  case 'ignored':
                    setState(() => _showIgnored = !_showIgnored);
                    unawaited(_load(_path));
                  case 'mkdir' || 'create':
                    unawaited(_createEntry(value));
                }
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(value: 'ignored', checked: _showIgnored, child: Text(l.showIgnored)),
                if (canWrite) ...[
                  PopupMenuItem(value: 'create', child: ListTile(leading: const Icon(Icons.note_add_outlined), title: Text(l.newFile))),
                  PopupMenuItem(
                    value: 'mkdir',
                    child: ListTile(leading: const Icon(Icons.create_new_folder_outlined), title: Text(l.newFolder)),
                  ),
                ],
              ],
            ),
          ],
          onRefresh: () => _load(_path),
          slivers: [
            if (!state.connected) const SliverToBoxAdapter(child: OfflineCard()),
            if (_root == null && state.workspaces.isEmpty)
              SliverToBoxAdapter(child: EmptyState(icon: Icons.folder_off_outlined, title: l.noWorkspace)),
            if (_searching) ..._search(context) else ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    children: [
                      ActionChip(avatar: const Icon(Icons.home_outlined, size: 18), label: Text(l.root), onPressed: () => _load('')),
                      for (var i = 0; i < crumbs.length; i++) ...[
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Icon(Icons.chevron_right_rounded, size: 18)),
                        ActionChip(label: Text(crumbs[i]), onPressed: () => _load(crumbs.sublist(0, i + 1).join('/'))),
                      ],
                    ],
                  ),
                ),
              ),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                    child: InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
                  ),
                ),
              if (_loading && listing == null) const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(Gap.xl), child: BusyIndicator()))),
              if (listing != null && listing.truncated)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                    child: InlineBanner(message: l.dirTruncated, tone: BannerTone.info),
                  ),
                ),
              if (listing != null && listing.entries.isEmpty && !_loading)
                SliverToBoxAdapter(child: EmptyState(icon: Icons.folder_open_outlined, title: l.emptyDir)),
              if (listing != null && listing.entries.isNotEmpty)
                SliverToBoxAdapter(
                  child: GroupedList(children: [
                    for (final entry in _sorted(listing.entries))
                      ListTile(
                        leading: Icon(
                          entry.kind == 'dir' ? Icons.folder_rounded : _fileIcon(entry.name),
                          color: entry.kind == 'dir' ? context.colors.primary : context.colors.onSurfaceVariant,
                        ),
                        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: entry.kind == 'dir'
                            ? null
                            : Text(
                                [formatBytes(entry.size), if (entry.git != null) l.gitStatus(entry.git!)].join(' · '),
                                style: context.text.bodySmall,
                              ),
                        trailing: canWrite
                            ? PopupMenuButton<String>(
                                tooltip: l.more,
                                onSelected: (action) => _entryAction(entry, action),
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'rename', child: Text(l.rename)),
                                  PopupMenuItem(value: 'delete', child: Text(l.delete, style: TextStyle(color: context.colors.error))),
                                ],
                              )
                            : null,
                        onTap: () => entry.kind == 'dir' ? _load(entry.path) : _openFile(entry.path),
                      ),
                  ]),
                ),
            ],
          ],
        ),
      );
    });
  }

  List<DirEntry> _sorted(List<DirEntry> entries) => [...entries]..sort((a, b) {
      if ((a.kind == 'dir') != (b.kind == 'dir')) return a.kind == 'dir' ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  List<Widget> _search(BuildContext context) {
    final l = context.l10n;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
          child: Column(children: [
            SearchBar(
              controller: _query,
              hintText: l.searchContent,
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onSubmitted: (query) {
                final root = _root;
                if (root != null && query.trim().isNotEmpty) unawaited(_app.startSearch(root, query.trim(), isRegex: _regex));
              },
              trailing: [
                FilterChip(label: Text(l.regex), selected: _regex, onSelected: (value) => setState(() => _regex = value)),
              ],
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: Watch(_app.search, builder: (context, view) {
          if (view == null) return const SizedBox.shrink();
          final state = view.state;
          final status = !state.done
              ? Row(children: [
                  const InlineBusy(),
                  const SizedBox(width: Gap.md),
                  Expanded(child: Text(l.searching)),
                  AppButton(label: l.stop, emphasis: ActionEmphasis.quiet, onPressed: _app.cancelSearch),
                ])
              : state.end == SearchEnd.interrupted
                  ? InlineBanner(message: l.searchInterrupted, tone: BannerTone.warning)
                  : state.end != null
                      ? InlineBanner(message: state.error is String ? state.error! as String : l.error(state.error))
                      : Text(
                          state.cancelled ? l.searchCancelled : l.searchSummary(state.totalMatches == 0 ? state.matches : state.totalMatches, state.fileCount == 0 ? state.files.length : state.fileCount),
                          style: context.text.labelLarge,
                        );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm), child: status),
            for (final file in state.files)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: GroupedList(children: [
                  ListTile(
                    leading: Icon(_fileIcon(file.path)),
                    title: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => _openFile(file.path),
                  ),
                  for (final match in file.matches.take(12))
                    ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 40,
                        child: Text('${match.line}', textAlign: TextAlign.end, style: context.text.labelMedium?.mono),
                      ),
                      title: Text.rich(_highlight(context, match), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _openFile(file.path, line: match.line),
                    ),
                  if (file.matches.length > 12)
                    ListTile(dense: true, title: Text(l.moreMatches(file.matches.length - 12))),
                ]),
              ),
          ]);
        }),
      ),
    ];
  }

  TextSpan _highlight(BuildContext context, SearchMatch match) {
    final colors = context.colors;
    final style = context.text.bodySmall?.mono;
    final spans = <TextSpan>[];
    var at = 0;
    final text = match.text;
    for (final range in match.ranges) {
      final start = range.start.clamp(0, text.length);
      final end = range.end.clamp(start, text.length);
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(
        text: text.substring(start, end),
        style: TextStyle(backgroundColor: colors.tertiaryContainer, color: colors.onTertiaryContainer, fontWeight: FontWeight.w600),
      ));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

IconData _fileIcon(String name) {
  final lower = name.toLowerCase();
  if (RegExp(r'\.(png|jpe?g|gif|webp|svg|ico|heic)$').hasMatch(lower)) return Icons.image_outlined;
  if (RegExp(r'\.(md|txt|rst)$').hasMatch(lower)) return Icons.article_outlined;
  if (RegExp(r'\.(json|ya?ml|toml|xml|ini|lock)$').hasMatch(lower)) return Icons.data_object_rounded;
  return Icons.code_rounded;
}

/// One file: read it, and with `files.write` edit and save it.
class FileViewer extends StatefulWidget {
  const FileViewer({super.key, required this.root, required this.path, this.line});

  final String root;
  final String path;
  final int? line;

  @override
  State<FileViewer> createState() => _FileViewerState();
}

class _FileViewerState extends State<FileViewer> {
  late final AppController _app = context.app;
  final TextEditingController _text = TextEditingController();
  ReadFileResult? _file;
  bool _loading = true;
  bool _editing = false;
  bool _dirty = false;
  bool _saving = false;
  Object? _error;
  String? _conflict;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      if (_editing && _file != null && _text.text != (_file!.text ?? '') && !_dirty) setState(() => _dirty = true);
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _conflict = null;
    });
    try {
      final file = await _app.readFile(widget.root, widget.path);
      if (!mounted) return;
      setState(() {
        _file = file;
        _text.text = file?.text ?? '';
        _dirty = false;
      });
      final line = widget.line;
      if (line != null && line > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo((line - 1) * 18.0 - 80);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _app.writeFile(widget.root, widget.path, _text.text, etag: _file?.etag);
      if (!mounted) return;
      if (result == null) return;
      if (result.ok) {
        showMessage(context, l.saved);
        // Re-read, so the etag and the line count move on.
        final fresh = await _app.readFile(widget.root, widget.path);
        if (mounted) {
          setState(() {
            _file = fresh;
            _dirty = false;
          });
        }
      } else if (result.conflict ?? false) {
        setState(() => _conflict = l.saveConflict);
      } else {
        setState(() => _error = result.error ?? l.errUnknown('fs.write'));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final file = _file;
    final canWrite = _app.state.canScope(Scopes.filesWrite) && file?.encoding == 'utf8';
    final name = widget.path.split('/').last;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (popped, _) async {
        if (popped) return;
        final navigator = Navigator.of(context);
        final discard = await confirm(context, title: l.unsavedChanges, body: widget.path, action: l.discard, destructive: true);
        if (discard && mounted) navigator.pop();
      },
      child: FixedPage(
        title: name,
        subtitle: file == null ? null : Text(l.fileLines(file.lines, formatBytes(file.size))),
        actions: [
          if (canWrite)
            IconButton(
              tooltip: _editing ? l.preview : l.edit,
              icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit_outlined),
              onPressed: () => setState(() => _editing = !_editing),
            ),
          IconButton(tooltip: l.reload, icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
        ],
        body: Column(children: [
          if (_error != null || _conflict != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              child: InlineBanner(
                message: _conflict ?? (_error is String ? _error! as String : l.error(_error)),
                tone: _conflict != null ? BannerTone.warning : BannerTone.error,
                onDismiss: () => setState(() {
                  _error = null;
                  _conflict = null;
                }),
              ),
            ),
          if (file != null && file.encoding != 'utf8')
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              child: InlineBanner(message: file.encoding == 'binary' ? l.binaryFile : l.tooLargeFile, tone: BannerTone.info),
            ),
          Expanded(
            child: _loading && file == null
                ? const Center(child: BusyIndicator())
                : _editing
                    ? Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: TextField(
                          controller: _text,
                          expands: true,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: context.text.bodySmall?.mono.copyWith(height: 1.5),
                          decoration: const InputDecoration(border: InputBorder.none, filled: false),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(Gap.lg),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SelectableText(
                            _text.text,
                            style: context.text.bodySmall?.mono.copyWith(height: 1.5),
                          ),
                        ),
                      ),
          ),
          if (_editing)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
                child: Row(children: [
                  Expanded(child: AppButton(label: l.save, icon: Icons.save_outlined, busy: _saving, expand: true, onPressed: _dirty ? _save : null)),
                  const SizedBox(width: Gap.sm),
                  AppButton(label: l.reload, emphasis: ActionEmphasis.outlined, onPressed: _saving ? null : _load),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
