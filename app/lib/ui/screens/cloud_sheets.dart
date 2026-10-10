import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:skidsense_core/skidsense_core.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/scope.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../kit/forms.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// The agent and the key of a cloud assignment, read out of the name the
/// computer gives it — `第一方 · {agent} · {key}` (`firstPartyProvider` on the
/// desktop), `云端 · …` where the context table heads it — which is in the
/// desktop's words, not the user's. Null for a name of any other shape.
({String agent, String key})? cloudAssignmentOf(String name) {
  const cloud = '云端 · ';
  const firstParty = '第一方 · ';
  final rest = name.startsWith(cloud) ? name.substring(cloud.length) : name;
  if (!rest.startsWith(firstParty)) return null;
  final parts = rest.substring(firstParty.length);
  final at = parts.indexOf(' · ');
  if (at <= 0 || at + 3 >= parts.length) return null;
  return (agent: parts.substring(0, at), key: parts.substring(at + 3));
}

/// A cloud assignment as the phone names it: `{agent} · {key}`.
String cloudAssignmentName(L10n l, String name) {
  final parts = cloudAssignmentOf(name);
  return parts == null ? name : '${parts.agent} · ${assignedKeyName(l, parts.key)}';
}

/// What a key group is for, as the account page says it under its name: a
/// description that only repeats the name left out.
String? keyGroupDetail(TokenGroup group) =>
    group.desc.isEmpty || group.desc.toLowerCase() == group.name.toLowerCase() ? null : group.desc;

/// A key group's price, as the account page shows it at the row's end.
String? keyGroupRatio(L10n l, TokenGroup group) => group.ratio == null && group.ratioLabel == null ? null : l.groupRatio(group);

/// What the computer names a key with none when it assigns its models — the
/// last part of `第一方 · {agent} · {key}` (`assign` in the desktop's
/// `src/main/cloud-keys.ts`).
const unnamedKeyAssignment = '第一方 Key';

/// The key's part of an assignment's name, in the user's words: the
/// computer's name for a key with none said in theirs.
String assignedKeyName(L10n l, String key) => key == unnamedKeyAssignment ? l.assignUnnamedKey : key;

/// How a new key's validity runs out: never, or after a day, a week, a month.
const _expiries = [-1, 86400, 604800, 2592000];

/// What the create sheet ends with: the key made, and whether to go on to
/// assign its models.
class CreatedKeyOutcome {
  const CreatedKeyOutcome({required this.key, required this.name, required this.assign});

  final CreatedKey key;
  final String name;
  final bool assign;
}

/// Make a cloud key with the phone's own sign-in (spec §7: the computer is
/// not asked) — name, group, quota and validity as on the desktop — then
/// show it, once, with a way on to assigning its models. The key is shown
/// whole, so the phone is unlocked for it first, as for showing one.
class CreateKeySheet extends StatefulWidget {
  const CreateKeySheet({super.key, required this.canAssign});

  /// Whether this phone may assign the key's models on the computer.
  final bool canAssign;

  @override
  State<CreateKeySheet> createState() => _CreateKeySheetState();
}

