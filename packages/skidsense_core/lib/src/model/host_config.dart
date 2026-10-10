import '../util/json.dart';
import '../util/web_url.dart';

// The desktop's model and account settings as `skidsense-rc/1` carries them
// (spec §7.1), decoded as leniently as desktop.dart: unknown keys are
// ignored, absent fields default, and a value of the wrong type reads as
// absent. Kinds and sources stay strings, as the desktop keeps adding them.

/// The wire dialects of a local account's endpoints — `Dialect` in
/// `src/shared/accounts.ts`.
abstract final class Dialects {
  static const anthropic = 'anthropic';
  static const openaiResponses = 'openai-responses';
  static const openaiChat = 'openai-chat';
  static const gemini = 'gemini';

  static const all = [anthropic, openaiResponses, openaiChat, gemini];
}

/// The machine-readable `code` of an `ok:false` (spec §7.1). Any other value
/// is read as no code at all.
abstract final class SettingCodes {
  /// The account was changed elsewhere since it was read: load it again.
  static const conflict = 'conflict';

  /// A stored key would go to another server: type the key again, or clear it.
  static const keyRequired = 'key-required';

  // `models.discover`'s failures.
  static const http = 'http';
  static const timeout = 'timeout';
  static const network = 'network';
  static const notJson = 'not-json';
  static const empty = 'empty';
  static const tooLarge = 'too-large';

  static const known = {conflict, keyRequired, http, timeout, network, notJson, empty, tooLarge};

  static String? read(String? code) => known.contains(code) ? code : null;
}

/// What a device may send, and what it is sent at most (spec §7.1, §13). The
/// host refuses more as `bad-request` — while its own window keeps none of
/// these limits, so an account made there (a fetched list of 3000 models, a
/// long name) can reach the phone over them: see [AccountGroupInput.problems].
abstract final class SettingLimits {
  /// An account's name, once trimmed.
  static const name = 100;
  static const note = 2000;
  static const apiKey = 4096;
  static const endpoints = 4;
  static const baseUrl = 2048;

  /// Models one endpoint saves. `models.discover` may find up to
  /// [discovered]: the user picks which to keep, as many as this.
  static const models = 1000;

  /// A model id, once trimmed (and at least one character).
  static const modelId = 200;
  static const extraEnv = 32;
  static const envName = 128;
  static const envValue = 4096;

  /// A window `models.context.set` sets, in tokens.
  static const windowMin = 1000;
  static const windowMax = 100000000;

  /// What `models.discover` finds at most (more is `truncated`).
  static const discovered = 5000;

  /// What `cloud.keys.models` lists at most.
  static const keyModels = 5000;

  /// `cloud.assign`: agents in one call, and models for each — fewer than a
  /// key may list ([keyModels]): the user picks.
  static const assignAgents = 16;
  static const assignModels = 500;
  static const keyName = 100;

  /// A revision sent back, and how many one save sends at most: the
  /// group's, and one per old endpoint it takes in, as many as it has
  /// endpoints (`revisionParam` in the desktop's `dispatch-settings.ts`).
  static const revision = 64;
  static const revisions = 5;
}

/// One reason the host would refuse an [AccountGroupInput] (spec §7.1).
class AccountInputProblem {
  const AccountInputProblem(this.field, this.kind, {this.dialect, this.limit, this.value});

  /// The parameter at fault: `name`, `note`, `apiKey`, `endpoints`,
  /// `dialect`, `baseUrl`, `models`, `modelMap`, `extraEnv`,
  /// `contextWindows` or `revision`.
  final String field;
  final AccountInputFault kind;

  /// The endpoint's protocol, for a field of one.
  final String? dialect;

  /// The limit it is over ([SettingLimits]).
  final int? limit;

  /// The model id, slot or variable name at fault, when it is one of many.
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is AccountInputProblem &&
      other.field == field &&
      other.kind == kind &&
      other.dialect == dialect &&
      other.limit == limit &&
      other.value == value;

  @override
  int get hashCode => Object.hash(field, kind, dialect, limit, value);

  @override
  String toString() => 'AccountInputProblem($field, ${kind.name}, dialect: $dialect, limit: $limit, value: $value)';
}

enum AccountInputFault {
  /// More characters than [AccountInputProblem.limit].
  tooLong,

  /// More entries than [AccountInputProblem.limit].
  tooMany,

  /// A model id that is only blank; an endpoint with no protocol chosen (an
  /// old endpoint has none until one is).
  empty,

  /// A control character (in a base URL, any whitespace); for `apiKey`,
  /// anything but printable ASCII.
  invalid,

  /// A context window outside 1 to [AccountInputProblem.limit] tokens.
  outOfRange,

  // The desktop's own rules (`accountProblem`, [AccountGroupInput.accountProblems]):

  /// Nothing where something is needed: a blank name, no protocol turned on
  /// (`endpoints`), a blank base URL, no model on Codex's endpoint
  /// (`models`, of `openai-responses`).
  missing,

  /// A protocol with two endpoints ([AccountInputProblem.value]).
  duplicate,

  /// A base URL that is no address as the URL Standard parses one (the
  /// desktop's `new URL`): no scheme, no host, a port past 65535, a host
  /// that is no domain or IP address.
  notAddress,

