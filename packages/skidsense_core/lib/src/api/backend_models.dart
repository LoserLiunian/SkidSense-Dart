import '../util/json.dart';

/// `GET /api/status`, the fields the login screen needs.
class ServerStatus {
  const ServerStatus({
    this.systemName,
    this.passwordLoginEnabled = true,
    this.geetestCheck = false,
    this.geetestId,
    this.turnstileCheck = false,
    this.turnstileSiteKey,
    this.serverAddress,
  });

  factory ServerStatus.fromJson(Map<String, Object?> j) => ServerStatus(
        systemName: j.str('system_name'),
        passwordLoginEnabled: j.boolean('password_login_enabled') ?? true,
        geetestCheck: j.boolean('geetest_check') ?? false,
        geetestId: j.str('geetest_id'),
        turnstileCheck: j.boolean('turnstile_check') ?? false,
        turnstileSiteKey: j.str('turnstile_site_key'),
        serverAddress: j.str('server_address'),
      );

  final String? systemName;
  final bool passwordLoginEnabled;
  final bool geetestCheck;
  final String? geetestId;
  final bool turnstileCheck;
  final String? turnstileSiteKey;
  final String? serverAddress;

  bool get needsGeetest => geetestCheck && (geetestId?.isNotEmpty ?? false);
  bool get needsTurnstile => turnstileCheck && !needsGeetest;
}

class LoginMethod {
  const LoginMethod({this.method = '', this.available = true, this.reason});

  factory LoginMethod.fromJson(Map<String, Object?> j) =>
      LoginMethod(method: j.str('method') ?? '', available: j.boolean('available') ?? true, reason: j.str('reason'));

  final String method;
  final bool available;
  final String? reason;
}

/// The password was right and the account has a second factor.
class LoginChallenge {
  const LoginChallenge(this.flowToken, this.methods);

  final String flowToken;
  final List<LoginMethod> methods;
}

class UserInfo {
  const UserInfo({this.id = 0, this.username = '', this.displayName});

  factory UserInfo.fromJson(Map<String, Object?> j) =>
      UserInfo(id: j.number('id') ?? 0, username: j.str('username') ?? '', displayName: j.str('display_name'));

  final int id;
  final String username;
  final String? displayName;
}

/// `GET /api/companion/config`.
class CompanionConfig {
  const CompanionConfig({
    this.enabled = false,
    this.grantPublicKey,
    this.accessTtl = 3600,
    this.enrollTtl = 600,
    this.wsPath,
    this.history,
    this.relay,
  });

  factory CompanionConfig.fromJson(Map<String, Object?> j) => CompanionConfig(
        enabled: j.boolean('enabled') ?? false,
        grantPublicKey: j.str('grant_public_key'),
        accessTtl: j.number('access_ttl') ?? 3600,
        enrollTtl: j.number('enroll_ttl') ?? 600,
        wsPath: j.str('ws_path'),
        history: j.object('history', CompanionHistoryConfig.fromJson),
        relay: j.object('relay', CompanionRelayConfig.fromJson),
      );

  final bool enabled;
  final String? grantPublicKey;
  final int accessTtl;
  final int enrollTtl;
  final String? wsPath;
  final CompanionHistoryConfig? history;
  final CompanionRelayConfig? relay;
}

/// The relay's own limits (§10, §13).
class CompanionRelayConfig {
  const CompanionRelayConfig({this.userBytesPerSecond});

  factory CompanionRelayConfig.fromJson(Map<String, Object?> j) =>
      CompanionRelayConfig(userBytesPerSecond: j.number('user_bytes_per_second'));

  /// The per-account budget, both directions together; absent from a backend that predates it.
  final int? userBytesPerSecond;
}

class CompanionHistoryConfig {
  const CompanionHistoryConfig({this.enabled = false, this.maxBlobBytes = 0, this.maxUserBytes = 0});

  factory CompanionHistoryConfig.fromJson(Map<String, Object?> j) => CompanionHistoryConfig(
        enabled: j.boolean('enabled') ?? false,
        maxBlobBytes: j.number('max_blob_bytes') ?? 0,
        maxUserBytes: j.number('max_user_bytes') ?? 0,
      );

  final bool enabled;
  final int maxBlobBytes;
  final int maxUserBytes;
}

/// One desktop registered under the account (spec §9). Times are Unix seconds.
class HostRow {
  const HostRow({
    required this.hostId,
    this.name = '',
    this.publicKey = '',
    this.platform = '',
    this.appVersion = '',
    this.lanAddrs = const [],
    this.lanPort = 0,
    this.online = false,
    this.createdAt = 0,
    this.lastSeenAt = 0,
  });

  factory HostRow.fromJson(Map<String, Object?> j) => HostRow(
        hostId: j.str('host_id') ?? '',
        name: j.str('name') ?? '',
        publicKey: j.str('public_key') ?? '',
        platform: j.str('platform') ?? '',
        appVersion: j.str('app_version') ?? '',
        lanAddrs: j.strings('lan_addrs'),
        lanPort: j.number('lan_port') ?? 0,
        online: j.boolean('online') ?? false,
        createdAt: j.number('created_at') ?? 0,
        lastSeenAt: j.number('last_seen_at') ?? 0,
      );

  final String hostId;
  final String name;
  final String publicKey;
  final String platform;
  final String appVersion;
  final List<String> lanAddrs;
  final int lanPort;

