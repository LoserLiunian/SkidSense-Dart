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
import '../kit/forms.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';

/// A protocol's name as the desktop shows it — `DIALECT_LABEL`.
String dialectLabel(String? dialect) => switch (dialect) {
      Dialects.anthropic => 'Anthropic',
      Dialects.openaiResponses => 'OpenAI Responses',
      Dialects.openaiChat => 'OpenAI Chat',
      Dialects.gemini => 'Gemini',
      null => '',
      _ => dialect,
    };

/// A preset's name: the desktop's own, but for the blank one, which it
/// names in its own language.
String presetName(L10n l, AccountPreset preset) => preset.id == 'custom' ? l.editorPresetCustom : preset.name;

/// An endpoint's address as short as it can be read: host, and the path
/// when there is one (`hostOf` on the desktop).
String hostOf(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null || parsed.host.isEmpty) return url;
  final path = parsed.path == '/' ? '' : parsed.path;
  return '${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}$path';
}

/// The agents that speak [dialect], as the accounts list names them.
String harnessesOf(L10n l, AccountsSnapshot? snapshot, String dialect) {
  final names = [
    for (final harness in snapshot?.harnesses ?? const <HarnessInfo>[])
      if (harness.dialect == dialect) harness.label.isEmpty ? harness.agent : harness.label,
  ];
  return names.join(l.localeName.startsWith('zh') ? '、' : ', ');
}

const _slots = ['main', 'sonnet', 'opus', 'haiku', 'subagent'];

/// One protocol's part of the form.
class _Endpoint {
  _Endpoint(this.dialect);

  final String dialect;
  bool enabled = false;

  /// The row this part edits, or an old endpoint it takes in.
  String? id;

  /// Whether [id]'s row has a key stored: one a fetch of models may use.
  bool hasKey = false;

  /// The name of an old endpoint taken in from elsewhere (not the one
  /// being edited).
  String? adopted;
  final TextEditingController baseUrl = TextEditingController();
  final TextEditingController models = TextEditingController();
  final Map<String, TextEditingController> slots = {for (final slot in _slots) slot: TextEditingController()};
  final TextEditingController env = TextEditingController();

  /// The windows the endpoint reported with its models; null keeps the
  /// stored ones.
  Map<String, int>? windows;

  bool fetching = false;
  int? fetched;
  int? kept;
  String? fetchError;

  bool get anthropic => dialect == Dialects.anthropic;

  void clearFetch() {
    fetching = false;
    fetched = null;
    kept = null;
    fetchError = null;
  }

  void fill({required String baseUrl, List<String> models = const [], ModelMap? map, Map<String, String>? env}) {
    this.baseUrl.text = baseUrl;
    this.models.text = models.join('\n');
    final read = map?.toJson() ?? const <String, String>{};
    for (final MapEntry(key: slot, value: field) in slots.entries) {
      field.text = read[slot] ?? '';
    }
    this.env.text = [for (final MapEntry(:key, :value) in (env ?? const <String, String>{}).entries) '$key=$value'].join('\n');
    windows = null;
    clearFetch();
  }

  void dispose() {
    baseUrl.dispose();
    models.dispose();
    env.dispose();
    for (final field in slots.values) {
      field.dispose();
    }
  }
}

/// Model ids as typed: one a line, or comma separated.
List<String> _listOf(String text) => [
      for (final model in text.split(RegExp(r'[\n,]')))
        if (model.trim().isNotEmpty) model.trim(),
    ];

/// Add or edit one of the computer's local accounts — `AccountDialog` on the
/// desktop: a vendor's preset, a name, a note and one key, and an endpoint
/// for each protocol it speaks, each with its models. Nothing here touches a
/// CLI's own configuration; the computer injects the account when it starts
/// an agent.
class AccountEditorScreen extends StatefulWidget {
  const AccountEditorScreen({super.key, this.group});

  /// The account as `accounts.list` gave it — a group, or one old endpoint;
  /// null adds one.
  final AccountGroup? group;