class _CreateKeySheetState extends State<CreateKeySheet> {
  late final AppController _app = context.app;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _quota = TextEditingController(text: '5');
  String _group = '';
  bool _unlimited = true;
  int _expiry = -1;
  List<TokenGroup>? _groups;
  bool _busy = false;
  Object? _error;
  String? _nameError;
  String? _quotaError;
  CreatedKey? _created;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
  }

  @override
  void dispose() {
    _name.dispose();
    _quota.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _app.backend.tokenGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      // The user's own group is always there to fall back on.
      if (mounted) setState(() => _groups = const []);
    }
  }

  Future<void> _create() async {
    final l = context.l10n;
    final name = _name.text.trim();
    final quota = double.tryParse(_quota.text.trim());
    setState(() {
      // new-api counts a name in bytes, not characters: a Chinese one
      // takes three.
      _nameError = name.isEmpty
          ? l.keyNameRequired
          : utf8.encode(name).length > CreateKeyInput.nameBytes
              ? l.keyNameTooLong(CreateKeyInput.nameBytes, CreateKeyInput.nameBytes ~/ 3)
              : null;
      _quotaError = !_unlimited && (quota == null || !quota.isFinite || quota <= 0) ? l.keyQuotaInvalid : null;
      _error = null;
    });
    if (_nameError != null || _quotaError != null) return;
    setState(() => _busy = true);
    try {
      // Asked before anything is made: the key is about to be shown whole.
      if (!await unlockForKey(context)) return;
      final created = await _app.backend.createToken(CreateKeyInput(
        name: name,
        unlimited: _unlimited,
        quotaUsd: _unlimited ? 0 : quota!,
        expiredTime: _expiry < 0 ? -1 : DateTime.now().millisecondsSinceEpoch ~/ 1000 + _expiry,
        group: _group,
      ));
      if (mounted) setState(() => _created = created);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) {
      return _KeyShown(
        title: context.l10n.keyCreatedTitle,
        subtitle: context.l10n.keyShownOnce,
        secret: created.key,
        assign: widget.canAssign
            ? () => Navigator.of(context).pop(CreatedKeyOutcome(key: created, name: _name.text.trim(), assign: true))
            : null,
        done: () => Navigator.of(context).pop(CreatedKeyOutcome(key: created, name: _name.text.trim(), assign: false)),
      );
    }
    final l = context.l10n;
    final groups = _groups;
    // The form scrolls; the action stays put under it.
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: Gap.lg), children: [
          SheetHeader(l.keyCreateTitle, subtitle: l.keyCreateHint),
          FormColumn(padding: const EdgeInsets.symmetric(horizontal: Gap.xl), children: [
            AppTextField(
              controller: _name,
              label: l.keyName,
              hint: l.keyNameHint,
              error: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            SelectField<String>(
              label: l.keyGroup,
              value: _group,
              helper: groups == null ? l.keyGroupsLoading : null,
              options: {
                '': l.keyGroupDefault,
                for (final group in groups ?? const <TokenGroup>[]) group.name: group.name,
              },
              details: {for (final group in groups ?? const <TokenGroup>[]) group.name: ?keyGroupDetail(group)},
              trailing: {for (final group in groups ?? const <TokenGroup>[]) group.name: ?keyGroupRatio(l, group)},
              onChanged: (value) => setState(() => _group = value),
            ),
            SwitchRow(
              title: l.keyUnlimited,
              subtitle: l.keyUnlimitedHint,
              value: _unlimited,
              onChanged: (value) => setState(() => _unlimited = value),
            ),
            if (!_unlimited)
              AppTextField(
                controller: _quota,
                label: l.keyQuota,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                error: _quotaError,
                onChanged: (_) {
                  if (_quotaError != null) setState(() => _quotaError = null);
                },
              ),
            FieldLabel(l.keyExpiry),
            ChoiceGroup<int>(
              items: [
                for (final seconds in _expiries)
                  GroupItem(
                    value: seconds,
                    label: switch (seconds) {
                      86400 => l.keyExpiryDays(1),
                      604800 => l.keyExpiryDays(7),
                      2592000 => l.keyExpiryDays(30),
                      _ => l.keyExpiryNever,
                    },
                  ),
              ],
              selected: _expiry,
              onSelected: (value) => setState(() => _expiry = value ?? -1),
            ),
          ]),
        ]),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, 0),
          child: InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
        ),
      FormActionBar(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.md),
        child: AppButton(label: l.create, icon: Icons.add_rounded, busy: _busy, expand: true, onPressed: _create),
      ),
    ]);
  }
}

/// A whole key, shown once: monospaced, its copy button under it; then
/// where to go from here — on to assigning its models, or done.
class _KeyShown extends StatelessWidget {
  const _KeyShown({required this.title, required this.subtitle, required this.secret, required this.done, this.assign});

  final String title;
  final String subtitle;
  final String secret;
  final VoidCallback done;
  final VoidCallback? assign;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(title, subtitle: subtitle),
        FormColumn(padding: const EdgeInsets.symmetric(horizontal: Gap.xl), children: [
          // Whole, every character of it on screen: a key cut off at the
          // edge reads as a shorter one.
          MonoBlock(secret, whole: true),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: l.copy,
              icon: Icons.copy_rounded,
              emphasis: ActionEmphasis.tonal,
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: secret)));
                showMessage(context, l.copied);
              },
            ),
          ),
          const SizedBox(height: Gap.sm),
          if (assign != null) ...[
            AppButton(label: l.keyAssign, icon: Icons.hub_outlined, expand: true, onPressed: assign),
            AppButton(label: l.done, emphasis: ActionEmphasis.quiet, expand: true, onPressed: done),
          ] else
            AppButton(label: l.done, expand: true, onPressed: done),
        ]),
      ]),
    );
  }
}

/// A key's whole value, after the phone was unlocked for it.
class KeyRevealSheet extends StatelessWidget {
  const KeyRevealSheet({super.key, required this.name, required this.secret});