  /// A base URL of a scheme other than http or https.
  notHttp,

  /// A variable ([AccountInputProblem.value]) not named as one: capital
  /// letters, digits and underscores, starting with a letter.
  badName,

  /// A variable ([AccountInputProblem.value]) the route itself sets — the
  /// endpoint, the credential, the process's reach — which an account may
  /// not override.
  reserved,
}

/// C0, DEL and C1: what a name, a model id or a variable may not hold.
final _control = RegExp(r'[\u0000-\u001f\u007f-\u009f]');

/// `extraEnvProblem` in the desktop's `src/shared/accounts.ts`: the shape of
/// a variable's name, and the names the route owns.
final _envName = RegExp(r'^[A-Z][A-Z0-9_]*$');
final _envDenied = RegExp(
  r'^(ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN|PATH|HOME|NODE_OPTIONS|HTTPS?_PROXY|ALL_PROXY|NO_PROXY|.*_TOKEN|.*_KEY|.*_SECRET)$',
  caseSensitive: false,
);

/// The same, minus line feed and tab: what a note may not hold.
final _controlInNote = RegExp(r'[\u0000-\u0008\u000b-\u001f\u007f-\u009f]');
final _secret = RegExp(r'^[\x21-\x7e]+$');

Map<String, String> _stringMap(Object? json) => {
      if (json is Map<String, Object?>)
        for (final entry in json.entries)
          if (entry.value is String) entry.key: entry.value as String,
    };

Map<String, int> _intMap(Object? json) => {
      if (json is Map<String, Object?>)
        for (final entry in json.entries)
          if (entry.value is num) entry.key: (entry.value as num).toInt(),
    };

/// Which model each of a harness's slots asks for. Claude Code uses all
/// five; every other harness only [main].
class ModelMap {
  const ModelMap({this.main, this.sonnet, this.opus, this.haiku, this.subagent});

  factory ModelMap.fromJson(Map<String, Object?> j) => ModelMap(
        main: j.str('main'),
        sonnet: j.str('sonnet'),
        opus: j.str('opus'),
        haiku: j.str('haiku'),
        subagent: j.str('subagent'),
      );

  final String? main;
  final String? sonnet;
  final String? opus;
  final String? haiku;
  final String? subagent;

  /// The slots that are set, trimmed; [mainOnly] for an endpoint that is not
  /// Anthropic's, where the others do nothing.
  Map<String, String> toJson({bool mainOnly = false}) => {
        for (final (slot, value) in [
          ('main', main),
          if (!mainOnly) ...[('sonnet', sonnet), ('opus', opus), ('haiku', haiku), ('subagent', subagent)],
        ])
          if (value != null && value.trim().isNotEmpty) slot: value.trim(),
      };
}

/// `AccountChoice`: which account a harness runs on.
class AccountChoice {
  const AccountChoice._(this.kind, [this.providerId]);

  /// Nothing injected: the CLI's own configuration decides (the default).
  const AccountChoice.cli() : this._('cli');

  /// The vendor's subscription login, over the CLI's own settings (Claude only).
  const AccountChoice.official() : this._('official');

  const AccountChoice.account(String providerId) : this._('account', providerId);

  /// An unknown kind is kept as it came; the UI shows it as neither.
  factory AccountChoice.fromJson(Map<String, Object?> j) => AccountChoice._(j.str('kind') ?? 'cli', j.str('providerId'));

  /// `cli`, `official` or `account`.
  final String kind;
  final String? providerId;

  Map<String, Object?> toJson() => {'kind': kind, 'providerId': ?providerId};

  @override
  bool operator ==(Object other) => other is AccountChoice && other.kind == kind && other.providerId == providerId;

  @override
  int get hashCode => Object.hash(kind, providerId);
}

/// One provider row — `ProviderProfile` in `src/store/providers.ts`, with
/// [hasKey] in place of the key, which never leaves the desktop.
class ProviderProfile {
  const ProviderProfile({
    this.id = '',
    this.name = '',
    this.note = '',
    this.kind = '',
    this.agents = const [],
    this.baseUrl = '',
    this.models = const [],
    this.hasKey = false,
    this.source = 'byok',
    this.createdAt = 0,
    this.dialect,
    this.groupId,
    this.presetId,
    this.modelMap,
    this.extraEnv,
    this.relayAuth,
    this.contextWindows,
  });

  factory ProviderProfile.fromJson(Map<String, Object?> j) => ProviderProfile(
        id: j.str('id') ?? '',
        name: j.str('name') ?? '',
        note: j.str('note') ?? '',
        kind: j.str('kind') ?? '',
        agents: j.strings('agents'),
        baseUrl: j.str('baseUrl') ?? '',
        models: j.strings('models'),
        hasKey: j.boolean('hasKey') ?? false,
        source: j.str('source') ?? 'byok',
        createdAt: j.number('createdAt') ?? 0,
        dialect: j.str('dialect'),
        groupId: j.str('groupId'),
        presetId: j.str('presetId'),
        modelMap: j.object('modelMap', ModelMap.fromJson),
        extraEnv: j['extraEnv'] is Map ? _stringMap(j['extraEnv']) : null,
        relayAuth: j.str('relayAuth'),
        contextWindows: j['contextWindows'] is Map ? _intMap(j['contextWindows']) : null,
      );

