import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';

import '../api/backend_client.dart';
import '../api/backend_models.dart';
import '../model/desktop.dart';
import '../protocol/bytes.dart';
import '../protocol/crypto_error.dart';
import '../protocol/pairing.dart';
import '../protocol/primitives.dart';
import '../protocol/protocol.dart';
import '../store/stores.dart';
import '../transport/carrier.dart';
import '../transport/enrollment.dart';
import '../transport/errors.dart';
import '../transport/inner.dart';
import '../transport/rc_client.dart';
import '../util/json.dart';
import '../util/mutex.dart';
import '../util/state_value.dart';
import 'app_state.dart';
import 'history.dart';
import 'live_turn.dart';
import 'search_fold.dart';
import 'terminal.dart';
import 'uploads.dart';

/// Raw bytes per upload chunk on the budgeted relay: about a second of the
/// default 100 KB/s once base64'd twice, so nothing else waits long behind
/// an attachment.
const relayUploadChunk = 48 * 1024;

/// What became of a prompt.
sealed class PromptOutcome {
  const PromptOutcome();
}

/// The desktop took the turn.
final class PromptAccepted extends PromptOutcome {
  const PromptAccepted(this.response);
  final PromptResponse response;
}

/// The desktop answered, on the same connection, that it did not take the
/// turn: the attachments are back in the composer for a retry. [reason] is a
/// [RemoteCallError] or the response's own `error` sentence.
final class PromptRefused extends PromptOutcome {
  const PromptRefused(this.reason);
  final Object? reason;
}

/// No trustworthy answer — a drop, a timeout: the turn may already be
/// running. The attachments were dropped (their ids died with the
/// connection either way, S28); the user should check the transcript.
final class PromptUncertain extends PromptOutcome {
  const PromptUncertain(this.error, {required this.droppedAttachments});
  final Object? error;
  final bool droppedAttachments;
}

/// Nothing was sent: an attachment is still uploading.
final class PromptBlocked extends PromptOutcome {
  const PromptBlocked(this.error);
  final RcException error;
}

/// What the pairing walk reports, for a progress line.
enum PairStep { registering, alreadyRegistered, handshaking, repairing, finishing }

/// What the files search exposes: a new object on every change, so a
/// listener that compares by identity sees every one (N02).
class SearchView {
  const SearchView(this.revision, this.state);
  final int revision;
  final SearchState state;
}

/// Why pairing could not go on, beyond the transport's own errors.
class PairingError implements Exception {
  const PairingError(this.reason, {this.server, this.signedIn, this.cause});

  /// `not-signed-in`, `wrong-backend` (the QR is for [server], we are signed
  /// in to [signedIn]), `no-ticket`, `no-grant` (already registered, but the
  /// backend will not issue a grant — revoked?), `cleanup-failed`.
  final String reason;
  final String? server;
  final String? signedIn;
  final Object? cause;

  @override
  String toString() => 'PairingError($reason${cause == null ? '' : ': $cause'})';
}

/// A refused `POST /grant`, sorted into "this pairing is over" and "try
/// later" (spec §9). 409 is the backend saying the device row is not active
/// — pending or revoked; 404 that the device or host row is gone. Neither
/// changes by retrying, and retrying is not free: every attempt spends the
/// account's per-user critical budget, so a revoked phone left open used to
/// lock every other phone of the account out of new grants.
RcException grantRefusal(BackendException error) => switch (error.status) {
      409 => RcException('revoked', detail: 'device', cause: error),
      404 => RcException('revoked', detail: 'gone', cause: error),
      _ => RcException('grant', cause: error),
    };

/// The application's one state machine: login, hosts, the connection to the
/// active host, the session list, and the live turn. Screens read [state]
/// and call the methods here; nothing else touches the transport or the
/// backend.
class AppController {
  AppController({
    required this.backend,
    required this._carriers,
    required this._secrets,
    required this._files,
    required this.platformName,
    required this.deviceModel,
    this.appInfo = const AppInfo(name: 'skidsense-mobile', version: '0.1.0', platform: 'android'),
    this.clientConfig = const ClientConfig(),
  }) {
    _grants = _GrantCache(this);
    _uploads = _newUploads();
  }

  final BackendClient backend;
  final CarrierFactory _carriers;
  final SecretStore _secrets;
  final FileStore _files;
  final String platformName;
  final String deviceModel;
  final AppInfo appInfo;
  final ClientConfig clientConfig;

  static const _identityKey = 'device-static-key';
  static const _pairedKey = 'paired-hosts.json';
  static const _lockKey = 'biometric-lock';

  final StateValue<AppState> _state = StateValue<AppState>(const AppState());
  StateValue<AppState> get states => _state;
  AppState get state => _state.value;

  void _update(AppState Function(AppState state) change) => _state.value = change(_state.value);

  /// Bumped whenever [liveTurn] changed.
  final StateValue<int> liveRevision = StateValue<int>(0);
  final LiveTurn liveTurn = LiveTurn();

  void _bumpLive() => liveRevision.value = liveRevision.value + 1;

  RcClient? _client;
  final List<StreamSubscription<Object?>> _clientSubscriptions = [];

  /// Bumped on every connect and disconnect: work started for one
  /// connection checks it after each `await` and stops when it moved.
  int _epoch = 0;

  late final _GrantCache _grants;
  late UploadManager _uploads;

  /// Attachments for the composer, tied to the live connection.
  UploadManager get uploads => _uploads;

  UploadManager _newUploads() => UploadManager(
        call: _callObject,
        connectionMarker: () => _client?.connectionMarker,
        chunkSize: () => _client?.route is RouteRelay ? relayUploadChunk : Protocol.uploadChunk,
      );

  // --- the device key ---------------------------------------------------------------

  KeyPair? _identity;

  /// The device's static X25519 key pair, from the secret store.
  ///
  /// A read that *throws* is not a missing key: it is the store failing, and
  /// generating a fresh pair then would overwrite the real one when the next
  /// read succeeds — every paired host would go `unknown-device`. So a throw
  /// propagates, and a new key is made only for a clean null (S27).
  Future<KeyPair> identity() async {
    final cached = _identity;
    if (cached != null) return cached;
    final stored = await _secrets.get(_identityKey);
    final KeyPair pair;
    if (stored != null && stored.length == 32) {
      pair = Primitives.keyPairFromPrivate(stored);
    } else {
      pair = Primitives.generateKeyPair();
      try {
        await _secrets.put(_identityKey, pair.priv);
      } catch (error) {
        // The key must not be used without being stored: the next launch
        // would generate another and the hosts would see a stranger.
        throw CryptoError('no-keystore', 'the secret store would not keep the device key', error);
      }
    }
    return _identity = pair;
  }

