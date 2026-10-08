import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../state/scope.dart';
import '../describe.dart';
import '../kit/containers.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';
import 'transcript.dart';

/// The server's encrypted copy of the computer's sessions (spec §11): the
/// list costs one request, each session is downloaded and decrypted only
/// when opened, and search runs here — the server cannot read what it holds.
class HistoryPane extends StatefulWidget {
  const HistoryPane({super.key});

  @override
  State<HistoryPane> createState() => _HistoryPaneState();
}

class _HistoryPaneState extends State<HistoryPane> {
  HistoryRepository? _repository;
  List<HistoryEntry> _entries = const [];
  final Map<String, HistoryEntry> _opened = {};
  bool _loading = true;
  Object? _error;
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    unawaited(_load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.app;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = _repository ?? await app.historyRepository();
      if (repository == null) return;
      _repository = repository;
      final host = app.state.activeHost;
      if (host != null) await repository.refreshKeys(host.deviceId);
      final entries = await repository.load();
      if (mounted) setState(() => _entries = entries);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(HistoryEntry entry) async {
    final repository = _repository;
    if (repository == null) return;
    final opened = await repository.open(entry);
    if (!mounted) return;
    setState(() => _opened[entry.sessionKey] = opened);
    if (opened.problem == null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _HistoryDetail(entry: opened)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = _query.text.trim();
    final shown = [for (final entry in _entries) _opened[entry.sessionKey] ?? entry];
    final filtered = HistoryRepository.search(shown, query);
    return AppPage(
      title: l.historyTitle,
      subtitle: Text(l.historySubtitle),
      automaticallyImplyLeading: false,
      actions: [settingsAction(context)],
      onRefresh: _load,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm),
            child: SearchBar(
              controller: _query,
              hintText: l.historySearch,
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
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
        if (_loading && _entries.isEmpty)
          const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(Gap.xl), child: BusyIndicator()))),
        if (!_loading && _entries.isEmpty && _error == null)
          SliverToBoxAdapter(child: EmptyState(icon: Icons.history_rounded, title: l.historyEmpty, body: l.historySubtitle)),
        if (filtered.isNotEmpty)
          SliverToBoxAdapter(
            child: GroupedList(children: [
              for (final entry in filtered)
                ListTile(
                  leading: Icon(
                    entry.problem != null ? Icons.lock_outline_rounded : (entry.opened ? Icons.lock_open_rounded : Icons.enhanced_encryption_outlined),
                    color: entry.problem != null ? context.colors.error : context.colors.primary,
                  ),
                  title: Text(entry.row?.title.isNotEmpty ?? false ? entry.row!.title : entry.sessionKey, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    entry.problem != null
                        ? l.historyProblem(entry)
                        : query.isNotEmpty && entry.opened
                            ? HistoryRepository.excerpt(entry, query)
                            : [
                                l.historyEpoch(entry.epoch),
                                formatBytes(entry.size),
                                if (entry.opened) l.historyTurns(entry.turns.length) else l.historyNotOpened,
                                if (entry.updatedAt > 0) l.ago(DateTime.fromMillisecondsSinceEpoch(entry.updatedAt * 1000)),
                              ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(entry),
                ),
            ]),
          ),
      ],
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final row = entry.row;
    return FixedPage(
      title: row?.title.isNotEmpty ?? false ? row!.title : entry.sessionKey,
      subtitle: Text('${l.historyEpoch(entry.epoch)} · ${row?.workdir ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
      body: ListView.separated(
        padding: const EdgeInsets.all(Gap.lg),
        itemCount: entry.turns.length,
        separatorBuilder: (_, _) => const SizedBox(height: Gap.xxl),
        itemBuilder: (_, index) => TurnView(snapshot: entry.turns[index].snapshot, error: entry.turns[index].error),
      ),
    );
  }
}