  final String id;
  final String name;
  final String note;

  /// `anthropic`, `openai-compatible` or `google`.
  final String kind;

  /// Which agents may use it; empty means all of them.
  final List<String> agents;
  final String baseUrl;
  final List<String> models;
  final bool hasKey;

  /// `byok` (an account or an old endpoint) or `first-party` (a cloud assignment).
  final String source;
  final int createdAt;

  /// A local account's protocol; an old endpoint has none.
  final String? dialect;

  /// Shared by the rows of one account, one per protocol.
  final String? groupId;
  final String? presetId;
  final ModelMap? modelMap;

  /// Only on Anthropic rows.
  final Map<String, String>? extraEnv;
  final String? relayAuth;
  final Map<String, int>? contextWindows;

  bool get firstParty => source == 'first-party';

  /// A byok row of no account: an endpoint from before accounts.
  bool get legacy => !firstParty && groupId == null;

  bool servesAgent(String agent) => agents.isEmpty || agents.contains(agent);
}

/// One account-capable harness, in `HARNESS_DIALECT` order.
class HarnessInfo {
  const HarnessInfo({
    this.agent = '',
    this.label = '',
    this.dialect = '',
    this.official = false,
    this.installed = false,
    this.driven = false,
  });

  factory HarnessInfo.fromJson(Map<String, Object?> j) => HarnessInfo(
        agent: j.str('agent') ?? '',
        label: j.str('label') ?? '',
        dialect: j.str('dialect') ?? '',
        official: j.boolean('official') ?? false,
        installed: j.boolean('installed') ?? false,
        driven: j.boolean('driven') ?? false,
      );

  final String agent;
  final String label;
  final String dialect;

  /// Whether it can be forced back onto the vendor's own login.
  final bool official;
  final bool installed;
  final bool driven;
}

/// The rows of one account as `accounts.list` gives them: every protocol
/// endpoint of one group, or a single old endpoint. [key] is what
/// [AccountsSnapshot.revisions] is keyed by.
class AccountGroup {
  const AccountGroup({required this.key, this.groupId, this.rows = const [], this.revision});

  final String key;
  final String? groupId;
  final List<ProviderProfile> rows;
  final String? revision;

  ProviderProfile get first => rows.first;
  String get name => first.name;
  String get note => first.note;
  String? get presetId => first.presetId;
  bool get hasKey => rows.any((row) => row.hasKey);
}

/// `accounts.list`.
class AccountsSnapshot {
  const AccountsSnapshot({
    this.providers = const [],
    this.active = const {},
    this.harnesses = const [],
    this.revisions = const {},
  });

  factory AccountsSnapshot.fromJson(Map<String, Object?> j) => AccountsSnapshot(
        providers: j.objects('providers', ProviderProfile.fromJson),
        active: {
          for (final entry in (j.obj('active') ?? const {}).entries)
            if (entry.value is Map<String, Object?>) entry.key: AccountChoice.fromJson(entry.value as Map<String, Object?>),
        },
        harnesses: j.objects('harnesses', HarnessInfo.fromJson),
        revisions: _stringMap(j['revisions']),
      );

  /// Every row: accounts, old endpoints, cloud assignments.
  final List<ProviderProfile> providers;
  final Map<String, AccountChoice> active;
  final List<HarnessInfo> harnesses;

  /// Per byok account: by `groupId`, or an old endpoint's own id. Opaque —
  /// sent back as it came with an edit or a removal (spec §7.1).
  final Map<String, String> revisions;

  AccountChoice choiceFor(String agent) => active[agent] ?? const AccountChoice.cli();

  List<ProviderProfile> get cloud => [for (final row in providers) if (row.firstParty) row];

  /// The byok rows, one entry per account, in the order their first rows came.
  List<AccountGroup> get accounts {
    final rows = <String, List<ProviderProfile>>{};
    for (final row in providers) {
      if (row.firstParty) continue;
      rows.putIfAbsent(row.groupId ?? row.id, () => []).add(row);
    }
    return [
      for (final MapEntry(:key, :value) in rows.entries)
        AccountGroup(key: key, groupId: value.first.groupId, rows: value, revision: revisions[key]),
    ];
  }
}

/// One endpoint of an `AccountPreset`.
class PresetEndpoint {
  const PresetEndpoint({
    this.dialect = '',
    this.baseUrl = '',
    this.models = const [],
    this.modelMap,
    this.extraEnv,
    this.modelsUrl,
    this.origin = '',
  });

  factory PresetEndpoint.fromJson(Map<String, Object?> j) => PresetEndpoint(
        dialect: j.str('dialect') ?? '',
        baseUrl: j.str('baseUrl') ?? '',
        models: j.strings('models'),
        modelMap: j.object('modelMap', ModelMap.fromJson),
        extraEnv: j['extraEnv'] is Map ? _stringMap(j['extraEnv']) : null,
        modelsUrl: j.str('modelsUrl'),
        origin: j.str('origin') ?? '',
      );

