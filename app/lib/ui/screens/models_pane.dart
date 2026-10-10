import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../l10n/gen/app_localizations.dart';
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
import 'account_editor_screen.dart';
import 'cloud_sheets.dart';
import 'context_sheet.dart';
import 'host_shell.dart';

/// The computer's 模型管理 (spec §7.1): where the agents' calls go (local
/// or cloud), which account each agent runs on, the accounts, the cloud keys
/// and what is assigned from them, and the context sizes. Changing any of
/// it takes `settings` — as much as the terminal, opened on the computer
/// alone; without it this shows everything and changes nothing.
class ModelsPane extends StatefulWidget {
  const ModelsPane({super.key});

  @override
  State<ModelsPane> createState() => _ModelsPaneState();
}

class _ModelsPaneState extends State<ModelsPane> {
  late final AppController _app = context.app;
  HostConfigController get _config => _app.config;
  final List<void Function()> _unwatch = [];

  /// The account's cloud keys, read with the phone's own sign-in.
  List<ApiKeyRow>? _keys;
  Object? _keysError;
  bool _keysLoading = false;

  bool _modeBusy = false;

  /// The computer's own sentence for a mode it would not switch to.
  String? _modeRefusal;

  @override
  void initState() {
    super.initState();
    _unwatch.addAll([_config.watchMode(), _config.watchAccounts(), _config.watchPresets()]);
    if (_app.state.serverScopes == null) unawaited(_app.loadServerScopes());
    unawaited(_loadKeys());
  }

