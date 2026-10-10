// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SkidSense';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get refresh => 'Refresh';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get preview => 'Preview';

  @override
  String get reload => 'Reload';

  @override
  String get more => 'More';

  @override
  String get search => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get create => 'Create';

  @override
  String get continueAction => 'Continue';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get none => '—';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle =>
      'Use the same account as SkidSense on your computer — that is how the two find each other.';

  @override
  String get serverAddress => 'Server';

  @override
  String serverAddressUsed(String address) {
    return 'Will use $address';
  }

  @override
  String get serverAddressInvalid =>
      'Enter the server\'s address, such as https://example.com';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get testConnection => 'Test connection';

  @override
  String serverReachable(String name) {
    return 'Server reachable: $name';
  }

  @override
  String get captchaTitle => 'Human verification';

  @override
  String get captchaPassed => 'Verified';

  @override
  String get captchaRedo => 'Verify again';

  @override
  String captchaFailed(String code) {
    return 'Verification failed ($code). Try again.';
  }

  @override
  String get captchaExpired => 'Verification expired. Try again.';

  @override
  String get captchaOnSignIn => 'A quick human check opens when you sign in.';

  @override
  String get captchaLoading => 'Loading the human check…';

  @override
  String get captchaLoadFailed => 'The human check didn\'t load';

  @override
  String get captchaLoadFailedHint =>
      'Check the network connection, then try again.';

  @override
  String get passwordLoginDisabled =>
      'This server has password sign-in turned off.';

  @override
  String get pairingAfterLogin =>
      'Signing in and pairing are two steps: sign in here first, then scan the QR code on your computer.';

  @override
  String get twoFactorTitle => 'Two-step verification';

  @override
  String get twoFactorHint =>
      'Enter the 6-digit code from your authenticator app, or a backup code.';

  @override
  String get twoFactorRequired => 'This account requires a second step.';

  @override
  String twoFactorMethods(String methods) {
    return 'Available: $methods';
  }

  @override
  String get verificationCode => 'Code';

  @override
  String get verify => 'Verify';

  @override
  String get twoFactorPasskeyOnly =>
      'This account\'s second step is a passkey, which the app can\'t use yet. On the web, turn on two-step verification with an authenticator app, then sign in here with its code.';

  @override
  String get hostsTitle => 'Computers';

  @override
  String signedInAs(String user, String server) {
    return '$user · $server';
  }

  @override
  String get pairComputer => 'Pair a computer';

  @override
  String get pairedSection => 'Paired';

  @override
  String get pairedSectionHint => 'Ready to connect';

  @override
  String get otherHostsSection => 'Other computers on this account';

  @override
  String get otherHostsHint => 'Not paired with this phone yet';

  @override
  String get presenceOnline => 'Online';

  @override
  String get presenceRelayOffline => 'Relay offline';

  @override
  String get presenceOffline => 'Offline';

  @override
  String get presenceRelayOfflineHint =>
      'Not connected to the relay — it may still answer on your local network.';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get lanAddresses => 'Local network';

  @override
  String get connect => 'Connect';

  @override
  String get forget => 'Forget';

  @override
  String forgetTitle(String name) {
    return 'Forget $name?';
  }

  @override
  String get forgetBody =>
      'This phone is also revoked on the server: the computer disconnects it at once and stops encrypting history for it. You will need to scan a new QR code to connect again.';

  @override
  String get forgetAction => 'Forget and revoke';

  @override
  String get noComputersTitle => 'No computers yet';

  @override
  String get noComputersBody =>
      'Open Remote Control in SkidSense on your computer and generate a pairing QR code, then scan it here.';

  @override
  String get hostNeedsQr => 'Generate a QR code on it to pair';

  @override
  String get loadingHosts => 'Loading computers…';

  @override
  String get settings => 'Settings';

  @override
  String get pairingTitle => 'Pair a computer';

  @override
  String get pairingIntro =>
      'In SkidSense on your computer, open Remote Control and scan the QR code it shows. A code works once, for 10 minutes.';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get pasteLinkSection => 'Or paste the pairing link';

  @override
  String get pasteLinkLabel => 'skidsense://pair/1?d=…';

  @override
  String get readLink => 'Read link';

  @override
  String get confirmComputer => 'Is this your computer?';

  @override
  String get machineName => 'Name';

  @override
  String get backend => 'Server';

  @override
  String get fingerprintCheck =>
      'Compare the fingerprint, group by group, with the one on your computer\'s screen. If it differs, this code is not from the computer you are using.';

  @override
  String get confirmPair => 'Pair';

  @override
  String get pairStepRegistering => 'Registering this phone…';

  @override
  String get pairStepAlreadyRegistered =>
      'This phone is already registered there — reconnecting…';

  @override
  String get pairStepHandshaking => 'Shaking hands with the computer…';

  @override
  String get pairStepRepairing =>
      'The computer has no record of this phone — pairing it again…';

  @override
  String get pairStepFinishing => 'Paired. Reading what this phone may do…';

  @override
  String pairStepTrying(String route) {
    return 'Trying $route…';
  }

  @override
  String get cameraUnavailable =>
      'The camera is not available. Paste the pairing link instead.';

  @override
  String get scannerPrompt =>
      'Point the camera at the QR code on your computer';

  @override
  String get scannerTorch => 'Torch';

  @override
  String get notAPairingCode => 'That QR code is not a SkidSense pairing code.';

  @override
  String get tabSessions => 'Sessions';

  @override
  String get tabFiles => 'Files';

  @override
  String get tabGit => 'Git';

  @override
  String get tabHistory => 'History';

  @override
  String routeLan(String address) {
    return 'LAN $address';
  }

  @override
  String get routeRelay => 'Relay';

  @override
  String statusConnected(String route) {
    return 'Connected · $route';
  }

  @override
  String statusConnectedLimited(String route, int rate) {
    return 'Connected · $route (limited to $rate KB/s)';
  }

  @override
  String statusConnecting(String route) {
    return 'Connecting · $route';
  }

  @override
  String get statusAuthorizing => 'Connecting · getting authorization';

  @override
  String statusWaiting(String error, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$error · retrying in $_temp0';
  }

  @override
  String statusFailed(String error) {
    return 'Can\'t connect: $error';
  }

  @override
  String get statusIdle => 'Not connected';

  @override
  String get offlineTitle => 'Not connected to the computer';

  @override
  String get offlineBody =>
      'Make sure SkidSense is running on the computer and this phone is paired with it. Without the local network the relay is used automatically.';

  @override
  String get backToComputers => 'Computers';

  @override
  String get searchSessions => 'Search sessions';

  @override
  String get noSessionsTitle => 'No sessions yet';

  @override
  String get noSessionsBody => 'Start one on the computer, or here.';

  @override
  String get noSessionsNoPrompt => 'This phone may not start sessions.';

  @override
  String noSearchResults(String query) {
    return 'Nothing matches “$query”';
  }

  @override
  String get newSession => 'New session';

  @override
  String get workspace => 'Workspace';

  @override
  String get agent => 'Agent';

  @override
  String get titleOptional => 'Title (optional)';

  @override
  String get renameSession => 'Rename session';

  @override
  String get sessionTitle => 'Title';

  @override
  String deleteSessionTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get deleteSessionBody =>
      'The session and its transcript are deleted on the computer.';

  @override
  String backgroundJobs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count background tasks',
      one: '1 background task',
    );
    return '$_temp0';
  }

  @override
  String get loadingSessions => 'Loading sessions…';

  @override
  String get runStateRunning => 'Running';

  @override
  String get runStateAwaiting => 'Waiting for you';

  @override
  String get runStateStarting => 'Starting';

  @override
  String get runStateIdle => 'Idle';

  @override
  String get runStateDone => 'Done';

  @override
  String get runStateError => 'Failed';

  @override
  String get runStateAborted => 'Stopped';

  @override
  String get runStatePending => 'Pending';

  @override
  String get runStateCancelled => 'Cancelled';

  @override
  String updatedAgo(String ago) {
    return 'Updated $ago';
  }

  @override
  String get openingSession => 'Opening the session…';

  @override
  String get sessionNotFound => 'The computer has no such session.';

  @override
  String get openTerminal => 'Terminal';

  @override
  String get openFiles => 'Files';

  @override
  String get openGit => 'Git';

  @override
  String get approvalPermission => 'Needs your permission';

  @override
  String get approvalQuestion => 'The agent asks';

  @override
  String get approvalInput => 'The agent is waiting for input';

  @override
  String get approvalOther => 'The agent needs an answer';

  @override
  String get approvalFreeText => 'Free answer allowed';

  @override
  String approvalCwd(String cwd) {
    return 'Working directory: $cwd';
  }

  @override
  String approvalScopes(String scopes) {
    return 'Requested permissions: $scopes';
  }

  @override
  String get approvalNoPermission =>
      'This phone may not answer approvals. Answer on the computer, or on a device that may.';

  @override
  String approvalAnsweredElsewhere(String device) {
    return 'Answered on $device';
  }

  @override
  String get allow => 'Allow';

  @override
  String get deny => 'Deny';

  @override
  String get sendAnswer => 'Send answer';

  @override
  String get skip => 'Skip';

  @override
  String get cancelTurn => 'Cancel turn';

  @override
  String get answerPlaceholder => 'Your answer';

  @override
  String get toolInput => 'Input';

  @override
  String get toolResult => 'Result';

  @override
  String toolTruncated(String label, String size) {
    return '$label truncated (originally $size)';
  }

  @override
  String get messageHint => 'Message';

  @override
  String get steerHint => 'Add to the running turn';

  @override
  String get send => 'Send';

  @override
  String get steer => 'Steer';

  @override
  String get stop => 'Stop';

  @override
  String get composerOptions => 'Options';

  @override
  String get attach => 'Attach a file';

  @override
  String get attachmentsNote =>
      'Attachments go with the next message; leaving this session discards them.';

  @override
  String get remove => 'Remove';

  @override
  String get noPromptPermission => 'This phone may not send messages.';

  @override
  String get options => 'Send options';

  @override
  String get model => 'Model';

  @override
  String get modelDefault => 'Default';

  @override
  String get noModels => 'No model list available';

  @override
  String modelDefaultNamed(String model) {
    return 'Default ($model)';
  }

  @override
  String get composerModelsLoading => 'Reading the models…';

  @override
  String get composerRouteCloud => 'Cloud: through your first-party account';

  @override
  String composerRouteAccount(String account) {
    return 'Local account: $account';
  }

  @override
  String get composerRouteOfficial =>
      'Local: Anthropic\'s official subscription (forced)';

  @override
  String get composerRouteCli => 'Local: the agent\'s own configuration';

  @override
  String get composerAccount => 'Account';

  @override
  String composerAccountHint(String agent) {
    return 'Set on the computer: every conversation with $agent uses it from its next turn.';
  }

  @override
  String get composerModelsCloud => 'Cloud models';

  @override
  String composerModelsAccount(String account) {
    return 'Models on $account';
  }

  @override
  String get composerModelsCli => 'The CLI\'s own models';

  @override
  String get composerModelsOtherAccounts =>
      'Other accounts (this conversation only)';

  @override
  String get composerModelsOtherEndpoints =>
      'Other endpoints (this conversation only)';

  @override
  String get composerModelsOtherHint =>
      'Only this conversation uses it; the account set on the computer stays as it is.';

  @override
  String get composerCloudEmptyTitle => 'No cloud models yet';

  @override
  String get composerCloudEmptyBody =>
      'Cloud mode offers only the models assigned to this agent from a cloud key.';

  @override
  String get composerOpenModels => 'Assign in Models';

  @override
  String get slashTitle => 'Commands';

  @override
  String slashCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commands',
      one: '1 command',
    );
    return '$_temp0';
  }

  @override
  String get slashLoading => 'Reading the commands…';

  @override
  String get slashSourceBuiltin => 'Built-in';

  @override
  String get slashSourceCommand => 'Command';

  @override
  String get slashSourceSkill => 'Skill';

  @override
  String get slashScopeWorkspace => 'This workspace';

  @override
  String get slashScopeGlobal => 'Global';

  @override
  String slashAliases(String names) {
    return 'Also $names';
  }

  @override
  String get effort => 'Thinking';

  @override
  String get effortMinimal => 'Minimal';

  @override
  String get effortLow => 'Low';

  @override
  String get effortMedium => 'Medium';

  @override
  String get effortHigh => 'High';

  @override
  String get effortXhigh => 'Very high';

  @override
  String get effortMax => 'Max';

  @override
  String get effortUltra => 'Ultra';

  @override
  String get approvalMode => 'Approvals';

  @override
  String get approvalModeLocked =>
      'Approvals (this phone may not approve: default only)';

  @override
  String get approvalDefault => 'Ask each time';

  @override
  String get approvalAcceptEdits => 'Accept edits';

  @override
  String get approvalPlan => 'Plan only';

  @override
  String get approvalDontAsk => 'Don\'t ask';

  @override
  String get approvalBypass => 'Bypass all';

  @override
  String get thinking => 'Thinking';

  @override
  String get plan => 'Plan';

  @override
  String get backgroundTasks => 'Background tasks';

  @override
  String usageContext(String tokens) {
    return 'Context $tokens';
  }

  @override
  String usageOutput(String tokens) {
    return 'Output $tokens';
  }

  @override
  String steered(String text) {
    return 'Steered: $text';
  }

  @override
  String get compactedAuto => 'Context compacted (automatically)';

  @override
  String get compactedManual => 'Context compacted';

  @override
  String get subAgent => 'Sub-agent';

  @override
  String get subAgentTask => 'Task';

  @override
  String get subAgentLatest => 'Latest';

  @override
  String get subAgentReport => 'Report';

  @override
  String get workflow => 'Workflow';

  @override
  String toolCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tool calls',
      one: '1 tool call',
    );
    return '$_temp0';
  }

  @override
  String promptRefused(String reason) {
    return 'The computer did not take the message: $reason';
  }

  @override
  String get promptRefusedPlain => 'The computer did not take the message.';

  @override
  String get promptUncertain =>
      'No answer came — the turn may have started. Check the transcript before sending again.';

  @override
  String get promptUncertainDropped =>
      'No answer came — the turn may have started. Check the transcript before sending again; the attachments were removed and need adding again.';

  @override
  String uploadIncomplete(String name) {
    return '“$name” is still uploading.';
  }

  @override
  String uploading(String name) {
    return 'Uploading $name';
  }

  @override
  String get jumpToLatest => 'Latest';

  @override
  String get you => 'You';

  @override
  String get filesTitle => 'Files';

  @override
  String get searchContent => 'Search file contents';

  @override
  String get regex => 'Regex';

  @override
  String get searching => 'Searching…';

  @override
  String searchSummary(int matches, int files) {
    String _temp0 = intl.Intl.pluralLogic(
      matches,
      locale: localeName,
      other: '$matches matches',
      one: '1 match',
    );
    String _temp1 = intl.Intl.pluralLogic(
      files,
      locale: localeName,
      other: '$files files',
      one: '1 file',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String get searchCancelled => 'Search stopped';

  @override
  String get searchInterrupted =>
      'The connection dropped and the search stopped. Search again.';

  @override
  String moreMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more matches',
      one: '1 more match',
    );
    return '$_temp0';
  }

  @override
  String get dirTruncated =>
      'This folder has too many entries; only some are shown.';

  @override
  String get emptyDir => 'This folder is empty';

  @override
  String get showIgnored => 'Show ignored files';

  @override
  String get binaryFile => 'A binary file — it can only be previewed.';

  @override
  String get tooLargeFile => 'This file is too large to open here.';

  @override
  String fileLines(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0 · $size';
  }

  @override
  String get saved => 'Saved';

  @override
  String get saveConflict =>
      'The file was changed elsewhere, so saving was refused rather than overwrite it. Reload, then edit again.';

  @override
  String get unsavedChanges => 'Discard your changes?';

  @override
  String get discard => 'Discard';

  @override
  String get newFile => 'New file';

  @override
  String get newFolder => 'New folder';

  @override
  String get name => 'Name';

  @override
  String deleteItemTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteItemBody => 'It is deleted on the computer.';

  @override
  String get noWorkspace => 'No workspace';

  @override
  String get chooseWorkspace => 'Workspace';

  @override
  String get root => 'Root';

  @override
  String get gitTitle => 'Git';

  @override
  String get notARepo => 'This workspace is not a Git repository.';

  @override
  String get initRepo => 'Initialize a repository here';

  @override
  String get branch => 'Branch';

  @override
  String detached(String sha) {
    return 'Detached at $sha';
  }

  @override
  String upstream(String name) {
    return 'Upstream $name';
  }

  @override
  String aheadBehind(int ahead, int behind) {
    return '↑$ahead ↓$behind';
  }

  @override
  String get branches => 'Branches';

  @override
  String get fetch => 'Fetch';

  @override
  String get pull => 'Pull';

  @override
  String get push => 'Push';

  @override
  String get switchBranch => 'Switch';

  @override
  String get currentBranch => 'Current';

  @override
  String get remoteBranch => 'Remote';

  @override
  String get changes => 'Changes';

  @override
  String get staged => 'Staged';

  @override
  String get unstaged => 'Not staged';

  @override
  String get noChanges => 'Nothing to commit';

  @override
  String get stage => 'Stage';

  @override
  String get unstage => 'Unstage';

  @override
  String get stageAll => 'Stage all';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String discardTitle(String path) {
    return 'Discard changes to $path?';
  }

  @override
  String get discardBody => 'The changes are lost on the computer.';

  @override
  String get commit => 'Commit';

  @override
  String get commitMessage => 'Commit message';

  @override
  String get commitStaged => 'Commit staged changes';

  @override
  String get committed => 'Committed';

  @override
  String renamedFrom(String path) {
    return 'from $path';
  }

  @override
  String get diffTruncated => 'The diff is too large; only part is shown.';

  @override
  String get binaryDiff => 'Binary file';

  @override
  String get gitModified => 'Modified';

  @override
  String get gitAdded => 'Added';

  @override
  String get gitDeleted => 'Deleted';

  @override
  String get gitRenamed => 'Renamed';

  @override
  String get gitUntracked => 'Untracked';

  @override
  String get gitConflicted => 'Conflict';

  @override
  String get gitIgnored => 'Ignored';

  @override
  String gitOperationFailed(String message) {
    return 'Git: $message';
  }

  @override
  String conflictsBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files have conflicts',
      one: '1 file has conflicts',
    );
    return '$_temp0';
  }

  @override
  String get terminalTitle => 'Terminal';

  @override
  String get terminalWarningTitle => 'The terminal bypasses approvals';

  @override
  String get terminalWarningBody =>
      'The terminal runs the real CLI on the computer. It answers its own permission prompts there: no approval card appears here and nothing is stopped. It works only if the computer granted this phone the terminal permission, which is off by default.';

  @override
  String get terminalOpen => 'I understand — open the terminal';

  @override
  String get terminalClose => 'Close terminal';

  @override
  String get terminalOpening => 'Opening the terminal…';

  @override
  String terminalExitCode(int code) {
    return 'Ended · exit code $code';
  }

  @override
  String terminalExitSignal(int signal) {
    return 'Ended · killed by signal $signal';
  }

  @override
  String get terminalEnded => 'Ended';

  @override
  String get terminalNotAllowed => 'This phone may not use the terminal.';

  @override
  String get historyTitle => 'History';

  @override
  String get historySubtitle =>
      'Encrypted on the server; only this phone can open it';

  @override
  String get historySearch => 'Search what you have opened';

  @override
  String historyEpoch(int epoch) {
    return 'Key generation $epoch';
  }

  @override
  String historyTurns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count turns',
      one: '1 turn',
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty => 'No history on the server';

  @override
  String historyNoKey(int epoch) {
    return 'This phone has no key for generation $epoch. It appears once the computer uploads again.';
  }

  @override
  String historyDownload(String error) {
    return 'Could not download: $error';
  }

  @override
  String get historyEncoding => 'The stored data is malformed.';

  @override
  String get historyDecrypt =>
      'Could not decrypt: this may belong to another session or key generation.';

  @override
  String get historyContent => 'Decrypted, but not a session.';

  @override
  String get historyNotOpened => 'Tap to download and decrypt';

  @override
  String get historyNoHost => 'Connect to a computer first.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Your pairings stay on this phone and come back when you sign in again.';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountUserId => 'User ID';

  @override
  String get accountLoading => 'Reading your account…';

  @override
  String get accountLoadFailed => 'Couldn\'t read your account';

  @override
  String get accountGroupsLoadFailed => 'Couldn\'t read the groups';

  @override
  String get accountOffline => 'Can\'t reach the server';

  @override
  String get accountOfflineBody =>
      'Check this phone\'s network connection, then try again.';

  @override
  String get accountQuota => 'Balance and usage';

  @override
  String get accountQuotaHint => 'In US dollars (USD)';

  @override
  String get accountBalance => 'Balance';

  @override
  String get accountUsed => 'Used';

  @override
  String get accountGroups => 'Groups';

  @override
  String get accountGroupsHint =>
      'A call costs its model\'s price times its group\'s ratio. Your keys can use any group here.';

  @override
  String get accountGroupYours => 'Your group';

  @override
  String accountGroupRatio(String ratio) {
    return 'Ratio $ratio';
  }

  @override
  String get groupRatioAuto => 'Auto';

  @override
  String get security => 'Security';

  @override
  String get keyProtected =>
      'This phone\'s private key is held by the system keystore and cannot be exported.';

  @override
  String get biometricLock => 'Require unlock when opening';

  @override
  String get biometricLockHint =>
      'A convenience lock: the keys do not depend on it.';

  @override
  String get appearance => 'Appearance';

  @override
  String get designStyle => 'Design';

  @override
  String get styleM3 => 'Material 3';

  @override
  String get styleM3E => 'Material 3 Expressive';

  @override
  String get styleM3Hint => 'Calm, compact, familiar';

  @override
  String get styleM3EHint => 'Bolder shapes, springy motion, emphasized type';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get dynamicColor => 'Wallpaper colors';

  @override
  String get dynamicColorHint =>
      'Use the colors of your wallpaper (Android 12 and later)';

  @override
  String get seedColor => 'Color';

  @override
  String seedColorOption(int number) {
    return 'Color $number';
  }

  @override
  String get colorVariant => 'Palette';

  @override
  String get variantTonalSpot => 'Tonal';

  @override
  String get variantVibrant => 'Vibrant';

  @override
  String get variantExpressive => 'Expressive';

  @override
  String get variantFidelity => 'Fidelity';

  @override
  String get variantNeutral => 'Neutral';

  @override
  String get contrast => 'Contrast';

  @override
  String get contrastStandard => 'Standard';

  @override
  String get contrastMedium => 'Medium';

  @override
  String get contrastHigh => 'High';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageZhHans => '简体中文';

  @override
  String get languageZhHant => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String devicesOnHost(String host) {
    return 'Devices on $host';
  }

  @override
  String get devicesConnectFirst =>
      'Connect to a computer to manage its devices.';

  @override
  String get effectiveScopes =>
      'What this phone may actually do (the server\'s grant, capped by the computer):';

  @override
  String get terminalScopeNote =>
      'The terminal is off by default: inside it the CLI answers its own permission prompts.';

  @override
  String get settingsScopeNote =>
      'Models & accounts is off by default and only the computer can turn it on: it can point the agents at any server and set their environment — as much as the terminal.';

  @override
  String get settingsScopeWarning =>
      'This phone may change models and accounts: it can point the agents at any server and set their environment, enough to run anything on the computer — as much as the terminal.';

  @override
  String get settingsScopeLocked =>
      'As much as the terminal: enough to run anything on the computer. Only the computer can turn it on; here it can only be turned off.';

  @override
  String get thisDevice => 'This phone';

  @override
  String get permissions => 'Permissions';

  @override
  String get serverScopesNote =>
      'These are the server\'s grants. What takes effect is their overlap with the cap the computer sets for this device: a permission the computer has not opened does nothing here.';

  @override
  String get savePermissions => 'Save permissions';

  @override
  String get noScopes => 'No permissions';

  @override
  String get revoke => 'Revoke';

  @override
  String revokeTitle(String name) {
    return 'Revoke $name?';
  }

  @override
  String get revokeBody =>
      'It will no longer connect and needs a new QR code to pair again.';

  @override
  String lastSeen(String ago) {
    return 'Last seen $ago';
  }

  @override
  String get deviceStatusPending => 'Pending';

  @override
  String get deviceStatusActive => 'Active';

  @override
  String get deviceStatusRevoked => 'Revoked';

  @override
  String get about => 'About';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String get componentGallery => 'Component gallery';

  @override
  String get reloginNote =>
      'After signing out or switching accounts, generate a new pairing QR code on the computer.';

  @override
  String get scopeSessions => 'View sessions';

  @override
  String get scopePrompt => 'Send messages';

  @override
  String get scopeApprove => 'Answer approvals';

  @override
  String get scopeFiles => 'View files';

  @override
  String get scopeFilesWrite => 'Change files';

  @override
  String get scopeGit => 'View Git';

  @override
  String get scopeGitWrite => 'Git writes';

  @override
  String get scopeTerminal => 'Terminal';

  @override
  String get scopeSettings => 'Models & accounts';

  @override
  String get lockedTitle => 'SkidSense is locked';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockReason => 'Unlock SkidSense';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get noticeSessionExpired => 'Your sign-in has expired. Sign in again.';

  @override
  String get noticeStoreReset =>
      'The sign-in data on this device could not be read (was it moved from another phone?). You have been signed out; sign in and pair again.';

  @override
  String noticeForgetUnrevoked(String error) {
    return 'Forgotten on this phone, but the server did not take the revocation ($error). Revoke this phone on the computer.';
  }

  @override
  String noticeUndecodable(String method) {
    return 'The computer\'s answer to $method could not be read. Is SkidSense on the computer up to date?';
  }

  @override
  String get errOffline => 'Not connected to the computer';

  @override
  String get errTimeout => 'The computer did not answer in time';

  @override
  String errTimeoutRoute(String route) {
    return '$route: timed out';
  }

  @override
  String errUnreachableRoute(String route) {
    return '$route: can\'t connect';
  }

  @override
  String errRouteReason(String route, String reason) {
    return '$route: $reason';
  }

  @override
  String get errUnreachable => 'Can\'t connect';

  @override
  String get errNoRoute => 'No way to reach this computer';

  @override
  String get errClosed => 'The connection was closed';

  @override
  String get errPeerClosed => 'The other side closed the connection';

  @override
  String get errIdle => 'The connection stopped responding';

  @override
  String get errHandshakeTimeout => 'The handshake timed out';

  @override
  String get errRelayFrameOnLan =>
      'Something on the local network pretended to be the relay';

  @override
  String get errPlaintextAfterHandshake =>
      'A forged message arrived after the handshake';

  @override
  String errProtocol(String code) {
    return 'The connection failed a check ($code)';
  }

  @override
  String get errBadResponse => 'The computer sent a malformed answer';

  @override
  String get errTooLarge => 'Too large';

  @override
  String get errHelloRefused => 'The computer refused this phone';

  @override
  String errHelloRefusedReason(String reason) {
    return 'The computer refused this phone: $reason';
  }

  @override
  String get errBye => 'The computer ended the connection';

  @override
  String errByeReason(String reason) {
    return 'The computer ended the connection: $reason';
  }

  @override
  String get errRevoked =>
      'This phone was revoked. Scan the QR code again to pair.';

  @override
  String get errHostGone =>
      'The server no longer has this pairing (the computer or this phone was removed). Scan the QR code again to pair.';

  @override
  String errGrant(String error) {
    return 'Could not get authorization: $error';
  }

  @override
  String get errCompanionDisabled =>
      'Remote control is not turned on on this server';

  @override
  String get errNoHost => 'No computer selected';

  @override
  String get errUploadDesync =>
      'The upload got out of step with the computer. Add the file again.';

  @override
  String get errTooManyUploads => 'At most 8 attachments at once';

  @override
  String get errUploadTooLarge => 'An attachment can be at most 20 MiB';

  @override
  String get errUploadsTooLarge => 'Attachments together can be at most 20 MiB';

  @override
  String get errNoKeystore =>
      'The system keystore is unavailable; a device key cannot be created';

  @override
  String get errKeyUnreadable =>
      'The system keystore could not be read. Try again in a moment.';

  @override
  String errUnknown(String detail) {
    return 'Something went wrong: $detail';
  }

  @override
  String get hsrUnsupportedVersion =>
      'The computer speaks another protocol version. Update the app or the computer.';

  @override
  String get hsrWrongHost =>
      'Connected to a different computer than the one paired';

  @override
  String get hsrEnrollClosed =>
      'The pairing code has expired. Generate a new QR code on the computer.';

  @override
  String get hsrUnknownDevice =>
      'This phone is not paired with that computer, or was revoked';

  @override
  String get hsrHandshakeFailed =>
      'The handshake failed: a wrong pairing code, or not the computer you paired';

  @override
  String get hsrReplayed => 'The handshake looked like a replay. Try again.';

  @override
  String get hsrRateLimited => 'Too many attempts. Try again later.';

  @override
  String get hsrDisabled => 'Remote control is off on the computer';

  @override
  String get relayHostOffline => 'The computer is offline';

  @override
  String get relayUnauthorized =>
      'Your sign-in is no longer valid. Sign in again.';

  @override
  String get relayRevoked => 'This phone was revoked. Pair it again.';

  @override
  String get relayRateLimited => 'Too many requests. Try again later.';

  @override
  String get relayTooLarge => 'The message was too large';

  @override
  String get relaySuperseded =>
      'This phone connected to the same computer elsewhere';

  @override
  String get relayShutdown => 'The relay is restarting';

  @override
  String get relayHostClosed => 'The computer ended this connection';

  @override
  String relayOther(String code) {
    return 'The relay refused ($code)';
  }

  @override
  String hsrOther(String code) {
    return 'The computer refused ($code)';
  }

  @override
  String get carrierRefused => 'refused';

  @override
  String get carrierNoCredentials => 'not signed in';

  @override
  String get carrierNoRelay => 'no relay address';

  @override
  String get carrierUpgrade => 'not a SkidSense endpoint';

  @override
  String get carrierTls => 'secure connection failed';

  @override
  String get carrierForbidden => 'the server refused this phone';

  @override
  String get carrierNotFound =>
      'the server has no such pairing or relay endpoint';

  @override
  String get carrierCredentialsUnavailable =>
      'sign-in could not be checked right now';

  @override
  String backendServer(String message) {
    return '$message';
  }

  @override
  String get backendNotSignedIn => 'Not signed in';

  @override
  String get backendSessionExpired => 'Sign-in expired. Sign in again.';

  @override
  String backendUnreachable(String base) {
    return 'Can\'t reach the server ($base)';
  }

  @override
  String backendInsecure(String base) {
    return '$base is plain http://, which would send your sign-in across the internet unencrypted. Use the server\'s https:// address.';
  }

  @override
  String backendHttp(int status) {
    return 'The server answered HTTP $status';
  }

  @override
  String backendRefreshFailed(int status) {
    return 'Couldn\'t renew the sign-in for now (HTTP $status). Try again later.';
  }

  @override
  String backendRefreshFailedIn(int status, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Couldn\'t renew the sign-in for now (HTTP $status). Try again in $_temp0.';
  }

  @override
  String backendUnparsable(String base) {
    return 'The server\'s answer could not be read. Is $base the right address?';
  }

  @override
  String get backendBadData => 'The server\'s answer had an unexpected shape';

  @override
  String get backendNoCredentials =>
      'Sign-in failed: the server returned no credentials';

  @override
  String get backendVerificationIncomplete =>
      'The account needs a second step, but the server gave no way to complete it';

  @override
  String get backendVerifyFailed => 'Wrong or expired code';

  @override
  String get backendRateLimited => 'Too many requests. Try again later.';

  @override
  String backendRateLimitedIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Too many requests. Try again in $_temp0.';
  }

  @override
  String get pairErrNotSignedIn => 'Sign in first';

  @override
  String pairErrWrongBackend(String server, String signedIn) {
    return 'This QR code is for $server, but you are signed in to $signedIn. Both must use the same server.';
  }

  @override
  String get pairErrNoTicket =>
      'The server issued no pairing ticket. Generate a new QR code.';

  @override
  String pairErrNoGrant(String error) {
    return 'This phone is registered with that computer, but no access grant is available ($error). Check on the computer whether it was revoked; if so, generate a new QR code.';
  }

  @override
  String pairErrCleanup(String error) {
    return 'Could not clear this phone\'s old record on the server ($error)';
  }

  @override
  String get pairCodeInvalid => 'Not a valid pairing code';

  @override
  String get pairCodeAppTooOld =>
      'This pairing code needs a newer version of the app';

  @override
  String get pairCodeUnsupported =>
      'This pairing code version is not supported';

  @override
  String get pairCodeBadKey => 'The computer\'s key in this code is invalid';

  @override
  String get tabModels => 'Models';

  @override
  String get modelsTitle => 'Models';

  @override
  String get modelsReadOnlyTitle => 'View only';

  @override
  String get modelsReadOnlyBody =>
      'To change models and accounts from this phone, turn on “Models & accounts” for it under Remote access on the computer.';

  @override
  String get modelsReadOnlyUnsupported =>
      'The server this computer uses can\'t let a phone change models and accounts yet: here they can only be viewed.';

  @override
  String get modelsReadOnlyOldComputer =>
      'SkidSense on this computer can\'t take these changes from a phone yet: update it on the computer to change them here.';

  @override
  String get modelsRoute => 'Route';

  @override
  String get modelsRouteHint =>
      'Where the agents\' calls go. Switching affects every conversation on this computer.';

  @override
  String get modelsLocalMode => 'Local';

  @override
  String get modelsLocalModeHint =>
      'Each agent uses its own account and subscription on this computer, not the first-party service.';

  @override
  String get modelsCloudMode => 'Cloud';

  @override
  String get modelsCloudModeHint =>
      'Every agent goes through your first-party account, using only the models assigned under the API keys.';

  @override
  String get modelsSwitch => 'Switch';

  @override
  String get modelsSwitchCloudTitle => 'Switch to cloud?';

  @override
  String get modelsSwitchCloudBody =>
      'This affects every conversation on this computer: from the next turn, every agent goes through your first-party account, with only the models assigned to it.';

  @override
  String get modelsSwitchLocalTitle => 'Switch back to local?';

  @override
  String get modelsSwitchLocalBody =>
      'This affects every conversation on this computer: from the next turn, each agent uses the account chosen for it under Local accounts.';

  @override
  String get modelsSwitchedCloud => 'Switched to cloud';

  @override
  String get modelsSwitchedLocal => 'Switched back to local';

  @override
  String get modelsSwitchRefused => 'The computer didn\'t switch';

  @override
  String get modelsLocal => 'Local accounts';

  @override
  String get modelsLocalHint =>
      'Which account each agent uses in local mode. Injected only when the computer starts it: the CLIs\' own configuration files are never changed.';

  @override
  String get modelsLocalCloudNote =>
      'Cloud mode is on: the agents go through the first-party account. These choices take effect when you switch back to local.';

  @override
  String get modelsLoading => 'Reading the computer\'s models and accounts…';

  @override
  String get modelsNoHarnesses => 'No agent on this computer takes an account.';

  @override
  String get modelsNotInstalled => 'Not installed';

  @override
  String get modelsNotDriven => 'Not supported yet';

  @override
  String get modelsChoiceCli => 'Follow the CLI\'s own configuration';

  @override
  String get modelsChoiceOfficial => 'Official subscription (forced)';

  @override
  String get modelsChoiceGone => 'A deleted account';

  @override
  String get modelsRouteCli =>
      'Decided by the CLI\'s own configuration (for example the file cc-switch writes)';

  @override
  String get modelsRouteOfficial =>
      'Forces Anthropic\'s official subscription login, over any third-party endpoint in settings.json';

  @override
  String get modelsRouteModelByCli => 'model chosen by the CLI';

  @override
  String get modelsNoKeyStored => 'no key stored';

  @override
  String modelsChoiceTitle(String agent) {
    return 'Account for $agent';
  }

  @override
  String modelsChoiceHint(String dialect) {
    return 'The accounts that speak $dialect';
  }

  @override
  String modelsChoiceNone(String dialect) {
    return 'No $dialect account yet.';
  }

  @override
  String get modelsAccounts => 'Accounts';

  @override
  String get modelsAccountsHint =>
      'Add DeepSeek, Zhipu, Kimi, OpenRouter and more from a preset, or your own relay. Keys stay in the computer\'s keychain.';

  @override
  String get modelsAccountsHintReadOnly =>
      'The provider accounts on the computer. Their keys stay in its keychain.';

  @override
  String get modelsNoAccounts =>
      'No accounts yet. Add one: pick a preset and enter its key.';

  @override
  String get modelsAddAccount => 'Add account';

  @override
  String get modelsLegacy => 'Older endpoint';

  @override
  String get modelsLegacyHint => 'Pick its protocol to make it an account';

  @override
  String modelsPresetTag(String preset) {
    return '$preset preset';
  }

  @override
  String get modelsKeyStored => 'Key stored';

  @override
  String get modelsKeyMissing => 'No key';

  @override
  String modelsDialectModels(String dialect, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$dialect ($_temp0)';
  }

  @override
  String modelsDeleteAccountTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get modelsDeleteAccountBody =>
      'Its key is deleted from the computer\'s keychain too. Agents using it go back to following the CLI\'s own configuration.';

  @override
  String modelsAccountDeleted(String name) {
    return 'Deleted “$name”';
  }

  @override
  String get modelsDeleteConflict =>
      'This account was changed elsewhere and has been read again. Check it, then delete it if you still want to.';

  @override
  String get modelsCloud => 'Cloud API keys';

  @override
  String get modelsCloudHint =>
      'Cloud mode runs on these: pick a key and assign its models to the agents. Managed with this phone\'s own sign-in.';

  @override
  String get keysLoading => 'Reading your keys…';

  @override
  String get keysEmpty => 'No keys yet. Create one to use cloud mode.';

  @override
  String get keyUnnamed => 'Unnamed';

  @override
  String get assignUnnamedKey => 'First-party key';

  @override
  String get keyUnlimited => 'Unlimited quota';

  @override
  String keyRemaining(String amount) {
    return '$amount left';
  }

  @override
  String keyGroupNamed(String group) {
    return 'group $group';
  }

  @override
  String get keyGroupDefault => 'The account\'s default';

  @override
  String get keyDisabled => 'Disabled';

  @override
  String get keyExpired => 'Expired';

  @override
  String get keyExhausted => 'Used up';

  @override
  String get keyAssign => 'Assign models';

  @override
  String get keyReveal => 'Show the whole key';

  @override
  String get keyCreate => 'New key';

  @override
  String get keyCreateTitle => 'New API key';

  @override
  String get keyCreateHint =>
      'Made on your account with this phone\'s sign-in; the computer is not involved.';

  @override
  String get keyName => 'Name';

  @override
  String get keyNameHint => 'e.g. My laptop';

  @override
  String get keyNameRequired => 'Give the key a name';

  @override
  String keyNameTooLong(int letters, int chinese) {
    return 'Too long: at most $letters letters, or $chinese Chinese characters';
  }

  @override
  String get keyGroup => 'Group';

  @override
  String get keyGroupsLoading => 'Reading your groups…';

  @override
  String get keyUnlimitedHint =>
      'Spends from the account\'s balance with no cap of its own';

  @override
  String get keyQuota => 'Quota (USD)';

  @override
  String get keyQuotaInvalid => 'Enter an amount above 0';

  @override
  String get keyExpiry => 'Expires';

  @override
  String get keyExpiryNever => 'Never';

  @override
  String keyExpiryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get keyCreatedTitle => 'Key created';

  @override
  String get keyShownOnce => 'This is the whole key, shown only this once.';

  @override
  String keyRevealTitle(String name) {
    return 'Key “$name”';
  }

  @override
  String get keyRevealHint =>
      'Keep it safe: anyone who has it can spend your balance.';

  @override
  String get keyRevealReason => 'Unlock to show the whole key';

  @override
  String keyDeleteTitle(String name) {
    return 'Delete the key “$name”?';
  }

  @override
  String get keyDeleteBody =>
      'Everything using it stops working, the cloud assignments made from it included. This can\'t be undone.';

  @override
  String get modelsAssigned => 'Assigned to agents';

  @override
  String get modelsAssignedHint => 'What cloud mode routes each agent through.';

  @override
  String get modelsNoModelsAssigned => 'No models specified';

  @override
  String get modelsUnassign => 'Unassign';

  @override
  String modelsUnassignTitle(String name) {
    return 'Unassign “$name”?';
  }

  @override
  String get modelsUnassignBody =>
      'In cloud mode the agent can no longer use these models. The key itself is kept.';

  @override
  String modelsUnassigned(String name) {
    return 'Unassigned “$name”';
  }

  @override
  String get assignTitle => 'Assign models';

  @override
  String assignHint(String key) {
    return 'Tick models and choose the agent they go to; cloud mode uses these. Each shows up as “agent · $key”.';
  }

  @override
  String get assignTo => 'Assigning to';

  @override
  String get assignToHint =>
      'Models ticked now go to this agent; pick another to give them to several.';

  @override
  String get assignToOnlyHint =>
      'Models ticked now go to this agent, the only one on this computer.';

  @override
  String get assignAgentsLoading => 'Reading the computer\'s agents…';

  @override
  String get assignAgentsFailed => 'Couldn\'t read the computer\'s agents';

  @override
  String get assignNoAgents =>
      'No agent on this computer is installed and supported.';

  @override
  String get assignSearch => 'Search models';

  @override
  String get assignLoading => 'Asking for this key\'s models…';

  @override
  String get assignNoModels => 'This key returned no models.';

  @override
  String assignGoesTo(String agents) {
    return 'To $agents';
  }

  @override
  String assignSummary(String agent, int count, int places) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    String _temp1 = intl.Intl.pluralLogic(
      places,
      locale: localeName,
      other: '$places assignments',
      one: '1 assignment',
    );
    return '$agent: $_temp0 ticked · $_temp1 in all';
  }

  @override
  String get assignConfirm => 'Confirm';

  @override
  String get assignNoneSelected => 'Tick at least one model';

  @override
  String assignTooMany(int limit) {
    return 'An agent takes at most $limit models at a time';
  }

  @override
  String assignPartial(String made, String error) {
    return 'Only partly done. Made: $made. Then: $error';
  }

  @override
  String assignDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Set up $count agents',
      one: 'Set up 1 agent',
    );
    return '$_temp0';
  }

  @override
  String get ctxTitle => 'Context and auto-compaction';

  @override
  String get ctxEntry => 'When each model compacts';

  @override
  String get ctxEntryHint =>
      'Compact only once the context grows past a size you set';

  @override
  String ctxHint(String min, String max) {
    return 'Give a model a size ($min–$max): its context is compacted only once it grows past it. A model without one is left to its agent. The window is what the model can hold.';
  }

  @override
  String get ctxLoading => 'Reading the models…';

  @override
  String get ctxEmpty => 'No models to set yet.';

  @override
  String ctxCliGroup(String agent) {
    return '$agent, built in';
  }

  @override
  String ctxCloudGroup(String agent, String key) {
    return '$agent, cloud key “$key”';
  }

  @override
  String get ctxDefaultModel => 'Default model';

  @override
  String get ctxNoAgents => 'No agent can use it yet.';

  @override
  String ctxSupportLine(String agents, String support) {
    return '$agents: $support';
  }

  @override
  String get ctxSupportNative => 'compacts at the size';

  @override
  String get ctxSupportManaged =>
      'checked between turns; past it, compacted before the next message';

  @override
  String get ctxSupportUnsupported => 'can\'t be set; it decides itself';

  @override
  String ctxWindow(String size, String source) {
    return 'Window $size · $source';
  }

  @override
  String get ctxSourceCustom => 'set by you';

  @override
  String get ctxSourceDiscovered => 'reported by the endpoint';

  @override
  String get ctxSourcePreset => 'account preset';

  @override
  String get ctxSourceKnown => 'model default';

  @override
  String get ctxSourceEstimate => 'estimate';

  @override
  String get ctxDefault => 'Default';

  @override
  String ctxSliderLabel(String model) {
    return 'Compaction size for $model';
  }

  @override
  String ctxCustom(String size) {
    return 'Compacts once the context passes $size, not before.';
  }

  @override
  String get ctxDefaultState => 'Default: the agent decides.';

  @override
  String ctxOverWindow(String window) {
    return 'That\'s more than the $window window: the agent compacts on its own before then. If the window is wrong, correct it.';
  }

  @override
  String get ctxEditWindow => 'Correct the window';

  @override
  String get ctxResetWindow => 'Reset the window';

  @override
  String get ctxReset => 'Reset to default';

  @override
  String get ctxWindowField => 'Window, like 200k, 1m or 200000';

  @override
  String get ctxWindowInvalid =>
      'Write the window like 200k, 1m or 200000 (1K–100M)';

  @override
  String get editorAddTitle => 'Add account';

  @override
  String get editorEditTitle => 'Edit account';

  @override
  String get editorAdd => 'Add';

  @override
  String editorSaved(String name) {
    return 'Saved “$name”';
  }

  @override
  String editorAdded(String name) {
    return 'Added “$name”: choose it for an agent under Local accounts';
  }

  @override
  String get editorPreset => 'Preset';

  @override
  String get editorPresetHint =>
      'A preset fills in each protocol\'s address and models. Model names change often: fetch them before saving.';

  @override
  String get editorPresetSearch => 'Search vendors';

  @override
  String get editorPresetsLoading => 'Reading the presets…';

  @override
  String get editorPresetCredit =>
      'Some presets come from cc-switch, under the MIT License.';

  @override
  String get editorPresetLicense => 'License';

  @override
  String get editorPresetCustom => 'Custom';

  @override
  String get editorAccountSection => 'Account';

  @override
  String get editorName => 'Name';

  @override
  String get editorNameHint => 'e.g. DeepSeek (personal)';

  @override
  String get editorNameRequired => 'Give the account a name';

  @override
  String get editorNote => 'Note';

  @override
  String get editorNoteHint => 'Whose key, what for, how it\'s billed…';

  @override
  String get editorApiKey => 'API key';

  @override
  String get editorKeyShared =>
      'One key for every protocol, kept in the computer\'s keychain and never shown again.';

  @override
  String get editorKeyKept =>
      'One key for every protocol. A key is stored: leave this empty to keep it.';

  @override
  String get editorKeyWillClear => 'The stored key is cleared when you save.';

  @override
  String get editorClearKey => 'Clear the stored key';

  @override
  String get editorClearKeyHint => 'For an endpoint that needs none';

  @override
  String get editorProtocols => 'Protocol endpoints';

  @override
  String get editorProtocolsHint =>
      'One account per vendor: an endpoint for each protocol it speaks, one key for all of them.';

  @override
  String get editorNoProtocol => 'Turn on at least one protocol';

  @override
  String editorDialectFor(String agents) {
    return 'For $agents';
  }

  @override
  String get editorBaseUrl => 'Base URL';

  @override
  String get editorUrlRequired => 'Enter the Base URL';

  @override
  String get editorUrlNotAddress =>
      'Not a valid address, like https://api.example.com/v1';

  @override
  String get editorUrlNotHttp => 'Must start with http:// or https://';

  @override
  String get editorModels => 'Models';

  @override
  String get editorModelsHint => 'Fetch asks the endpoint itself for its list.';

  @override
  String get editorFetch => 'Fetch models';

  @override
  String get editorModelList => 'Model ids';

  @override
  String get editorModelsHelper => 'One per line, or separated by commas';

  @override
  String get editorCodexNeedsModel =>
      'Codex needs a model on this endpoint: list one, or set the default model';

  @override
  String get editorFetching => 'Asking the endpoint for its models…';

  @override
  String get editorFetchFailed => 'Couldn\'t fetch the models';

  @override
  String editorFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return 'Got $_temp0 and filled in the list.';
  }

  @override
  String editorFetchedSome(int count, int kept) {
    return 'Got $count models; filled in the first $kept, as many as a protocol keeps.';
  }

  @override
  String get editorFetchNeedsUrl => 'Enter the Base URL first';

  @override
  String get editorFetchNoQuery =>
      'The address can\'t have ? or # in it: the model list\'s path goes after it';

  @override
  String editorFetchRejected(int status) {
    return 'The key was rejected ($status): check this endpoint\'s key';
  }

  @override
  String editorFetchHttp(int status) {
    return 'The endpoint answered HTTP $status';
  }

  @override
  String get editorFetchTimeout =>
      'The endpoint didn\'t answer within 20 seconds';

  @override
  String get editorFetchNetwork => 'Couldn\'t reach this address';

  @override
  String get editorFetchNotJson => 'The endpoint\'s answer isn\'t JSON';

  @override
  String get editorFetchEmpty => 'The endpoint listed no models';

  @override
  String get editorFetchTooLarge =>
      'The endpoint\'s answer is too large (over 8 MiB)';

  @override
  String get editorModelMap => 'Model mapping';

  @override
  String get editorModelMapHint =>
      'The model the agent asks for unless told otherwise.';

  @override
  String get editorModelMapHintAnthropic =>
      'Which model each of Claude Code\'s slots asks for; an empty slot uses the main model.';

  @override
  String get editorSlotMain => 'Main model';

  @override
  String get editorSlotDefault => 'Default model';

  @override
  String get editorSlotHaiku => 'Haiku (background)';

  @override
  String get editorSlotSubagent => 'Subagent';

  @override
  String get editorSameAsMain => 'Same as main';

  @override
  String get editorPickModel => 'Pick from the list';

  @override
  String get editorExtraEnv => 'Extra environment variables';

  @override
  String get editorExtraEnvHint =>
      'Set for Claude Code only. The endpoint and key are the route\'s own and can\'t be overridden here.';

  @override
  String get editorExtraEnvField => 'Variables';

  @override
  String get editorExtraEnvFormat => 'KEY=VALUE, one per line';

  @override
  String editorEnvLine(String line) {
    return 'Not KEY=VALUE: $line';
  }

  @override
  String editorEnvBadName(String name) {
    return '$name isn\'t a variable name: capital letters, digits and underscores, starting with a letter';
  }

  @override
  String editorEnvReserved(String name) {
    return '$name is set by the route itself and can\'t be overridden here';
  }

  @override
  String get editorAdopt => 'Take in an older endpoint';

  @override
  String editorAdopted(String name) {
    return 'Takes in the older endpoint “$name”';
  }

  @override
  String get editorAdoptUndo => 'Don\'t take it in';

  @override
  String get editorAdoptHint =>
      'Pick an older endpoint and the protocol it speaks: it becomes this account\'s endpoint for that protocol, its key with it.';

  @override
  String get editorAdoptProtocol => 'The protocol it speaks';

  @override
  String get editorAdoptAction => 'Take it in';

  @override
  String get editorLegacyTitle => 'An older endpoint';

  @override
  String get editorLegacyBody =>
      'It was made before accounts and names no protocol. Turn on the one it speaks: saving makes it an account.';

  @override
  String get editorConflictTitle => 'Changed elsewhere';

  @override
  String get editorConflictBody =>
      'The computer or another phone changed this account while you were editing. Reloading discards your changes here.';

  @override
  String get editorReload => 'Reload';

  @override
  String editorReloadFailed(String error) {
    return 'Couldn\'t read it again: $error';
  }

  @override
  String get editorDeletedElsewhere => 'This account was deleted elsewhere.';

  @override
  String get editorKeyRequired => 'New server address: enter the API key again';

  @override
  String get editorKeyRequiredBody =>
      'The stored key can\'t go to a new address. Enter the key again, or clear the stored one, then save.';

  @override
  String editorFixFields(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields need fixing',
      one: '1 field needs fixing',
    );
    return '$_temp0';
  }

  @override
  String get editorStatusConflict => 'Changed elsewhere: reload it at the top';

  @override
  String get editorStatusRefused => 'Not saved: the reason is at the top';

  @override
  String editorTooLong(int limit) {
    return 'At most $limit characters';
  }

  @override
  String editorTooMany(int limit) {
    return 'At most $limit';
  }

  @override
  String editorTooManyModels(int limit) {
    return 'At most $limit models';
  }

  @override
  String editorTooManyEnv(int limit) {
    return 'At most $limit variables';
  }

  @override
  String get editorEmpty => 'Can\'t be blank';

  @override
  String get editorKeyInvalid => 'Printable ASCII only, no spaces';

  @override
  String get editorUrlInvalid => 'No spaces or control characters';

  @override
  String get editorControlChars => 'No control characters';

  @override
  String editorProblemIn(String item, String problem) {
    return '$item: $problem';
  }

  @override
  String get editorDiscardTitle => 'Discard your changes?';

  @override
  String get editorDiscardBody => 'What you changed here isn\'t saved.';

  @override
  String get editorUnknownProtocol =>
      'This account speaks a protocol this version of the app doesn\'t know: edit it on the computer, or update the app.';

  @override
  String editorProtocolTwice(String protocol) {
    return '$protocol is there twice';
  }

  @override
  String get errProviderUnsupported =>
      'This computer can\'t take a model on a chosen account. Pick the model again.';

  @override
  String get backendKeyNotLocated =>
      'The key was created, but isn\'t in the list that came after. Check your keys before creating another.';

  @override
  String get backendNoKey => 'The server returned no key';
}
