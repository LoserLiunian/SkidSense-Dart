import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SkidSense'**
  String get appName;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get none;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the same account as SkidSense on your computer — that is how the two find each other.'**
  String get loginSubtitle;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverAddress;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @serverReachable.
  ///
  /// In en, this message translates to:
  /// **'Server reachable: {name}'**
  String serverReachable(String name);

  /// No description provided for @captchaTitle.
  ///
  /// In en, this message translates to:
  /// **'Human verification'**
  String get captchaTitle;

  /// No description provided for @captchaPassed.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get captchaPassed;

  /// No description provided for @captchaRedo.
  ///
  /// In en, this message translates to:
  /// **'Verify again'**
  String get captchaRedo;

  /// No description provided for @captchaFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed ({code}). Try again.'**
  String captchaFailed(String code);

  /// No description provided for @captchaExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification expired. Try again.'**
  String get captchaExpired;

  /// No description provided for @captchaOnSignIn.
  ///
  /// In en, this message translates to:
  /// **'A quick human check opens when you sign in.'**
  String get captchaOnSignIn;

  /// No description provided for @passwordLoginDisabled.
  ///
  /// In en, this message translates to:
  /// **'This server has password sign-in turned off.'**
  String get passwordLoginDisabled;

  /// No description provided for @pairingAfterLogin.
  ///
  /// In en, this message translates to:
  /// **'Signing in and pairing are two steps: sign in here first, then scan the QR code on your computer.'**
  String get pairingAfterLogin;

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app, or a backup code.'**
  String get twoFactorHint;

  /// No description provided for @twoFactorRequired.
  ///
  /// In en, this message translates to:
  /// **'This account requires a second step.'**
  String get twoFactorRequired;

  /// No description provided for @twoFactorMethods.
  ///
  /// In en, this message translates to:
  /// **'Available: {methods}'**
  String twoFactorMethods(String methods);

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get verificationCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @hostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get hostsTitle;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'{user} · {server}'**
  String signedInAs(String user, String server);

  /// No description provided for @pairComputer.
  ///
  /// In en, this message translates to:
  /// **'Pair a computer'**
  String get pairComputer;

  /// No description provided for @pairedSection.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get pairedSection;

  /// No description provided for @pairedSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to connect'**
  String get pairedSectionHint;

  /// No description provided for @otherHostsSection.
  ///
  /// In en, this message translates to:
  /// **'Other computers on this account'**
  String get otherHostsSection;

  /// No description provided for @otherHostsHint.
  ///
  /// In en, this message translates to:
  /// **'Not paired with this phone yet'**
  String get otherHostsHint;

  /// No description provided for @presenceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get presenceOnline;

  /// No description provided for @presenceRelayOffline.
  ///
  /// In en, this message translates to:
  /// **'Relay offline'**
  String get presenceRelayOffline;

  /// No description provided for @presenceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get presenceOffline;

  /// No description provided for @presenceRelayOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the relay — it may still answer on your local network.'**
  String get presenceRelayOfflineHint;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @lanAddresses.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get lanAddresses;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @forgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget {name}?'**
  String forgetTitle(String name);

  /// No description provided for @forgetBody.
  ///
  /// In en, this message translates to:
  /// **'This phone is also revoked on the server: the computer disconnects it at once and stops encrypting history for it. You will need to scan a new QR code to connect again.'**
  String get forgetBody;

  /// No description provided for @forgetAction.
  ///
  /// In en, this message translates to:
  /// **'Forget and revoke'**
  String get forgetAction;

  /// No description provided for @noComputersTitle.
  ///
  /// In en, this message translates to:
  /// **'No computers yet'**
  String get noComputersTitle;

  /// No description provided for @noComputersBody.
  ///
  /// In en, this message translates to:
  /// **'Open Remote Control in SkidSense on your computer and generate a pairing QR code, then scan it here.'**
  String get noComputersBody;

  /// No description provided for @hostNeedsQr.
  ///
  /// In en, this message translates to:
  /// **'Generate a QR code on it to pair'**
  String get hostNeedsQr;

  /// No description provided for @loadingHosts.
  ///
  /// In en, this message translates to:
  /// **'Loading computers…'**
  String get loadingHosts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @pairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair a computer'**
  String get pairingTitle;

  /// No description provided for @pairingIntro.
  ///
  /// In en, this message translates to:
  /// **'In SkidSense on your computer, open Remote Control and scan the QR code it shows. A code works once, for 10 minutes.'**
  String get pairingIntro;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @pasteLinkSection.
  ///
  /// In en, this message translates to:
  /// **'Or paste the pairing link'**
  String get pasteLinkSection;

  /// No description provided for @pasteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'skidsense://pair/1?d=…'**
  String get pasteLinkLabel;

  /// No description provided for @readLink.
  ///
  /// In en, this message translates to:
  /// **'Read link'**
  String get readLink;

  /// No description provided for @confirmComputer.
  ///
  /// In en, this message translates to:
  /// **'Is this your computer?'**
  String get confirmComputer;

  /// No description provided for @machineName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get machineName;

  /// No description provided for @backend.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get backend;

  /// No description provided for @fingerprintCheck.
  ///
  /// In en, this message translates to:
  /// **'Compare the fingerprint, group by group, with the one on your computer\'s screen. If it differs, this code is not from the computer you are using.'**
  String get fingerprintCheck;

  /// No description provided for @confirmPair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get confirmPair;

  /// No description provided for @pairStepRegistering.
  ///
  /// In en, this message translates to:
  /// **'Registering this phone…'**
  String get pairStepRegistering;

  /// No description provided for @pairStepAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This phone is already registered there — reconnecting…'**
  String get pairStepAlreadyRegistered;

  /// No description provided for @pairStepHandshaking.
  ///
  /// In en, this message translates to:
  /// **'Shaking hands with the computer…'**
  String get pairStepHandshaking;

  /// No description provided for @pairStepRepairing.
  ///
  /// In en, this message translates to:
  /// **'The computer has no record of this phone — pairing it again…'**
  String get pairStepRepairing;

  /// No description provided for @pairStepFinishing.
  ///
  /// In en, this message translates to:
  /// **'Paired. Reading what this phone may do…'**
  String get pairStepFinishing;

  /// No description provided for @pairStepTrying.
  ///
  /// In en, this message translates to:
  /// **'Trying {route}…'**
  String pairStepTrying(String route);

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available. Paste the pairing link instead.'**
  String get cameraUnavailable;

  /// No description provided for @scannerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code on your computer'**
  String get scannerPrompt;

  /// No description provided for @scannerTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get scannerTorch;

  /// No description provided for @notAPairingCode.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a SkidSense pairing code.'**
  String get notAPairingCode;

  /// No description provided for @tabSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get tabSessions;

  /// No description provided for @tabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get tabFiles;

  /// No description provided for @tabGit.
  ///
  /// In en, this message translates to:
  /// **'Git'**
  String get tabGit;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @routeLan.
  ///
  /// In en, this message translates to:
  /// **'LAN {address}'**
  String routeLan(String address);

  /// No description provided for @routeRelay.
  ///
  /// In en, this message translates to:
  /// **'Relay'**
  String get routeRelay;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected · {route}'**
  String statusConnected(String route);

  /// No description provided for @statusConnectedLimited.
  ///
  /// In en, this message translates to:
  /// **'Connected · {route} (limited to {rate} KB/s)'**
  String statusConnectedLimited(String route, int rate);

  /// No description provided for @statusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting · {route}'**
  String statusConnecting(String route);

  /// No description provided for @statusAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'Connecting · getting authorization'**
  String get statusAuthorizing;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'{error} · retrying in {seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String statusWaiting(String error, int seconds);

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect: {error}'**
  String statusFailed(String error);

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusIdle;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the computer'**
  String get offlineTitle;

  /// No description provided for @offlineBody.
  ///
  /// In en, this message translates to:
  /// **'Make sure SkidSense is running on the computer and this phone is paired with it. Without the local network the relay is used automatically.'**
  String get offlineBody;

  /// No description provided for @backToComputers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get backToComputers;

  /// No description provided for @searchSessions.
  ///
  /// In en, this message translates to:
  /// **'Search sessions'**
  String get searchSessions;

  /// No description provided for @noSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsTitle;

  /// No description provided for @noSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Start one on the computer, or here.'**
  String get noSessionsBody;

  /// No description provided for @noSessionsNoPrompt.
  ///
  /// In en, this message translates to:
  /// **'This phone may not start sessions.'**
  String get noSessionsNoPrompt;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”'**
  String noSearchResults(String query);

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @titleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get titleOptional;

  /// No description provided for @renameSession.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get renameSession;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sessionTitle;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String deleteSessionTitle(String title);

  /// No description provided for @deleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'The session and its transcript are deleted on the computer.'**
  String get deleteSessionBody;

  /// No description provided for @backgroundJobs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 background task} other{{count} background tasks}}'**
  String backgroundJobs(int count);

  /// No description provided for @loadingSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions…'**
  String get loadingSessions;

  /// No description provided for @runStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get runStateRunning;

  /// No description provided for @runStateAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get runStateAwaiting;

  /// No description provided for @runStateStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get runStateStarting;

  /// No description provided for @runStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get runStateIdle;

  /// No description provided for @runStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get runStateDone;

  /// No description provided for @runStateError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get runStateError;

  /// No description provided for @runStateAborted.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get runStateAborted;

  /// No description provided for @runStatePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get runStatePending;

  /// No description provided for @runStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get runStateCancelled;

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {ago}'**
  String updatedAgo(String ago);

  /// No description provided for @openingSession.
  ///
  /// In en, this message translates to:
  /// **'Opening the session…'**
  String get openingSession;

  /// No description provided for @sessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The computer has no such session.'**
  String get sessionNotFound;

  /// No description provided for @openTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get openTerminal;

  /// No description provided for @openFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get openFiles;

  /// No description provided for @openGit.
  ///
  /// In en, this message translates to:
  /// **'Git'**
  String get openGit;

  /// No description provided for @approvalPermission.
  ///
  /// In en, this message translates to:
  /// **'Needs your permission'**
  String get approvalPermission;

  /// No description provided for @approvalQuestion.
  ///
  /// In en, this message translates to:
  /// **'The agent asks'**
  String get approvalQuestion;

  /// No description provided for @approvalInput.
  ///
  /// In en, this message translates to:
  /// **'The agent is waiting for input'**
  String get approvalInput;

  /// No description provided for @approvalOther.
  ///
  /// In en, this message translates to:
  /// **'The agent needs an answer'**
  String get approvalOther;

  /// No description provided for @approvalFreeText.
  ///
  /// In en, this message translates to:
  /// **'Free answer allowed'**
  String get approvalFreeText;

  /// No description provided for @approvalCwd.
  ///
  /// In en, this message translates to:
  /// **'Working directory: {cwd}'**
  String approvalCwd(String cwd);

  /// No description provided for @approvalScopes.
  ///
  /// In en, this message translates to:
  /// **'Requested permissions: {scopes}'**
  String approvalScopes(String scopes);

  /// No description provided for @approvalNoPermission.
  ///
  /// In en, this message translates to:
  /// **'This phone may not answer approvals. Answer on the computer, or on a device that may.'**
  String get approvalNoPermission;

  /// No description provided for @approvalAnsweredElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Answered on {device}'**
  String approvalAnsweredElsewhere(String device);

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @sendAnswer.
  ///
  /// In en, this message translates to:
  /// **'Send answer'**
  String get sendAnswer;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @cancelTurn.
  ///
  /// In en, this message translates to:
  /// **'Cancel turn'**
  String get cancelTurn;

  /// No description provided for @answerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get answerPlaceholder;

  /// No description provided for @toolInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get toolInput;

  /// No description provided for @toolResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get toolResult;

  /// No description provided for @toolTruncated.
  ///
  /// In en, this message translates to:
  /// **'{label} truncated (originally {size})'**
  String toolTruncated(String label, String size);

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @steerHint.
  ///
  /// In en, this message translates to:
  /// **'Add to the running turn'**
  String get steerHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @steer.
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get steer;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @composerOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get composerOptions;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get attach;

  /// No description provided for @attachmentsNote.
  ///
  /// In en, this message translates to:
  /// **'Attachments go with the next message; leaving this session discards them.'**
  String get attachmentsNote;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @noPromptPermission.
  ///
  /// In en, this message translates to:
  /// **'This phone may not send messages.'**
  String get noPromptPermission;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Send options'**
  String get options;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @modelDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get modelDefault;

  /// No description provided for @modelAccount.
  ///
  /// In en, this message translates to:
  /// **'Model ({account})'**
  String modelAccount(String account);

  /// No description provided for @noModels.
  ///
  /// In en, this message translates to:
  /// **'No model list available'**
  String get noModels;

  /// No description provided for @effort.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get effort;

  /// No description provided for @effortMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get effortMinimal;

  /// No description provided for @effortLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get effortLow;

  /// No description provided for @effortMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get effortMedium;

  /// No description provided for @effortHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get effortHigh;

  /// No description provided for @effortXhigh.
  ///
  /// In en, this message translates to:
  /// **'Very high'**
  String get effortXhigh;

  /// No description provided for @effortMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get effortMax;

  /// No description provided for @effortUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get effortUltra;

  /// No description provided for @approvalMode.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvalMode;

  /// No description provided for @approvalModeLocked.
  ///
  /// In en, this message translates to:
  /// **'Approvals (this phone may not approve: default only)'**
  String get approvalModeLocked;

  /// No description provided for @approvalDefault.
  ///
  /// In en, this message translates to:
  /// **'Ask each time'**
  String get approvalDefault;

  /// No description provided for @approvalAcceptEdits.
  ///
  /// In en, this message translates to:
  /// **'Accept edits'**
  String get approvalAcceptEdits;

  /// No description provided for @approvalPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan only'**
  String get approvalPlan;

  /// No description provided for @approvalDontAsk.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask'**
  String get approvalDontAsk;

  /// No description provided for @approvalBypass.
  ///
  /// In en, this message translates to:
  /// **'Bypass all'**
  String get approvalBypass;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get thinking;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @backgroundTasks.
  ///
  /// In en, this message translates to:
  /// **'Background tasks'**
  String get backgroundTasks;

  /// No description provided for @usageContext.
  ///
  /// In en, this message translates to:
  /// **'Context {tokens}'**
  String usageContext(String tokens);

  /// No description provided for @usageOutput.
  ///
  /// In en, this message translates to:
  /// **'Output {tokens}'**
  String usageOutput(String tokens);

  /// No description provided for @steered.
  ///
  /// In en, this message translates to:
  /// **'Steered: {text}'**
  String steered(String text);

  /// No description provided for @compactedAuto.
  ///
  /// In en, this message translates to:
  /// **'Context compacted (automatically)'**
  String get compactedAuto;

  /// No description provided for @compactedManual.
  ///
  /// In en, this message translates to:
  /// **'Context compacted'**
  String get compactedManual;

  /// No description provided for @subAgent.
  ///
  /// In en, this message translates to:
  /// **'Sub-agent'**
  String get subAgent;

  /// No description provided for @subAgentTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get subAgentTask;

  /// No description provided for @subAgentLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get subAgentLatest;

  /// No description provided for @subAgentReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get subAgentReport;

  /// No description provided for @workflow.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get workflow;

  /// No description provided for @toolCalls.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tool call} other{{count} tool calls}}'**
  String toolCalls(int count);

  /// No description provided for @promptRefused.
  ///
  /// In en, this message translates to:
  /// **'The computer did not take the message: {reason}'**
  String promptRefused(String reason);

  /// No description provided for @promptRefusedPlain.
  ///
  /// In en, this message translates to:
  /// **'The computer did not take the message.'**
  String get promptRefusedPlain;

  /// No description provided for @promptUncertain.
  ///
  /// In en, this message translates to:
  /// **'No answer came — the turn may have started. Check the transcript before sending again.'**
  String get promptUncertain;

  /// No description provided for @promptUncertainDropped.
  ///
  /// In en, this message translates to:
  /// **'No answer came — the turn may have started. Check the transcript before sending again; the attachments were removed and need adding again.'**
  String get promptUncertainDropped;

  /// No description provided for @uploadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is still uploading.'**
  String uploadIncomplete(String name);

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {name}'**
  String uploading(String name);

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get jumpToLatest;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @searchContent.
  ///
  /// In en, this message translates to:
  /// **'Search file contents'**
  String get searchContent;

  /// No description provided for @regex.
  ///
  /// In en, this message translates to:
  /// **'Regex'**
  String get regex;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @searchSummary.
  ///
  /// In en, this message translates to:
  /// **'{matches, plural, =1{1 match} other{{matches} matches}} in {files, plural, =1{1 file} other{{files} files}}'**
  String searchSummary(int matches, int files);

  /// No description provided for @searchCancelled.
  ///
  /// In en, this message translates to:
  /// **'Search stopped'**
  String get searchCancelled;

  /// No description provided for @searchInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The connection dropped and the search stopped. Search again.'**
  String get searchInterrupted;

  /// No description provided for @moreMatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more match} other{{count} more matches}}'**
  String moreMatches(int count);

  /// No description provided for @dirTruncated.
  ///
  /// In en, this message translates to:
  /// **'This folder has too many entries; only some are shown.'**
  String get dirTruncated;

  /// No description provided for @emptyDir.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get emptyDir;

  /// No description provided for @showIgnored.
  ///
  /// In en, this message translates to:
  /// **'Show ignored files'**
  String get showIgnored;

  /// No description provided for @binaryFile.
  ///
  /// In en, this message translates to:
  /// **'A binary file — it can only be previewed.'**
  String get binaryFile;

  /// No description provided for @tooLargeFile.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to open here.'**
  String get tooLargeFile;

  /// No description provided for @fileLines.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}} · {size}'**
  String fileLines(int count, String size);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @saveConflict.
  ///
  /// In en, this message translates to:
  /// **'The file was changed elsewhere, so saving was refused rather than overwrite it. Reload, then edit again.'**
  String get saveConflict;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get unsavedChanges;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFile;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteItemTitle(String name);

  /// No description provided for @deleteItemBody.
  ///
  /// In en, this message translates to:
  /// **'It is deleted on the computer.'**
  String get deleteItemBody;

  /// No description provided for @noWorkspace.
  ///
  /// In en, this message translates to:
  /// **'No workspace'**
  String get noWorkspace;

  /// No description provided for @chooseWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get chooseWorkspace;

  /// No description provided for @root.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// No description provided for @gitTitle.
  ///
  /// In en, this message translates to:
  /// **'Git'**
  String get gitTitle;

  /// No description provided for @notARepo.
  ///
  /// In en, this message translates to:
  /// **'This workspace is not a Git repository.'**
  String get notARepo;

  /// No description provided for @initRepo.
  ///
  /// In en, this message translates to:
  /// **'Initialize a repository here'**
  String get initRepo;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @detached.
  ///
  /// In en, this message translates to:
  /// **'Detached at {sha}'**
  String detached(String sha);

  /// No description provided for @upstream.
  ///
  /// In en, this message translates to:
  /// **'Upstream {name}'**
  String upstream(String name);

  /// No description provided for @aheadBehind.
  ///
  /// In en, this message translates to:
  /// **'↑{ahead} ↓{behind}'**
  String aheadBehind(int ahead, int behind);

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @fetch.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get fetch;

  /// No description provided for @pull.
  ///
  /// In en, this message translates to:
  /// **'Pull'**
  String get pull;

  /// No description provided for @push.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get push;

  /// No description provided for @switchBranch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchBranch;

  /// No description provided for @currentBranch.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentBranch;

  /// No description provided for @remoteBranch.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remoteBranch;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @staged.
  ///
  /// In en, this message translates to:
  /// **'Staged'**
  String get staged;

  /// No description provided for @unstaged.
  ///
  /// In en, this message translates to:
  /// **'Not staged'**
  String get unstaged;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'Nothing to commit'**
  String get noChanges;

  /// No description provided for @stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @unstage.
  ///
  /// In en, this message translates to:
  /// **'Unstage'**
  String get unstage;

  /// No description provided for @stageAll.
  ///
  /// In en, this message translates to:
  /// **'Stage all'**
  String get stageAll;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes to {path}?'**
  String discardTitle(String path);

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'The changes are lost on the computer.'**
  String get discardBody;

  /// No description provided for @commit.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get commit;

  /// No description provided for @commitMessage.
  ///
  /// In en, this message translates to:
  /// **'Commit message'**
  String get commitMessage;

  /// No description provided for @commitStaged.
  ///
  /// In en, this message translates to:
  /// **'Commit staged changes'**
  String get commitStaged;

  /// No description provided for @committed.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get committed;

  /// No description provided for @renamedFrom.
  ///
  /// In en, this message translates to:
  /// **'from {path}'**
  String renamedFrom(String path);

  /// No description provided for @diffTruncated.
  ///
  /// In en, this message translates to:
  /// **'The diff is too large; only part is shown.'**
  String get diffTruncated;

  /// No description provided for @binaryDiff.
  ///
  /// In en, this message translates to:
  /// **'Binary file'**
  String get binaryDiff;

  /// No description provided for @gitModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get gitModified;

  /// No description provided for @gitAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get gitAdded;

  /// No description provided for @gitDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get gitDeleted;

  /// No description provided for @gitRenamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed'**
  String get gitRenamed;

  /// No description provided for @gitUntracked.
  ///
  /// In en, this message translates to:
  /// **'Untracked'**
  String get gitUntracked;

  /// No description provided for @gitConflicted.
  ///
  /// In en, this message translates to:
  /// **'Conflict'**
  String get gitConflicted;

  /// No description provided for @gitIgnored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get gitIgnored;

  /// No description provided for @gitOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Git: {message}'**
  String gitOperationFailed(String message);

  /// No description provided for @conflictsBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file has conflicts} other{{count} files have conflicts}}'**
  String conflictsBanner(int count);

  /// No description provided for @terminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminalTitle;

  /// No description provided for @terminalWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'The terminal bypasses approvals'**
  String get terminalWarningTitle;

  /// No description provided for @terminalWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The terminal runs the real CLI on the computer. It answers its own permission prompts there: no approval card appears here and nothing is stopped. It works only if the computer granted this phone the terminal permission, which is off by default.'**
  String get terminalWarningBody;

  /// No description provided for @terminalOpen.
  ///
  /// In en, this message translates to:
  /// **'I understand — open the terminal'**
  String get terminalOpen;

  /// No description provided for @terminalClose.
  ///
  /// In en, this message translates to:
  /// **'Close terminal'**
  String get terminalClose;

  /// No description provided for @terminalOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening the terminal…'**
  String get terminalOpening;

  /// No description provided for @terminalExitCode.
  ///
  /// In en, this message translates to:
  /// **'Ended · exit code {code}'**
  String terminalExitCode(int code);

  /// No description provided for @terminalExitSignal.
  ///
  /// In en, this message translates to:
  /// **'Ended · killed by signal {signal}'**
  String terminalExitSignal(int signal);

  /// No description provided for @terminalEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get terminalEnded;

  /// No description provided for @terminalNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This phone may not use the terminal.'**
  String get terminalNotAllowed;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted on the server; only this phone can open it'**
  String get historySubtitle;

  /// No description provided for @historySearch.
  ///
  /// In en, this message translates to:
  /// **'Search what you have opened'**
  String get historySearch;

  /// No description provided for @historyEpoch.
  ///
  /// In en, this message translates to:
  /// **'Key generation {epoch}'**
  String historyEpoch(int epoch);

  /// No description provided for @historyTurns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 turn} other{{count} turns}}'**
  String historyTurns(int count);

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history on the server'**
  String get historyEmpty;

  /// No description provided for @historyNoKey.
  ///
  /// In en, this message translates to:
  /// **'This phone has no key for generation {epoch}. It appears once the computer uploads again.'**
  String historyNoKey(int epoch);

  /// No description provided for @historyDownload.
  ///
  /// In en, this message translates to:
  /// **'Could not download: {error}'**
  String historyDownload(String error);

  /// No description provided for @historyEncoding.
  ///
  /// In en, this message translates to:
  /// **'The stored data is malformed.'**
  String get historyEncoding;

  /// No description provided for @historyDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Could not decrypt: this may belong to another session or key generation.'**
  String get historyDecrypt;

  /// No description provided for @historyContent.
  ///
  /// In en, this message translates to:
  /// **'Decrypted, but not a session.'**
  String get historyContent;

  /// No description provided for @historyNotOpened.
  ///
  /// In en, this message translates to:
  /// **'Tap to download and decrypt'**
  String get historyNotOpened;

  /// No description provided for @historyNoHost.
  ///
  /// In en, this message translates to:
  /// **'Connect to a computer first.'**
  String get historyNoHost;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your pairings stay on this phone and come back when you sign in again.'**
  String get signOutBody;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @keyProtected.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s private key is held by the system keystore and cannot be exported.'**
  String get keyProtected;

  /// No description provided for @biometricLock.
  ///
  /// In en, this message translates to:
  /// **'Require unlock when opening'**
  String get biometricLock;

  /// No description provided for @biometricLockHint.
  ///
  /// In en, this message translates to:
  /// **'A convenience lock: the keys do not depend on it.'**
  String get biometricLockHint;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @designStyle.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get designStyle;

  /// No description provided for @styleM3.
  ///
  /// In en, this message translates to:
  /// **'Material 3'**
  String get styleM3;

  /// No description provided for @styleM3E.
  ///
  /// In en, this message translates to:
  /// **'Material 3 Expressive'**
  String get styleM3E;

  /// No description provided for @styleM3Hint.
  ///
  /// In en, this message translates to:
  /// **'Calm, compact, familiar'**
  String get styleM3Hint;

  /// No description provided for @styleM3EHint.
  ///
  /// In en, this message translates to:
  /// **'Bolder shapes, springy motion, emphasized type'**
  String get styleM3EHint;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper colors'**
  String get dynamicColor;

  /// No description provided for @dynamicColorHint.
  ///
  /// In en, this message translates to:
  /// **'Use the colors of your wallpaper (Android 12 and later)'**
  String get dynamicColorHint;

  /// No description provided for @seedColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get seedColor;

  /// No description provided for @seedColorOption.
  ///
  /// In en, this message translates to:
  /// **'Color {number}'**
  String seedColorOption(int number);

  /// No description provided for @colorVariant.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get colorVariant;

  /// No description provided for @variantTonalSpot.
  ///
  /// In en, this message translates to:
  /// **'Tonal'**
  String get variantTonalSpot;

  /// No description provided for @variantVibrant.
  ///
  /// In en, this message translates to:
  /// **'Vibrant'**
  String get variantVibrant;

  /// No description provided for @variantExpressive.
  ///
  /// In en, this message translates to:
  /// **'Expressive'**
  String get variantExpressive;

  /// No description provided for @variantFidelity.
  ///
  /// In en, this message translates to:
  /// **'Fidelity'**
  String get variantFidelity;

  /// No description provided for @variantNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get variantNeutral;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @contrastStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get contrastStandard;

  /// No description provided for @contrastMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get contrastMedium;

  /// No description provided for @contrastHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get contrastHigh;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageZhHans.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZhHans;

  /// No description provided for @languageZhHant.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageZhHant;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @devicesOnHost.
  ///
  /// In en, this message translates to:
  /// **'Devices on {host}'**
  String devicesOnHost(String host);

  /// No description provided for @devicesConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect to a computer to manage its devices.'**
  String get devicesConnectFirst;

  /// No description provided for @effectiveScopes.
  ///
  /// In en, this message translates to:
  /// **'What this phone may actually do (the server\'s grant, capped by the computer):'**
  String get effectiveScopes;

  /// No description provided for @terminalScopeNote.
  ///
  /// In en, this message translates to:
  /// **'The terminal is off by default: inside it the CLI answers its own permission prompts.'**
  String get terminalScopeNote;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get thisDevice;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @serverScopesNote.
  ///
  /// In en, this message translates to:
  /// **'These are the server\'s grants. What takes effect is their overlap with the cap the computer sets for this device: a permission the computer has not opened does nothing here.'**
  String get serverScopesNote;

  /// No description provided for @savePermissions.
  ///
  /// In en, this message translates to:
  /// **'Save permissions'**
  String get savePermissions;

  /// No description provided for @noScopes.
  ///
  /// In en, this message translates to:
  /// **'No permissions'**
  String get noScopes;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke {name}?'**
  String revokeTitle(String name);

  /// No description provided for @revokeBody.
  ///
  /// In en, this message translates to:
  /// **'It will no longer connect and needs a new QR code to pair again.'**
  String get revokeBody;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {ago}'**
  String lastSeen(String ago);

  /// No description provided for @deviceStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get deviceStatusPending;

  /// No description provided for @deviceStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get deviceStatusActive;

  /// No description provided for @deviceStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get deviceStatusRevoked;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @componentGallery.
  ///
  /// In en, this message translates to:
  /// **'Component gallery'**
  String get componentGallery;

  /// No description provided for @reloginNote.
  ///
  /// In en, this message translates to:
  /// **'After signing out or switching accounts, generate a new pairing QR code on the computer.'**
  String get reloginNote;

  /// No description provided for @scopeSessions.
  ///
  /// In en, this message translates to:
  /// **'View sessions'**
  String get scopeSessions;

  /// No description provided for @scopePrompt.
  ///
  /// In en, this message translates to:
  /// **'Send messages'**
  String get scopePrompt;

  /// No description provided for @scopeApprove.
  ///
  /// In en, this message translates to:
  /// **'Answer approvals'**
  String get scopeApprove;

  /// No description provided for @scopeFiles.
  ///
  /// In en, this message translates to:
  /// **'View files'**
  String get scopeFiles;

  /// No description provided for @scopeFilesWrite.
  ///
  /// In en, this message translates to:
  /// **'Change files'**
  String get scopeFilesWrite;

  /// No description provided for @scopeGit.
  ///
  /// In en, this message translates to:
  /// **'View Git'**
  String get scopeGit;

  /// No description provided for @scopeGitWrite.
  ///
  /// In en, this message translates to:
  /// **'Git writes'**
  String get scopeGitWrite;

  /// No description provided for @scopeTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get scopeTerminal;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'SkidSense is locked'**
  String get lockedTitle;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock SkidSense'**
  String get unlockReason;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String daysAgo(int count);

  /// No description provided for @noticeSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in has expired. Sign in again.'**
  String get noticeSessionExpired;

  /// No description provided for @noticeStoreReset.
  ///
  /// In en, this message translates to:
  /// **'The sign-in data on this device could not be read (was it moved from another phone?). You have been signed out; sign in and pair again.'**
  String get noticeStoreReset;

  /// No description provided for @noticeForgetUnrevoked.
  ///
  /// In en, this message translates to:
  /// **'Forgotten on this phone, but the server did not take the revocation ({error}). Revoke this phone on the computer.'**
  String noticeForgetUnrevoked(String error);

  /// No description provided for @noticeUndecodable.
  ///
  /// In en, this message translates to:
  /// **'The computer\'s answer to {method} could not be read. Is SkidSense on the computer up to date?'**
  String noticeUndecodable(String method);

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected to the computer'**
  String get errOffline;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'The computer did not answer in time'**
  String get errTimeout;

  /// No description provided for @errTimeoutRoute.
  ///
  /// In en, this message translates to:
  /// **'{route}: timed out'**
  String errTimeoutRoute(String route);

  /// No description provided for @errUnreachableRoute.
  ///
  /// In en, this message translates to:
  /// **'{route}: can\'t connect'**
  String errUnreachableRoute(String route);

  /// No description provided for @errUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t connect'**
  String get errUnreachable;

  /// No description provided for @errNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No way to reach this computer'**
  String get errNoRoute;

  /// No description provided for @errClosed.
  ///
  /// In en, this message translates to:
  /// **'The connection was closed'**
  String get errClosed;

  /// No description provided for @errPeerClosed.
  ///
  /// In en, this message translates to:
  /// **'The other side closed the connection'**
  String get errPeerClosed;

  /// No description provided for @errIdle.
  ///
  /// In en, this message translates to:
  /// **'The connection stopped responding'**
  String get errIdle;

  /// No description provided for @errHandshakeTimeout.
  ///
  /// In en, this message translates to:
  /// **'The handshake timed out'**
  String get errHandshakeTimeout;

  /// No description provided for @errRelayFrameOnLan.
  ///
  /// In en, this message translates to:
  /// **'Something on the local network pretended to be the relay'**
  String get errRelayFrameOnLan;

  /// No description provided for @errPlaintextAfterHandshake.
  ///
  /// In en, this message translates to:
  /// **'A forged message arrived after the handshake'**
  String get errPlaintextAfterHandshake;

  /// No description provided for @errProtocol.
  ///
  /// In en, this message translates to:
  /// **'The connection failed a check ({code})'**
  String errProtocol(String code);

  /// No description provided for @errBadResponse.
  ///
  /// In en, this message translates to:
  /// **'The computer sent a malformed answer'**
  String get errBadResponse;

  /// No description provided for @errTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too large'**
  String get errTooLarge;

  /// No description provided for @errHelloRefused.
  ///
  /// In en, this message translates to:
  /// **'The computer refused this phone'**
  String get errHelloRefused;

  /// No description provided for @errHelloRefusedReason.
  ///
  /// In en, this message translates to:
  /// **'The computer refused this phone: {reason}'**
  String errHelloRefusedReason(String reason);

  /// No description provided for @errBye.
  ///
  /// In en, this message translates to:
  /// **'The computer ended the connection'**
  String get errBye;

  /// No description provided for @errByeReason.
  ///
  /// In en, this message translates to:
  /// **'The computer ended the connection: {reason}'**
  String errByeReason(String reason);

  /// No description provided for @errRevoked.
  ///
  /// In en, this message translates to:
  /// **'This phone was revoked. Scan the QR code again to pair.'**
  String get errRevoked;

  /// No description provided for @errHostGone.
  ///
  /// In en, this message translates to:
  /// **'The server no longer has this pairing (the computer or this phone was removed). Scan the QR code again to pair.'**
  String get errHostGone;

  /// No description provided for @errGrant.
  ///
  /// In en, this message translates to:
  /// **'Could not get authorization: {error}'**
  String errGrant(String error);

  /// No description provided for @errNoHost.
  ///
  /// In en, this message translates to:
  /// **'No computer selected'**
  String get errNoHost;

  /// No description provided for @errUploadDesync.
  ///
  /// In en, this message translates to:
  /// **'The upload got out of step with the computer. Add the file again.'**
  String get errUploadDesync;

  /// No description provided for @errTooManyUploads.
  ///
  /// In en, this message translates to:
  /// **'At most 8 attachments at once'**
  String get errTooManyUploads;

  /// No description provided for @errUploadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'An attachment can be at most 20 MiB'**
  String get errUploadTooLarge;

  /// No description provided for @errUploadsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachments together can be at most 20 MiB'**
  String get errUploadsTooLarge;

  /// No description provided for @errNoKeystore.
  ///
  /// In en, this message translates to:
  /// **'The system keystore is unavailable; a device key cannot be created'**
  String get errNoKeystore;

  /// No description provided for @errKeyUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The system keystore could not be read. Try again in a moment.'**
  String get errKeyUnreadable;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String errUnknown(String detail);

  /// No description provided for @hsrUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'The computer speaks another protocol version. Update the app or the computer.'**
  String get hsrUnsupportedVersion;

  /// No description provided for @hsrWrongHost.
  ///
  /// In en, this message translates to:
  /// **'Connected to a different computer than the one paired'**
  String get hsrWrongHost;

  /// No description provided for @hsrEnrollClosed.
  ///
  /// In en, this message translates to:
  /// **'The pairing code has expired. Generate a new QR code on the computer.'**
  String get hsrEnrollClosed;

  /// No description provided for @hsrUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'This phone is not paired with that computer, or was revoked'**
  String get hsrUnknownDevice;

  /// No description provided for @hsrHandshakeFailed.
  ///
  /// In en, this message translates to:
  /// **'The handshake failed: a wrong pairing code, or not the computer you paired'**
  String get hsrHandshakeFailed;

  /// No description provided for @hsrReplayed.
  ///
  /// In en, this message translates to:
  /// **'The handshake looked like a replay. Try again.'**
  String get hsrReplayed;

  /// No description provided for @hsrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get hsrRateLimited;

  /// No description provided for @hsrDisabled.
  ///
  /// In en, this message translates to:
  /// **'Remote control is off on the computer'**
  String get hsrDisabled;

  /// No description provided for @relayHostOffline.
  ///
  /// In en, this message translates to:
  /// **'The computer is offline'**
  String get relayHostOffline;

  /// No description provided for @relayUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in is no longer valid. Sign in again.'**
  String get relayUnauthorized;

  /// No description provided for @relayRevoked.
  ///
  /// In en, this message translates to:
  /// **'This phone was revoked. Pair it again.'**
  String get relayRevoked;

  /// No description provided for @relayRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Try again later.'**
  String get relayRateLimited;

  /// No description provided for @relayTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The message was too large'**
  String get relayTooLarge;

  /// No description provided for @relaySuperseded.
  ///
  /// In en, this message translates to:
  /// **'This phone connected to the same computer elsewhere'**
  String get relaySuperseded;

  /// No description provided for @relayShutdown.
  ///
  /// In en, this message translates to:
  /// **'The relay is restarting'**
  String get relayShutdown;

  /// No description provided for @relayOther.
  ///
  /// In en, this message translates to:
  /// **'The relay refused ({code})'**
  String relayOther(String code);

  /// No description provided for @hsrOther.
  ///
  /// In en, this message translates to:
  /// **'The computer refused ({code})'**
  String hsrOther(String code);

  /// No description provided for @carrierRefused.
  ///
  /// In en, this message translates to:
  /// **'refused'**
  String get carrierRefused;

  /// No description provided for @carrierNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'no sign-in to show the relay (server unreachable, or sign-in expired)'**
  String get carrierNoCredentials;

  /// No description provided for @carrierNoRelay.
  ///
  /// In en, this message translates to:
  /// **'no relay address'**
  String get carrierNoRelay;

  /// No description provided for @carrierUpgrade.
  ///
  /// In en, this message translates to:
  /// **'not a SkidSense endpoint'**
  String get carrierUpgrade;

  /// No description provided for @carrierTls.
  ///
  /// In en, this message translates to:
  /// **'secure connection failed'**
  String get carrierTls;

  /// No description provided for @backendServer.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String backendServer(String message);

  /// No description provided for @backendNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get backendNotSignedIn;

  /// No description provided for @backendSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in expired. Sign in again.'**
  String get backendSessionExpired;

  /// No description provided for @backendUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server ({base})'**
  String backendUnreachable(String base);

  /// No description provided for @backendInsecure.
  ///
  /// In en, this message translates to:
  /// **'{base} is plain http://, which would send your sign-in across the internet unencrypted. Use the server\'s https:// address.'**
  String backendInsecure(String base);

  /// No description provided for @backendHttp.
  ///
  /// In en, this message translates to:
  /// **'The server answered HTTP {status}'**
  String backendHttp(int status);

  /// No description provided for @backendUnparsable.
  ///
  /// In en, this message translates to:
  /// **'The server\'s answer could not be read. Is {base} the right address?'**
  String backendUnparsable(String base);

  /// No description provided for @backendBadData.
  ///
  /// In en, this message translates to:
  /// **'The server\'s answer had an unexpected shape'**
  String get backendBadData;

  /// No description provided for @backendNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: the server returned no credentials'**
  String get backendNoCredentials;

  /// No description provided for @backendVerificationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The account needs a second step, but the server gave no way to complete it'**
  String get backendVerificationIncomplete;

  /// No description provided for @backendVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong or expired code'**
  String get backendVerifyFailed;

  /// No description provided for @pairErrNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in first'**
  String get pairErrNotSignedIn;

  /// No description provided for @pairErrWrongBackend.
  ///
  /// In en, this message translates to:
  /// **'This QR code is for {server}, but you are signed in to {signedIn}. Both must use the same server.'**
  String pairErrWrongBackend(String server, String signedIn);

  /// No description provided for @pairErrNoTicket.
  ///
  /// In en, this message translates to:
  /// **'The server issued no pairing ticket. Generate a new QR code.'**
  String get pairErrNoTicket;

  /// No description provided for @pairErrNoGrant.
  ///
  /// In en, this message translates to:
  /// **'This phone is registered with that computer, but no access grant is available ({error}). Check on the computer whether it was revoked; if so, generate a new QR code.'**
  String pairErrNoGrant(String error);

  /// No description provided for @pairErrCleanup.
  ///
  /// In en, this message translates to:
  /// **'Could not clear this phone\'s old record on the server ({error})'**
  String pairErrCleanup(String error);

  /// No description provided for @pairCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not a valid pairing code'**
  String get pairCodeInvalid;

  /// No description provided for @pairCodeAppTooOld.
  ///
  /// In en, this message translates to:
  /// **'This pairing code needs a newer version of the app'**
  String get pairCodeAppTooOld;

  /// No description provided for @pairCodeUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This pairing code version is not supported'**
  String get pairCodeUnsupported;

  /// No description provided for @pairCodeBadKey.
  ///
  /// In en, this message translates to:
  /// **'The computer\'s key in this code is invalid'**
  String get pairCodeBadKey;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return L10nZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