  final String dialect;
  final String baseUrl;
  final List<String> models;
  final ModelMap? modelMap;
  final Map<String, String>? extraEnv;
  final String? modelsUrl;

  /// `cc-switch` or `skidsense`: where the preset came from (the notice).
  final String origin;
}

/// A vendor's account template — `AccountPreset` in `src/shared/account-presets.ts`.
class AccountPreset {
  const AccountPreset({this.id = '', this.name = '', this.websiteUrl = '', this.category = '', this.endpoints = const []});

  factory AccountPreset.fromJson(Map<String, Object?> j) => AccountPreset(
        id: j.str('id') ?? '',
        name: j.str('name') ?? '',
        websiteUrl: j.str('websiteUrl') ?? '',
        category: j.str('category') ?? '',
        endpoints: j.objects('endpoints', PresetEndpoint.fromJson),
      );

  final String id;
  final String name;
  final String websiteUrl;

  /// `cn_official`, `aggregator` or `custom`.
  final String category;
  final List<PresetEndpoint> endpoints;
}

/// `accounts.presets`: the presets, and the licence notice that must be
/// visible wherever they are shown.
class PresetCatalog {
  const PresetCatalog({this.presets = const [], this.notice = ''});

  factory PresetCatalog.fromJson(Map<String, Object?> j) =>
      PresetCatalog(presets: j.objects('presets', AccountPreset.fromJson), notice: j.str('notice') ?? '');

  final List<AccountPreset> presets;
  final String notice;
}

/// One model `models.discover` found.
class DiscoveredModel {
  const DiscoveredModel({this.id = '', this.name, this.contextLength});

  factory DiscoveredModel.fromJson(Map<String, Object?> j) =>
      DiscoveredModel(id: j.str('id') ?? '', name: j.str('name'), contextLength: j.number('contextLength'));

  final String id;
  final String? name;
  final int? contextLength;
}

/// One harness that can run a [ModelContextRow]'s model.
class ContextAgent {
  const ContextAgent({this.agent = '', this.label = '', this.support = ''});

  factory ContextAgent.fromJson(Map<String, Object?> j) =>
      ContextAgent(agent: j.str('agent') ?? '', label: j.str('label') ?? '', support: j.str('support') ?? '');

  final String agent;
  final String label;

  /// How it takes the threshold: `native`, `managed` or `unsupported`.
  final String support;
}

class ContextGroup {
  const ContextGroup({this.kind = '', this.id = '', this.label = ''});

  factory ContextGroup.fromJson(Map<String, Object?> j) =>
      ContextGroup(kind: j.str('kind') ?? '', id: j.str('id') ?? '', label: j.str('label') ?? '');

  /// `cloud`, `account` or `cli`.
  final String kind;
  final String id;
  final String label;
}

/// One model on 上下文与自动压缩 — `ModelContextRow` in `src/shared/model-windows.ts`.
class ModelContextRow {
  const ModelContextRow({
    this.key = '',
    this.group = const ContextGroup(),
    this.modelId = '',
    this.label = '',
    this.window = 0,
    this.windowSource = '',
    this.compactAt,
    this.agents = const [],
  });

  factory ModelContextRow.fromJson(Map<String, Object?> j) => ModelContextRow(
        key: j.str('key') ?? '',
        group: j.object('group', ContextGroup.fromJson) ?? const ContextGroup(),
        modelId: j.str('modelId') ?? '',
        label: j.str('label') ?? '',
        window: j.number('window') ?? 0,
        windowSource: j.str('windowSource') ?? '',
        compactAt: j.number('compactAt'),
        agents: j.objects('agents', ContextAgent.fromJson),
      );

  /// What `models.context.set` takes.
  final String key;
  final ContextGroup group;

  /// Empty for a CLI's default model.
  final String modelId;
  final String label;
  final int window;

  /// `custom`, `discovered`, `preset`, `known` or `estimate`.
  final String windowSource;

  /// Null: the harness decides when to compact.
  final int? compactAt;
  final List<ContextAgent> agents;
}

/// `models.context.list` and `models.context.set`: the rows, and the range a
/// threshold may take.
class ModelContextList {
  const ModelContextList({this.rows = const [], this.compactMin = 10000, this.compactMax = 5000000});

  factory ModelContextList.fromJson(Map<String, Object?> j) => ModelContextList(
        rows: j.objects('rows', ModelContextRow.fromJson),
        compactMin: j.number('compactMin') ?? 10000,
        compactMax: j.number('compactMax') ?? 5000000,
      );

  final List<ModelContextRow> rows;
  final int compactMin;
  final int compactMax;
}

/// One entry of the composer's `/` menu — `SlashCommand` in `src/core/slash.ts`.
class SlashCommand {
  const SlashCommand({
    required this.name,
    this.description,
    this.argumentHint,
    this.aliases = const [],
    this.source = 'builtin',
    this.scope,
    this.store,
  });

  factory SlashCommand.fromJson(Map<String, Object?> j) => SlashCommand(
        name: j.str('name') ?? '',
        description: j.str('description'),
        argumentHint: j.str('argumentHint'),
        aliases: j.strings('aliases'),
        source: j.str('source') ?? 'builtin',
        scope: j.str('scope'),
        store: j.str('store'),
      );

