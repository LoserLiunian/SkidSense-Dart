import 'package:skidsense_core/skidsense_core.dart';

import '../l10n/gen/app_localizations.dart';
import 'material.dart';

/// Words for what the core reports as data: errors, states, routes, times.
extension Describe on L10n {
  String route(HostRoute route) => switch (route) {
        RouteLan(:final address) => routeLan(address),
        RouteRelay() => routeRelay,
      };

  /// One sentence for anything that can be thrown at the UI.
  String error(Object? error) {
    if (error == null) return errUnknown('');
    return switch (error) {
      RemoteCallError(:final code, :final message) => (message?.trim().isNotEmpty ?? false) ? message! : hsrOther(code),
      HandshakeRejected(:final code) => _handshake(code),
      RelayRejected(:final code) => _relay(code),
      HostBye(:final message) => (message?.trim().isNotEmpty ?? false) ? errByeReason(message!) : errBye,
      HelloRefused(:final message) =>
        (message?.trim().isNotEmpty ?? false) ? errHelloRefusedReason(message!) : errHelloRefused,
      ConnectionClosed(:final detail) => _closed(detail),
      RcException() => _rc(error),
      CryptoError(:final code) => code == 'no-keystore' ? errNoKeystore : errProtocol(code),
      BackendException() => backend(error),
      PairingError() => _pairing(error),
      PairingFormatException(:final problem) => switch (problem) {
          PairingProblem.invalid => pairCodeInvalid,
          PairingProblem.appTooOld => pairCodeAppTooOld,
          PairingProblem.unsupportedVersion => pairCodeUnsupported,
          PairingProblem.badHostKey => pairCodeBadKey,
        },
      CarrierUnavailable() => _carrier(error),
      _ => errUnknown(_short(error)),
    };
  }

  String _rc(RcException error) {
    final at = error.route;
    switch (error.code) {
      case 'offline':
        return errOffline;
      case 'timeout':
        return at == null ? errTimeout : errTimeoutRoute(route(at));
      case 'unreachable':
        final cause = error.cause;
        final why = cause is CarrierUnavailable ? _carrierReason(cause) : null;
        if (at == null) return errUnreachable;
        return why == null ? errUnreachableRoute(route(at)) : '${route(at)}: $why';
      case 'no-route':
        return errNoRoute;
      case 'no-host':
        return errNoHost;
      case 'bad-response':
        return errBadResponse;
      case 'too-large':
        return errTooLarge;
      case 'revoked':
        return error.detail == 'gone' ? errHostGone : errRevoked;
      case 'grant':
        return errGrant(this.error(error.cause));
      case 'upload-desync':
        return errUploadDesync;
      case 'upload-incomplete':
        return uploadIncomplete(error.message ?? '');
      case 'too-many-uploads':
        return errTooManyUploads;
      case 'upload-too-large':
        return errUploadTooLarge;
      case 'uploads-too-large':
        return errUploadsTooLarge;
      default:
        // A crypto code attributed to a route (a failed confirmation there).
        final prefix = at == null ? '' : '${route(at)}: ';
        if (error.cause is CryptoError) return '$prefix${errProtocol(error.code)}';
        return '$prefix${errUnknown(error.code)}';
    }
  }

  String _closed(String? detail) => switch (detail) {
        'peer-closed' => errPeerClosed,
        'idle' => errIdle,
        'handshake-timeout' => errHandshakeTimeout,
        'relay-frame-on-lan' => errRelayFrameOnLan,
        'plaintext-after-handshake' => errPlaintextAfterHandshake,
        'closed' || null => errClosed,
        _ => errProtocol(detail),
      };

  String _handshake(String code) => switch (code) {
        'unsupported-version' => hsrUnsupportedVersion,
        'wrong-host' => hsrWrongHost,
        'enroll-closed' => hsrEnrollClosed,
        'unknown-device' => hsrUnknownDevice,
        'handshake-failed' => hsrHandshakeFailed,
        'replayed' => hsrReplayed,
        'rate-limited' => hsrRateLimited,
        'disabled' => hsrDisabled,
        _ => hsrOther(code),
      };

  String _relay(String code) => switch (code) {
        'host-offline' => relayHostOffline,
        'unauthorized' => relayUnauthorized,
        'revoked' => relayRevoked,
        'rate-limited' => relayRateLimited,
        'too-large' => relayTooLarge,
        'superseded' => relaySuperseded,
        'shutdown' => relayShutdown,
        _ => relayOther(code),
      };

  String? _carrierReason(CarrierUnavailable error) => switch (error.reason) {
        'refused' => carrierRefused,
        'no-credentials' => carrierNoCredentials,
        'no-relay' => carrierNoRelay,
        'upgrade' => carrierUpgrade,
        'tls' => carrierTls,
        'unauthorized' => relayUnauthorized,
        'too-large' => errTooLarge,
        'timeout' => errTimeout,
        _ => null,
      };

  String _carrier(CarrierUnavailable error) => _carrierReason(error) ?? errUnreachable;

  String backend(BackendException error) => switch (error.code) {
        'server' => backendServer(error.message ?? ''),
        'not-signed-in' => backendNotSignedIn,
        'session-expired' => backendSessionExpired,
        'unreachable' => backendUnreachable(error.base ?? ''),
        'http' => backendHttp(error.status),
        'unparsable' => backendUnparsable(error.base ?? ''),
        'bad-data' => backendBadData,
        'no-credentials' => backendNoCredentials,
        'verification-incomplete' => backendVerificationIncomplete,
        'verify-failed' => backendVerifyFailed,
        _ => errUnknown(error.code),
      };