  @override
  void dispose() {
    for (final unwatch in _unwatch) {
      unwatch();
    }
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() => _keysLoading = true);
    try {
      final keys = await _app.backend.tokens();
      if (mounted) {
        setState(() {
          _keys = keys;
          _keysError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _keysError = error);
    } finally {
      if (mounted) setState(() => _keysLoading = false);
    }
  }

  Future<void> _refresh() => Future.wait([_config.loadMode(), _config.loadAccounts(), _loadKeys()]);

  // --- the route ----------------------------------------------------------------------

  Future<void> _switchMode(String next) async {
    final l = context.l10n;
    final cloud = next == 'cloud';
    final ok = await confirm(
      context,
      title: cloud ? l.modelsSwitchCloudTitle : l.modelsSwitchLocalTitle,
      body: cloud ? l.modelsSwitchCloudBody : l.modelsSwitchLocalBody,
      action: l.modelsSwitch,
    );
    if (!ok || !mounted) return;
    setState(() {
      _modeBusy = true;
      _modeRefusal = null;
    });
    try {
      final result = await _config.setMode(next);
      if (!mounted) return;
      if (result.ok) {
        showMessage(context, cloud ? l.modelsSwitchedCloud : l.modelsSwitchedLocal);
      } else {
        setState(() => _modeRefusal = result.error ?? l.errUnknown(''));
      }
    } catch (error) {
      if (mounted) setState(() => _modeRefusal = l.error(error));
    } finally {
      if (mounted) setState(() => _modeBusy = false);
    }
  }

  // --- local accounts -----------------------------------------------------------------

  Future<void> _pickAccount(HarnessInfo harness, AccountsSnapshot snapshot) async {
    final l = context.l10n;
    final picked = await showAppSheet<Object>(context, builder: (_) => _ChoiceSheet(harness: harness, snapshot: snapshot));
    if (!mounted || picked == null) return;
    if (picked is! AccountChoice) {
      await _edit(null);
      return;
    }
    if (picked == snapshot.choiceFor(harness.agent)) return;
    try {
      final result = await _config.setActive(harness.agent, picked);
      if (mounted && !result.ok) showMessage(context, result.error ?? l.errUnknown(''));
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  Future<void> _edit(AccountGroup? group) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountEditorScreen(group: group)));

  Future<void> _delete(AccountGroup group) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.modelsDeleteAccountTitle(group.name),
      body: l.modelsDeleteAccountBody,
      action: l.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final groupId = group.groupId;
      final result = groupId != null
          ? await _config.removeGroup(groupId, revision: group.revision)
          : await _config.removeLegacy(group.first.id);
      if (!mounted) return;
      if (result.ok) {
        showMessage(context, l.modelsAccountDeleted(group.name));
      } else if (result.code == SettingCodes.conflict) {
        // Changed elsewhere since it was read: shown again, as it is now,
        // to be deleted (or not) knowing that.
        showMessage(context, l.modelsDeleteConflict);
        unawaited(_config.loadAccounts());
      } else {
        showMessage(context, result.error ?? l.errUnknown(''));
      }
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  // --- cloud --------------------------------------------------------------------------

  Future<void> _createKey(bool canAssign) async {
    final outcome = await showAppSheet<CreatedKeyOutcome>(context, builder: (_) => CreateKeySheet(canAssign: canAssign));
    if (!mounted) return;
    unawaited(_loadKeys());
    if (outcome != null && outcome.assign) await _assign(outcome.key.id, outcome.name);
  }

  Future<void> _assign(int keyId, String keyName) async {
    final l = context.l10n;
    final result = await showAppSheet<CloudAssignResult>(context, builder: (_) => AssignSheet(keyId: keyId, keyName: keyName));
    if (!mounted || result == null) return;
    showMessage(context, l.assignDone(result.providers.length));
  }

  Future<void> _reveal(ApiKeyRow key) async {
    final l = context.l10n;
    if (!await unlockForKey(context) || !mounted) return;
    try {
      final secret = await _app.backend.revealToken(key.id);
      if (!mounted) return;
      await showAppSheet<void>(context, builder: (_) => KeyRevealSheet(name: key.name.isEmpty ? l.keyUnnamed : key.name, secret: secret));
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  Future<void> _deleteKey(ApiKeyRow key) async {
    if (await deleteKey(context, key) && mounted) unawaited(_loadKeys());
  }

  Future<void> _unassign(ProviderProfile row) async {
    final l = context.l10n;
    final name = cloudAssignmentName(l, row.name);
    final ok = await confirm(context, title: l.modelsUnassignTitle(name), body: l.modelsUnassignBody, action: l.modelsUnassign, destructive: true);
    if (!ok || !mounted) return;
    try {
      final result = await _config.cloudUnassign(row.id);
      if (!mounted) return;
      showMessage(context, result.ok ? l.modelsUnassigned(name) : result.error ?? l.errUnknown(''));
    } catch (error) {
      if (mounted) showMessage(context, l.error(error));
    }
  }

  // --- the page -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Watch(_app.states, builder: (context, state) {
      // `mode.set` is listed only to a device with `settings` (spec §7.1).
      final canSet = state.can('mode.set');
      final connected = state.connected;
      return Watch(_config.mode, builder: (context, mode) {
        return Watch(_config.accounts, builder: (context, accounts) {
          return Watch(_config.presets, builder: (context, presets) {
            final snapshot = accounts.value;
            final cloud = mode.value == 'cloud';
            final writable = canSet && connected;
            final route = [
              SliverToBoxAdapter(child: SectionHeader(l.modelsRoute, hint: l.modelsRouteHint)),
              SliverToBoxAdapter(
                child: _ModeCards(
                  mode: mode.value,
                  busy: _modeBusy,
                  onPick: writable && !_modeBusy ? _switchMode : null,
                ),
              ),
              if (_modeRefusal != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                    child: InlineBanner(title: l.modelsSwitchRefused, message: _modeRefusal!, onDismiss: () => setState(() => _modeRefusal = null)),
                  ),
                ),
              if (mode.value == null && mode.error != null)
                SliverToBoxAdapter(child: _ErrorBanner(error: mode.error, onRetry: _config.loadMode)),
            ];
            final local = [
              // --- local accounts, per agent ------------------------------------------
              SliverToBoxAdapter(child: SectionHeader(l.modelsLocal, hint: l.modelsLocalHint)),
              if (cloud)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                    child: InlineBanner(tone: BannerTone.info, icon: Icons.cloud_outlined, message: l.modelsLocalCloudNote),
                  ),
                ),
              if (snapshot == null && accounts.loading) SliverToBoxAdapter(child: LoadingRow(l.modelsLoading)),
              if (snapshot == null && accounts.error != null)
                SliverToBoxAdapter(child: _ErrorBanner(error: accounts.error, onRetry: _config.loadAccounts)),
              if (snapshot != null)
                SliverToBoxAdapter(
                  child: snapshot.harnesses.isEmpty
                      ? _Note(l.modelsNoHarnesses)
                      : GroupedList(children: [
                          for (final harness in snapshot.harnesses)
                            _HarnessTile(
                              harness: harness,
                              snapshot: snapshot,
                              muted: cloud,
                              onTap: writable ? () => _pickAccount(harness, snapshot) : null,
                            ),
                        ]),
                ),

              // --- accounts ------------------------------------------------------------
              if (snapshot != null) ...[
                SliverToBoxAdapter(child: SectionHeader(l.modelsAccounts, hint: writable ? l.modelsAccountsHint : l.modelsAccountsHintReadOnly)),
                SliverToBoxAdapter(
                  child: snapshot.accounts.isEmpty
                      ? _Note(l.modelsNoAccounts)
                      : GroupedList(children: [
                          for (final group in snapshot.accounts)
                            _AccountTile(
                              group: group,
                              presets: presets.value,
                              onEdit: writable ? () => _edit(group) : null,
                              onDelete: writable ? () => _delete(group) : null,
                            ),
                        ]),
                ),
                if (writable)
                  SliverToBoxAdapter(
                    child: _Actions(children: [
                      AppButton(label: l.modelsAddAccount, icon: Icons.add_rounded, emphasis: ActionEmphasis.tonal, onPressed: () => _edit(null)),
                    ]),
                  ),
              ],
            ];
            final keys = _keys;
            final clouds = [
              // --- cloud: the phone's own keys, and what the computer was given --------
              SliverToBoxAdapter(child: SectionHeader(l.modelsCloud, hint: l.modelsCloudHint)),
              if (keys == null && _keysLoading) SliverToBoxAdapter(child: LoadingRow(l.keysLoading)),
              if (_keysError != null)
                SliverToBoxAdapter(child: _ErrorBanner(error: _keysError, onRetry: _loadKeys)),
              if (keys != null) ...[
                SliverToBoxAdapter(
                  child: keys.isEmpty
                      ? _Note(l.keysEmpty)
                      : GroupedList(children: [
                          for (final key in keys)
                            _KeyTile(
                              apiKey: key,
                              // Assigning is the computer's; the key itself
                              // is this phone's sign-in's, with the computer
                              // offline as much as without settings (spec §7).
                              onAssign: writable ? () => _assign(key.id, key.name) : null,
                              onReveal: () => _reveal(key),
                              onDelete: () => _deleteKey(key),
                            ),
                        ]),
                ),
                SliverToBoxAdapter(
                  child: _Actions(children: [
                    AppButton(
                      label: l.keyCreate,
                      icon: Icons.add_rounded,
                      emphasis: ActionEmphasis.tonal,
                      onPressed: () => _createKey(writable),
                    ),
                  ]),
                ),
              ],
              if (snapshot != null && snapshot.cloud.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHeader(l.modelsAssigned, hint: l.modelsAssignedHint)),
                SliverToBoxAdapter(
                  child: GroupedList(children: [
                    for (final row in snapshot.cloud)
                      ListTile(
                        title: Text(cloudAssignmentName(l, row.name)),
                        subtitle: Text(
                          row.models.isEmpty ? l.modelsNoModelsAssigned : row.models.join(l.localeName.startsWith('zh') ? '、' : ', '),
                          style: context.text.bodySmall?.mono.copyWith(color: context.colors.onSurfaceVariant),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: writable
                            ? IconButton(
                                tooltip: l.modelsUnassign,
                                icon: const Icon(Icons.link_off_rounded),
                                onPressed: () => _unassign(row),
                              )
                            : null,
                      ),
                  ]),
                ),
              ],
            ];
            return AppPage(
              title: l.modelsTitle,
              subtitle: const ConnectionSubtitle(),
              automaticallyImplyLeading: false,
              actions: [settingsAction(context)],
              onRefresh: _refresh,
              maxContentWidth: AppPage.readableWidth,
              slivers: [
                if (!connected) const SliverToBoxAdapter(child: OfflineCard()),
                if (!canSet && state.welcome != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                      child: InlineBanner(
                        tone: BannerTone.info,
                        icon: Icons.lock_outline_rounded,
                        title: l.modelsReadOnlyTitle,
                        message: settingsReadOnlyReason(l, state),
                      ),
                    ),
                  ),
                ...route,
                // What the route uses first: the other waits below.
                if (cloud) ...[...clouds, ...local] else ...[...local, ...clouds],

                // --- context -------------------------------------------------------------
                SliverToBoxAdapter(child: SectionHeader(l.ctxTitle)),
                SliverToBoxAdapter(
                  child: GroupedList(children: [
                    ListTile(
                      leading: const Icon(Icons.data_usage_rounded),
                      title: Text(l.ctxEntry),
                      subtitle: Text(l.ctxEntryHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showAppSheet<void>(context, builder: (_) => const ContextSheet()),
                    ),
                  ]),
                ),
              ],
            );
          });
        });
      });
    });
  }
}