  final String name;
  final String? description;
  final String? argumentHint;

  /// Other names the harness takes for it.
  final List<String> aliases;

  /// `builtin`, `command` (a file the user wrote) or `skill`.
  final String source;

  /// For a command file: `workspace` or `global`.
  final String? scope;

  /// For a skill listed beside the CLI's own: `skidsense`, `claude`, `agents` or `codex`.
  final String? store;
}

/// One protocol endpoint of an account being saved.
class AccountEndpointInput {
  const AccountEndpointInput({
    this.id,
    required this.dialect,
    required this.baseUrl,
    this.models = const [],
    this.modelMap,
    this.extraEnv,
    this.contextWindows,
  });

  /// The row as stored, to be saved again: every field the save would
  /// otherwise drop carried back. An old endpoint has no protocol: one must
  /// be chosen before it is saved ([AccountGroupInput.problems]).
  factory AccountEndpointInput.fromRow(ProviderProfile row) => AccountEndpointInput(
        id: row.id,
        dialect: (row.dialect?.isEmpty ?? true) ? null : row.dialect,
        baseUrl: row.baseUrl,
        models: row.models,
        modelMap: row.modelMap,
        extraEnv: row.extraEnv,
      );

  /// The row edited, or an old endpoint to fold into the account.
  final String? id;

  /// One of [Dialects]; null until one is chosen — the host refuses an
  /// endpoint with none.
  final String? dialect;
  final String baseUrl;
  final List<String> models;
  final ModelMap? modelMap;

  /// Anthropic endpoints only.
  final Map<String, String>? extraEnv;

  /// Null keeps the row's stored windows (those of models it still lists).
  /// Only the windows of models in [models] go out — those the endpoint
  /// reported for models not kept mean nothing — and only those of
  /// 1–[SettingLimits.windowMax] tokens: the host refuses the whole save
  /// over any other.
  final Map<String, int>? contextWindows;

  bool get _anthropic => dialect == Dialects.anthropic;

  /// The extra environment as sent: an Anthropic endpoint's alone.
  Map<String, String>? get _sentEnv => _anthropic && extraEnv != null && extraEnv!.isNotEmpty ? extraEnv : null;

  /// The host compares a window's model with the ids it keeps, trimmed.
  Set<String> get _listed => {for (final id in models) id.trim()};

  static bool _windowFits(int size) => size >= 1 && size <= SettingLimits.windowMax;

  /// The windows as sent ([contextWindows]).
  Map<String, int>? get _sentWindows {
    final windows = contextWindows;
    if (windows == null) return null;
    final listed = _listed;
    return {
      for (final MapEntry(key: model, value: size) in windows.entries)
        if (listed.contains(model) && _windowFits(size)) model: size,
    };
  }

  List<AccountInputProblem> _problems() {
    final found = <AccountInputProblem>[];
    void add(String field, AccountInputFault kind, {int? limit, String? value}) =>
        found.add(AccountInputProblem(field, kind, dialect: dialect, limit: limit, value: value));
    // [id] as it goes out: a model list as it is, a slot trimmed.
    void model(String field, String id, String value) {
      final trimmed = id.trim();
      if (_control.hasMatch(id)) {
        add(field, AccountInputFault.invalid, value: value);
      } else if (trimmed.isEmpty) {
        add(field, AccountInputFault.empty, value: value);
      } else if (trimmed.length > SettingLimits.modelId) {
        add(field, AccountInputFault.tooLong, limit: SettingLimits.modelId, value: value);
      }
    }

    if (dialect?.isEmpty ?? true) add('dialect', AccountInputFault.empty);
    if (baseUrl.length > SettingLimits.baseUrl) add('baseUrl', AccountInputFault.tooLong, limit: SettingLimits.baseUrl);
    if (RegExp(r'\s').hasMatch(baseUrl) || _control.hasMatch(baseUrl)) add('baseUrl', AccountInputFault.invalid);
    if (models.length > SettingLimits.models) add('models', AccountInputFault.tooMany, limit: SettingLimits.models);
    for (final id in models) {
      model('models', id, id);
    }
    for (final MapEntry(key: slot, value: id) in (modelMap?.toJson(mainOnly: !_anthropic) ?? const {}).entries) {
      model('modelMap', id, slot);
    }
    final env = _sentEnv;
    if (env != null) {
      if (env.length > SettingLimits.extraEnv) add('extraEnv', AccountInputFault.tooMany, limit: SettingLimits.extraEnv);
      for (final MapEntry(key: name, value: value) in env.entries) {
        if (_control.hasMatch(name) || _control.hasMatch(value)) {
          add('extraEnv', AccountInputFault.invalid, value: name);
        } else if (name.length > SettingLimits.envName) {
          add('extraEnv', AccountInputFault.tooLong, limit: SettingLimits.envName, value: name);
        } else if (value.length > SettingLimits.envValue) {
          add('extraEnv', AccountInputFault.tooLong, limit: SettingLimits.envValue, value: name);
        }
      }
    }
    // A window outside the range is left out of the save: said here, as the
    // model would then save without it. One of a model not kept is moot.
    final listed = _listed;
    for (final MapEntry(key: model, value: size) in (contextWindows ?? const <String, int>{}).entries) {
      if (listed.contains(model) && !_windowFits(size)) {
        add('contextWindows', AccountInputFault.outOfRange, limit: SettingLimits.windowMax, value: model);
      }
    }
    return found;
  }