  /// Whether the desktop is connected to the *relay*. A desktop with only
  /// LAN access on is never online here — which is not the same as unreachable.
  final bool online;
  final int createdAt;
  final int lastSeenAt;
}

class DeviceRow {
  const DeviceRow({
    required this.deviceId,
    this.hostId = '',
    this.name = '',
    this.publicKey = '',
    this.platform = '',
    this.scopes = const [],
    this.status = '',
    this.createdAt = 0,
    this.activatedAt,
    this.revokedAt,
    this.lastSeenAt,
  });

  factory DeviceRow.fromJson(Map<String, Object?> j) => DeviceRow(
        deviceId: j.str('device_id') ?? '',
        hostId: j.str('host_id') ?? '',
        name: j.str('name') ?? '',
        publicKey: j.str('public_key') ?? '',
        platform: j.str('platform') ?? '',
        scopes: j.strings('scopes'),
        status: j.str('status') ?? '',
        createdAt: j.number('created_at') ?? 0,
        activatedAt: j.number('activated_at'),
        revokedAt: j.number('revoked_at'),
        lastSeenAt: j.number('last_seen_at'),
      );

  final String deviceId;
  final String hostId;
  final String name;
  final String publicKey;
  final String platform;
  final List<String> scopes;

  /// `pending | active | revoked`.
  final String status;
  final int createdAt;
  final int? activatedAt;
  final int? revokedAt;
  final int? lastSeenAt;
}

class DeviceRegistration {
  const DeviceRegistration({required this.device, required this.ticket, this.ticketExpiresAt = 0});

  factory DeviceRegistration.fromJson(Map<String, Object?> j) => DeviceRegistration(
        device: j.object('device', DeviceRow.fromJson) ?? const DeviceRow(deviceId: ''),
        ticket: j.str('ticket') ?? '',
        ticketExpiresAt: j.number('ticket_expires_at') ?? 0,
      );

  final DeviceRow device;
  final String ticket;
  final int ticketExpiresAt;
}

class GrantResponse {
  const GrantResponse({required this.grant, this.expiresAt = 0});

  factory GrantResponse.fromJson(Map<String, Object?> j) =>
      GrantResponse(grant: j.str('grant') ?? '', expiresAt: j.number('expires_at') ?? 0);

  final String grant;

  /// Unix seconds, or milliseconds from a backend that sends those.
  final int expiresAt;
}

class HistoryKeyRow {
  const HistoryKeyRow({required this.epoch, required this.wrapped});

  factory HistoryKeyRow.fromJson(Map<String, Object?> j) =>
      HistoryKeyRow(epoch: j.number('epoch') ?? 0, wrapped: j.str('wrapped') ?? '');

  final int epoch;
  final String wrapped;
}

class HistorySessionRow {
  const HistorySessionRow({required this.sessionKey, required this.epoch, this.updatedAt = 0, this.size = 0});

  factory HistorySessionRow.fromJson(Map<String, Object?> j) => HistorySessionRow(
        sessionKey: j.str('session_key') ?? '',
        epoch: j.number('epoch') ?? 0,
        updatedAt: j.number('updated_at') ?? 0,
        size: j.number('size') ?? 0,
      );

  final String sessionKey;
  final int epoch;
  final int updatedAt;
  final int size;
}

class HistoryBlobRow {
  const HistoryBlobRow({required this.sessionKey, required this.epoch, this.updatedAt = 0, required this.blob});

  factory HistoryBlobRow.fromJson(Map<String, Object?> j) => HistoryBlobRow(
        sessionKey: j.str('session_key') ?? '',
        epoch: j.number('epoch') ?? 0,
        updatedAt: j.number('updated_at') ?? 0,
        blob: j.str('blob') ?? '',
      );

  final String sessionKey;
  final int epoch;
  final int updatedAt;
  final String blob;
}

/// The signed-in session. Persisted, encrypted, in the secret store.
class AuthSession {
  const AuthSession({
    required this.baseUrl,
    required this.accessToken,
    this.accessExpiresAt = 0,
    this.refreshCookie,
    this.sessionId,
    this.userId = 0,
    this.username = '',
  });

  factory AuthSession.fromJson(Map<String, Object?> j) => AuthSession(
        baseUrl: j.str('baseUrl') ?? '',
        accessToken: j.str('accessToken') ?? '',
        accessExpiresAt: j.number('accessExpiresAt') ?? 0,
        refreshCookie: j.str('refreshCookie'),
        sessionId: j.str('sessionId'),
        userId: j.number('userId') ?? 0,
        username: j.str('username') ?? '',
      );

  final String baseUrl;
  final String accessToken;

  /// Local expiry estimate, epoch ms.
  final int accessExpiresAt;
  final String? refreshCookie;
  final String? sessionId;
  final int userId;
  final String username;

  Map<String, Object?> toJson() => {
        'baseUrl': baseUrl,
        'accessToken': accessToken,
        'accessExpiresAt': accessExpiresAt,
        'refreshCookie': ?refreshCookie,
        'sessionId': ?sessionId,
        'userId': userId,
        'username': username,
      };

  AuthSession withExpiry(int expiresAt) => AuthSession(
        baseUrl: baseUrl,
        accessToken: accessToken,
        accessExpiresAt: expiresAt,
        refreshCookie: refreshCookie,
        sessionId: sessionId,
        userId: userId,
        username: username,
      );
}
