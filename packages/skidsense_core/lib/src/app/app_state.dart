import '../api/backend_models.dart';
import '../model/desktop.dart';
import '../protocol/bytes.dart';
import '../protocol/history_crypto.dart';
import '../protocol/pairing.dart';
import '../transport/inner.dart';
import '../transport/rc_client.dart';
import '../util/json.dart';

/// A paired host as this phone stores it.
class PairedHost {
  const PairedHost({
    required this.hostId,
    required this.hostKey,
    required this.deviceId,
    this.name = '',
    this.machine = '',
    this.lanAddrs = const [],
    this.lanPort = 0,
    this.server = '',
    this.userId = 0,
    this.pairedAt = 0,
  });

  factory PairedHost.fromJson(Map<String, Object?> j) => PairedHost(
        hostId: j.str('hostId') ?? '',
        hostKey: j.str('hostKey') ?? '',
        deviceId: j.str('deviceId') ?? '',
        name: j.str('name') ?? '',
        machine: j.str('machine') ?? '',
        lanAddrs: j.strings('lanAddrs'),
        lanPort: j.number('lanPort') ?? 0,
        server: j.str('server') ?? '',
        userId: j.number('userId') ?? 0,
        pairedAt: j.number('pairedAt') ?? 0,
      );

  final String hostId;

  /// The host's static public key, pinned from the QR code (base64url).
  final String hostKey;
  final String deviceId;
  final String name;
  final String machine;
  final List<String> lanAddrs;
  final int lanPort;

  /// The backend both ends were signed in to at pairing time.
  final String server;

  /// Whose pairing this is (S33) — 0 for a record written before pairings
  /// carried it.
  final int userId;
  final int pairedAt;

  String get displayName => name.isNotEmpty ? name : (machine.isNotEmpty ? machine : hostId);

  String get fingerprint {
    try {
      return hostFingerprint(B64u.decode(hostKey, 32));
    } catch (_) {
      return '';
    }
  }

  Map<String, Object?> toJson() => {
        'hostId': hostId,
        'hostKey': hostKey,
        'deviceId': deviceId,
        'name': name,
        'machine': machine,
        'lanAddrs': lanAddrs,
        'lanPort': lanPort,
        'server': server,
        'userId': userId,
        'pairedAt': pairedAt,
      };

  HostEndpoint endpoint() => HostEndpoint(
        hostId: hostId,
        hostKey: B64u.decode(hostKey, 32),
        deviceId: deviceId,
        lanAddrs: lanAddrs,
        lanPort: lanPort,
      );

  /// Visible to [userId] on [server]: an exact account match, or a legacy
  /// record with no owner on the same backend, adopted for lack of a better
  /// claimant.
  bool visibleTo(int userId, String server) =>
      this.userId == userId || (this.userId == 0 && normalizeBackendUrl(this.server) == normalizeBackendUrl(server));

  PairedHost copyWith({String? name, List<String>? lanAddrs, int? lanPort}) => PairedHost(
        hostId: hostId,
        hostKey: hostKey,
        deviceId: deviceId,
        name: name ?? this.name,
        machine: machine,
        lanAddrs: lanAddrs ?? this.lanAddrs,
        lanPort: lanPort ?? this.lanPort,
        server: server,
        userId: userId,
        pairedAt: pairedAt,
      );
}

/// Something the app wants to tell the user, as data; the app words it.
enum NoticeKind {
  /// [AppNotice.error] says what failed.
  error,

  /// The backend ended the session: sign in again.
  sessionExpired,

  /// The secure store could not decrypt what it held (a device migration):
  /// signed out, pairings forgotten.
  storeReset,

  /// Forgotten here, but the backend did not take the revocation:
  /// [AppNotice.error] says why; the desktop must finish it.
  forgetUnrevoked,

  /// A host answer did not decode; [AppNotice.detail] names the method.
  undecodable,
}

class AppNotice {
  const AppNotice(this.kind, {this.error, this.detail});

  final NoticeKind kind;
  final Object? error;
  final String? detail;
}

const Object _unset = Object();

/// Everything the UI reads. One object, replaced wholesale on change.
class AppState {
  const AppState({
    this.ready = false,
    this.baseUrl = '',
    this.status,
    this.user,
    this.userId = 0,
    this.hosts = const [],
    this.hostsError,
    this.hostsLoading = false,
    this.paired = const [],
    this.activeHostId,
    this.connection = const ClientIdle(),
    this.welcome,
    this.workspaces = const [],
    this.sessions = const [],
    this.sessionsLoading = false,
    this.sessionsError,
    this.search = '',
    this.devices = const [],
    this.serverScopes,
    this.biometricLock = false,
    this.locked = false,
    this.notice,
    this.relayBytesPerSecond,
  });

