import 'dart:async';

import '../../state/scope.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// Every kit component in the current style, with a switch to flip the
/// style in place: the place to compare Material 3 and Material 3 Expressive
/// side by side.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String? _choice = 'b';
  double _progress = 0.35;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final appearance = context.services.appearance;
    return ValueListenableBuilder(
      valueListenable: appearance,
      builder: (context, value, _) => AppPage(
        title: l.componentGallery,
        subtitle: Text(value.style == DesignStyle.expressive ? l.styleM3E : l.styleM3),
        actions: [
          Tooltip(
            message: l.styleM3E,
            child: Switch(
              value: value.style == DesignStyle.expressive,
              onChanged: (on) => unawaited(appearance.update(value.copyWith(style: on ? DesignStyle.expressive : DesignStyle.material3))),
            ),
          ),
          const SizedBox(width: Gap.sm),
        ],
        floatingActionButton: AppFab(actions: [
          FabAction(icon: Icons.add_rounded, label: l.newSession, onPressed: () {}),
          FabAction(icon: Icons.qr_code_scanner_rounded, label: l.pairComputer, onPressed: () {}),
        ]),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            sliver: SliverList.list(children: [
              const _Label('Buttons'),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                AppButton(label: l.send, icon: Icons.send_rounded, onPressed: () {}),
                AppButton(label: l.connect, emphasis: ActionEmphasis.tonal, onPressed: () {}),
                AppButton(label: l.readLink, emphasis: ActionEmphasis.outlined, onPressed: () {}),
                AppButton(label: l.skip, emphasis: ActionEmphasis.quiet, onPressed: () {}),
                AppButton(label: l.forget, emphasis: ActionEmphasis.outlined, destructive: true, onPressed: () {}),
                AppButton(label: l.signIn, busy: true, onPressed: () {}),
              ]),
              const SizedBox(height: Gap.md),
              AppButton(label: l.pairComputer, icon: Icons.qr_code_scanner_rounded, large: true, expand: true, onPressed: () {}),
              const _Label('Action group'),
              ActionGroup(items: [
                GroupItem(label: l.fetch, icon: Icons.cloud_sync_outlined, onPressed: () {}),
                GroupItem(label: l.pull, icon: Icons.download_rounded, onPressed: () {}),
                GroupItem(label: l.push, icon: Icons.upload_rounded, onPressed: () {}),
              ]),
              const _Label('Choice group'),
              ChoiceGroup<String>(
                items: [
                  GroupItem(value: 'a', label: l.effortLow),
                  GroupItem(value: 'b', label: l.effortMedium),
                  GroupItem(value: 'c', label: l.effortHigh),
                ],
                selected: _choice,
                onSelected: (value) => setState(() => _choice = value),
              ),
              const _Label('Send'),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SendButton(
                  label: l.send,
                  onSend: () {},
                  menu: [
                    SendMenuItem(value: 'attach', label: l.attach, icon: Icons.attach_file_rounded),
                    SendMenuItem(value: 'options', label: l.options, icon: Icons.tune_rounded),
                  ],
                  onMenu: (_) {},
                ),
              ),
              const _Label('Progress'),
              const Row(children: [BusyIndicator(), SizedBox(width: Gap.lg), BusyIndicator(contained: true), SizedBox(width: Gap.lg), InlineBusy()]),
              const SizedBox(height: Gap.md),
              ProgressBar(value: _progress),
              Slider(value: _progress, onChanged: (value) => setState(() => _progress = value)),
              const ProgressBar(),
              const _Label('Status'),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                StatusBadge(l.runStateRunning, tone: StatusTone.running),
                StatusBadge(l.runStateAwaiting, tone: StatusTone.waiting),
                StatusBadge(l.runStateDone, tone: StatusTone.done),
                StatusBadge(l.runStateError, tone: StatusTone.failed),
                StatusBadge(l.presenceOffline, tone: StatusTone.neutral),
              ]),
              const _Label('Banners'),
              InlineBanner(message: l.offlineBody, title: l.offlineTitle, tone: BannerTone.info, onDismiss: () {}),
              const SizedBox(height: Gap.sm),
              InlineBanner(message: l.terminalWarningBody, title: l.terminalWarningTitle, tone: BannerTone.warning),
              const SizedBox(height: Gap.sm),
              InlineBanner(message: l.hsrUnknownDevice, onDismiss: () {}),
              const _Label('Card'),
              AppCard(
                onTap: () {},
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('书房的 Mac', style: context.text.titleMedium),
                  const SizedBox(height: Gap.sm),
                  KeyValueRow(l.fingerprint, 'D511-0BBB-BA1D-667B', mono: true),
                  KeyValueRow(l.lanAddresses, '192.168.1.20', mono: true),
                ]),
              ),
              const _Label('Code'),
              const MonoBlock('git push origin main\n# working tree clean'),
              const _Label('Empty state'),
              EmptyState(icon: Icons.forum_outlined, title: l.noSessionsTitle, body: l.noSessionsBody),
            ]),
          ),
          const SliverToBoxAdapter(child: _Label('Grouped list', padded: true)),
          SliverToBoxAdapter(
            child: GroupedList(children: [
              ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('Refactor the parser'), subtitle: Text(l.runStateRunning)),
              ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('修复登录页'), subtitle: Text(l.runStateDone)),
              ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('寫測試'), subtitle: Text(l.runStateIdle)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.padded = false});

  final String text;
  final bool padded;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(padded ? Gap.lg : 0, Gap.xl, padded ? Gap.lg : 0, Gap.sm),
        child: Text(text, style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
      );
}
