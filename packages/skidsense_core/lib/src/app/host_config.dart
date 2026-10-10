import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

import '../model/host_config.dart';
import '../protocol/protocol.dart';
import '../transport/errors.dart';
import '../util/json.dart';
import '../util/state_value.dart';

/// A request on the live connection: the host's answer, or a throw.
typedef HostCall = Future<Object?> Function(String method, Object? params);

/// What a screen shows of something read from the host: the last [value],
/// whether a read is out, and how the last one failed.
class Loaded<T> {
  const Loaded({this.value, this.loading = false, this.error});

  final T? value;
  final bool loading;
  final Object? error;
}

/// A change to one of a context row's two settings: [value] sets it, null
/// puts it back to the default. Leaving the argument out keeps it.
class Change<T> {
  const Change(this.value);

  final T? value;
}

/// The desktop's model and account settings (spec §7.1): typed calls for
/// each method, and what the screens read, kept current while they show it.
///
/// The host pushes only *that* something changed (spec §6.4): `mode.changed`
/// carries the mode, the other two nothing. What a screen watches is read
/// again — coalesced as `sessions.changed` is, so a burst of five events costs
/// at most two reads. What nobody watches is only marked out of date and read
/// when a screen next watches it: over the budgeted relay a whole
/// `accounts.list` is not read for a screen that was closed. A value that
/// lands meanwhile from elsewhere (the event's mode, the table a
/// `models.context.set` answers with) is not painted over by a read that left
/// before it.
class HostConfigController {
  HostConfigController(this._call) {
    _mode = _Slot<String>(
      this,
      () async => _modeOf(await _object('mode.get', null)) ?? (throw const RcException('bad-response', detail: 'mode.get')),
      pushed: true,
    );
    _accounts = _Slot<AccountsSnapshot>(this, () async => AccountsSnapshot.fromJson(await _object('accounts.list', null)));
    _presets = _Slot<PresetCatalog>(this, () async => PresetCatalog.fromJson(await _object('accounts.presets', null)));
    _context = _Slot<ModelContextList>(this, () async => ModelContextList.fromJson(await _object('models.context.list', null)));
  }

  final HostCall _call;

  /// Bumped when the connection changes: work started for the old one
  /// checks it after each `await`, and keeps nothing it brought back.
  int _generation = 0;

  /// The live connection's `welcome.device.scopes`; null until one has been
  /// up since [reset].
  Set<String>? _scopes;

  late final _Slot<String> _mode;
  late final _Slot<AccountsSnapshot> _accounts;
  late final _Slot<PresetCatalog> _presets;
  late final _Slot<ModelContextList> _context;

  List<_Slot<Object>> get _slots => [_mode, _accounts, _presets, _context];

  /// `local` or `cloud`.
  StateValue<Loaded<String>> get mode => _mode.state;
  StateValue<Loaded<AccountsSnapshot>> get accounts => _accounts.state;
  StateValue<Loaded<PresetCatalog>> get presets => _presets.state;
  StateValue<Loaded<ModelContextList>> get context => _context.state;

  /// A screen showing it, until it calls the function returned (once is
  /// enough; more do nothing). Read now unless what is held is current, and
  /// again whenever the host says it changed, for as long as any screen
  /// watches. The mode, once held, is kept current without a watch: its
  /// event carries it.
  void Function() watchMode() => _mode.watch();
  void Function() watchAccounts() => _accounts.watch();
  void Function() watchPresets() => _presets.watch();
  void Function() watchContext() => _context.watch();

  /// Read now (with a read out: once more after it) — a pull to refresh, a
  /// retry. Kept current only while watched.
  Future<void> loadMode() => _mode.request();
  Future<void> loadAccounts() => _accounts.request();
  Future<void> loadPresets() => _presets.request();
  Future<void> loadContext() => _context.request();

  // --- the connection ---------------------------------------------------------------

  /// Another host, or none: forget everything. The watches stay: they are
  /// the screens', which say when they close.
  void reset() {
    _generation += 1;
    _scopes = null;
    for (final slot in _slots) {
      slot.reset(forget: true);
    }
    _commands.clear();
  }

  /// A connection to this host is up, holding [scopes]
  /// (`welcome.device.scopes`). The first since [reset] notes them, and reads
  /// again what a screen watches but could not read before there was a
  /// connection to read it on (it would show `offline` until a pull to
  /// refresh) or kept watching across the [reset]. Any later one is
  /// [reconnected], told whether they changed.
  void connected(Iterable<String> scopes) {
    final before = _scopes;
    final now = _scopes = scopes.toSet();
    if (before != null) {
      reconnected(scopesChanged: before.length != now.length || !before.containsAll(now));
      return;
    }
    for (final slot in _slots) {
      slot.retryFailed();
    }
  }