  @override
  State<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends State<AccountEditorScreen> {
  late final AppController _app = context.app;
  HostConfigController get _config => _app.config;
  final List<void Function()> _unwatch = [];

  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _presetQuery = TextEditingController();
  final List<_Endpoint> _endpoints = [for (final dialect in Dialects.all) _Endpoint(dialect)];

  /// The account being edited as it was read: its group (an old endpoint has
  /// none), its revision, and those of the old endpoints in the form.
  AccountGroup? _group;
  String? _groupId;
  String? _revision;
  final Map<String, String> _legacyRevisions = {};

  String? _presetId;
  bool _hasKey = false;
  bool _clearKey = false;

  /// Changed since it was opened or saved: leaving asks first.
  bool _dirty = false;
  bool _busy = false;

  /// What is wrong with a field, by `name`, `note`, `apiKey`, `endpoints`
  /// (none turned on), `<dialect>/<field>` (`baseUrl`, `models`, `env`,
  /// `slot/<slot>`), or `form` for what is no one field's.
  Map<String, String> _errors = const {};

  /// Why the last save was refused, when it was.
  _Refusal? _refusal;

  /// Why reading the account again after a refusal failed: said with the
  /// refusal, which stays — as does everything typed.
  String? _reloadError;

  /// Where each field is, by the keys of [_errors] (and `refusal`, the
  /// banner at the top): a save that is refused goes to the first wrong.
  final Map<String, GlobalKey> _anchors = {};

  GlobalKey _anchor(String field) => _anchors.putIfAbsent(field, () => GlobalKey(debugLabel: field));

  bool get _editing => widget.group != null;

  /// A protocol this build does not know: saved whole, the account would
  /// lose that row (spec §7.1).
  bool get _unknownProtocol => _group?.rows.any((row) => row.dialect != null && !Dialects.all.contains(row.dialect)) ?? false;

  @override
  void initState() {
    super.initState();
    _unwatch.addAll([_config.watchPresets(), _config.watchAccounts()]);
    final group = widget.group;
    if (group != null) _load(group);
  }

  @override
  void dispose() {
    for (final unwatch in _unwatch) {
      unwatch();
    }
    _name.dispose();
    _note.dispose();
    _apiKey.dispose();
    _presetQuery.dispose();
    for (final endpoint in _endpoints) {
      endpoint.dispose();
    }
    super.dispose();
  }

  _Endpoint _of(String dialect) => _endpoints.firstWhere((endpoint) => endpoint.dialect == dialect);

  /// The form from the account as read: each protocol's row in its part. An
  /// old endpoint, of no stated protocol, fills every part for the user to
  /// say which it speaks.
  void _load(AccountGroup group) {
    _group = group;
    _groupId = group.groupId;
    _revision = group.revision;
    _legacyRevisions.clear();
    _name.text = group.name;
    _note.text = group.note;
    _apiKey.clear();
    _presetId = group.presetId;
    _hasKey = group.hasKey;
    _clearKey = false;
    for (final endpoint in _endpoints) {
      endpoint
        ..enabled = false
        ..id = null
        ..hasKey = false
        ..adopted = null
        ..fill(baseUrl: '');
    }
    for (final row in group.rows) {
      final dialect = row.dialect;
      if (dialect != null && Dialects.all.contains(dialect)) {
        _of(dialect)
          ..enabled = true
          ..id = row.id
          ..hasKey = row.hasKey
          ..fill(baseUrl: row.baseUrl, models: row.models, map: row.modelMap, env: row.extraEnv);
      } else if (row.legacy) {
        if (group.revision != null) _legacyRevisions[row.id] = group.revision!;
        for (final endpoint in _endpoints) {
          endpoint
            ..id = row.id
            ..hasKey = row.hasKey
            ..fill(baseUrl: row.baseUrl, models: row.models);
        }
      }
    }
    _errors = const {};
    _dirty = false;
  }

  /// [field] changed: its error goes, and — for [fetchOf]'s address or its
  /// list, or the key any fetch used — what the last fetch said, which was
  /// about what was there before.
  void _changed([String? field, Iterable<_Endpoint> fetchOf = const []]) {
    setState(() {
      _dirty = true;
      if (field != null && _errors.containsKey(field)) _errors = {..._errors}..remove(field);
      for (final endpoint in fetchOf) {
        endpoint.fetchError = null;
      }
    });
  }

  // --- presets ------------------------------------------------------------------------

  /// A preset fills in every protocol's part. The name follows it while it
  /// is empty or still another preset's (`choosePreset` on the desktop).
  void _choosePreset(AccountPreset preset, List<AccountPreset> all) {
    setState(() {
      _presetId = preset.id;
      if (preset.id != 'custom' && (_name.text.trim().isEmpty || all.any((candidate) => candidate.name == _name.text))) {
        _name.text = preset.name;
      }
      for (final endpoint in _endpoints) {
        final from = preset.endpoints.where((candidate) => candidate.dialect == endpoint.dialect).firstOrNull;
        // A blank "custom" preset turns nothing on until the user fills one in.
        endpoint
          ..enabled = from != null && from.baseUrl.isNotEmpty
          ..fill(baseUrl: from?.baseUrl ?? '', models: from?.models ?? const [], map: from?.modelMap, env: from?.extraEnv);
      }
      _errors = const {};
      _dirty = true;
    });
  }

  Future<void> _showNotice(String notice) => showAppSheet<void>(
        context,
        builder: (sheet) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader(sheet.l10n.editorPresetLicense),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              child: MonoBlock(notice, maxHeight: 420),
            ),
          ]),
        ),
      );

  // --- old endpoints ------------------------------------------------------------------

  /// Old endpoints (from before accounts) the form may take in: those of
  /// no other part, and not the one being edited.
  List<ProviderProfile> _adoptable(AccountsSnapshot? snapshot) {
    final taken = {for (final endpoint in _endpoints) ?endpoint.id};
    return [
      for (final row in snapshot?.providers ?? const <ProviderProfile>[])
        if (row.legacy && !taken.contains(row.id)) row,
    ];
  }

  /// The parts an old endpoint may go in: those of no row of the account's
  /// own — an old endpoint being edited offers every part turned off.
  List<_Endpoint> get _adoptInto {
    final editedLegacy = _groupId == null ? _group?.rows.firstOrNull?.id : null;
    return [
      for (final endpoint in _endpoints)
        if (endpoint.id == null || endpoint.adopted != null || (endpoint.id == editedLegacy && !endpoint.enabled)) endpoint,
    ];
  }

  Future<void> _pickAdoption(AccountsSnapshot snapshot) async {
    final picked = await showAppSheet<(ProviderProfile, String)>(
      context,
      builder: (_) => _AdoptSheet(rows: _adoptable(snapshot), dialects: [for (final endpoint in _adoptInto) endpoint.dialect]),
    );
    if (picked == null || !mounted) return;
    final (row, dialect) = picked;
    final endpoint = _of(dialect);
    if (endpoint.adopted != null) _unadopt(endpoint);
    _adopt(endpoint, row, snapshot);
  }

  void _adopt(_Endpoint endpoint, ProviderProfile row, AccountsSnapshot snapshot) {
    setState(() {
      final revision = snapshot.revisions[row.id];
      if (revision != null) _legacyRevisions[row.id] = revision;
      endpoint
        ..enabled = true
        ..id = row.id
        ..hasKey = row.hasKey
        ..adopted = row.name.isEmpty ? row.id : row.name
        ..fill(baseUrl: row.baseUrl, models: row.models);
      _dirty = true;
    });
  }

  void _unadopt(_Endpoint endpoint) {
    setState(() {
      _legacyRevisions.remove(endpoint.id);
      endpoint
        ..id = null
        ..hasKey = false
        ..adopted = null;
      _dirty = true;
    });
  }

  // --- fetching models ----------------------------------------------------------------

  /// The row whose stored key a fetch may use when none is typed: the part's
  /// own, else any of the account's (as the desktop's form does).
  String? _keyHolder(_Endpoint endpoint) {
    if (endpoint.hasKey && endpoint.id != null) return endpoint.id;
    return _group?.rows.where((row) => row.hasKey).firstOrNull?.id;
  }

  Future<void> _discover(_Endpoint endpoint) async {
    final l = context.l10n;
    final url = endpoint.baseUrl.text.trim();
    String? problem;
    if (url.isEmpty) {
      problem = l.editorFetchNeedsUrl;
    } else if (url.contains('?') || url.contains('#')) {
      // The model list's path goes after it: a query or a fragment would
      // swallow it, and the host refuses such an address (spec §7).
      problem = l.editorFetchNoQuery;
    }
    if (problem != null) {
      setState(() => endpoint
        ..clearFetch()
        ..fetchError = problem);
      return;
    }
    setState(() => endpoint
      ..clearFetch()
      ..fetching = true);
    final typed = _clearKey ? '' : _apiKey.text.trim();
    try {
      final result = await _config.discoverModels(
        dialect: endpoint.dialect,
        baseUrl: url,
        apiKey: typed,
        providerId: typed.isEmpty && !_clearKey ? _keyHolder(endpoint) : null,
        presetId: _presetId,
      );
      if (!mounted) return;
      setState(() {
        endpoint.fetching = false;
        if (!result.ok) {
          endpoint.fetchError = _discoverError(l, result);
          return;
        }
        // More than a protocol saves are offered, not taken whole: the
        // first of them, said so.
        final ids = [for (final model in result.models) model.id];
        final kept = ids.take(SettingLimits.models).toList();
        endpoint
          ..fetched = ids.length
          ..kept = kept.length
          ..models.text = kept.join('\n');
        final keptSet = kept.toSet();
        final windows = {
          for (final model in result.models)
            if (model.contextLength != null && keptSet.contains(model.id)) model.id: model.contextLength!,
        };
        endpoint.windows = windows.isEmpty ? null : windows;
        _dirty = true;
        _errors = {..._errors}..remove('${endpoint.dialect}/models');
      });
    } catch (error) {
      if (mounted) {
        setState(() => endpoint
          ..fetching = false
          ..fetchError = l.error(error));
      }
    }
  }

  static String _discoverError(L10n l, DiscoverResult result) => switch (result.code) {
        SettingCodes.keyRequired => l.editorKeyRequired,
        SettingCodes.http => switch (result.status) {
            401 || 403 => l.editorFetchRejected(result.status!),
            final status? => l.editorFetchHttp(status),
            null => result.error ?? l.errUnknown(''),
          },
        SettingCodes.timeout => l.editorFetchTimeout,
        SettingCodes.network => l.editorFetchNetwork,
        SettingCodes.notJson => l.editorFetchNotJson,
        SettingCodes.empty => l.editorFetchEmpty,
        SettingCodes.tooLarge => l.editorFetchTooLarge,
        _ => result.error ?? l.errUnknown(''),
      };

  // --- saving -------------------------------------------------------------------------

  /// `KEY=VALUE` a line, blank lines and `#` comments skipped; a line that is
  /// neither is said, not dropped.
  (Map<String, String>, String?) _envOf(String text) {
    final env = <String, String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final at = trimmed.indexOf('=');
      if (at <= 0) return (env, trimmed);
      env[trimmed.substring(0, at).trim()] = trimmed.substring(at + 1).trim();
    }
    return (env, null);
  }

  AccountGroupInput _input() {
    // An old endpoint fills every part, but is taken in by one: the first
    // turned on. The host refuses one id claimed twice.
    final claimed = <String>{};
    final endpoints = [
      for (final endpoint in _endpoints)
        if (endpoint.enabled)
          AccountEndpointInput(
            id: endpoint.id != null && claimed.add(endpoint.id!) ? endpoint.id : null,
            dialect: endpoint.dialect,
            baseUrl: endpoint.baseUrl.text.trim(),
            models: _listOf(endpoint.models.text),
            modelMap: ModelMap(
              main: endpoint.slots['main']!.text,
              sonnet: endpoint.slots['sonnet']!.text,
              opus: endpoint.slots['opus']!.text,
              haiku: endpoint.slots['haiku']!.text,
              subagent: endpoint.slots['subagent']!.text,
            ),
            extraEnv: endpoint.anthropic ? _envOf(endpoint.env.text).$1 : null,
            contextWindows: endpoint.windows,
          ),
    ];
    // The revisions of what the save writes over, as they were read: the
    // group's, and each old endpoint's it takes in — into a group too, which
    // the host checks as much as the group (spec §7).
    final legacy = [
      for (final endpoint in endpoints)
        if (endpoint.id != null && _legacyRevisions.containsKey(endpoint.id)) _legacyRevisions[endpoint.id]!,
    ];
    final revisions = [if (_groupId != null && _revision != null) _revision!, ...legacy];
    final key = _apiKey.text.trim();
    // A preset the computer no longer lists is refused: the account keeps none.
    final presets = _config.presets.value.value?.presets;
    final presetId = presets == null || presets.any((preset) => preset.id == _presetId) ? _presetId : null;
    return AccountGroupInput(
      groupId: _groupId,
      revision: revisions.firstOrNull,
      revisions: revisions.length > 1 ? revisions : null,
      name: _name.text.trim(),
      note: _note.text.trim(),
      presetId: presetId,
      apiKey: _clearKey ? '' : (key.isEmpty ? null : key),
      endpoints: endpoints,
    );
  }

  /// What the host would refuse, by field, in the user's words: past the
  /// limits a phone is held to, what the desktop's own `accountProblem`
  /// says of any account — each beside its field, where the desktop says
  /// only the first, in its words.
  Map<String, String> _check(L10n l, AccountGroupInput input) {
    final found = <String, List<String>>{};
    void add(String field, String message) => found.putIfAbsent(field, () => []).add(message);
    for (final endpoint in _endpoints) {
      if (!endpoint.enabled || !endpoint.anthropic) continue;
      final bad = _envOf(endpoint.env.text).$2;
      if (bad != null) add('${endpoint.dialect}/env', l.editorEnvLine(bad));
    }
    for (final problem in [...input.problems, ...input.accountProblems]) {
      // A window out of range is left out of the save, not refused; and
      // nothing here can set one.
      if (problem.field == 'contextWindows') continue;
      final value = problem.value;
      final message = switch (problem.kind) {
        AccountInputFault.tooLong => l.editorTooLong(problem.limit ?? 0),
        AccountInputFault.tooMany => switch (problem.field) {
            'models' => l.editorTooManyModels(problem.limit ?? 0),
            'extraEnv' => l.editorTooManyEnv(problem.limit ?? 0),
            _ => l.editorTooMany(problem.limit ?? 0),
          },
        AccountInputFault.empty => l.editorEmpty,
        AccountInputFault.invalid => switch (problem.field) {
            'apiKey' => l.editorKeyInvalid,
            'baseUrl' => l.editorUrlInvalid,
            'dialect' => l.editorUnknownProtocol,
            _ => l.editorControlChars,
          },
        AccountInputFault.outOfRange => l.editorTooLong(problem.limit ?? 0),
        AccountInputFault.missing => switch (problem.field) {
            'name' => l.editorNameRequired,
            'endpoints' => l.editorNoProtocol,
            'baseUrl' => l.editorUrlRequired,
            'models' => l.editorCodexNeedsModel,
            _ => l.editorEmpty,
          },
        AccountInputFault.duplicate => l.editorProtocolTwice(dialectLabel(value)),
        AccountInputFault.notAddress => l.editorUrlNotAddress,
        AccountInputFault.notHttp => l.editorUrlNotHttp,
        AccountInputFault.badName => l.editorEnvBadName(value ?? ''),
        AccountInputFault.reserved => l.editorEnvReserved(value ?? ''),
      };
      // The model, slot or variable at fault, where the message does not
      // name it itself.
      final named = value != null &&
          problem.field != 'modelMap' &&
          problem.field != 'dialect' &&
          problem.kind != AccountInputFault.badName &&
          problem.kind != AccountInputFault.reserved;
      final field = switch (problem.field) {
        'name' || 'note' || 'apiKey' || 'endpoints' => problem.field,
        'baseUrl' || 'models' => '${problem.dialect}/${problem.field}',
        'modelMap' => '${problem.dialect}/slot/$value',
        'extraEnv' => '${problem.dialect}/env',
        _ => 'form',
      };
      add(field, named ? l.editorProblemIn(value, message) : message);
    }
    return {for (final MapEntry(:key, :value) in found.entries) key: value.take(3).join('\n')};
  }

  /// The fields in the order they show, as [_errors] names them.
  List<String> get _order => [
        'refusal',
        'name',
        'note',
        'apiKey',
        'endpoints',
        for (final endpoint in _endpoints)
          if (endpoint.enabled) ...[
            '${endpoint.dialect}/baseUrl',
            '${endpoint.dialect}/models',
            for (final slot in _slots) '${endpoint.dialect}/slot/$slot',
            '${endpoint.dialect}/env',
          ],
      ];

  /// Where a refused save went wrong first: the banner at the top for the
  /// computer's refusal (or what is no field's), else the first field with
  /// an error.
  String? get _firstProblem {
    final refusal = _refusal;
    if (refusal != null && refusal.kind != _RefusalKind.keyRequired) return 'refusal';
    return _order.where(_errors.containsKey).firstOrNull ?? (refusal == null ? null : 'refusal');
  }

  /// Bring the first problem on screen, once the frame showing it is laid
  /// out: the action that was refused is at the bottom of a long form, and
  /// what went wrong may be anywhere above it.
  void _revealProblem() {
    final target = _firstProblem;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final at = _anchors[target]?.currentContext;
      if (!mounted || at == null || !at.mounted) return;
      final motion = context.design.motion.spatial;
      // Clear of the top bar, which stays pinned over the content — and
      // whole, where what went wrong is near the top (the banner there).
      unawaited(AppPage.reveal(at, duration: motion.duration, curve: motion.curve));
    });
  }

  /// The line over the action, after a save that did not go through: what
  /// to do about it, where the reason is shown above.
  String? _status(L10n l) {
    final refusal = _refusal;
    return switch (refusal?.kind) {
      _RefusalKind.conflict => l.editorStatusConflict,
      _RefusalKind.keyRequired => l.editorKeyRequired,
      _ when _errors.isNotEmpty => l.editorFixFields(_errors.length),
      _RefusalKind.other => l.editorStatusRefused,
      null => null,
    };
  }

  Future<void> _save() async {
    final l = context.l10n;
    final input = _input();
    final errors = _check(l, input);
    setState(() {
      _errors = errors;
      _refusal = errors.containsKey('form') ? _Refusal(_RefusalKind.other, errors['form']!) : null;
      _reloadError = null;
    });
    if (errors.isNotEmpty) {
      _revealProblem();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _config.saveGroup(input);
      if (!mounted) return;
      if (result.ok) {
        _dirty = false;
        showMessage(context, _editing ? l.editorSaved(input.name) : l.editorAdded(input.name));
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _refusal = switch (result.code) {
          SettingCodes.conflict => _Refusal(_RefusalKind.conflict, l.editorConflictBody),
          SettingCodes.keyRequired => _Refusal(_RefusalKind.keyRequired, l.editorKeyRequiredBody),
          _ => _Refusal(_RefusalKind.other, result.error ?? l.errUnknown('')),
        };
        if (result.code == SettingCodes.keyRequired) _errors = {..._errors, 'apiKey': l.editorKeyRequired};
      });
      _revealProblem();
    } catch (error) {
      if (mounted) {
        setState(() => _refusal = _Refusal(_RefusalKind.other, l.error(error)));
        _revealProblem();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Start again from the account as it is now, after a save was refused as
  /// stale: by its group, or an old endpoint by its own row — which may
  /// have joined a group since. A new account was refused over the old
  /// endpoints it takes in: those are read again, and let go of when gone.
  /// A read that fails changes nothing — not the form, nor the refusal —
  /// and says so: what is held is what was refused.
  Future<void> _reload() async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _reloadError = null;
    });
    await _config.loadAccounts();
    if (!mounted) return;
    final loaded = _config.accounts.value;
    final snapshot = loaded.value;
    if (loaded.error != null || snapshot == null) {
      setState(() {
        _busy = false;
        _reloadError = l.editorReloadFailed(l.error(loaded.error));
      });
      _revealProblem();
      return;
    }
    if (_group == null) {
      for (final endpoint in _endpoints) {
        if (endpoint.adopted == null) continue;
        final row = snapshot.providers.where((row) => row.id == endpoint.id && row.legacy).firstOrNull;
        _unadopt(endpoint);
        if (row != null) _adopt(endpoint, row, snapshot);
      }
      setState(() {
        _busy = false;
        _refusal = null;
      });
      return;
    }
    final first = _group?.rows.firstOrNull;
    final key = _groupId ?? snapshot.providers.where((row) => row.id == first?.id).firstOrNull?.groupId ?? first?.id;
    final group = snapshot.accounts.where((group) => group.key == key).firstOrNull;
    // The old endpoints taken in stay taken in, as they are now.
    final adopted = {
      for (final endpoint in _endpoints)
        if (endpoint.adopted != null && endpoint.id != null) endpoint.dialect: endpoint.id!,
    };
    setState(() {
      _busy = false;
      if (group == null) {
        _refusal = _Refusal(_RefusalKind.other, l.editorDeletedElsewhere);
        return;
      }
      _load(group);
      _refusal = null;
    });
    if (group == null) {
      _revealProblem();
      return;
    }
    for (final MapEntry(key: dialect, value: id) in adopted.entries) {
      final endpoint = _of(dialect);
      final row = snapshot.providers.where((row) => row.id == id && row.legacy).firstOrNull;
      if (row != null && endpoint.id == null && !_endpoints.any((other) => other.id == id)) _adopt(endpoint, row, snapshot);
    }
  }

  Future<void> _leave() async {
    final l = context.l10n;
    final leave = await confirm(context, title: l.editorDiscardTitle, body: l.editorDiscardBody, action: l.discard, destructive: true);
    if (!leave || !mounted) return;
    setState(() => _dirty = false);
    Navigator.of(context).pop();
  }

  // --- the form -----------------------------------------------------------------------

  /// A banner at the form's inset, with room over it.
  static Widget _banner(Widget banner) => Padding(padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0), child: banner);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = _app;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: WatchSelect(app.states, select: (AppState s) => s.connected, builder: (context, connected) {
        return Watch(_config.presets, builder: (context, presets) {
          return Watch(_config.accounts, builder: (context, accounts) {
            final snapshot = accounts.value;
            final status = _status(l);
            final refusal = _refusal;
            return AppPage(
              title: _editing ? l.editorEditTitle : l.editorAddTitle,
              subtitle: _editing && (widget.group?.name.isNotEmpty ?? false)
                  ? Text(widget.group!.name, maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              maxContentWidth: AppPage.readableWidth,
              bottom: FormActionBar(
                maxContentWidth: AppPage.readableWidth,
                // Where the save went wrong, said where it was asked for —
                // the reason itself is beside its field, or at the top.
                above: status == null ? null : FormStatus(status),
                child: AppButton(
                  label: _editing ? l.save : l.editorAdd,
                  icon: Icons.check_rounded,
                  large: true,
                  expand: true,
                  busy: _busy,
                  onPressed: connected && !_unknownProtocol ? _save : null,
                ),
              ),
              slivers: [
                // One piece, laid out whole: a refused save scrolls to any
                // field of it, built or not.
                SliverToBoxAdapter(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (!connected) const OfflineCard(),
                    if (_unknownProtocol) _banner(InlineBanner(tone: BannerTone.warning, message: l.editorUnknownProtocol)),
                    if (refusal != null) KeyedSubtree(key: _anchor('refusal'), child: _banner(_refusalBanner(context, refusal))),
                    if (_group != null && _group!.groupId == null)
                      _banner(InlineBanner(tone: BannerTone.info, title: l.editorLegacyTitle, message: l.editorLegacyBody)),
                    ..._presetSection(context, presets),
                    SectionHeader(l.editorAccountSection),
                    _accountFields(context),
                    SectionHeader(l.editorProtocols, hint: l.editorProtocolsHint),
                    if (_errors['endpoints'] != null)
                      KeyedSubtree(
                        key: _anchor('endpoints'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                          child: InlineBanner(message: _errors['endpoints']!),
                        ),
                      ),
                    for (final endpoint in _endpoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
                        child: _endpointCard(context, endpoint, snapshot),
                      ),
                    // Endpoints from before accounts, to make part of this one.
                    if (snapshot != null && _adoptable(snapshot).isNotEmpty && _adoptInto.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AppButton(
                            label: l.editorAdopt,
                            icon: Icons.call_merge_rounded,
                            emphasis: ActionEmphasis.quiet,
                            onPressed: () => _pickAdoption(snapshot),
                          ),
                        ),
                      ),
                  ]),
                ),
              ],
            );
          });
        });
      }),
    );
  }

  Widget _refusalBanner(BuildContext context, _Refusal refusal) {
    final l = context.l10n;
    // A reload that failed is said with what it was to answer.
    final message = _reloadError == null ? refusal.message : '${refusal.message}\n\n$_reloadError';
    return switch (refusal.kind) {
      _RefusalKind.conflict => InlineBanner(
          title: l.editorConflictTitle,
          message: message,
          action: AppButton(
            label: l.editorReload,
            icon: Icons.refresh_rounded,
            emphasis: ActionEmphasis.tonal,
            busy: _busy,
            onPressed: _reload,
          ),
        ),
      _RefusalKind.keyRequired => InlineBanner(
          tone: BannerTone.warning,
          title: l.editorKeyRequired,
          message: message,
          onDismiss: () => setState(() => _refusal = null),
        ),
      _RefusalKind.other => InlineBanner(message: message, onDismiss: () => setState(() => _refusal = null)),
    };
  }

  List<Widget> _presetSection(BuildContext context, Loaded<PresetCatalog> loaded) {
    final l = context.l10n;
    final catalog = loaded.value;
    if (catalog == null || catalog.presets.isEmpty) {
      return [
        if (loaded.loading) LoadingRow(l.editorPresetsLoading),
        if (loaded.error != null && catalog == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
            child: InlineBanner(
              message: l.error(loaded.error),
              action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, onPressed: _config.loadPresets),
            ),
          ),
      ];
    }
    final query = _presetQuery.text.trim().toLowerCase();
    final shown = [
      for (final preset in catalog.presets)
        if (query.isEmpty || presetName(l, preset).toLowerCase().contains(query) || preset.name.toLowerCase().contains(query) || preset.id.contains(query)) preset,
    ];
    return [
      SectionHeader(l.editorPreset, hint: l.editorPresetHint),
      FormColumn(children: [
        if (catalog.presets.length > 8)
          SearchField(controller: _presetQuery, hint: l.editorPresetSearch, onChanged: (_) => setState(() {})),
        if (shown.isEmpty)
          Text(l.noSearchResults(_presetQuery.text), style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))
        else
          ChoiceGroup<String>(
            wrap: true,
            items: [for (final preset in shown) GroupItem(value: preset.id, label: presetName(l, preset))],
            selected: _presetId,
            onSelected: (id) {
              final preset = shown.where((candidate) => candidate.id == id).firstOrNull;
              if (preset != null) _choosePreset(preset, catalog.presets);
            },
          ),
        if (catalog.notice.isNotEmpty)
          Row(children: [
            Expanded(
              child: Text(l.editorPresetCredit, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
            const SizedBox(width: Gap.sm),
            AppButton(label: l.editorPresetLicense, emphasis: ActionEmphasis.quiet, onPressed: () => _showNotice(catalog.notice)),
          ]),
      ]),
    ];
  }

  /// The key changed, or is to be cleared: what any fetch said of the old
  /// one is past, and so is the computer's asking for it again.
  void _keyChanged() {
    _changed('apiKey', _endpoints);
    if (_refusal?.kind == _RefusalKind.keyRequired) setState(() => _refusal = null);
  }

  Widget _accountFields(BuildContext context) {
    final l = context.l10n;
    return FormColumn(children: [
      KeyedSubtree(
        key: _anchor('name'),
        child: AppTextField(
          controller: _name,
          label: l.editorName,
          hint: l.editorNameHint,
          error: _errors['name'],
          onChanged: (_) => _changed('name'),
        ),
      ),
      KeyedSubtree(
        key: _anchor('note'),
        child: AppTextField(
          controller: _note,
          label: l.editorNote,
          hint: l.editorNoteHint,
          minLines: 1,
          maxLines: 4,
          error: _errors['note'],
          onChanged: (_) => _changed('note'),
        ),
      ),
      KeyedSubtree(
        key: _anchor('apiKey'),
        child: SecretField(
          controller: _apiKey,
          label: l.editorApiKey,
          hint: _hasKey ? null : 'sk-…',
          helper: _hasKey ? (_clearKey ? l.editorKeyWillClear : l.editorKeyKept) : l.editorKeyShared,
          error: _errors['apiKey'],
          enabled: !_clearKey,
          onChanged: (_) => _keyChanged(),
        ),
      ),
      if (_hasKey)
        SwitchRow(
          title: l.editorClearKey,
          subtitle: l.editorClearKeyHint,
          value: _clearKey,
          onChanged: (value) {
            if (value) _apiKey.clear();
            setState(() => _clearKey = value);
            _keyChanged();
          },
        ),
    ]);
  }

  Widget _endpointCard(BuildContext context, _Endpoint endpoint, AccountsSnapshot? snapshot) {
    final l = context.l10n;
    final agents = harnessesOf(l, snapshot, endpoint.dialect);
    // One card, its switch the head of it.
    return GroupedList(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SwitchRow(
          inset: true,
          heading: true,
          title: dialectLabel(endpoint.dialect),
          subtitle: agents.isEmpty ? null : l.editorDialectFor(agents),
          value: endpoint.enabled,
          onChanged: (value) => setState(() {
            endpoint.enabled = value;
            _dirty = true;
            // What was wrong with it is no longer counted once it is off,
            // nor "none turned on" once one is.
            final part = '${endpoint.dialect}/';
            _errors = {
              for (final MapEntry(:key, :value) in _errors.entries)
                if (!key.startsWith(part) && key != 'endpoints') key: value,
            };
          }),
        ),
        if (endpoint.enabled) _endpointFields(context, endpoint, snapshot),
      ]),
    ]);
  }

  Widget _endpointFields(BuildContext context, _Endpoint endpoint, AccountsSnapshot? snapshot) {
    final l = context.l10n;
    final dialect = endpoint.dialect;
    final models = _listOf(endpoint.models.text);
    final fetchHelper = endpoint.fetching
        ? l.editorFetching
        : endpoint.fetched != null
            ? (endpoint.kept! < endpoint.fetched! ? l.editorFetchedSome(endpoint.fetched!, endpoint.kept!) : l.editorFetched(endpoint.fetched!))
            : l.editorModelsHelper;
    Widget pick(TextEditingController field, String key) => models.isEmpty
        ? const SizedBox.shrink()
        : PopupMenuButton<String>(
            tooltip: l.editorPickModel,
            icon: const Icon(Icons.arrow_drop_down_rounded),
            onSelected: (model) {
              field.text = model;
              _changed(key);
            },
            itemBuilder: (_) => [for (final model in models.take(200)) PopupMenuItem(value: model, child: Text(model, style: context.text.bodyMedium?.mono))],
          );
    final slotLabels = {
      'main': endpoint.anthropic ? l.editorSlotMain : l.editorSlotDefault,
      'sonnet': 'Sonnet',
      'opus': 'Opus',
      'haiku': l.editorSlotHaiku,
      'subagent': l.editorSlotSubagent,
    };
    return FormColumn(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
      children: [
        KeyedSubtree(
          key: _anchor('$dialect/baseUrl'),
          child: AppTextField(
            controller: endpoint.baseUrl,
            label: l.editorBaseUrl,
            hint: switch (dialect) {
              Dialects.anthropic => 'https://api.example.com/anthropic',
              Dialects.gemini => 'https://generativelanguage.googleapis.com',
              _ => 'https://api.example.com/v1',
            },
            mono: true,
            keyboardType: TextInputType.url,
            error: _errors['$dialect/baseUrl'],
            onChanged: (_) => _changed('$dialect/baseUrl', [endpoint]),
          ),
        ),
        if (endpoint.adopted != null)
          Row(children: [
            Icon(Icons.call_merge_rounded, size: 20, color: context.colors.primary),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(l.editorAdopted(endpoint.adopted!), style: context.text.bodyMedium)),
            IconButton(tooltip: l.editorAdoptUndo, icon: const Icon(Icons.close_rounded), onPressed: () => _unadopt(endpoint)),
          ]),
        const SizedBox(height: Gap.xs),
        FieldLabel(
          l.editorModels,
          hint: l.editorModelsHint,
          trailing: AppButton(
            label: l.editorFetch,
            icon: Icons.download_rounded,
            emphasis: ActionEmphasis.tonal,
            busy: endpoint.fetching,
            onPressed: _app.state.connected ? () => _discover(endpoint) : null,
          ),
        ),
        // What the fetch said, under the button that asked: apart from the
        // list's own error, which a failed fetch is none of — nor one more
        // field to fix.
        if (endpoint.fetchError != null)
          InlineBanner(
            title: l.editorFetchFailed,
            message: endpoint.fetchError!,
            onDismiss: () => setState(() => endpoint.fetchError = null),
          ),
        KeyedSubtree(
          key: _anchor('$dialect/models'),
          child: AppTextField(
            controller: endpoint.models,
            label: l.editorModelList,
            mono: true,
            minLines: 3,
            maxLines: 8,
            helper: fetchHelper,
            error: _errors['$dialect/models'],
            // Typed over, the list is the user's: the reported windows go
            // with it only for the models still there.
            onChanged: (_) => _changed('$dialect/models', [endpoint]),
          ),
        ),
        const SizedBox(height: Gap.xs),
        FieldLabel(l.editorModelMap, hint: endpoint.anthropic ? l.editorModelMapHintAnthropic : l.editorModelMapHint),
        for (final slot in endpoint.anthropic ? _slots : const ['main'])
          KeyedSubtree(
            key: _anchor('$dialect/slot/$slot'),
            child: AppTextField(
              controller: endpoint.slots[slot]!,
              label: slotLabels[slot]!,
              hint: slot == 'main' ? (models.firstOrNull ?? '') : l.editorSameAsMain,
              mono: true,
              error: _errors['$dialect/slot/$slot'],
              onChanged: (_) => _changed('$dialect/slot/$slot'),
              suffix: pick(endpoint.slots[slot]!, '$dialect/slot/$slot'),
            ),
          ),
        if (endpoint.anthropic) ...[
          const SizedBox(height: Gap.xs),
          FieldLabel(l.editorExtraEnv, hint: l.editorExtraEnvHint),
          KeyedSubtree(
            key: _anchor('$dialect/env'),
            // A short label, which floats whole at any text size; the format
            // goes under it.
            child: AppTextField(
              controller: endpoint.env,
              label: l.editorExtraEnvField,
              helper: l.editorExtraEnvFormat,
              mono: true,
              minLines: 2,
              maxLines: 6,
              error: _errors['$dialect/env'],
              onChanged: (_) => _changed('$dialect/env'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pick an old endpoint and the protocol it speaks, to take it into the
/// account: its row, and its key, become that protocol's. Pops both.
class _AdoptSheet extends StatefulWidget {
  const _AdoptSheet({required this.rows, required this.dialects});

  final List<ProviderProfile> rows;

  /// The protocols it may go in.
  final List<String> dialects;

  @override
  State<_AdoptSheet> createState() => _AdoptSheetState();
}

class _AdoptSheetState extends State<_AdoptSheet> {
  late ProviderProfile _row = widget.rows.first;
  late String _dialect = widget.dialects.first;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(l.editorAdopt, subtitle: l.editorAdoptHint),
        for (final row in widget.rows)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            selected: row.id == _row.id,
            leading: Icon(row.id == _row.id ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
            title: Text(row.name.isEmpty ? row.id : row.name),
            subtitle: Text(
              [hostOf(row.baseUrl), row.hasKey ? context.l10n.modelsKeyStored : context.l10n.modelsKeyMissing].join(' · '),
            ),
            onTap: () => setState(() => _row = row),
          ),
        FormColumn(padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, 0), children: [
          FieldLabel(l.editorAdoptProtocol),
          ChoiceGroup<String>(
            items: [for (final dialect in widget.dialects) GroupItem(value: dialect, label: dialectLabel(dialect))],
            selected: _dialect,
            onSelected: (value) => setState(() => _dialect = value ?? _dialect),
          ),
          const SizedBox(height: Gap.xs),
          AppButton(
            label: l.editorAdoptAction,
            icon: Icons.call_merge_rounded,
            expand: true,
            onPressed: () => Navigator.of(context).pop((_row, _dialect)),
          ),
        ]),
      ]),
    );
  }
}

enum _RefusalKind { conflict, keyRequired, other }

class _Refusal {
  const _Refusal(this.kind, this.message);

  final _RefusalKind kind;
  final String message;
}
