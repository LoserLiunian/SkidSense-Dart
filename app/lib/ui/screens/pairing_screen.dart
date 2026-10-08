import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skidsense_core/skidsense_core.dart';

import '../../state/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';

/// Pair a computer: scan its QR code or paste the link, check the
/// fingerprint against the computer's screen (spec §3 — the one check that
/// makes the pinned key mean something, so it is never skipped), then the
/// registration and the enroll handshake.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, this.initialLink});

  /// A `skidsense://` link the app was opened with.
  final String? initialLink;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final TextEditingController _link = TextEditingController(text: widget.initialLink ?? '');
  PairingPayload? _payload;
  Object? _error;
  bool _busy = false;
  PairStep? _step;

  @override
  void initState() {
    super.initState();
    _link.addListener(() => setState(() {}));
    if (widget.initialLink != null) _read(widget.initialLink!);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _read(String text) {
    setState(() {
      _error = null;
      try {
        _payload = Pairing.decode(text);
      } catch (error) {
        _payload = null;
        _error = error;
      }
    });
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (scanned == null || !mounted) return;
    _link.text = scanned;
    _read(scanned);
  }

  Future<void> _pair(PairingPayload payload) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.app;
    final navigator = Navigator.of(context);
    try {
      final host = await app.pair(payload, onStep: (step) {
        if (mounted) setState(() => _step = step);
      });
      await app.connect(host.hostId);
      if (!mounted) return;
      await navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => const HostShell()));
      app.disconnect();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _step = null;
        });
      }
    }
  }

  String _stepLabel(L10n l, PairStep step) => switch (step) {
        PairStep.registering => l.pairStepRegistering,
        PairStep.alreadyRegistered => l.pairStepAlreadyRegistered,
        PairStep.handshaking => l.pairStepHandshaking,
        PairStep.repairing => l.pairStepRepairing,
        PairStep.finishing => l.pairStepFinishing,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final payload = _payload;
    return AppPage(
      title: l.pairingTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          sliver: SliverList.list(children: [
            Text(l.pairingIntro, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
            const SizedBox(height: Gap.xl),
            AppButton(
              label: l.scanQr,
              icon: Icons.qr_code_scanner_rounded,
              large: true,
              expand: true,
              onPressed: _busy ? null : _scan,
            ),
            const SizedBox(height: Gap.xl),
            Text(l.pasteLinkSection, style: context.text.titleSmall),
            const SizedBox(height: Gap.sm),
            TextField(
              controller: _link,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enabled: !_busy,
              decoration: InputDecoration(labelText: l.pasteLinkLabel),
            ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                label: l.readLink,
                emphasis: ActionEmphasis.tonal,
                onPressed: _link.text.trim().isEmpty || _busy ? null : () => _read(_link.text),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Gap.lg),
              InlineBanner(message: l.error(_error), onDismiss: () => setState(() => _error = null)),
            ],
            if (payload != null) ...[
              const SizedBox(height: Gap.xl),
              AnimatedSize(
                duration: context.design.motion.spatial.duration,
                curve: context.design.motion.spatial.curve,
                child: AppCard(
                  tone: context.colors.secondaryContainer,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.confirmComputer, style: context.text.titleLarge),
                    const SizedBox(height: Gap.md),
                    KeyValueRow(l.machineName, payload.machine.isEmpty ? payload.hostId : payload.machine),
                    KeyValueRow(l.fingerprint, payload.fingerprint, mono: true),
                    KeyValueRow(l.backend, payload.server),
                    KeyValueRow(l.lanAddresses, payload.lanAddrs.isEmpty ? l.none : payload.lanAddrs.join(', '), mono: true),
                    const SizedBox(height: Gap.md),
                    Text(l.fingerprintCheck, style: context.text.bodySmall),
                    const SizedBox(height: Gap.lg),
                    if (_step != null) ...[
                      const ProgressBar(),
                      const SizedBox(height: Gap.sm),
                      Text(_stepLabel(l, _step!), style: context.text.bodyMedium),
                      const SizedBox(height: Gap.md),
                    ],
                    Row(children: [
                      Expanded(
                        child: AppButton(
                          label: l.confirmPair,
                          icon: Icons.link_rounded,
                          busy: _busy,
                          expand: true,
                          onPressed: () => _pair(payload),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      AppButton(
                        label: l.cancel,
                        emphasis: ActionEmphasis.quiet,
                        onPressed: _busy ? null : () => setState(() => _payload = null),
                      ),
                    ]),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// The camera, looking for the desktop's `skidsense://` QR code. Pops with
/// the first one it reads.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;
  bool _wrongCode = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      if (value.startsWith('skidsense://')) {
        _done = true;
        Navigator.of(context).pop(value);
        return;
      }
      if (!_wrongCode) setState(() => _wrongCode = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FixedPage(
      title: l.scanQr,
      actions: [
        IconButton(
          tooltip: l.scannerTorch,
          icon: const Icon(Icons.flashlight_on_outlined),
          onPressed: () => unawaited(_controller.toggleTorch()),
        ),
      ],
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: InlineBanner(message: l.cameraUnavailable),
            ),
          ),
        ),
        // The viewfinder.
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(context.design.expressive ? 36 : 20),
            ),
          ),
        ),
        Positioned(
          left: Gap.xl,
          right: Gap.xl,
          bottom: Gap.xxl,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_wrongCode) InlineBanner(message: l.notAPairingCode, tone: BannerTone.warning),
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(100)),
              child: Text(l.scannerPrompt, style: context.text.bodyMedium?.copyWith(color: Colors.white)),
            ),
          ]),
        ),
      ]),
    );
  }
}