  /// The same host, on a new connection: what was read on the old one is
  /// dropped as it comes back, and nothing held is current any more — the
  /// events sent while the line was down reached nobody. What is watched
  /// (and the mode, once held) is read again now; the rest on its next
  /// watch.
  ///
  /// With [scopesChanged] the accounts held are dropped too: `accounts.list`
  /// gives a device with `settings` the extra environment it hides from one
  /// without (spec §7.1), and a save is whole — an edit started from a copy
  /// read under the old scopes would save the account without it.
  void reconnected({bool scopesChanged = false}) {
    _generation += 1;
    _commands.clear();
    for (final slot in _slots) {
      final wanted = slot.wanted;
      slot.reset(forget: scopesChanged && identical(slot, _accounts));
      if (wanted) unawaited(slot.request());
    }
  }

  /// `mode.changed`, `accounts.changed`, `models.context.changed`. Never waits
  /// on a read here: they run on their own, so a burst of events does not
  /// stall the reader (N09).
  void onEvent(String kind, Object? payload) {
    switch (kind) {
      case Events.modeChanged:
        final mode = _modeOf(payload);
        if (mode != null) {
          _mode.land(mode);
        } else {
          _mode.changed();
        }
      case Events.accountsChanged:
        _accounts.changed();
        // The context rows come from the accounts and the assignments.
        _context.changed();
      case Events.modelsContextChanged:
        _context.changed();
    }
  }

  static String? _modeOf(Object? json) {
    final mode = asMap(json).str('mode');
    return mode == 'local' || mode == 'cloud' ? mode : null;
  }

  // --- calls ------------------------------------------------------------------------

  Future<Map<String, Object?>> _object(String method, Object? params) async {
    final answer = await _call(method, params);
    if (answer is! Map<String, Object?>) throw RcException('bad-response', detail: method);
    return answer;
  }

  /// A refusal (`ok:false`) is returned as the host wrote it, not thrown.
  Future<ModeResult> setMode(String mode) async {
    final result = ModeResult.fromJson(await _object('mode.set', {'mode': mode}));
    final now = result.mode;
    if (result.ok && (now == 'local' || now == 'cloud')) _mode.land(now!);
    return result;
  }

  Future<SettingResult> setActive(String agent, AccountChoice choice) async =>
      SettingResult.fromJson(await _object('accounts.setActive', {'agent': agent, 'choice': choice.toJson()}));

  Future<SaveGroupResult> saveGroup(AccountGroupInput input) async =>
      SaveGroupResult.fromJson(await _object('accounts.saveGroup', input.toJson()));

  /// [revision] as `accounts.list` gave it.
  Future<SettingResult> removeGroup(String groupId, {String? revision}) async =>
      SettingResult.fromJson(await _object('accounts.removeGroup', {'groupId': groupId, 'revision': ?revision}));

  /// An endpoint from before accounts (no `groupId`).
  Future<SettingResult> removeLegacy(String providerId) async =>
      SettingResult.fromJson(await _object('accounts.remove', {'providerId': providerId}));

  /// Ask an endpoint for its models. With no [apiKey], [providerId]'s stored
  /// key is used — only towards that account's own servers (`key-required`).
  /// [presetId] lets the host find the preset's model-list address.
  Future<DiscoverResult> discoverModels({
    required String dialect,
    required String baseUrl,
    String? apiKey,
    String? providerId,
    String? presetId,
  }) async =>
      DiscoverResult.fromJson(await _object('models.discover', {
        'dialect': dialect,
        'baseUrl': baseUrl,
        if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
        'providerId': ?providerId,
        'presetId': ?presetId,
      }));

  /// Set or reset a row's threshold and window; the table that comes back is
  /// the one shown.
  Future<ModelContextList> setContext(String key, {Change<int>? compactAt, Change<int>? window}) async {
    final list = ModelContextList.fromJson(await _object('models.context.set', {
      'key': key,
      if (compactAt != null) 'compactAt': compactAt.value,
      if (window != null) 'window': window.value,
    }));
    _context.land(list);
    return list;
  }

  Future<CloudModelsResult> cloudKeyModels(int keyId) async =>
      CloudModelsResult.fromJson(await _object('cloud.keys.models', {'keyId': keyId}));

  /// [keyName] goes into the assignments' names; the desktop has a default.
  Future<CloudAssignResult> cloudAssign(int keyId, List<CloudAssignment> assignments, {String? keyName}) async =>
      CloudAssignResult.fromJson(await _object('cloud.assign', {
        'keyId': keyId,
        if (keyName != null && keyName.trim().isNotEmpty) 'keyName': keyName.trim(),
        'assignments': [for (final assignment in assignments) assignment.toJson()],
      }));

