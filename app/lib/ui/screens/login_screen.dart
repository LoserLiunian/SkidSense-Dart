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

  String get _base => _server.text.trim();

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

  Future<void> _probe() async {
    final base = _base;
    if (!RegExp(r'^https?://[^/\s]+').hasMatch(base)) return;
    _probedFor = base;
    try {
      final status = await context.app.probe(base);
      if (!mounted || _base != base) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } catch (error) {
      if (mounted && _base == base) setState(() => _error = error);
    }
  }

  bool get _needsGeetest => _status?.needsGeetest ?? false;
  bool get _needsTurnstile => _status?.needsTurnstile ?? false;

  bool get _canSubmit =>
      !_busy &&
      _username.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      (!_needsGeetest || _geetest != null) &&
      (!_needsTurnstile || _turnstile != null);

  Future<void> _signIn() async {
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
      // A used captcha token is single-use: a retry needs a new solve.
      if (mounted) {
        setState(() {
          _error = error;
          _geetest = null;
          _turnstile = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        if (_needsGeetest || _needsTurnstile) ...[
          const SizedBox(height: Gap.xl),
          Text(l.captchaTitle, style: context.text.titleSmall),
          const SizedBox(height: Gap.sm),
          _captcha(context, l),
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

  Widget _captcha(BuildContext context, L10n l) {
    final solved = _needsGeetest ? _geetest != null : _turnstile != null;
    if (solved) {
      return Row(children: [
        Icon(Icons.verified_rounded, color: context.colors.primary),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(l.captchaPassed, style: context.text.bodyMedium)),
        AppButton(
          label: l.captchaRedo,
          emphasis: ActionEmphasis.quiet,
          onPressed: () => setState(() {
            _geetest = null;
            _turnstile = null;
          }),
        ),
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
        child: _needsGeetest
            ? CaptchaView(
                key: ValueKey('geetest-${status.geetestId}'),
                html: geeTestPage(status.geetestId ?? ''),
                baseUrl: 'https://static.geetest.com/',
                onResult: (value) => setState(() => _geetest = value.isEmpty ? null : value),
              )
            : CaptchaView(
                key: ValueKey('turnstile-${status.turnstileSiteKey}'),
                // Turnstile checks the page's hostname against the site-key
                // allowlist — which names the login server (S26).
                html: turnstilePage(status.turnstileSiteKey ?? ''),
                baseUrl: _base.endsWith('/') ? _base : '$_base/',
                height: 140,
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

  Widget _twoFactor(BuildContext context, L10n l) {
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
      AppButton(
        label: l.back,
        emphasis: ActionEmphasis.quiet,
        onPressed: _busy
            ? null
            : () => setState(() {
                  _challenge = null;
                  _code.clear();
                  _error = null;
                }),
      ),
    ]);
  }
}