  final bool ready;
  final String baseUrl;
  final ServerStatus? status;

  /// The signed-in username; null when signed out.
  final String? user;
  final int userId;
  final List<HostRow> hosts;
  final Object? hostsError;
  final bool hostsLoading;
  final List<PairedHost> paired;
  final String? activeHostId;
  final ClientState connection;
  final Welcome? welcome;
  final List<Workspace> workspaces;
  final List<SessionRow> sessions;
  final bool sessionsLoading;
  final Object? sessionsError;
  final String search;

  /// The devices the active host has, from the backend.
  final List<DeviceRow> devices;

  /// The scopes the backend knows, from `/config` — [Scopes.legacy] from one
  /// that lists none. Null until read, and after a read that failed: nothing
  /// is known of the backend then. `Scopes.known` reads that as the eight
  /// from before `settings`, so a permission it may not know is never
  /// offered; nor is the backend said to lack one.
  final List<String>? serverScopes;
  final bool biometricLock;
  final bool locked;
  final AppNotice? notice;

  /// The relay's per-account budget from `/config`, so the UI can say why the
  /// relay is slow.
  final int? relayBytesPerSecond;

  bool get signedIn => user != null;
  bool get connected => connection is ClientConnected;

  /// Scopes come from the host's `welcome` — the effective set, already
  /// narrowed (spec §8.3).
  Set<String> get scopes => welcome?.device.scopes.toSet() ?? const {};
  bool can(String method) => welcome?.can(method) ?? false;
  bool canScope(String scope) => scopes.contains(scope);

  /// Sessions for one workspace, newest first.
  List<SessionRow> sessionsIn(String workdir) =>
      sessions.where((row) => row.workdir == workdir).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  PairedHost? get activeHost {
    for (final host in paired) {
      if (host.hostId == activeHostId) return host;
    }
    return null;
  }

  HostRow? hostRow(String hostId) {
    for (final row in hosts) {
      if (row.hostId == hostId) return row;
    }
    return null;
  }

  AppState copyWith({
    bool? ready,
    String? baseUrl,
    Object? status = _unset,
    Object? user = _unset,
    int? userId,
    List<HostRow>? hosts,
    Object? hostsError = _unset,
    bool? hostsLoading,
    List<PairedHost>? paired,
    Object? activeHostId = _unset,
    ClientState? connection,
    Object? welcome = _unset,
    List<Workspace>? workspaces,
    List<SessionRow>? sessions,
    bool? sessionsLoading,
    Object? sessionsError = _unset,
    String? search,
    List<DeviceRow>? devices,
    Object? serverScopes = _unset,
    bool? biometricLock,
    bool? locked,
    Object? notice = _unset,
    Object? relayBytesPerSecond = _unset,
  }) =>
      AppState(
        ready: ready ?? this.ready,
        baseUrl: baseUrl ?? this.baseUrl,
        status: identical(status, _unset) ? this.status : status as ServerStatus?,
        user: identical(user, _unset) ? this.user : user as String?,
        userId: userId ?? this.userId,
        hosts: hosts ?? this.hosts,
        hostsError: identical(hostsError, _unset) ? this.hostsError : hostsError,
        hostsLoading: hostsLoading ?? this.hostsLoading,
        paired: paired ?? this.paired,
        activeHostId: identical(activeHostId, _unset) ? this.activeHostId : activeHostId as String?,
        connection: connection ?? this.connection,
        welcome: identical(welcome, _unset) ? this.welcome : welcome as Welcome?,
        workspaces: workspaces ?? this.workspaces,
        sessions: sessions ?? this.sessions,
        sessionsLoading: sessionsLoading ?? this.sessionsLoading,
        sessionsError: identical(sessionsError, _unset) ? this.sessionsError : sessionsError,
        search: search ?? this.search,
        devices: devices ?? this.devices,
        serverScopes: identical(serverScopes, _unset) ? this.serverScopes : serverScopes as List<String>?,
        biometricLock: biometricLock ?? this.biometricLock,
        locked: locked ?? this.locked,
        notice: identical(notice, _unset) ? this.notice : notice as AppNotice?,
        relayBytesPerSecond: identical(relayBytesPerSecond, _unset) ? this.relayBytesPerSecond : relayBytesPerSecond as int?,
      );
}