  Future<SettingResult> cloudUnassign(String providerId) async =>
      SettingResult.fromJson(await _object('cloud.unassign', {'providerId': providerId}));

  // --- the `/` menu -------------------------------------------------------------------

  /// How long a list is answered from here once it has come.
  static const commandsFresh = Duration(seconds: 5);
  static const _commandsKept = 8;

  final LinkedHashMap<(String, String), _CommandsEntry> _commands = LinkedHashMap();

  /// The `/` menu for [agent] in [workdir]. Listing them can start the CLI
  /// (spec §7.1): a list that came less than [commandsFresh] ago is reused,
  /// and one on its way is shared. A failure is not kept.
  Future<List<SlashCommand>> commands(String agent, String workdir) {
    final key = (agent, workdir);
    final held = _commands.remove(key);
    if (held != null && (held.at == null || clock.now().difference(held.at!) < commandsFresh)) {
      _commands[key] = held;
      return held.future;
    }
    final entry = _CommandsEntry(() async {
      final answer = await _call('commands.list', {'agent': agent, 'workdir': workdir});
      if (answer is! List) throw const RcException('bad-response', detail: 'commands.list');
      return decodeObjects(answer, SlashCommand.fromJson);
    }());
    _commands[key] = entry;
    while (_commands.length > _commandsKept) {
      _commands.remove(_commands.keys.first);
    }
    unawaited(entry.future.then((_) => entry.at = clock.now(), onError: (Object _) {
      if (identical(_commands[key], entry)) _commands.remove(key);
    }));
    return entry.future;
  }
}

class _CommandsEntry {
  _CommandsEntry(this.future);

  final Future<List<SlashCommand>> future;

  /// When it came; null while it is on its way.
  DateTime? at;
}

/// One thing the screens read: its value, the screens watching it, and the
/// one read of it that runs at a time — a request that arrives while it runs
/// owes exactly one more.
class _Slot<T extends Object> {
  _Slot(this._owner, this._read, {this.pushed = false});

  final HostConfigController _owner;
  final Future<T> Function() _read;

  /// Its event carries it (`mode.changed`): once held it is kept current
  /// with no screen watching — read again after a reconnect, which is cheap.
  final bool pushed;
  final StateValue<Loaded<T>> state = StateValue<Loaded<T>>(Loaded<T>());

  int _watchers = 0;

  /// What is held may be behind the host — it said so, or the connection
  /// changed, while nobody watched; or the last read failed: the next watch
  /// reads.
  bool _stale = false;
  bool _owed = false;
  Object? _token;
  Future<void>? _running;

  /// Bumped when a value lands from elsewhere: a read that left before it
  /// brings back something older.
  int _version = 0;

  /// Read again when the host says it changed.
  bool get wanted => _watchers > 0 || (pushed && state.value.value != null);

  void Function() watch() {
    _watchers += 1;
    if (_stale || (state.value.value == null && _running == null)) unawaited(request());
    var open = true;
    return () {
      if (!open) return;
      open = false;
      _watchers -= 1;
    };
  }

  /// Watched, out of date — the last read failed, or a [reset] forgot what
  /// it read — and no read out now: read again.
  void retryFailed() {
    if (wanted && _stale && _running == null) unawaited(request());
  }

  /// The host said it changed.
  void changed() {
    if (wanted) {
      unawaited(request());
    } else {
      _stale = true;
    }
  }

  Future<void> request() {
    _owed = true;
    final running = _running;
    if (running != null) return running;
    final token = Object();
    _token = token;
    return _running = _run(token);
  }

  Future<void> _run(Object token) async {
    final generation = _owner._generation;
    bool current() => generation == _owner._generation && identical(_token, token);
    try {
      while (_owed && current()) {
        _owed = false;
        // A change said from here on is after what this read brings.
        _stale = false;
        final version = _version;
        state.value = Loaded<T>(value: state.value.value, loading: true);
        try {
          final value = await _read();
          if (!current()) return;
          state.value = Loaded<T>(value: version == _version ? value : state.value.value);
        } catch (error) {
          if (!current()) return;
          _stale = true;
          state.value = Loaded<T>(value: state.value.value, error: error);
        }
      }
    } finally {
      // Only its own: a read of a connection gone must not free the slot of
      // the one that replaced it.
      if (identical(_token, token)) {
        _token = null;
        _running = null;
      }
    }
  }

  void land(T value) {
    _version += 1;
    _stale = false;
    state.value = Loaded<T>(value: value, loading: state.value.loading);
  }

  void reset({required bool forget}) {
    _owed = false;
    _token = null;
    _running = null;
    _version += 1;
    _stale = true;
    if (forget) {
      state.value = Loaded<T>();
    } else if (state.value.loading) {
      state.value = Loaded<T>(value: state.value.value, error: state.value.error);
    }
  }
}