/// Why this phone may only look at the computer's models and accounts —
/// the same words on the models tab and in the composer's account menu.
/// The phone's own grant first: granted `settings`, and still nothing to
/// change with, the computer is too old for it. Not granted: a backend read
/// not to know `settings` has no switch for it on the computer to send
/// anyone to; one not read (yet, or the read failed) is said nothing of,
/// and the switch is where it would be; otherwise the grant is off.
String settingsReadOnlyReason(L10n l, AppState state) {
  if (state.canScope(Scopes.settings)) return l.modelsReadOnlyOldComputer;
  final listed = state.serverScopes;
  if (listed != null && !listed.contains(Scopes.settings)) return l.modelsReadOnlyUnsupported;
  return l.modelsReadOnlyBody;
}

/// A line under a section header when there is nothing to list.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: InlineBanner(tone: BannerTone.info, message: text),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
        child: InlineBanner(
          message: context.l10n.error(error),
          action: AppButton(label: context.l10n.retry, emphasis: ActionEmphasis.tonal, onPressed: onRetry),
        ),
      );
}

/// A section's actions, under its list.
class _Actions extends StatelessWidget {
  const _Actions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
        child: Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: children),
      );
}

/// Local or cloud, as two cards: what each means, the current one marked.
class _ModeCards extends StatelessWidget {
  const _ModeCards({required this.mode, required this.busy, required this.onPick});