  final String name;
  final String secret;

  @override
  Widget build(BuildContext context) => _KeyShown(
        title: context.l10n.keyRevealTitle(name),
        subtitle: context.l10n.keyRevealHint,
        secret: secret,
        done: () => Navigator.of(context).pop(),
      );
}

/// Ask for the phone's unlock before a key is shown whole: the same check
/// as the app lock (`LockScreen`).
Future<bool> unlockForKey(BuildContext context) => context.services.biometrics.authenticate(context.l10n.keyRevealReason);

/// Give a cloud key's models to the computer's agents (`cloud.assign`):
/// what the key may use is asked of the computer (`cloud.keys.models`, by
/// its id alone), then each model is ticked for the agents it goes to — an
/// agent at a time, as on the desktop.
class AssignSheet extends StatefulWidget {
  const AssignSheet({super.key, required this.keyId, required this.keyName});

  final int keyId;

  /// The key's name on the backend; empty for one with none — the computer
  /// then names the assignment itself.
  final String keyName;

  @override
  State<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<AssignSheet> {
  late final AppController _app = context.app;
  final TextEditingController _query = TextEditingController();
  List<String>? _models;
  Object? _error;

  /// The agents the computer can assign to; null until read.
  List<AgentStatus>? _agents;
  Object? _agentsError;
  String? _agent;

  /// Model → the agents it is ticked for.
  final Map<String, List<String>> _assign = {};
  bool _busy = false;
  String? _refusal;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAgents());
    unawaited(_loadModels());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    if (_agentsError != null) setState(() => _agentsError = null);
    try {
      final agents = await _app.agents();
      if (!mounted) return;
      setState(() {
        // The computer takes installed agents it can drive, and no other.
        final usable = _agents = [for (final agent in agents) if (agent.installed && agent.driven) agent];
        _agent ??= usable.firstOrNull?.id;
      });
    } catch (error) {
      // Not "none there": the list was not read.
      if (mounted) setState(() => _agentsError = error);
    }
  }

  Future<void> _loadModels() async {
    setState(() {
      _models = null;
      _error = null;
    });
    try {
      final result = await _app.config.cloudKeyModels(widget.keyId);
      if (!mounted) return;
      setState(() {
        if (result.ok) {
          _models = result.models;
        } else {
          _error = result.error ?? context.l10n.errUnknown('');
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  String _label(String agent) {
    final found = _agents?.where((candidate) => candidate.id == agent).firstOrNull;
    return found == null || found.label.isEmpty ? agent : found.label;
  }

  void _toggle(String model) {
    final agent = _agent;
    if (agent == null) return;
    final l = context.l10n;
    final agents = _assign[model] ?? const <String>[];
    if (!agents.contains(agent)) {
      final count = _assign.values.where((list) => list.contains(agent)).length;
      if (count >= SettingLimits.assignModels) {
        showMessage(context, l.assignTooMany(SettingLimits.assignModels));
        return;
      }
    }
    setState(() {
      final next = agents.contains(agent) ? [for (final a in agents) if (a != agent) a] : [...agents, agent];
      if (next.isEmpty) {
        _assign.remove(model);
      } else {
        _assign[model] = next;
      }
      _refusal = null;
    });
  }

  /// Take [agents] out of every model's ticks.
  void _untick(Set<String> agents) {
    for (final model in _assign.keys.toList()) {
      final left = [for (final agent in _assign[model]!) if (!agents.contains(agent)) agent];
      if (left.isEmpty) {
        _assign.remove(model);
      } else {
        _assign[model] = left;
      }
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final byAgent = <String, List<String>>{};
    for (final MapEntry(key: model, value: agents) in _assign.entries) {
      for (final agent in agents) {
        byAgent.putIfAbsent(agent, () => []).add(model);
      }
    }
    if (byAgent.isEmpty) {
      setState(() => _refusal = l.assignNoneSelected);
      return;
    }
    setState(() {
      _busy = true;
      _refusal = null;
    });
    final sent = byAgent.keys.toList();
    try {
      final result = await _app.config.cloudAssign(
        widget.keyId,
        [for (final MapEntry(:key, :value) in byAgent.entries) CloudAssignment(agent: key, models: value)],
        keyName: widget.keyName,
      );
      if (!mounted) return;
      if (result.ok) {
        Navigator.of(context).pop(result);
        return;
      }
      // Those made before the failure are kept, and said. The computer
      // makes them in the order sent, one an agent, and stops at the first
      // that fails: the first so many agents are done — untick them, or a
      // second confirm would make them twice.
      final error = result.error ?? l.errUnknown('');
      final made = [for (final name in result.providers) cloudAssignmentName(l, name)];
      setState(() {
        final done = sent.take(result.providers.length).toSet();
        _untick(done);
        if (done.contains(_agent)) _agent = sent.skip(done.length).firstOrNull ?? _agent;
        _refusal = made.isEmpty ? error : l.assignPartial(made.join(l.localeName.startsWith('zh') ? '、' : ', '), error);
      });
    } catch (error) {
      if (mounted) setState(() => _refusal = l.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final models = _models;
    final agents = _agents;
    final query = _query.text.trim().toLowerCase();
    final shown = [for (final model in models ?? const <String>[]) if (query.isEmpty || model.toLowerCase().contains(query)) model];
    final places = _assign.values.fold<int>(0, (sum, list) => sum + list.length);
    final agent = _agent;
    // What the list shows ticked: the models of the agent picked.
    final ticked = agent == null ? 0 : _assign.values.where((list) => list.contains(agent)).length;
    // Only the confirmation stays put: at large text the heading alone can
    // fill the sheet.
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: ListView(shrinkWrap: true, children: [
          // Named as the computer will name it: a key with none, its way.
          SheetHeader(l.assignTitle, subtitle: l.assignHint(widget.keyName.trim().isEmpty ? l.assignUnnamedKey : widget.keyName.trim())),
          FormColumn(padding: const EdgeInsets.symmetric(horizontal: Gap.xl), children: [
            if (agents == null && _agentsError == null)
              LoadingRow(l.assignAgentsLoading, padding: EdgeInsets.zero)
            else if (_agentsError != null)
              InlineBanner(
                title: l.assignAgentsFailed,
                message: l.error(_agentsError),
                action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, onPressed: _loadAgents),
              )
            else if (agents!.isEmpty)
              InlineBanner(tone: BannerTone.info, message: l.assignNoAgents)
            else ...[
              // A lone agent has no other to switch to.
              FieldLabel(l.assignTo, hint: agents.length > 1 ? l.assignToHint : l.assignToOnlyHint),
              ChoiceGroup<String>(
                items: [for (final a in agents) GroupItem(value: a.id, label: a.label.isEmpty ? a.id : a.label)],
                selected: agent,
                onSelected: (value) => setState(() => _agent = value ?? _agent),
              ),
            ],
            if (models != null && models.length > 8)
              SearchField(controller: _query, hint: l.assignSearch, onChanged: (_) => setState(() {})),
          ]),
          const SizedBox(height: Gap.sm),
          if (models == null && _error == null) LoadingRow(l.assignLoading),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.sm),
              child: InlineBanner(
                message: _error is String ? _error! as String : l.error(_error),
                action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, onPressed: _loadModels),
              ),
            ),
          if (models != null && models.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.sm),
              child: InlineBanner(tone: BannerTone.info, message: l.assignNoModels),
            ),
          for (final model in shown)
            CheckRow(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              mono: true,
              title: model,
              value: agent != null && (_assign[model]?.contains(agent) ?? false),
              onChanged: agent == null ? null : (_) => _toggle(model),
              subtitle: _assign[model] == null ? null : l.assignGoesTo(_assign[model]!.map(_label).join(', ')),
            ),
        ]),
      ),
      if (_refusal != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, 0),
          child: InlineBanner(message: _refusal!, onDismiss: () => setState(() => _refusal = null)),
        ),
      FormActionBar(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.md),
        // As many as the list shows ticked, for the agent it shows them for;
        // and all of them, each agent's.
        above: agent == null ? null : Text(l.assignSummary(_label(agent), ticked, places)),
        child: AppButton(
          label: l.assignConfirm,
          icon: Icons.check_rounded,
          expand: true,
          busy: _busy,
          onPressed: models == null || models.isEmpty || agents == null || agents.isEmpty ? null : _submit,
        ),
      ),
    ]);
  }
}

/// Confirm, then delete a cloud key on the backend.
Future<bool> deleteKey(BuildContext context, ApiKeyRow key) async {
  final l = context.l10n;
  final name = key.name.isEmpty ? l.keyUnnamed : key.name;
  final ok = await confirm(context, title: l.keyDeleteTitle(name), body: l.keyDeleteBody, action: l.delete, destructive: true);
  if (!ok || !context.mounted) return false;
  try {
    await context.app.backend.deleteToken(key.id);
    return true;
  } catch (error) {
    if (context.mounted) showMessage(context, l.error(error));
    return false;
  }
}