  /// `accountProblem`'s rules for one endpoint: [seen] the protocols of
  /// those before it. One of no protocol is [_problems]' to say; so is a base
  /// URL with a space or a control character in it, not said again here as
  /// no address.
  List<AccountInputProblem> _accountProblems(Set<String> seen) {
    final chosen = dialect;
    if (chosen == null || chosen.isEmpty) return const [];
    final found = <AccountInputProblem>[];
    void add(String field, AccountInputFault kind, {String? value}) =>
        found.add(AccountInputProblem(field, kind, dialect: chosen, value: value));
    if (!Dialects.all.contains(chosen)) {
      add('dialect', AccountInputFault.invalid, value: chosen);
      return found;
    }
    if (!seen.add(chosen)) add('dialect', AccountInputFault.duplicate, value: chosen);
    // The host parses it trimmed, as the URL Standard does
    // (`new URL(baseUrl.trim())`): what that takes is taken here.
    final url = baseUrl.trim();
    if (url.isEmpty) {
      add('baseUrl', AccountInputFault.missing);
    } else if (!RegExp(r'\s').hasMatch(url) && !_control.hasMatch(url)) {
      switch (webUrlKind(url)) {
        case WebUrlKind.invalid:
          add('baseUrl', AccountInputFault.notAddress);
        case WebUrlKind.other:
          add('baseUrl', AccountInputFault.notHttp);
        case WebUrlKind.http:
          break;
      }
    }
    // Without one, Codex would ask this endpoint for whatever model its own
    // configuration names — another vendor's id.
    final hasModel = models.any((id) => id.trim().isNotEmpty) || (modelMap?.main?.trim().isNotEmpty ?? false);
    if (chosen == Dialects.openaiResponses && !hasModel) add('models', AccountInputFault.missing);
    // What is sent: an Anthropic endpoint's alone.
    for (final name in (_sentEnv ?? const <String, String>{}).keys) {
      if (!_envName.hasMatch(name)) {
        add('extraEnv', AccountInputFault.badName, value: name);
      } else if (_envDenied.hasMatch(name)) {
        add('extraEnv', AccountInputFault.reserved, value: name);
      }
    }
    return found;
  }

  AccountEndpointInput _withId(String id) => AccountEndpointInput(
        id: id,
        dialect: dialect,
        baseUrl: baseUrl,
        models: models,
        modelMap: modelMap,
        extraEnv: extraEnv,
        contextWindows: contextWindows,
      );

  /// Throws [StateError] with no [dialect]: check [AccountGroupInput.problems]
  /// first.
  Map<String, Object?> toJson() {
    final chosen = dialect;
    if (chosen == null || chosen.isEmpty) throw StateError('an endpoint with no protocol: choose one before saving');
    final map = modelMap?.toJson(mainOnly: !_anthropic);
    return {
      'id': ?id,
      'dialect': chosen,
      'baseUrl': baseUrl,
      'models': models,
      if (map != null && map.isNotEmpty) 'modelMap': map,
      'extraEnv': ?_sentEnv,
      'contextWindows': ?_sentWindows,
    };
  }
}

/// `accounts.saveGroup`'s parameters. Everything but [apiKey] and the
/// endpoints' `contextWindows` replaces what is stored: an edit that leaves
/// [note] or [presetId] out clears them (spec §7.1) — start an edit from
/// [AccountGroupInput.fromGroup].
class AccountGroupInput {
  const AccountGroupInput({
    this.groupId,
    this.revision,
    this.revisions,
    required this.name,
    this.note = '',
    this.presetId,
    this.apiKey,
    this.endpoints = const [],
  });

  /// The account as stored, ready to be changed and saved back. A preset
  /// [presets] (`accounts.presets`) does not list — one a later desktop
  /// dropped — is left out: the host refuses a save naming it, and has
  /// nothing of it to use. Without [presets] it is kept as stored.
  ///
  /// What else was stored can be over a remote limit: check [problems].
  factory AccountGroupInput.fromGroup(AccountGroup group, {PresetCatalog? presets}) {
    final presetId = group.presetId;
    final known = presets == null || presets.presets.any((preset) => preset.id == presetId);
    return AccountGroupInput(
      groupId: group.groupId,
      revision: group.revision,
      name: group.name,
      note: group.note,
      presetId: known ? presetId : null,
      endpoints: [for (final row in group.rows) AccountEndpointInput.fromRow(row)],
    );
  }

  /// Editing an account; null makes a new one.
  final String? groupId;

  /// What `accounts.list` said for this account; required when editing.
  /// Sent only with a save that writes over what it was read for (spec
  /// §7): the group, or an old endpoint taken in by its id. An old endpoint
  /// whose protocol was turned off is left as it is and the save makes a new
  /// account, where a revision would be refused as stale — after every
  /// reload too. `editRevision` in the desktop's `src/shared/accounts.ts`.
  final String? revision;