  /// The narrowest a card's line of text may be at the normal text size:
  /// room for a hint's longest word ("subscription") and a few around it.
  /// A 360dp phone leaves each card 126dp at the normal size — the two side
  /// by side on every common phone — and a larger size puts them one over
  /// the other there (past 1.25×; on a 412dp one, past 1.5×).
  static const minLine = 100.0;

  final String? mode;
  final bool busy;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget card(String value, IconData icon, String title, String hint) => _ModeCard(
          icon: icon,
          title: title,
          hint: hint,
          selected: mode == value,
          busy: busy && mode != value,
          onTap: onPick == null || mode == value ? null : () => onPick!(value),
        );
    final local = card('local', Icons.computer_rounded, l.modelsLocalMode, l.modelsLocalModeHint);
    final cloud = card('cloud', Icons.cloud_outlined, l.modelsCloudMode, l.modelsCloudModeHint);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: LayoutBuilder(builder: (context, constraints) {
        // Side by side while each card leaves its text a readable line;
        // one over the other once it would not (large text).
        final inside = (constraints.maxWidth - Gap.md) / 2 - Gap.lg * 2;
        if (inside < MediaQuery.textScalerOf(context).scale(_ModeCards.minLine)) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [local, const SizedBox(height: Gap.md), cloud]);
        }
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: local),
            const SizedBox(width: Gap.md),
            Expanded(child: cloud),
          ]),
        );
      }),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.hint, required this.selected, required this.busy, this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // One that cannot be picked (a phone that may only look) looks it.
    final muted = !selected && onTap == null && !busy;
    final foreground = selected ? colors.onSecondaryContainer : muted ? colors.onSurfaceVariant : colors.onSurface;
    return AppCard(
      selected: selected,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: selected ? colors.onSecondaryContainer : muted ? colors.onSurfaceVariant : colors.primary),
          const Spacer(),
          if (busy)
            const InlineBusy()
          else if (selected)
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 20),
        ]),
        const SizedBox(height: Gap.sm),
        Text(title, style: context.text.titleMedium?.copyWith(color: foreground)),
        const SizedBox(height: Gap.xs),
        Text(hint, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      ]),
    );
  }
}