  Future<String> devicePublicKey() async => B64u.encode((await identity()).pub);

  // --- startup ------------------------------------------------------------------

  bool _started = false;
  StreamSubscription<AuthSession?>? _sessionWatch;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _restoreSecretsIfBroken();
    await backend.restore();
    final session = backend.session.value;
    final paired = await _loadPaired(session?.userId ?? 0, session?.baseUrl ?? '');
    final locked = await _files.read(_lockKey) == '1';
    _update((s) => s.copyWith(
          ready: true,
          baseUrl: session?.baseUrl ?? backend.defaultBaseUrl,
          user: session?.username,
          userId: session?.userId ?? 0,
          paired: paired,
          biometricLock: locked,
          locked: locked,
        ));
    // The landing screen keys on `user`: a session the backend has since
    // revoked is cleared by the client's next refresh, and the UI must
    // follow it back to login.
    _sessionWatch = backend.session.changes.listen((current) {
      if (current == null && _state.value.user != null) _onSessionExpired();
    });
    if (session != null) unawaited(refreshHosts());
  }

  /// The store said its master would not decrypt this install (S27): the
  /// session it held cannot be recovered, so the phone is signed out and the
  /// pairings (made with a device key that is already gone) forgotten.
  Future<void> _restoreSecretsIfBroken() async {
    final secrets = _secrets;
    if (secrets is! BrokenStoreRestorer) return;
    final restorer = secrets as BrokenStoreRestorer;
    if (!await restorer.restoreIfBroken()) return;
    await _files.delete(_pairedKey);
    _update((s) => s.copyWith(notice: const AppNotice(NoticeKind.storeReset)));
  }

  void _onSessionExpired() {
    disconnect();
    _update((s) => s.copyWith(
          user: null,
          userId: 0,
          hosts: const [],
          hostsError: null,
          activeHostId: null,
          welcome: null,
          sessions: const [],
          paired: const [],
          notice: const AppNotice(NoticeKind.sessionExpired),
        ));
  }

  // --- login --------------------------------------------------------------------

  /// What the server at [base] asks of a login (captcha, password login on).
  Future<ServerStatus> probe(String base) async {
    final status = await backend.status(base);
    _update((s) => s.copyWith(baseUrl: base, status: status));
    return status;
  }

  /// Signs in; returns the second-factor challenge when one is required.
  Future<LoginChallenge?> login(String base, String username, String password, {String? geetest, String? turnstile}) async {
    final challenge = await backend.login(base, username, password, geetest: geetest, turnstile: turnstile);
    _update((s) => s.copyWith(baseUrl: base));
    if (challenge == null) await _onSignedIn();
    return challenge;
  }

  Future<void> verifyTwoFactor(String base, String flowToken, String code) async {
    await backend.verifyLogin(base, flowToken, code);
    await _onSignedIn();
  }

  Future<void> _onSignedIn() async {
    final session = backend.session.value;
    // Pairings belong to an account (`server` + `userId`): another account
    // must neither see the previous one's computers nor overwrite its
    // records with its own (S33).
    final paired = await _loadPaired(session?.userId ?? 0, session?.baseUrl ?? '');
    _update((s) => s.copyWith(
          user: session?.username,
          userId: session?.userId ?? 0,
          baseUrl: session?.baseUrl ?? s.baseUrl,
          paired: paired,
          notice: null,
        ));
    unawaited(refreshHosts());
  }

  Future<void> logout() async {
    disconnect();
    await backend.logout();
    // Disk is deliberately untouched: the pairings on it belong to the
    // account that just left, and are read back if it signs in again (S33).
    _update((s) => s.copyWith(
          user: null,
          userId: 0,
          hosts: const [],
          paired: const [],
          activeHostId: null,
          welcome: null,
          sessions: const [],
          devices: const [],
        ));
  }

  // --- hosts --------------------------------------------------------------------

  Future<void> refreshHosts() async {
    _update((s) => s.copyWith(hostsLoading: true));
    try {
      final hosts = await backend.hosts();
      _update((s) => s.copyWith(hosts: hosts, hostsLoading: false, hostsError: null));
      await _learnAddresses(hosts);
    } catch (error) {
      _update((s) => s.copyWith(hostsLoading: false, hostsError: error));
    }
  }

  /// The live endpoint per host, so a fresher address list reaches the client.
  final Map<String, HostEndpoint> _liveEndpoints = {};

  /// Fold the backend's `lan_addrs`/`lan_port` into the paired hosts. The
  /// QR code's address is a snapshot; a router gives out another after a
  /// reboot. When an address really changed the active connection is nudged.
  Future<void> _learnAddresses(List<HostRow> hosts) async {
    final paired = _state.value.paired;
    if (paired.isEmpty) return;
    var changed = false;
    var dirty = false;
    final updated = [
      for (final host in paired)
        () {
          final row = hosts.where((row) => row.hostId == host.hostId).firstOrNull;
          if (row == null) return host;
          final port = row.lanPort >= 1 && row.lanPort <= 65535 ? row.lanPort : null;
          final endpoint = _liveEndpoints[host.hostId];
          final fresh = endpoint?.learn(row.lanAddrs, port) ?? !_sameStrings(row.lanAddrs, host.lanAddrs);
          if (fresh) changed = true;
          final next = host.copyWith(
            lanAddrs: row.lanAddrs.isEmpty ? host.lanAddrs : row.lanAddrs,
            lanPort: port ?? host.lanPort,
            name: row.name.isEmpty ? host.name : row.name,
          );
          if (!_sameStrings(next.lanAddrs, host.lanAddrs) || next.lanPort != host.lanPort || next.name != host.name) {
            dirty = true;
            return next;
          }
          return host;
        }(),
    ];
    if (dirty) {
      await _persistPaired(updated);
      _update((s) => s.copyWith(paired: updated));
    }
    if (changed && _state.value.activeHostId != null) _client?.retry();
  }

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  Future<void> loadDevices() async {
    final host = _state.value.activeHost;
    if (host == null) return;
    try {
      final devices = await backend.devices(host.hostId);
      _update((s) => s.copyWith(devices: devices));
    } catch (error) {
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.error, error: error)));
    }
  }

  Future<void> renameDevice(String deviceId, String name) async {
    await backend.updateDevice(deviceId, name: name);
    await loadDevices();
  }

  Future<void> setDeviceScopes(String deviceId, List<String> scopes) async {
    await backend.updateDevice(deviceId, scopes: scopes);
    await loadDevices();
  }

  /// Revoke a device. Revoking *this* phone also forgets the host here.
  Future<void> revokeDevice(String deviceId) async {
    final host = _state.value.activeHost;
    if (host == null) return;
    await backend.revokeDevice(deviceId);
    if (deviceId == host.deviceId) {
      disconnect();
      final remaining = _state.value.paired.where((p) => p.hostId != host.hostId).toList();
      await _persistPaired(remaining);
      _update((s) => s.copyWith(paired: remaining, activeHostId: null, welcome: null, sessions: const [], devices: const []));
      return;
    }
    await loadDevices();
  }

  // --- pairing ------------------------------------------------------------------

  /// The whole first visit: check the QR points at the backend we are signed
  /// in to, register this device's key, run the enroll handshake, and only
  /// then treat the host as paired — the `welcome` is the host's
  /// acknowledgement that it recorded this key (spec §4.3 step 5, §8.4).
  Future<PairedHost> pair(PairingPayload payload, {void Function(PairStep step)? onStep}) async {
    final session = backend.session.value;
    if (session == null) throw const PairingError('not-signed-in');
    if (normalizeBackendUrl(payload.server) != normalizeBackendUrl(session.baseUrl)) {
      throw PairingError('wrong-backend', server: payload.server, signedIn: session.baseUrl);
    }
    onStep?.call(PairStep.registering);
    final DeviceRegistration registration;
    try {
      registration = await backend.registerDevice(payload.hostId, _deviceName, await devicePublicKey(), platformName);
    } on BackendException catch (error) {
      // 409: this key is already active on that host, so per spec §9 the
      // answer names the device but carries no ticket. Recovery is a grant,
      // then an ordinary `connect` handshake.
      final existing = asMap(error.data).str('device_id');
      if (error.status != 409 || existing == null || existing.isEmpty) rethrow;
      onStep?.call(PairStep.alreadyRegistered);
      return _reconnectExisting(payload, existing, onStep);
    }
    return _finishPairing(payload, registration.device.deviceId, registration.ticket, onStep);
  }

  String get _deviceName => deviceModel.trim().isEmpty ? 'Phone' : deviceModel.trim();

  /// The 409 path. The grant is fetched directly rather than through the
  /// cache, which is keyed on the *active* host — and this one is not active.
  Future<PairedHost> _reconnectExisting(PairingPayload payload, String deviceId, void Function(PairStep)? onStep) async {
    final String grant;
    try {
      grant = (await backend.grant(payload.hostId, deviceId)).grant;
    } on BackendException catch (error) {
      throw PairingError('no-grant', cause: error);
    }
    onStep?.call(PairStep.handshaking);
    final Welcome welcome;
    try {
      welcome = await Enrollment.connectWithGrant(
        payload: payload,
        deviceId: deviceId,
        identity: await identity(),
        grant: grant,
        carriers: _carriers,
        config: clientConfig,
      );
    } on HandshakeRejected catch (error) {
      // `hsr` is plaintext: this refusal only earns the destructive repair
      // once the relay — TLS to the backend — agrees (C6).
      if (error.code != 'unknown-device') rethrow;
      return _repairStaleConfirmed(payload, deviceId, grant, onStep);
    }
    return _rememberPairing(payload, deviceId, welcome, onStep);
  }

  /// The LAN walk said `unknown-device`; before believing it, the relay route
  /// is asked on its own. Only when the backend-mediated route says the same
  /// does the stale row get revoked. A relay that is itself unreachable says
  /// nothing — the phone keeps its pairing and the user retries.
  Future<PairedHost> _repairStaleConfirmed(
    PairingPayload payload,
    String deviceId,
    String grant,
    void Function(PairStep)? onStep,
  ) async {
    try {
      final welcome = await Enrollment.connectWithGrant(
        payload: payload.copyWith(lanAddrs: const [], lanPort: 0),
        deviceId: deviceId,
        identity: await identity(),
        grant: grant,
        carriers: _carriers,
        config: clientConfig,
      );
      // The relay took the plain `connect` after all: the LAN answer was
      // the forged one. Nothing stale to repair.
      return await _rememberPairing(payload, deviceId, welcome, onStep);
    } on HandshakeRejected catch (error) {
      if (error.code != 'unknown-device') rethrow;
      return _repairStale(payload, deviceId, onStep);
    }
  }

  /// The backend lists this phone as active on that host, and the host —
  /// through the relay — has no record of it. Retrying `connect` can never
  /// work, and every new registration earns the same 409. The user is
  /// holding a fresh QR code, so this does what they would do by hand:
  /// revoke the stale row, register again, and enrol with the code in hand.
  Future<PairedHost> _repairStale(PairingPayload payload, String staleDeviceId, void Function(PairStep)? onStep) async {
    onStep?.call(PairStep.repairing);
    try {
      await backend.revokeDevice(staleDeviceId);
    } on BackendException catch (error) {
      throw PairingError('cleanup-failed', cause: error);
    }
    final registration = await backend.registerDevice(payload.hostId, _deviceName, await devicePublicKey(), platformName);
    return _finishPairing(payload, registration.device.deviceId, registration.ticket, onStep);
  }

  Future<PairedHost> _finishPairing(PairingPayload payload, String deviceId, String ticket, void Function(PairStep)? onStep) async {
    if (ticket.isEmpty) throw const PairingError('no-ticket');
    onStep?.call(PairStep.handshaking);
    final welcome = await Enrollment.enroll(
      payload: payload,
      deviceId: deviceId,
      identity: await identity(),
      ticket: ticket,
      carriers: _carriers,
      config: clientConfig,
    );
    return _rememberPairing(payload, deviceId, welcome, onStep);
  }

  /// Record the host after any successful handshake, `enroll` or `connect` —
  /// one place, so the two paths cannot record different fields.
  Future<PairedHost> _rememberPairing(
    PairingPayload payload,
    String deviceId,
    Welcome welcome,
    void Function(PairStep)? onStep,
  ) async {
    final host = PairedHost(
      hostId: payload.hostId,
      hostKey: B64u.encode(payload.hostKey),
      deviceId: deviceId,
      name: welcome.host.name,
      machine: payload.machine,
      lanAddrs: payload.lanAddrs,
      lanPort: payload.lanPort,
      server: payload.server,
      userId: _state.value.userId,
      pairedAt: clock.now().millisecondsSinceEpoch,
    );
    final remaining = [..._state.value.paired.where((p) => p.hostId != host.hostId), host];
    await _persistPaired(remaining);
    _liveEndpoints.remove(host.hostId);
    _update((s) => s.copyWith(paired: remaining, notice: null));
    onStep?.call(PairStep.finishing);
    return host;
  }

  /// Forget a host here, and revoke this phone's device row there — the one
  /// signal both other ends act on (spec §8.2). The local half never waits on
  /// the network: offline, the pairing is still forgotten here, and the user
  /// is told the desktop must finish it.
  Future<void> forgetHost(String hostId) async {
    final host = _state.value.paired.where((p) => p.hostId == hostId).firstOrNull;
    final wasActive = _state.value.activeHostId == hostId;
    if (wasActive) disconnect();
    final remaining = _state.value.paired.where((p) => p.hostId != hostId).toList();
    await _persistPaired(remaining);
    _liveEndpoints.remove(hostId);
    _update((s) => s.copyWith(paired: remaining, activeHostId: wasActive ? null : s.activeHostId));
    if (host == null) return;
    try {
      await backend.revokeDevice(host.deviceId);
    } on BackendException catch (error) {
      // Already gone there (revoked from the desktop, host removed): done.
      if (error.status == 404) return;
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.forgetUnrevoked, error: error)));
    } catch (error) {
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.forgetUnrevoked, error: error)));
    }
  }

  // --- connection -------------------------------------------------------------------

  bool _connectedBefore = false;

  Future<void> connect(String hostId) async {
    final host = _state.value.paired.where((p) => p.hostId == hostId).firstOrNull;
    if (host == null) return;
    disconnect();
    _grants.clear();
    final epoch = _epoch;
    // One endpoint object per host, kept across reconnects: it is where a
    // fresher address list from `GET /hosts` lands.
    final endpoint = _liveEndpoints.putIfAbsent(hostId, host.endpoint);
    final rc = RcClient(
      endpoint: endpoint,
      identity: await identity(),
      credentials: _grants,
      carriers: _carriers,
      config: clientConfig,
    );
    if (epoch != _epoch) return;
    rc.onLanUnreachable = _onLanUnreachable;
    _client = rc;
    _connectedBefore = false;
    _uploads = _newUploads();
    // A half-sent attachment lives in the desktop's per-connection stash;
    // moving to the LAN mid-upload would lose it.
    rc.canSwitchRoute = () => !_uploads.busy;
    if (_state.value.relayBytesPerSecond == null) unawaited(_loadRelayBudget());
    _search.value = null;
    _update((s) => s.copyWith(
          activeHostId: hostId,
          connection: const ClientIdle(),
          welcome: null,
          sessions: const [],
          workspaces: const [],
          devices: const [],
        ));
    _clientSubscriptions
      ..add(rc.states.changes.listen(_onConnectionState))
      ..add(rc.events.listen((event) => _onEvent(event.kind, event.payload)));
    rc.start();
  }

  Future<void> _loadRelayBudget() async {
    try {
      final budget = (await backend.companionConfig()).relay?.userBytesPerSecond;
      if (budget != null && budget > 0) _update((s) => s.copyWith(relayBytesPerSecond: budget));
    } catch (_) {}
  }

  void disconnect() {
    _epoch += 1;
    for (final subscription in _clientSubscriptions) {
      unawaited(subscription.cancel());
    }
    _clientSubscriptions.clear();
    _resyncToken = null;
    _resyncPendingSeq = null;
    _healToken = null;
    _reloadOwed = false;
    _terminalKey = null;
    _terminalSink = null;
    _terminalBuffer.clear();
    _openSessionKey = null;
    final rc = _client;
    if (rc == null) return;
    _client = null;
    unawaited(rc.dispose());
    liveTurn.reset();
    _bumpLive();
    _update((s) => s.copyWith(connection: const ClientIdle(), welcome: null, sessions: const []));
  }

  void retry() => _client?.retry();

  /// The phone's network changed or the app came to the foreground: cut a
  /// backoff short, and on the relay look for the desktop on the LAN now.
  void networkChanged() {
    _client?.retry();
    _client?.probeLan();
  }

  /// A LAN attempt failed and the client is falling back to the relay: ask
  /// the backend for the host's current addresses. Rate-limited.
  int _lastAddressRefresh = 0;

  Future<void> _onLanUnreachable() async {
    final now = clock.now().millisecondsSinceEpoch;
    if (now - _lastAddressRefresh < 60000) return;
    _lastAddressRefresh = now;
    await refreshHosts();
  }

  void _onConnectionState(ClientState connection) {
    _update((s) => s.copyWith(connection: connection, welcome: connection is ClientConnected ? connection.welcome : null));
    if (connection is ClientConnected) {
      // Whatever was uploaded on the connection that just died is gone from
      // the desktop's stash too.
      _uploads.dropStaleConnections();
      if (_state.value.workspaces.isEmpty) unawaited(loadWorkspaces());
      unawaited(loadSessions());
      // A reconnect: whatever the open turn did while the line was down was
      // published to nobody — and a turn waiting on an answer publishes
      // none, so its question would never appear. Re-read it now.
      if (_connectedBefore) _resyncAfterReconnect();
      _connectedBefore = true;
    } else {
      _endInterruptedSearch();
    }
  }

  /// Events are folded in arrival order, but the work they trigger is not:
  /// a request made from inside this handler used to stall the reader behind
  /// a burst of events (N09). So this stays a fold, and hands round trips to
  /// single-flight work that runs on its own.
  void _onEvent(String kind, Object? payload) {
    switch (kind) {
      case Events.sessionPatch:
        _onSessionPatch(payload);
      case Events.sessionsChanged:
        _onSessionsChanged();
      case Events.tuiData:
        final decoded = TerminalEvents.decodeData(payload);
        if (decoded == null) return;
        final (key, data) = decoded;
        // The terminal's first bytes are on the wire before the screen has
        // registered its sink (the CLI draws at once); they wait here (N04).
        if (_terminalSink != null && _terminalKey == key) {
          _terminalSink!.onData(key, data);
        } else if (_terminalKey == null || _terminalKey == key) {
          final buffer = _terminalBuffer.putIfAbsent(key, StringBuffer.new);
          buffer.write(data);
          if (buffer.length > TerminalChannel.bufferLimit) {
            final text = buffer.toString();
            buffer
              ..clear()
              ..write(text.substring(text.length - TerminalChannel.bufferLimit));
          }
        }
      case Events.tuiExit:
        final exit = TerminalEvents.decodeExit(payload);
        if (exit == null || exit.key != _terminalKey) return;
        _terminalBuffer.remove(exit.key);
        _terminalSink?.onExit(exit);
      case Events.searchProgress:
        _onSearchProgress(payload);
      default:
        // agents.changed, fs.changed, git.changed, background.jobs: the UI
        // reads what it needs on demand.
        break;
    }
  }

  // --- terminal routing -------------------------------------------------------------

  String? _terminalKey;
  TerminalSink? _terminalSink;
  final Map<String, StringBuffer> _terminalBuffer = {};

  /// A terminal screen appeared for [key]: hand over everything held for it.
  void attachTerminal(String key, TerminalSink sink) {
    _terminalKey = key;
    _terminalSink = sink;
    final held = _terminalBuffer.remove(key);
    if (held != null && held.isNotEmpty) sink.onData(key, held.toString());
  }

  /// The bytes [attachTerminal] would hand over for [key] (tests).
  String bufferedTerminalData(String key) => _terminalBuffer[key]?.toString() ?? '';

  void detachTerminal(TerminalSink sink) {
    if (!identical(_terminalSink, sink)) return;
    _terminalSink = null;
    _terminalKey = null;
  }

  // --- the open session -------------------------------------------------------------

  String? _openSessionKey;
  String? get openSessionKey => _openSessionKey;

  /// The one re-read in flight for the open session, as a token: cleared to
  /// cancel, compared after each `await` to tell whether this is still it.
  Object? _resyncToken;
  int _resyncGeneration = 0;
  int? _resyncPendingSeq;

  /// The session row's `updatedAt` as of the transcript held here — what a
  /// reconnect compares to tell whether a turn ran meanwhile.
  int _historyUpdatedAt = 0;

  void _onSessionPatch(Object? payload) {
    if (payload is! Map<String, Object?>) return;
    final SessionPatchPush push;
    try {
      push = SessionPatchPush.fromJson(payload);
    } catch (_) {
      return;
    }
    if (push.sessionKey != _openSessionKey) return;
    // A re-read is bringing back a snapshot that already contains the patches
    // still in flight: applying any of them under the old baseline would
    // duplicate their deltas (C1).
    if (_resyncToken != null) {
      _resyncPendingSeq = _max(_resyncPendingSeq ?? push.seq, push.seq);
      return;
    }
    switch (liveTurn.apply(push)) {
      case Applied.ok:
        _bumpLive();
      case Applied.gap:
        _resyncSnapshot(push.seq);
    }
  }

  static int _max(int a, int b) => a > b ? a : b;

  void _resyncSnapshot(int seq) {
    if (_resyncToken != null) {
      _resyncPendingSeq = _max(_resyncPendingSeq ?? seq, seq);
      return;
    }
    _scheduleResync(seq);
  }

  /// After a reconnect: re-read the open turn, and the transcript only if
  /// something ran.
  void _resyncAfterReconnect() {
    if (_openSessionKey == null) return;
    // A re-read that was in flight belonged to the dead connection.
    _resyncToken = null;
    _resyncPendingSeq = null;
    _scheduleResync(liveTurn.seq, quietIfIdle: true);
  }

  void _scheduleResync(int triggerSeq, {bool quietIfIdle = false}) {
    final key = _openSessionKey;
    if (key == null) return;
    final generation = ++_resyncGeneration;
    final token = Object();
    _resyncToken = token;
    unawaited(_runResync(key, token, generation, triggerSeq, quietIfIdle));
  }

  Future<void> _runResync(String key, Object token, int generation, int triggerSeq, bool quietIfIdle) async {
    bool current() => generation == _resyncGeneration && identical(_resyncToken, token);
    try {
      var target = triggerSeq;
      while (true) {
        final fresh = await _readSnapshot(key);
        // A stale job must not write over what a newer `sessions.open` or
        // re-read already decided.
        if (!current()) return;
        // Null: the request failed, so the baseline does not move, and the
        // next frame — or `sessions.changed` — tries again.
        if (fresh == null) return;
        final snapshot = fresh.$1;
        if (snapshot != null) {
          liveTurn
            ..setSnapshot(snapshot)
            ..acceptSeq(fresh.$2 ?? target);
        } else {
          final row = _state.value.sessions.where((r) => r.key == key).firstOrNull;
          if (quietIfIdle && liveTurn.snapshot?.running != true && (row?.updatedAt ?? 0) <= _historyUpdatedAt) {
            // Nothing was running and nothing ran: the transcript held is
            // current, and over the budgeted relay a re-read is not free.
            liveTurn.acceptSeq(target);
            return;
          }
          // The turn ended before the re-read arrived: its end lives in the
          // session record, not in `turn.snapshot` (C1).
          final opened = await _tryDecoded('sessions.open', {'key': key}, OpenSessionResponse.fromJson);
          if (!current()) return;
          if (opened == null) return;
          _historyUpdatedAt = opened.row.updatedAt;
          liveTurn
            ..setHistory(opened.turns)
            ..setSnapshot(opened.live ?? opened.turns.lastOrNull?.snapshot)
            ..acceptSeq(target);
        }
        _bumpLive();
        unawaited(loadSessions());
        final again = _resyncPendingSeq;
        if (again == null || again == target) return;
        _resyncPendingSeq = null;
        target = again;
      }
    } finally {
      // Only its own slot: a cancelled re-read finishing after its
      // replacement started must not clear the replacement.
      if (identical(_resyncToken, token)) _resyncToken = null;
      // A gap that arrived while this one ran still needs an answer: its
      // patches were dropped, not applied.
      final pending = _resyncPendingSeq;
      if (pending != null && generation == _resyncGeneration && _openSessionKey == key) {
        _resyncPendingSeq = null;
        _resyncSnapshot(pending);
      }
    }
  }

  /// One `turn.snapshot`: (snapshot or null when the turn has ended, the seq
  /// it already contains when the desktop says), or null when the request failed.
  Future<(TurnSnapshot?, int?)?> _readSnapshot(String key) async {
    final Object? answer;
    try {
      answer = await _request('turn.snapshot', {'key': key});
    } catch (_) {
      return null;
    }
    if (answer is! Map<String, Object?> || answer.isEmpty) return (null, null);
    return (TurnSnapshot.fromJson(answer), answer.integer('seq'));
  }

  /// The session list is refreshed here — coalesced, never from inside the
  /// event handler — and doubles as the gap rule's backstop (C1).
  bool _reloadRunning = false;
  bool _reloadOwed = false;

  /// `sessions.changed`, coalesced but never dropped: a signal that arrives
  /// while a reload is in flight owes exactly one more.
  void _onSessionsChanged() {
    _reloadOwed = true;
    if (_reloadRunning) return;
    _reloadRunning = true;
    final epoch = _epoch;
    unawaited(() async {
      try {
        while (_reloadOwed && epoch == _epoch) {
          _reloadOwed = false;
          try {
            await _reloadSessionsOnce();
            if (epoch == _epoch) _healIfStale();
          } catch (_) {
            // Offline mid-reload: the next change or reconnect asks again.
          }
        }
      } finally {
        _reloadRunning = false;
      }
    }());
  }

  /// The row says the open turn is over while the live view still runs it (a
  /// gap whose re-read failed is the usual way in): read the turn's end from
  /// the session record. Patches keep applying while that read is out, and
  /// its answer is used only if none did — an answer computed before the
  /// turn's last patch must not be painted over it.
  Object? _healToken;

  void _healIfStale() {
    final key = _openSessionKey;
    if (key == null || liveTurn.snapshot?.running != true) return;
    final row = _state.value.sessions.where((r) => r.key == key).firstOrNull;
    if (row == null || row.runState == 'running') return;
    if (_resyncToken != null || _healToken != null) return;
    final generation = _resyncGeneration;
    final before = liveTurn.revision;
    final token = Object();
    _healToken = token;
    unawaited(() async {
      try {
        final opened = await _tryDecoded('sessions.open', {'key': key}, OpenSessionResponse.fromJson);
        if (opened == null || !identical(_healToken, token)) return;
        if (_openSessionKey != key || generation != _resyncGeneration) return;
        if (liveTurn.revision != before) {
          if (liveTurn.snapshot?.running == true && _resyncToken == null) _scheduleResync(liveTurn.seq);
          return;
        }
        _historyUpdatedAt = opened.row.updatedAt;
        liveTurn
          ..setHistory(opened.turns)
          ..setSnapshot(opened.live ?? opened.turns.lastOrNull?.snapshot);
        _bumpLive();
      } finally {
        if (identical(_healToken, token)) _healToken = null;
      }
    }());
  }

  Future<void> _reloadSessionsOnce() async {
    final rows = await _decodedList('sessions.list', <String, Object?>{}, SessionRow.fromJson);
    if (rows == null) return;
    _update((s) => s.copyWith(sessions: rows, sessionsLoading: false, sessionsError: null));
  }

  // --- host calls ------------------------------------------------------------------

  /// A `req` on the live connection. Throws when offline or when the host refuses.
  Future<Object?> _request(String method, [Object? params, Duration? timeout]) {
    final rc = _client;
    if (rc == null) return Future.error(const RcException('offline'));
    return rc.call(method, params, timeout);
  }

  Future<Map<String, Object?>?> _callObject(String method, Map<String, Object?> params) async {
    final answer = await _request(method, params);
    return answer is Map<String, Object?> ? answer : null;
  }

  /// [method]'s answer decoded with [decode]. A shape that does not decode is
  /// reported as a notice and answers null; a failed request throws.
  Future<T?> _decoded<T>(String method, Object? params, T Function(Map<String, Object?> json) decode) async {
    final answer = await _request(method, params);
    if (answer is! Map<String, Object?>) {
      if (answer == null) return null;
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.undecodable, detail: method)));
      return null;
    }
    try {
      return decode(answer);
    } catch (error) {
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.undecodable, detail: method, error: error)));
      return null;
    }
  }

  Future<List<T>?> _decodedList<T>(String method, Object? params, T Function(Map<String, Object?> json) decode) async {
    final answer = await _request(method, params);
    if (answer == null) return const [];
    if (answer is! List) {
      _update((s) => s.copyWith(notice: AppNotice(NoticeKind.undecodable, detail: method)));
      return null;
    }
    return decodeObjects(answer, decode);
  }

  /// [_decoded] that answers null instead of throwing.
  Future<T?> _tryDecoded<T>(String method, Object? params, T Function(Map<String, Object?> json) decode) async {
    try {
      return await _decoded(method, params, decode);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadWorkspaces() async {
    try {
      final workspaces = await _decodedList('workspaces.list', null, Workspace.fromJson);
      if (workspaces == null) return;
      workspaces.sort((a, b) => a.order.compareTo(b.order));
      _update((s) => s.copyWith(workspaces: workspaces));
    } catch (_) {}
  }

  Future<void> loadSessions() async {
    _update((s) => s.copyWith(sessionsLoading: true));
    try {
      final rows = await _decodedList('sessions.list', <String, Object?>{}, SessionRow.fromJson);
      _update((s) => s.copyWith(sessions: rows ?? const [], sessionsLoading: false, sessionsError: null));
    } catch (error) {
      _update((s) => s.copyWith(sessionsLoading: false, sessionsError: error));
    }
  }

  Future<void> searchSessions(String query) async {
    _update((s) => s.copyWith(search: query));
    if (query.trim().isEmpty) {
      await loadSessions();
      return;
    }
    try {
      // `sessions.search` answers `SessionRow[]` — the same shape as `sessions.list`.
      final rows = await _decodedList('sessions.search', {'query': query}, SessionRow.fromJson);
      if (_state.value.search != query) return;
      _update((s) => s.copyWith(sessions: rows ?? const []));
    } catch (error) {
      _update((s) => s.copyWith(sessionsError: error));
    }
  }

  Future<OpenSessionResponse?> openSession(String key) async {
    final previous = _openSessionKey;
    if (previous != null && previous != key) unawaited(_client?.unsubscribe(previous));
    // The in-flight re-read belongs to whichever session it was following:
    // its answer must not land on this one.
    _resyncToken = null;
    _resyncPendingSeq = null;
    _resyncGeneration += 1;
    _openSessionKey = key;
    liveTurn.reset();
    _bumpLive();
    final response = await _decoded('sessions.open', {'key': key}, OpenSessionResponse.fromJson);
    if (response == null || _openSessionKey != key) return response;
    await _client?.subscribe(key);
    _historyUpdatedAt = response.row.updatedAt;
    liveTurn
      ..setHistory(response.turns)
      ..setSnapshot(response.live);
    _bumpLive();
    return response;
  }

  Future<void> closeSession() async {
    final key = _openSessionKey;
    if (key == null) return;
    _resyncToken = null;
    _resyncPendingSeq = null;
    _resyncGeneration += 1;
    _openSessionKey = null;
    liveTurn.reset();
    _bumpLive();
    await _client?.unsubscribe(key);
  }

  /// Send a turn, with whatever attachments are staged *for this session*.
  ///
  /// The parameter is `sessionKey` — the one exception to the `key`
  /// convention of spec §7. The upload ids are handed over only once every
  /// one is complete: an unfinished id fails the whole turn on the desktop.
  ///
  /// The uploads go back only if the host *said*, on the same connection,
  /// that it did not take the turn. Anything else leaves it uncertain whether
  /// the turn started, and the ids are dead with the connection regardless:
  /// they are dropped and the user is told to check the transcript (S28).
  Future<PromptOutcome> prompt(String key, String text, {String? model, String? effort, String? approvalMode}) async {
    final List<Upload> taken;
    try {
      taken = _uploads.take(key);
    } on RcException catch (error) {
      return PromptBlocked(error);
    }
    final body = <String, Object?>{
      'sessionKey': key,
      'prompt': text,
      if (model != null && model.isNotEmpty) 'model': model,
      if (effort != null && effort.isNotEmpty) 'effort': effort,
      if (approvalMode != null && approvalMode.isNotEmpty) 'approvalMode': approvalMode,
      if (taken.isNotEmpty) 'uploads': [for (final upload in taken) upload.id],
    };
    try {
      final answer = await _request('turn.prompt', body);
      if (answer is! Map<String, Object?>) return PromptUncertain(null, droppedAttachments: taken.isNotEmpty);
      final response = PromptResponse.fromJson(answer);
      if (!response.ok) {
        // The host answered on this connection and refused: the stash still
        // holds the ids, and a retry may carry them as they are.
        _uploads.restore(taken);
        return PromptRefused(response.error);
      }
      return PromptAccepted(response);
    } on RemoteCallError catch (error) {
      _uploads.restore(taken);
      return PromptRefused(error);
    } catch (error) {
      return PromptUncertain(error, droppedAttachments: taken.isNotEmpty);
    }
  }

  /// Stage a file for the next turn's prompt.
  Future<void> attach(String name, String? mimeType, List<int> bytes, {String? sessionKey}) =>
      _uploads.begin(name, mimeType, bytes, sessionKey: sessionKey);

  Future<void> detach(String id) => _uploads.abort(id);

  /// Everything staged for [sessionKey], dropped — when leaving its composer.
  /// Safe to call from a widget's dispose: it runs on its own (S29).
  Future<void> detachAll(String sessionKey) => _uploads.abortAll(sessionKey);

  Future<void> stopTurn(String key) async {
    try {
      await _request('turn.stop', {'key': key});
    } catch (_) {}
  }

  Future<void> steer(String key, String text) => _request('turn.steer', {'key': key, 'text': text});

  /// Answer a question. [answer] is the wire form of `AskUserAnswer`.
  Future<void> interact(String key, String interactionId, Map<String, Object?> answer) =>
      _request('turn.interact', {'key': key, 'interactionId': interactionId, 'answer': answer});

  Future<void> selectChoice(String key, String interactionId, String choiceId) =>
      interact(key, interactionId, {'action': 'select', 'choiceId': choiceId});

  Future<void> answerText(String key, String interactionId, String text) =>
      interact(key, interactionId, {'action': 'text', 'text': text});

  Future<void> skipQuestion(String key, String interactionId) => interact(key, interactionId, {'action': 'skip'});

  Future<void> cancelQuestion(String key, String interactionId) => interact(key, interactionId, {'action': 'cancel'});

  Future<List<AgentStatus>> agents() async => await _decodedList('agents.list', null, AgentStatus.fromJson) ?? const [];

  Future<ModelCatalog?> models(String agent) => _decoded('models.list', {'agent': agent}, ModelCatalog.fromJson);

  Future<SessionRow?> newSession(String agent, String workdir, {String? title}) async {
    final row = await _decoded(
      'sessions.new',
      {'agent': agent, 'workdir': workdir, if (title != null && title.trim().isNotEmpty) 'title': title.trim()},
      SessionRow.fromJson,
    );
    unawaited(loadSessions());
    return row;
  }

  Future<void> renameSession(String key, String title) async {
    await _request('sessions.rename', {'key': key, 'title': title});
    await loadSessions();
  }

  Future<void> deleteSession(String key) async {
    await _request('sessions.delete', {'key': key});
    if (_openSessionKey == key) _openSessionKey = null;
    await loadSessions();
  }

  // --- files search (spec §6.4) -------------------------------------------------------

  final StateValue<SearchView?> _search = StateValue<SearchView?>(null);
  StateValue<SearchView?> get search => _search;
  SearchFold? _searchFold;
  int _searchRevision = 0;

  void _publishSearch() {
    final fold = _searchFold;
    _search.value = fold == null ? null : SearchView(++_searchRevision, fold.state);
  }

  /// Start a content search. Progress comes back as `search.progress` under
  /// the id chosen here — the desktop namespaces it internally and echoes
  /// ours back, so cancelling uses the same string.
  Future<String> startSearch(String root, String query, {bool isRegex = false}) async {
    await cancelSearch();
    final id = 's${bytesToHex(Primitives.randomBytes(8))}';
    final fold = SearchFold(id, query);
    _searchFold = fold;
    _publishSearch();
    try {
      await _request('search.start', {'id': id, 'root': root, 'query': query, 'isRegex': isRegex});
    } catch (error) {
      if (identical(_searchFold, fold)) {
        fold.fail(SearchEnd.request, error);
        _publishSearch();
      }
    }
    return id;
  }

  Future<void> cancelSearch() async {
    final fold = _searchFold;
    if (fold == null || fold.state.done) return;
    fold.cancel();
    _publishSearch();
    try {
      await _request('search.cancel', {'id': fold.id});
    } catch (_) {}
  }

  /// Leaving the files screen: stop the desktop streaming to nobody.
  void clearSearch() {
    unawaited(cancelSearch());
    _searchFold = null;
    _publishSearch();
  }

  /// The desktop cancels a device's searches when its connection ends, and
  /// the `done` it would have sent goes nowhere: the search box spun for ever.
  void _endInterruptedSearch() {
    final fold = _searchFold;
    if (fold == null || fold.state.done) return;
    fold.fail(SearchEnd.interrupted);
    _publishSearch();
  }

  void _onSearchProgress(Object? payload) {
    final fold = _searchFold;
    if (fold == null || payload is! Map<String, Object?>) return;
    final SearchProgressPush push;
    try {
      push = SearchProgressPush.fromJson(payload);
    } catch (_) {
      return;
    }
    if (fold.apply(push)) _publishSearch();
  }

  // --- artifacts and files -------------------------------------------------------------

  Future<List<ArtifactRow>> artifacts({String? root, int limit = 200}) async =>
      await _decodedList('artifacts.list', {'root': ?root, 'limit': limit}, ArtifactRow.fromJson) ?? const [];

  Future<ListDirResult?> listDir(String root, String path, {bool showIgnored = false}) =>
      _decoded('fs.list', {'root': root, 'path': path, 'showIgnored': showIgnored}, ListDirResult.fromJson);

  Future<ReadFileResult?> readFile(String root, String path) =>
      _decoded('fs.read', {'root': root, 'path': path}, ReadFileResult.fromJson);

  /// Save [text] over [path] if it is still the version [etag] names: an edit
  /// made elsewhere since is a `conflict`, not a silent overwrite.
  Future<WriteFileResult?> writeFile(String root, String path, String text, {String? etag}) =>
      _decoded('fs.write', {'root': root, 'path': path, 'text': text, 'etag': ?etag}, WriteFileResult.fromJson);

  /// `kind`: `mkdir`, `create`, `rename`, `delete`.
  Future<FileOpResult?> fileOp(String root, String kind, {String? path, String? to}) =>
      _decoded('fs.op', {'root': root, 'kind': kind, 'path': ?path, 'to': ?to}, FileOpResult.fromJson);

  // --- git -------------------------------------------------------------------------------

  Future<GitSnapshot?> gitSnapshot(String root) => _decoded('git.snapshot', {'root': root}, GitSnapshot.fromJson);

  Future<GitDiffResult?> gitDiff(String root, String path, {String against = 'head'}) =>
      _decoded('git.diff', {'root': root, 'path': path, 'against': against}, GitDiffResult.fromJson);

  Future<List<GitBranchInfo>> gitBranches(String root) async =>
      await _decodedList('git.branches', {'root': root}, GitBranchInfo.fromJson) ?? const [];

  /// `op`: `stage`, `unstage`, `stageAll`, `discard`, `discardUntracked`,
  /// `commit`, `fetch`, `pull`, `push`, `switchBranch`, `init`.
  Future<GitMutateResult?> gitMutate(String root, String op, {List<String>? paths, String? message, String? branch}) =>
      _decoded(
        'git.mutate',
        {'root': root, 'op': op, 'paths': ?paths, 'message': ?message, 'branch': ?branch},
        GitMutateResult.fromJson,
      );

  // --- terminal ----------------------------------------------------------------------------

  Future<Object?> openTerminal(String key, int cols, int rows) => _request('tui.open', {'key': key, 'cols': cols, 'rows': rows});

  Future<void> terminalInput(String key, String data) => _request('tui.input', {'key': key, 'data': data});

  Future<void> terminalResize(String key, int cols, int rows) =>
      _request('tui.resize', {'key': key, 'cols': cols, 'rows': rows});

  /// Safe to call from a widget's dispose: it runs on its own (S29).
  Future<void> closeTerminal(String key) async {
    try {
      await _request('tui.close', {'key': key});
    } catch (_) {}
  }

  // --- history -------------------------------------------------------------------------------

  Future<HistoryRepository?> historyRepository() async {
    final host = _state.value.activeHost;
    if (host == null) return null;
    return HistoryRepository(backend: backend, identity: await identity(), hostId: host.hostId);
  }

  // --- settings ------------------------------------------------------------------------------

  Future<void> setBiometricLock(bool enabled) async {
    await _files.write(_lockKey, enabled ? '1' : '0');
    _update((s) => s.copyWith(biometricLock: enabled, locked: enabled && s.locked));
  }

  void unlock() => _update((s) => s.copyWith(locked: false));

  void lock() {
    if (_state.value.biometricLock) _update((s) => s.copyWith(locked: true));
  }

  void clearNotice() => _update((s) => s.copyWith(notice: null, hostsError: null, sessionsError: null));

  // --- persistence ---------------------------------------------------------------------------

  /// The pairings one account may see, as stored on disk.
  Future<List<PairedHost>> _loadPaired(int userId, String server) async {
    final all = await _readPaired();
    return all.where((host) => host.visibleTo(userId, server)).toList();
  }

  Future<List<PairedHost>> _readPaired() async {
    final raw = await _files.read(_pairedKey);
    if (raw == null) return const [];
    try {
      return decodeObjects(jsonDecode(raw), PairedHost.fromJson);
    } catch (_) {
      return const [];
    }
  }

  /// Write [visible] — what the *current* account holds — back, preserving
  /// any pairing on disk the current account cannot see (S33).
  Future<void> _persistPaired(List<PairedHost> visible) => _persistLock.run(() async {
        final userId = _state.value.userId;
        final server = backend.session.value?.baseUrl ?? _state.value.baseUrl;
        final others = (await _readPaired()).where((host) => !host.visibleTo(userId, server));
        await _files.write(_pairedKey, jsonEncode([for (final host in [...visible, ...others]) host.toJson()]));
      });

  final Mutex _persistLock = Mutex();

  Future<void> dispose() async {
    disconnect();
    await _sessionWatch?.cancel();
  }
}

/// Grants for the active host, fetched from the backend and cached until
/// they expire. `rc-access` lasts an hour, which is also how long LAN mode
/// survives with the backend unreachable (spec §8).
class _GrantCache extends Credentials {
  _GrantCache(this._app);

  final AppController _app;
  final Mutex _lock = Mutex();
  String? _cached;
  int _expiresAt = 0;

  @override
  Future<String> grant({required bool fresh}) => _lock.run(() async {
        final host = _app.state.activeHost;
        if (host == null) throw const RcException('no-host');
        final now = clock.now().millisecondsSinceEpoch;
        final cached = _cached;
        if (!fresh && cached != null && now < _expiresAt - 60000) return cached;
        final GrantResponse response;
        try {
          response = await _app.backend.grant(host.hostId, host.deviceId);
        } on BackendException catch (error) {
          throw grantRefusal(error);
        }
        _cached = response.grant;
        _expiresAt = response.expiresAt > 1000000000000 ? response.expiresAt : response.expiresAt * 1000;
        if (_expiresAt <= now) _expiresAt = now + 3600000;
        return response.grant;
      });

  @override
  Future<void> onUnauthorized() async {
    await _app.backend.invalidateAccessToken();
    clear();
  }

  /// The host kicked this device because its scopes changed or it was
  /// revoked (spec §6.5): the cached grant still lists the old scopes.
  @override
  Future<void> onDropped() async => clear();

  void clear() {
    _cached = null;
    _expiresAt = 0;
  }
}