  /// In place of [revision], for a save that writes over more than one
  /// account: the group's revision (with [groupId]) and each old endpoint's
  /// it takes in, as `accounts.list` gave them — an endpoint taken into a
  /// group is written over as much as the group, and sending the group's
  /// alone is a `conflict`. The host compares them as a set, so in any
  /// order, and any one changed elsewhere is a `conflict` (spec §7). 1 to
  /// [SettingLimits.revisions] of them; an empty list sends [revision].
  final List<String>? revisions;
  final String name;
  final String note;
  final String? presetId;

  /// Null keeps the stored key, `''` clears it, anything else sets it.
  final String? apiKey;
  final List<AccountEndpointInput> endpoints;

  AccountGroupInput copyWith({
    Object? revision = _unset,
    Object? revisions = _unset,
    String? name,
    String? note,
    Object? presetId = _unset,
    Object? apiKey = _unset,
    List<AccountEndpointInput>? endpoints,
  }) =>
      AccountGroupInput(
        groupId: groupId,
        revision: identical(revision, _unset) ? this.revision : revision as String?,
        revisions: identical(revisions, _unset) ? this.revisions : revisions as List<String>?,
        name: name ?? this.name,
        note: note ?? this.note,
        presetId: identical(presetId, _unset) ? this.presetId : presetId as String?,
        apiKey: identical(apiKey, _unset) ? this.apiKey : apiKey as String?,
        endpoints: endpoints ?? this.endpoints,
      );

  /// This account as saving it left it — [result] is that save's answer —
  /// to edit on without reading `accounts.list` again (spec §7): with its
  /// group (a new account has one only now; a revision sent without it makes
  /// a new account again, refused as stale), its new revision, each
  /// endpoint's row, and the key now stored kept. A refusal saved nothing:
  /// this, as it is.
  AccountGroupInput afterSave(SaveGroupResult result) {
    if (!result.ok) return this;
    final ids = result.ids.length == endpoints.length ? result.ids : null;
    return AccountGroupInput(
      groupId: result.groupId ?? groupId,
      revision: result.revision,
      name: name,
      note: note,
      presetId: presetId,
      endpoints: [
        for (final (index, endpoint) in endpoints.indexed)
          ids == null ? endpoint : endpoint._withId(ids[index]),
      ],
    );
  }

  /// Why the host would refuse this as it is (spec §7.1), field by field;
  /// empty when nothing would. Its window keeps none of these limits, so an
  /// account read back whole can already be over one: the editor says which
  /// before saving — a list it trims on its own would save less than the
  /// user sees. An old endpoint taken in has no protocol until one is
  /// chosen; a context window out of range is not refused but left out
  /// ([AccountEndpointInput.contextWindows]), and said here for that. The
  /// rest (a blank name, a base URL that is no address) is
  /// [accountProblems]'.
  List<AccountInputProblem> get problems {
    final found = <AccountInputProblem>[];
    void add(String field, AccountInputFault kind, {int? limit}) => found.add(AccountInputProblem(field, kind, limit: limit));

    if (name.trim().length > SettingLimits.name) add('name', AccountInputFault.tooLong, limit: SettingLimits.name);
    if (_control.hasMatch(name)) add('name', AccountInputFault.invalid);
    if (note.length > SettingLimits.note) add('note', AccountInputFault.tooLong, limit: SettingLimits.note);
    if (_controlInNote.hasMatch(note)) add('note', AccountInputFault.invalid);
    final key = apiKey;
    if (key != null && key.isNotEmpty) {
      if (key.length > SettingLimits.apiKey) {
        add('apiKey', AccountInputFault.tooLong, limit: SettingLimits.apiKey);
      } else if (!_secret.hasMatch(key)) {
        add('apiKey', AccountInputFault.invalid);
      }
    }
    if (endpoints.length > SettingLimits.endpoints) add('endpoints', AccountInputFault.tooMany, limit: SettingLimits.endpoints);
    for (final endpoint in endpoints) {
      found.addAll(endpoint._problems());
    }
    // What `accounts.list` gave fits; anything else is refused whole as
    // `bad-request` (`revisionParam`).
    final read = switch (_sentRevision) {
      final List<String> several => several,
      final String one => [one],
      _ => const <String>[],
    };
    if (read.length > SettingLimits.revisions) add('revision', AccountInputFault.tooMany, limit: SettingLimits.revisions);
    for (final revision in read) {
      if (_control.hasMatch(revision)) {
        add('revision', AccountInputFault.invalid);
      } else if (revision.length > SettingLimits.revision) {
        add('revision', AccountInputFault.tooLong, limit: SettingLimits.revision);
      }
    }
    return found;
  }

  /// What the desktop's `accountProblem` (`src/shared/accounts.ts`, which
  /// the host runs on every save) would refuse: a blank name, no protocol
  /// turned on, a protocol twice, a base URL that is no http(s) address,
  /// Codex's endpoint without a model, a variable not named as one or one
  /// the route sets itself. The host answers the first of them with a
  /// sentence in its own words; these are each field's, for the user's.
  /// Empty when it would take it — but for [problems], which are not
  /// repeated here.
  List<AccountInputProblem> get accountProblems {
    final found = <AccountInputProblem>[
      if (name.trim().isEmpty) const AccountInputProblem('name', AccountInputFault.missing),
      if (endpoints.isEmpty) const AccountInputProblem('endpoints', AccountInputFault.missing),
    ];
    final seen = <String>{};
    for (final endpoint in endpoints) {
      found.addAll(endpoint._accountProblems(seen));
    }
    return found;
  }