/// The accounts [harness] can run on: those of its protocol (`isAccountFor`).
List<ProviderProfile> accountsFor(HarnessInfo harness, AccountsSnapshot snapshot) => [
      for (final row in snapshot.providers)
        if (!row.firstParty && row.dialect == harness.dialect) row,
    ];

/// What an agent's account choice is called.
String _choiceName(L10n l, AccountChoice choice, AccountsSnapshot snapshot) => switch (choice.kind) {
      'official' => l.modelsChoiceOfficial,
      'account' => snapshot.providers.where((row) => row.id == choice.providerId).firstOrNull?.name ?? l.modelsChoiceGone,
      _ => l.modelsChoiceCli,
    };

/// Where an account sends an agent's calls: host, main model, whether a
/// key is stored.
String _route(L10n l, ProviderProfile row) => [
      '→ ${hostOf(row.baseUrl)}',
      row.modelMap?.main ?? row.models.firstOrNull ?? l.modelsRouteModelByCli,
      if (!row.hasKey) l.modelsNoKeyStored,
    ].join(' · ');

/// One agent of the computer: its protocol, whether it is there to run, the
/// account it runs on in local mode and where that sends it.
class _HarnessTile extends StatelessWidget {
  const _HarnessTile({required this.harness, required this.snapshot, required this.muted, required this.onTap});

  final HarnessInfo harness;
  final AccountsSnapshot snapshot;

  /// Cloud mode: the choice waits for local mode, and looks it.
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final choice = snapshot.choiceFor(harness.agent);
    final account = choice.kind == 'account'
        ? snapshot.providers.where((row) => row.id == choice.providerId && !row.firstParty).firstOrNull
        : null;
    // The CLI's own configuration needs no line of its own: the choice says
    // it, and the sheet says what it means.
    final route = account != null
        ? _route(l, account)
        : choice.kind == 'official'
            ? l.modelsRouteOfficial
            : null;
    return ListTile(
      onTap: onTap,
      title: Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(harness.label.isEmpty ? harness.agent : harness.label, style: muted ? TextStyle(color: colors.onSurfaceVariant) : null),
        Text(dialectLabel(harness.dialect), style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        if (!harness.installed) StatusBadge(l.modelsNotInstalled, tone: StatusTone.neutral),
        if (harness.installed && !harness.driven) StatusBadge(l.modelsNotDriven, tone: StatusTone.neutral),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Text(_choiceName(l, choice, snapshot), style: context.text.bodyMedium?.copyWith(color: muted ? colors.onSurfaceVariant : colors.onSurface)),
        if (route != null) Text(route, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      ]),
      trailing: onTap == null ? null : const Icon(Icons.unfold_more_rounded),
    );
  }
}

/// Pick the account an agent runs on: its CLI's own configuration, the
/// vendor's subscription (where it can be forced), or an account of its
/// protocol. Pops the [AccountChoice] — or `true` to add an account.
class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.harness, required this.snapshot});

  final HarnessInfo harness;
  final AccountsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = snapshot.choiceFor(harness.agent);
    final options = accountsFor(harness, snapshot);
    Widget option(AccountChoice choice, String title, String subtitle) {
      final selected = choice == current;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        selected: selected,
        leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () => Navigator.of(context).pop(choice),
      );
    }

    final name = harness.label.isEmpty ? harness.agent : harness.label;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(l.modelsChoiceTitle(name), subtitle: l.modelsChoiceHint(dialectLabel(harness.dialect))),
        option(const AccountChoice.cli(), l.modelsChoiceCli, l.modelsRouteCli),
        if (harness.official) option(const AccountChoice.official(), l.modelsChoiceOfficial, l.modelsRouteOfficial),
        for (final row in options) option(AccountChoice.account(row.id), row.name, _route(l, row)),
        if (options.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, 0),
            child: InlineBanner(
              tone: BannerTone.info,
              message: l.modelsChoiceNone(dialectLabel(harness.dialect)),
              action: AppButton(
                label: l.modelsAddAccount,
                icon: Icons.add_rounded,
                emphasis: ActionEmphasis.tonal,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ),
      ]),
    );
  }
}

