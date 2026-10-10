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

/// new-api quota units per display dollar (`common.QuotaPerUnit`), as the
/// desktop's `src/main/backend.ts` counts them.
const quotaPerUnit = 500000;

/// A quota in new-api's units, in dollars — the desktop's `usd()`: a number,
/// or a string of one; anything else is 0.
double usdFromQuota(Object? quota) {
  final value = switch (quota) {
    num() => quota.toDouble(),
    String() => double.tryParse(quota.trim().isEmpty ? '0' : quota.trim()),
    _ => null,
  };
  return value == null || !value.isFinite ? 0 : value / quotaPerUnit;
}

/// Dollars in new-api's quota units, never below 0.
int quotaFromUsd(double dollars) {
  final units = dollars * quotaPerUnit;
  return units.isFinite && units > 0 ? units.round() : 0;
}

/// `GET /api/user/self`: who is signed in, and their balance.
class UserInfo {
  const UserInfo({
    this.id = 0,
    this.username = '',
    this.displayName,
    this.group = '',
    this.affCode = '',
    this.quotaUsd = 0,
    this.usedQuotaUsd = 0,
  });

  factory UserInfo.fromJson(Map<String, Object?> j) => UserInfo(
        id: j.number('id') ?? 0,
        username: j.str('username') ?? '',
        displayName: j.str('display_name'),
        group: j.str('group') ?? '',
        affCode: j.str('aff_code') ?? '',
        quotaUsd: usdFromQuota(j['quota']),
        usedQuotaUsd: usdFromQuota(j['used_quota']),
      );

  final int id;
  final String username;
  final String? displayName;

  /// The user's own group (what a key with no group of its own uses).
  final String group;
  final String affCode;

  /// The balance left, and what has been spent, in dollars.
  final double quotaUsd;
  final double usedQuotaUsd;
}

/// One API key (`token`) of the account, as `GET /api/token/` lists it — the
/// key itself masked; `BackendClient.revealToken` fetches it.
class ApiKeyRow {
  const ApiKeyRow({
    this.id = 0,
    this.name = '',
    this.maskedKey = '',
    this.status = 0,
    this.unlimited = false,
    this.remainQuotaUsd = 0,
    this.usedQuotaUsd = 0,
    this.expiredTime = -1,
    this.group = '',
    this.modelLimitsEnabled = false,
    this.modelLimits = '',
  });

  factory ApiKeyRow.fromJson(Map<String, Object?> j) => ApiKeyRow(
        id: j.number('id') ?? 0,
        name: j.str('name') ?? '',
        maskedKey: j.str('key') ?? '',
        status: j.number('status') ?? 0,
        unlimited: j.boolean('unlimited_quota') ?? false,
        remainQuotaUsd: usdFromQuota(j['remain_quota']),
        usedQuotaUsd: usdFromQuota(j['used_quota']),
        expiredTime: j.number('expired_time') ?? -1,
        group: j.str('group') ?? '',
        modelLimitsEnabled: j.boolean('model_limits_enabled') ?? false,
        modelLimits: j.str('model_limits') ?? '',
      );

  final int id;
  final String name;

  /// Masked, e.g. `abcd**********wxyz`.
  final String maskedKey;

  /// new-api's token status: 1 enabled, 2 disabled, 3 expired, 4 exhausted.
  final int status;
  final bool unlimited;
  final double remainQuotaUsd;
  final double usedQuotaUsd;

  /// Unix seconds, or -1 for never.
  final int expiredTime;
  final String group;

  /// Whether the key keeps to its own model list, [modelLimits] (comma separated).
  final bool modelLimitsEnabled;
  final String modelLimits;
}

/// A new API key.
class CreateKeyInput {
  const CreateKeyInput({required this.name, this.unlimited = true, this.quotaUsd = 0, this.expiredTime = -1, this.group = ''});

  /// The most [name] may take, in UTF-8 bytes — new-api refuses a longer one
  /// (`len(token.Name) > 50` in its `controller/token.go`): 50 letters, 16
  /// Chinese characters.
  static const nameBytes = 50;

  final String name;
  final bool unlimited;

  /// The key's own limit, when not [unlimited].
  final double quotaUsd;

  /// Unix seconds, or -1 for never.
  final int expiredTime;

  /// Empty: the user's own group.
  final String group;

  Map<String, Object?> toJson() => {
        'name': name,
        'unlimited_quota': unlimited,
        'remain_quota': unlimited ? 0 : quotaFromUsd(quotaUsd),
        'expired_time': expiredTime,
        'group': group,
        'model_limits_enabled': false,
        'model_limits': '',
      };
}

/// A key just made: its id, and the key itself, to be shown once.
class CreatedKey {
  const CreatedKey({required this.id, required this.key});

  final int id;
  final String key;
}

/// A group the user may put a key in (`GET /api/user/self/groups`).
class TokenGroup {
  const TokenGroup({required this.name, this.desc = '', this.ratio, this.ratioLabel});

  factory TokenGroup.fromJson(String name, Map<String, Object?> j) {
    final ratio = j['ratio'];
    return TokenGroup(
      name: name,
      desc: j.str('desc') ?? '',
      ratio: ratio is num ? ratio : null,
      ratioLabel: ratio is String ? ratio : null,
    );
  }

  final String name;
  final String desc;

  /// The price multiplier for this user in this group.
  final num? ratio;

  /// In place of [ratio] where there is no one figure — `自动` for `auto`.
  final String? ratioLabel;
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
    this.scopes,
    this.defaultScopes,
  });

  factory CompanionConfig.fromJson(Map<String, Object?> j) => CompanionConfig(
        enabled: j.boolean('enabled') ?? false,
        grantPublicKey: j.str('grant_public_key'),
        accessTtl: j.number('access_ttl') ?? 3600,
        enrollTtl: j.number('enroll_ttl') ?? 600,
        wsPath: j.str('ws_path'),
        history: j.object('history', CompanionHistoryConfig.fromJson),
        relay: j.object('relay', CompanionRelayConfig.fromJson),
        scopes: j['scopes'] is List ? j.strings('scopes') : null,
        defaultScopes: j['default_scopes'] is List ? j.strings('default_scopes') : null,
      );

  final bool enabled;
  final String? grantPublicKey;
  final int accessTtl;
  final int enrollTtl;
  final String? wsPath;
  final CompanionHistoryConfig? history;
  final CompanionRelayConfig? relay;

  /// Every scope this backend knows, in canonical order; null from a backend
  /// that predates the field, which knows `Scopes.legacy` (spec §9). A scope
  /// it does not know is neither shown nor sent in a `PATCH`, which it would
  /// refuse whole (spec §8.5).
  final List<String>? scopes;

  /// What it gives a device it activates.
  final List<String>? defaultScopes;
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
