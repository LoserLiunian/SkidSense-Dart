import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../platform/captcha_view.dart';
import '../../state/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/feedback.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// Sign in to new-api (spec §12): the server's own login, an optional
/// GeeTest or Turnstile challenge in a WebView, then a second factor when
/// the account has one.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _server;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  Object? _error;
  ServerStatus? _status;
  String? _probedFor;
  int _probes = 0;
  Timer? _probeDelay;
  String? _geetest;
  String? _turnstile;
  String? _captchaProblem;
  LoginChallenge? _challenge;

  @override
  void initState() {
    super.initState();
    final state = context.app.state;
    _server = TextEditingController(text: state.baseUrl.isEmpty ? BackendClient.defaultBase : state.baseUrl);
    _server.addListener(_serverChanged);
    _username.addListener(_rebuild);
    _password.addListener(_rebuild);
    _code.addListener(_rebuild);
    unawaited(_probe());
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _probeDelay?.cancel();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _typed => _server.text.trim();

  /// The address as typed, made the URL the client will use
  /// ([normalizeBackendBase]): `https://` when it names no scheme
  /// (`ai.surise.cn`), `HTTPS://…` as `https://…` — so either is probed and
  /// signed in to as the address it means.
  String get _base => normalizeBackendBase(_typed);

  /// http(s) and a host: what can be a server at all.
  static bool _isServer(String base) {
    final uri = Uri.tryParse(base);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
  }

  /// Whether this server wants a captcha is the server's answer, so it is
  /// asked again whenever the address changes, once typing pauses.
  void _serverChanged() {
    if (_probedFor == _base) return;
    _probeDelay?.cancel();
    setState(() {
      _status = null;
      _geetest = null;
      _turnstile = null;
    });
    _probeDelay = Timer(const Duration(milliseconds: 600), _probe);
  }

  /// Asks the server what a login needs; true once its answer is in. Only
  /// the latest question counts: an earlier one still out (the screen's
  /// first, when signing in asks again) must not overwrite its answer.
  Future<bool> _probe() async {
    final base = _base;
    if (!_isServer(base)) return false;
    _probedFor = base;
    final ask = ++_probes;
    try {
      final status = await context.app.probe(base);
      if (!mounted || ask != _probes || _base != base) return false;
      setState(() {
        _status = status;
        _error = null;
      });
      return true;
    } catch (error) {
      if (mounted && ask == _probes && _base == base) setState(() => _error = error);
      return false;
    }
  }

  bool get _needsGeetest => _status?.needsGeetest ?? false;
  bool get _needsTurnstile => _status?.needsTurnstile ?? false;

  bool get _canSubmit =>
      !_busy &&
      _isServer(_base) &&
      _username.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      (!_needsTurnstile || _turnstile != null);

  Future<void> _signIn() async {
    // Whether a captcha is due is the server's answer. Without one — the
    // probe failed, or is still out — the login would go without it and be
    // refused however often it is retried: the server is asked first.
    if (_status == null) {
      _probeDelay?.cancel();
      setState(() {
        _busy = true;
        _error = null;
      });
      final answered = await _probe();
      if (!mounted) return;
      setState(() => _busy = false);
      // A Turnstile server shows its widget now; signing in waits for it.
      if (!answered || !_canSubmit) return;
    }
    // GeeTest asks when it is needed, not before: the challenge opens over
    // the form, and signing in goes on once it is solved.
    if (_needsGeetest && _geetest == null) {
      final token = await _solveGeeTest();
      if (token == null || !mounted) return;
      _geetest = token;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await context.app.login(
        _base,
        _username.text.trim(),
        _password.text,
        geetest: _geetest,
        turnstile: _turnstile,
      );
      if (mounted) setState(() => _challenge = challenge);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      // A captcha token is single-use, and this attempt spent it whatever
      // the answer: the next login — a retry, or back from the second
      // step — needs a new solve.
      if (mounted) {
        setState(() {
          _busy = false;
          _geetest = null;
          _turnstile = null;
        });
      }
    }
  }

  /// The GeeTest challenge in a sheet; its token, or null when closed.
  Future<String?> _solveGeeTest() async {
    final l = context.l10n;
    final status = _status!;
    final language = geeTestLanguage(Localizations.localeOf(context));
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // Only the handle drags the sheet. Were the whole sheet draggable, the
      // slider would get no touch until the sheet gave up the drag — on
      // release — and a drag that drifts downwards would pull the sheet.
      enableDrag: false,
      builder: (sheet) => _GeeTestSheet(
        captchaId: status.geetestId ?? '',
        language: language,
        onResult: (value) {
          if (Navigator.of(sheet).canPop()) Navigator.of(sheet).pop(value);
        },
      ),
    );
    if (!mounted || result == null || result == 'close') return null;
    if (result.startsWith('err:')) {
      setState(() => _error = l.captchaFailed(result.substring(4)));
      return null;
    }
    return result;
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.app.verifyTwoFactor(_base, challenge.flowToken, _code.text.trim());
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final expressive = context.design.expressive;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedSwitcher(
                duration: context.design.motion.spatial.duration,
                switchInCurve: context.design.motion.spatial.curve,
                child: _challenge == null ? _form(context, l, expressive) : _twoFactor(context, l),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(BuildContext context, L10n l, String title, String subtitle) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(context.design.expressive ? 20 : 16),
        ),
        child: Icon(Icons.terminal_rounded, color: colors.onPrimaryContainer, size: 30),
      ),
      const SizedBox(height: Gap.xl),
      Text(title, style: context.design.expressive ? context.text.displaySmall : context.text.headlineMedium),
      const SizedBox(height: Gap.sm),
      Text(subtitle, style: context.text.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
      const SizedBox(height: Gap.xl),
    ]);
  }

  Widget _form(BuildContext context, L10n l, bool expressive) {
    final status = _status;
    final base = _base;
    final server = _isServer(base);
    return AutofillGroup(
      key: const ValueKey('form'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _brand(context, l, l.loginTitle, l.loginSubtitle),
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l.serverAddress,
            // What is used when it is not what was typed; nothing to sign in
            // to when it cannot be an address.
            helperText: server && base != _typed ? l.serverAddressUsed(base) : null,
            errorText: _typed.isNotEmpty && !server ? l.serverAddressInvalid : null,
            prefixIcon: const Icon(Icons.dns_outlined),
            suffixIcon: status?.systemName == null
                ? null
                : Tooltip(message: l.serverReachable(status!.systemName!), child: const Icon(Icons.check_circle_outline_rounded)),
          ),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _username,
          autofillHints: const [AutofillHints.username],
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.username, prefixIcon: const Icon(Icons.person_outline_rounded)),
        ),
        const SizedBox(height: Gap.md),
        TextField(
          controller: _password,
          autofillHints: const [AutofillHints.password],
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_canSubmit) unawaited(_signIn());
          },
          decoration: InputDecoration(
            labelText: l.password,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscure ? l.showPassword : l.hidePassword,
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        if (_needsGeetest) ...[
          const SizedBox(height: Gap.lg),
          Row(children: [
            Icon(Icons.verified_user_outlined, size: 20, color: context.colors.onSurfaceVariant),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(l.captchaOnSignIn, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
          ]),
        ] else if (_needsTurnstile) ...[
          const SizedBox(height: Gap.xl),
          Text(l.captchaTitle, style: context.text.titleSmall),
          const SizedBox(height: Gap.sm),
          _turnstileBox(context, l),
        ],
        if (status != null && !status.passwordLoginEnabled) ...[
          const SizedBox(height: Gap.lg),
          InlineBanner(message: l.passwordLoginDisabled, tone: BannerTone.warning),
        ],
        if (_error != null) ...[
          const SizedBox(height: Gap.lg),
          InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
        ],
        const SizedBox(height: Gap.xl),
        AppButton(label: l.signIn, onPressed: _canSubmit ? _signIn : null, busy: _busy, large: true, expand: true),
        const SizedBox(height: Gap.sm),
        AppButton(
          label: l.testConnection,
          emphasis: ActionEmphasis.quiet,
          onPressed: _busy
              ? null
              : () {
                  _probedFor = null;
                  unawaited(_probe());
                },
        ),
        const SizedBox(height: Gap.lg),
        Text(l.pairingAfterLogin, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _turnstileBox(BuildContext context, L10n l) {
    if (_turnstile != null) {
      return Row(children: [
        Icon(Icons.verified_rounded, color: context.colors.primary),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(l.captchaPassed, style: context.text.bodyMedium)),
        AppButton(label: l.captchaRedo, emphasis: ActionEmphasis.quiet, onPressed: () => setState(() => _turnstile = null)),
      ]);
    }
    final status = _status!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_captchaProblem != null) ...[
        InlineBanner(message: _captchaProblem!, onDismiss: () => setState(() => _captchaProblem = null)),
        const SizedBox(height: Gap.sm),
      ],
      ClipRRect(
        borderRadius: BorderRadius.circular(context.design.shapes.large),
        child: CaptchaView(
          key: ValueKey('turnstile-${status.turnstileSiteKey}'),
          // Turnstile checks the page's hostname against the site-key
          // allowlist — which names the login server (S26).
          html: turnstilePage(status.turnstileSiteKey ?? ''),
          baseUrl: _base.endsWith('/') ? _base : '$_base/',
          height: 72,
          onResult: (value) => setState(() {
            if (value.startsWith('err:')) {
              _captchaProblem = l.captchaFailed(value.substring(4));
            } else if (value.isEmpty) {
              _captchaProblem = l.captchaExpired;
            } else {
              _captchaProblem = null;
              _turnstile = value;
            }
          }),
        ),
      ),
    ]);
  }


  void _back() => setState(() {
        _challenge = null;
        _code.clear();
        _error = null;
      });

  Widget _twoFactor(BuildContext context, L10n l) {
    final listed = [for (final method in _challenge!.methods) method.method];
    // The app completes the second step with a code (TOTP or a backup code,
    // §12). An account whose only factor is a passkey has no code to give:
    // it is told what to do, not asked for one the server cannot accept.
    if (listed.contains('passkey') && !listed.contains('2fa')) {
      return Column(key: const ValueKey('2fa'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _brand(context, l, l.twoFactorTitle, l.twoFactorPasskeyOnly),
        AppButton(label: l.back, large: true, expand: true, onPressed: _back),
      ]);
    }
    final methods = [for (final method in _challenge!.methods) if (method.available) method.method];
    final hint = methods.contains('2fa')
        ? l.twoFactorHint
        : methods.isEmpty
            ? l.twoFactorRequired
            : l.twoFactorMethods(methods.join(', '));
    return Column(key: const ValueKey('2fa'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _brand(context, l, l.twoFactorTitle, hint),
      TextField(
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (_code.text.trim().isNotEmpty && !_busy) unawaited(_verify());
        },
        decoration: InputDecoration(labelText: l.verificationCode, prefixIcon: const Icon(Icons.pin_outlined)),
      ),
      if (_error != null) ...[
        const SizedBox(height: Gap.lg),
        InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
      ],
      const SizedBox(height: Gap.xl),
      AppButton(
        label: l.verify,
        large: true,
        expand: true,
        busy: _busy,
        onPressed: _code.text.trim().isEmpty ? null : _verify,
      ),
      const SizedBox(height: Gap.sm),
      AppButton(label: l.back, emphasis: ActionEmphasis.quiet, onPressed: _busy ? null : _back),
    ]);
  }
}