/// One local account: its preset, whether a key is stored, its note, and
/// the protocols it speaks with how many models each — or an old endpoint
/// waiting for its protocol.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.group, required this.presets, required this.onEdit, required this.onDelete});

  final AccountGroup group;
  final PresetCatalog? presets;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final first = group.first;
    final legacy = first.legacy;
    final preset = presets?.presets.where((candidate) => candidate.id == group.presetId).firstOrNull;
    final quiet = context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final key = group.hasKey ? l.modelsKeyStored : l.modelsKeyMissing;
    return ListTile(
      onTap: onEdit,
      title: Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(group.name.isEmpty ? first.id : group.name),
        if (legacy) StatusBadge(l.modelsLegacy, tone: StatusTone.neutral),
      ]),
      // The user's own words first, then what the account is made of.
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        if (group.note.isNotEmpty)
          Text(group.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: colors.onSurface)),
        if (legacy) ...[
          Text(hostOf(first.baseUrl), style: quiet?.mono),
          Text('$key · ${l.modelsLegacyHint}', style: quiet),
        ] else
          Text(
            [
              if (preset != null && preset.id != 'custom') l.modelsPresetTag(presetName(l, preset)),
              key,
              for (final row in group.rows) l.modelsDialectModels(dialectLabel(row.dialect), row.models.length),
            ].join(' · '),
            style: quiet,
          ),
      ]),
      trailing: onEdit == null
          ? null
          : PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (action) => action == 'edit' ? onEdit!() : onDelete?.call(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit))),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: colors.error),
                    title: Text(l.delete, style: TextStyle(color: colors.error)),
                  ),
                ),
              ],
            ),
    );
  }
}

/// One cloud key: its name, the key masked, its quota and group, and
/// whether it can be used now.
class _KeyTile extends StatelessWidget {
  const _KeyTile({required this.apiKey, required this.onAssign, required this.onReveal, required this.onDelete});

  final ApiKeyRow apiKey;
  final VoidCallback? onAssign;
  final VoidCallback onReveal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final key = apiKey;
    final state = switch (key.status) {
      1 => null,
      3 => l.keyExpired,
      4 => l.keyExhausted,
      _ => l.keyDisabled,
    };
    return ListTile(
      onTap: onAssign,
      title: Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(key.name.isEmpty ? l.keyUnnamed : key.name),
        if (state != null) StatusBadge(state, tone: StatusTone.failed),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(key.maskedKey, style: context.text.bodySmall?.mono.copyWith(color: colors.onSurfaceVariant)),
        Text([
          key.unlimited ? l.keyUnlimited : l.keyRemaining(usdLabel(key.remainQuotaUsd)),
          if (key.group.isNotEmpty) l.keyGroupNamed(key.group),
        ].join(' · ')),
      ]),
      trailing: PopupMenuButton<String>(
        tooltip: l.more,
        onSelected: (action) => switch (action) {
          'assign' => onAssign?.call(),
          'reveal' => onReveal(),
          _ => onDelete(),
        },
        itemBuilder: (_) => [
          if (onAssign != null) PopupMenuItem(value: 'assign', child: ListTile(leading: const Icon(Icons.hub_outlined), title: Text(l.keyAssign))),
          PopupMenuItem(value: 'reveal', child: ListTile(leading: const Icon(Icons.visibility_outlined), title: Text(l.keyReveal))),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: colors.error),
              title: Text(l.delete, style: TextStyle(color: colors.error)),
            ),
          ),
        ],
      ),
    );
  }
}