  bool get _writesOver => groupId != null || endpoints.any((endpoint) => endpoint.id != null);

  /// `revision` as sent: the list when there is one, else the one. Only a
  /// save that writes over something sends either.
  Object? get _sentRevision {
    if (!_writesOver) return null;
    final several = revisions;
    return several != null && several.isNotEmpty ? several : revision;
  }

  Map<String, Object?> toJson() => {
        'groupId': ?groupId,
        'revision': ?_sentRevision,
        'name': name,
        'note': note,
        'presetId': ?presetId,
        'apiKey': ?apiKey,
        'endpoints': [for (final endpoint in endpoints) endpoint.toJson()],
      };
}

const _unset = Object();

/// One agent's share of a cloud key's models (`cloud.assign`): 1 to
/// [SettingLimits.assignModels] of them, for at most
/// [SettingLimits.assignAgents] agents a call.
class CloudAssignment {
  const CloudAssignment({required this.agent, required this.models});

  final String agent;
  final List<String> models;

  Map<String, Object?> toJson() => {'agent': agent, 'models': models};
}

/// A settings method's `{ok:true,…} | {ok:false, error, code?}` (spec §7.1):
/// `ok:false` is the desktop declining, [error] its sentence to show as it
/// is, [code] what a screen may act on ([SettingCodes]).
class SettingResult {
  const SettingResult({this.ok = false, this.error, this.code});

  factory SettingResult.fromJson(Map<String, Object?> j) =>
      SettingResult(ok: j.boolean('ok') ?? false, error: j.str('error'), code: SettingCodes.read(j.str('code')));

  final bool ok;
  final String? error;
  final String? code;
}

/// `mode.set`.
class ModeResult extends SettingResult {
  const ModeResult({super.ok, super.error, super.code, this.mode});

  factory ModeResult.fromJson(Map<String, Object?> j) =>
      ModeResult(ok: j.boolean('ok') ?? false, error: j.str('error'), code: SettingCodes.read(j.str('code')), mode: j.str('mode'));

  final String? mode;
}

/// `accounts.saveGroup`: the account's group (new when the save made one),
/// the saved rows' ids in the order of the endpoints sent, and its new
/// revision — what [AccountGroupInput.afterSave] edits on with.
class SaveGroupResult extends SettingResult {
  const SaveGroupResult({super.ok, super.error, super.code, this.groupId, this.ids = const [], this.revision});

  factory SaveGroupResult.fromJson(Map<String, Object?> j) => SaveGroupResult(
        ok: j.boolean('ok') ?? false,
        error: j.str('error'),
        code: SettingCodes.read(j.str('code')),
        groupId: j.str('groupId'),
        ids: j.strings('ids'),
        revision: j.str('revision'),
      );

  final String? groupId;
  final List<String> ids;
  final String? revision;
}

/// `models.discover`. On failure [status] is the endpoint's HTTP status, for
/// [SettingCodes.http].
class DiscoverResult extends SettingResult {
  const DiscoverResult({super.ok, super.error, super.code, this.models = const [], this.truncated = false, this.status});

  factory DiscoverResult.fromJson(Map<String, Object?> j) => DiscoverResult(
        ok: j.boolean('ok') ?? false,
        error: j.str('error'),
        code: SettingCodes.read(j.str('code')),
        models: j.objects('models', DiscoveredModel.fromJson),
        truncated: j.boolean('truncated') ?? false,
        status: j.integer('status'),
      );

  /// Up to [SettingLimits.discovered] — more than an endpoint saves
  /// ([SettingLimits.models]): offered to pick from, not taken whole.
  final List<DiscoveredModel> models;

  /// More than the 5000 sent.
  final bool truncated;
  final int? status;
}

/// `cloud.keys.models`.
class CloudModelsResult extends SettingResult {
  const CloudModelsResult({super.ok, super.error, super.code, this.models = const []});

  factory CloudModelsResult.fromJson(Map<String, Object?> j) => CloudModelsResult(
        ok: j.boolean('ok') ?? false,
        error: j.str('error'),
        code: SettingCodes.read(j.str('code')),
        models: j.strings('models'),
      );

  /// Up to [SettingLimits.keyModels] — more than one agent is assigned
  /// ([SettingLimits.assignModels]): offered to pick from.
  final List<String> models;
}

/// `cloud.assign`: the assignments made — on failure too, as those made
/// before it are kept.
class CloudAssignResult extends SettingResult {
  const CloudAssignResult({super.ok, super.error, super.code, this.providers = const []});

  factory CloudAssignResult.fromJson(Map<String, Object?> j) => CloudAssignResult(
        ok: j.boolean('ok') ?? false,
        error: j.str('error'),
        code: SettingCodes.read(j.str('code')),
        providers: j.strings('providers'),
      );

  final List<String> providers;
}