/// GeeTest's page in the sign-in sheet: a spinner until the challenge is up
/// and, when the SDK cannot be loaded, why, with a way to try again — not an
/// empty sheet that closes to nothing.
class _GeeTestSheet extends StatefulWidget {
  const _GeeTestSheet({required this.captchaId, required this.language, required this.onResult});

  final String captchaId;
  final String language;

  /// The page's answer: a token, `close` or `err:<code>`.
  final ValueChanged<String> onResult;

  @override
  State<_GeeTestSheet> createState() => _GeeTestSheetState();
}

class _GeeTestSheetState extends State<_GeeTestSheet> {
  bool _ready = false;
  bool _unloaded = false;
  int _attempt = 0;

  void _onPage(String value) {
    if (!mounted) return;
    switch (value) {
      case 'ready':
        setState(() => _ready = true);
      // The SDK, or what the challenge fetches after it — its script (GeeTest's
      // 60204), stylesheet (60200), language pack (60201), all before
      // `ready`, or its pictures (60202, the challenge up with nothing in it
      // but "network failure") — could not be fetched: the network, which a
      // retry may get past. Not the user failing the check.
      case 'err:load' || 'err:timeout' || 'err:60200' || 'err:60201' || 'err:60202' || 'err:60204':
        setState(() => _unloaded = true);
      // Only GeeTest's device script (gct) could not be: the challenge comes
      // up without it and is solved as ever — maybe already on screen, the
      // error 20 s behind it. Nothing to tear down, nor to report.
      case 'err:60205':
        break;
      default:
        widget.onResult(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 520,
      child: _unloaded
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: l.captchaLoadFailed,
                  body: l.captchaLoadFailedHint,
                  action: AppButton(
                    label: l.retry,
                    onPressed: () => setState(() {
                      _unloaded = false;
                      _ready = false;
                      _attempt++;
                    }),
                  ),
                ),
              ),
            )
          : Stack(fit: StackFit.expand, children: [
              CaptchaView(
                // A new page, and so a new load, on every attempt.
                key: ValueKey('geetest-${widget.captchaId}-$_attempt'),
                html: geeTestPage(widget.captchaId, language: widget.language),
                baseUrl: 'https://static.geetest.com/',
                onResult: _onPage,
              ),
              if (!_ready) IgnorePointer(child: Center(child: BusyIndicator(semanticsLabel: l.captchaLoading))),
            ]),
    );
  }
}