  String _pairing(PairingError error) => switch (error.reason) {
        'not-signed-in' => pairErrNotSignedIn,
        'wrong-backend' => pairErrWrongBackend(error.server ?? '', error.signedIn ?? ''),
        'no-ticket' => pairErrNoTicket,
        'no-grant' => pairErrNoGrant(this.error(error.cause)),
        'cleanup-failed' => pairErrCleanup(this.error(error.cause)),
        _ => errUnknown(error.reason),
      };

  static String _short(Object error) {
    final text = error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  /// The connection line under a host's name.
  String connection(ClientState state, {int? relayBytesPerSecond}) => switch (state) {
        ClientConnected(:final route) => route is RouteRelay && relayBytesPerSecond != null
            ? statusConnectedLimited(this.route(route), ((relayBytesPerSecond + 512) ~/ 1024))
            : statusConnected(this.route(route)),
        ClientConnecting(:final via) => via == null ? statusAuthorizing : statusConnecting(route(via)),
        ClientWaiting(:final error, :final retryIn) => statusWaiting(this.error(error), (retryIn.inMilliseconds / 1000).ceil()),
        ClientFailed(:final error) => statusFailed(this.error(error)),
        ClientIdle() => statusIdle,
      };

  String notice(AppNotice notice) => switch (notice.kind) {
        NoticeKind.error => error(notice.error),
        NoticeKind.sessionExpired => noticeSessionExpired,
        NoticeKind.storeReset => noticeStoreReset,
        NoticeKind.forgetUnrevoked => noticeForgetUnrevoked(error(notice.error)),
        NoticeKind.undecodable => noticeUndecodable(notice.detail ?? ''),
      };

  /// `last_seen_at` and friends: how long ago, in words.
  String ago(DateTime then, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(then);
    if (elapsed.inSeconds < 60) return justNow;
    if (elapsed.inMinutes < 60) return minutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return hoursAgo(elapsed.inHours);
    return daysAgo(elapsed.inDays);
  }

  /// The word next to a computer's name. The backend's `online` measures
  /// the relay only: a computer with just LAN access on is never online
  /// there, and calling it offline sent people away from a host they could
  /// reach. So a missing relay is only "offline" with no LAN route to try.
  String? presence(bool? online, List<String> lanAddrs) => switch (online) {
        null => null,
        true => presenceOnline,
        false => lanAddrs.isNotEmpty ? presenceRelayOffline : presenceOffline,
      };

  String runState(String state) => switch (state) {
        'running' => runStateRunning,
        'awaiting-input' => runStateAwaiting,
        'starting' => runStateStarting,
        'idle' => runStateIdle,
        'done' || 'ok' || 'completed' || 'complete' => runStateDone,
        'error' || 'failed' => runStateError,
        'aborted' || 'stopped' => runStateAborted,
        'pending' || 'queued' => runStatePending,
        'cancelled' || 'canceled' => runStateCancelled,
        _ => state,
      };

  String scope(String scope) => switch (scope) {
        Scopes.sessions => scopeSessions,
        Scopes.prompt => scopePrompt,
        Scopes.approve => scopeApprove,
        Scopes.files => scopeFiles,
        Scopes.filesWrite => scopeFilesWrite,
        Scopes.git => scopeGit,
        Scopes.gitWrite => scopeGitWrite,
        Scopes.terminal => scopeTerminal,
        _ => scope,
      };

  String gitStatus(String status) => switch (status) {
        'modified' => gitModified,
        'added' => gitAdded,
        'deleted' => gitDeleted,
        'renamed' => gitRenamed,
        'untracked' => gitUntracked,
        'conflicted' => gitConflicted,
        'ignored' => gitIgnored,
        _ => status,
      };

  String effortLevel(String value) => switch (value) {
        'minimal' => effortMinimal,
        'low' => effortLow,
        'medium' => effortMedium,
        'high' => effortHigh,
        'xhigh' => effortXhigh,
        'max' => effortMax,
        'ultra' => effortUltra,
        _ => value,
      };

  String terminalExit(TerminalExit exit) {
    final reason = exit.reason;
    if (reason != null && reason.trim().isNotEmpty) return reason;
    final signal = exit.signal;
    if (signal != null && signal > 0) return terminalExitSignal(signal);
    return exit.code >= 0 ? terminalExitCode(exit.code) : terminalEnded;
  }

  String historyProblem(HistoryEntry entry) => switch (entry.problem) {
        HistoryProblem.noKey => historyNoKey(entry.epoch),
        HistoryProblem.download => historyDownload(error(entry.error)),
        HistoryProblem.encoding => historyEncoding,
        HistoryProblem.decrypt => historyDecrypt,
        HistoryProblem.content => historyContent,
        null => '',
      };
}

/// The effort levels each agent takes, matching the desktop's composer.
List<String> effortLevels(String agent) => switch (agent) {
      'claude' => const ['low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
      'codex' => const ['minimal', 'low', 'medium', 'high', 'xhigh'],
      'antigravity' => const ['low', 'medium', 'high'],
      _ => const [],
    };

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes >= 10 * 1024 * 1024 ? 0 : 1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

String formatTokens(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

/// A status word's tone, for its badge colour.
enum RunTone { running, waiting, done, failed, neutral }

RunTone runTone(String state) => switch (state) {
      'running' || 'starting' => RunTone.running,
      'awaiting-input' || 'pending' || 'queued' => RunTone.waiting,
      'done' || 'ok' || 'completed' || 'complete' => RunTone.done,
      'error' || 'failed' => RunTone.failed,
      _ => RunTone.neutral,
    };

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}
