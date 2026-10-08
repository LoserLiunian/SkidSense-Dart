import 'package:skidsense_core/skidsense_core.dart';

import '../../state/scope.dart';
import '../../state/watch.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'files_pane.dart';
import 'git_pane.dart';
import 'history_pane.dart';
import 'sessions_pane.dart';
import 'settings_screen.dart';

/// One connected computer: its sessions, files, Git and history, as
/// top-level destinations the window lays out (a bar on a phone, a rail
/// beside anything wider).
class HostShell extends StatefulWidget {
  const HostShell({super.key});

  @override
  State<HostShell> createState() => _HostShellState();
}

class _HostShellState extends State<HostShell> {
  int _tab = 0;

  /// The workspace the files and Git panes show; shared between them.
  final ValueNotifier<String?> workspace = ValueNotifier(null);

  @override
  void dispose() {
    workspace.dispose();
    super.dispose();
  }

  /// Open a workspace in the files or Git pane, from elsewhere in the shell.
  void show(int tab, {String? root}) {
    if (root != null) workspace.value = root;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    final panes = <Widget>[
      SessionsPane(onOpenFiles: (root) => show(1, root: root), onOpenGit: (root) => show(2, root: root)),
      FilesPane(workspace: workspace),
      GitPane(workspace: workspace),
      const HistoryPane(),
    ];
    return WatchSelect(app.states, select: (AppState s) => s.welcome?.device.scopes.join(','), builder: (context, _) {
      final state = app.state;
      bool can(String scope) => state.welcome == null || state.canScope(scope);
      return _ShellScope(
        shell: this,
        child: AdaptiveNavigation(
          selected: _tab,
          onSelected: (index) => setState(() => _tab = index),
          items: [
            NavItem(icon: Icons.forum_outlined, selectedIcon: Icons.forum_rounded, label: l.tabSessions),
            NavItem(icon: Icons.folder_outlined, selectedIcon: Icons.folder_rounded, label: l.tabFiles),
            NavItem(icon: Icons.merge_type_outlined, selectedIcon: Icons.merge_type_rounded, label: l.tabGit),
            NavItem(icon: Icons.history_outlined, selectedIcon: Icons.history_rounded, label: l.tabHistory),
          ],
          railLeading: IconButton(
            tooltip: l.backToComputers,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          body: AnimatedSwitcher(
            duration: context.design.motion.effects.duration,
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                1 when !can(Scopes.files) => _NotAllowed(scope: Scopes.files),
                2 when !can(Scopes.git) => _NotAllowed(scope: Scopes.git),
                _ => panes[_tab],
              },
            ),
          ),
        ),
      );
    });
  }
}

class _ShellScope extends InheritedWidget {
  const _ShellScope({required this.shell, required super.child});

  final _HostShellState shell;

  @override
  bool updateShouldNotify(_ShellScope old) => false;
}

extension ShellContext on BuildContext {
  /// Jump to the files (1) or Git (2) pane of the enclosing shell.
  void showInShell(int tab, {String? root}) =>
      getInheritedWidgetOfExactType<_ShellScope>()?.shell.show(tab, root: root);
}

class _NotAllowed extends StatelessWidget {
  const _NotAllowed({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context) => AppPage(
        title: context.l10n.scope(scope),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(icon: Icons.lock_outline_rounded, title: context.l10n.scope(scope), body: context.l10n.noScopes),
          ),
        ],
      );
}

/// The connection line: route, rate limit, or why not and when again.
class ConnectionSubtitle extends StatelessWidget {
  const ConnectionSubtitle({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return WatchSelect(app.states, select: (AppState s) => (s.connection, s.relayBytesPerSecond), builder: (context, value) {
      final (connection, budget) = value;
      final connected = connection is ClientConnected;
      final color = connected
          ? (connection.route is RouteRelay ? context.colors.tertiary : context.colors.primary)
          : connection is ClientFailed
              ? context.colors.error
              : context.colors.onSurfaceVariant;
      return Row(children: [
        if (connection is ClientConnecting || connection is ClientWaiting)
          const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: InlineBusy(size: 12))
        else
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        Flexible(
          child: Text(
            context.l10n.connection(connection, relayBytesPerSecond: budget),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
    });
  }
}

/// Shown in place of a pane's content while the computer is not reachable.
class OfflineCard extends StatelessWidget {
  const OfflineCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: InlineBanner(
        tone: BannerTone.info,
        icon: Icons.cloud_off_rounded,
        title: l.offlineTitle,
        message: l.offlineBody,
        action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, onPressed: context.app.retry),
      ),
    );
  }
}

/// The host's name for the top bar.
String hostTitle(BuildContext context) {
  final host = context.app.state.activeHost;
  return host?.displayName ?? context.l10n.tabSessions;
}

/// The settings action every pane's top bar carries.
Widget settingsAction(BuildContext context) => IconButton(
      tooltip: context.l10n.settings,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
    );

/// The workspace picker in the files and Git panes.
class WorkspacePicker extends StatelessWidget {
  const WorkspacePicker({super.key, required this.workspace});

  final ValueNotifier<String?> workspace;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return WatchSelect(app.states, select: (AppState s) => s.workspaces, builder: (context, workspaces) {
      return ValueListenableBuilder(
        valueListenable: workspace,
        builder: (context, selected, _) {
          if (workspaces.isEmpty) return const SizedBox.shrink();
          final current = workspaces.where((w) => w.path == selected).firstOrNull ?? workspaces.first;
          if (selected == null || selected != current.path) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (workspace.value != current.path) workspace.value = current.path;
            });
          }
          return PopupMenuButton<String>(
            tooltip: context.l10n.chooseWorkspace,
            initialValue: current.path,
            onSelected: (path) => workspace.value = path,
            itemBuilder: (_) => [
              for (final w in workspaces)
                PopupMenuItem(value: w.path, child: Text(w.name.isEmpty ? w.path : w.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspaces_outline, size: 20),
                const SizedBox(width: Gap.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(current.name.isEmpty ? current.path : current.name, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ]),
            ),
          );
        },
      );
    });
  }
}
