import 'dart:async';

import 'package:skidsense_core/skidsense_core.dart';

import '../../state/scope.dart';
import '../../state/watch.dart';
import '../describe.dart';
import '../kit/actions.dart';
import '../kit/containers.dart';
import '../kit/dialogs.dart';
import '../kit/feedback.dart';
import '../kit/scaffold.dart';
import '../material.dart';
import '../theme/tokens.dart';
import 'host_shell.dart';
import 'pairing_screen.dart';
import 'settings_screen.dart';

/// "Computers": the desktops this phone has paired with, and the others the
/// account has registered (`GET /hosts`). Only a paired host can be
/// connected to — the pin from the QR code is what makes it trustworthy.
class HostsScreen extends StatefulWidget {
  const HostsScreen({super.key});

  @override
  State<HostsScreen> createState() => _HostsScreenState();
}

class _HostsScreenState extends State<HostsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.app.refreshHosts());
  }

  Future<void> _open(PairedHost host) async {
    final app = context.app;
    await app.connect(host.hostId);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HostShell()));
    // Back from the host: let it go.
    app.disconnect();
  }

  void _pair() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PairingScreen()));

  Future<void> _forget(PairedHost host) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.forgetTitle(host.displayName),
      body: l.forgetBody,
      action: l.forgetAction,
      destructive: true,
    );
    if (ok && mounted) await context.app.forgetHost(host.hostId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = context.app;
    return Watch(app.states, builder: (context, state) {
      final pairedIds = {for (final host in state.paired) host.hostId};
      final others = [for (final row in state.hosts) if (!pairedIds.contains(row.hostId)) row];
      final notice = state.notice;
      final hostsError = state.hostsError;
      return AppPage(
        title: l.hostsTitle,
        automaticallyImplyLeading: false,
        subtitle: Text(l.signedInAs(state.user ?? '', state.baseUrl), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
        onRefresh: app.refreshHosts,
        floatingActionButton: AppFab(actions: [
          FabAction(icon: Icons.qr_code_scanner_rounded, label: l.pairComputer, onPressed: _pair),
        ]),
        slivers: [
          if (notice != null || hostsError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                child: InlineBanner(
                  message: notice != null ? l.notice(notice) : l.error(hostsError),
                  tone: notice?.kind == NoticeKind.forgetUnrevoked ? BannerTone.warning : BannerTone.error,
                  onDismiss: app.clearNotice,
                ),
              ),
            ),
          if (state.hostsLoading && state.hosts.isEmpty && state.paired.isEmpty)
            SliverToBoxAdapter(child: LoadingRow(l.loadingHosts)),
          if (state.paired.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.pairedSection, hint: l.pairedSectionHint)),
            SliverList.separated(
              itemCount: state.paired.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
              itemBuilder: (context, index) {
                final host = state.paired[index];
                final row = state.hostRow(host.hostId);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: _PairedHostCard(
                    host: host,
                    presence: l.presence(row?.online, row?.lanAddrs ?? host.lanAddrs),
                    online: row?.online,
                    onOpen: () => _open(host),
                    onForget: () => _forget(host),
                  ),
                );
              },
            ),
          ],
          if (others.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.otherHostsSection, hint: l.otherHostsHint)),
            SliverToBoxAdapter(
              child: GroupedList(children: [
                for (final row in others)
                  ListTile(
                    leading: const Icon(Icons.computer_rounded),
                    title: Text(row.name.isEmpty ? row.hostId : row.name),
                    subtitle: Text([row.platform, row.appVersion, l.hostNeedsQr].where((part) => part.isNotEmpty).join(' · ')),
                    trailing: StatusBadge(
                      l.presence(row.online, row.lanAddrs) ?? '',
                      tone: row.online ? StatusTone.done : StatusTone.neutral,
                    ),
                  ),
              ]),
            ),
          ],
          if (state.paired.isEmpty && state.hosts.isEmpty && !state.hostsLoading)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.computer_rounded,
                title: l.noComputersTitle,
                body: l.noComputersBody,
                action: AppButton(label: l.pairComputer, icon: Icons.qr_code_scanner_rounded, onPressed: _pair),
              ),
            ),
        ],
      );
    });
  }
}

class _PairedHostCard extends StatelessWidget {
  const _PairedHostCard({
    required this.host,
    required this.presence,
    required this.online,
    required this.onOpen,
    required this.onForget,
  });

  final PairedHost host;
  final String? presence;
  final bool? online;
  final VoidCallback onOpen;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final expressive = context.design.expressive;
    return AppCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: online == true ? colors.primaryContainer : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(expressive ? 14 : 22),
            ),
            child: Icon(Icons.laptop_mac_rounded, color: online == true ? colors.onPrimaryContainer : colors.onSurfaceVariant),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(host.displayName, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (host.machine.isNotEmpty && host.machine != host.displayName)
                Text(host.machine, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ]),
          ),
          if (presence != null)
            Tooltip(
              message: online == false && host.lanAddrs.isNotEmpty ? l.presenceRelayOfflineHint : presence!,
              child: StatusBadge(presence!, tone: online == true ? StatusTone.done : StatusTone.neutral),
            ),
        ]),
        const SizedBox(height: Gap.md),
        KeyValueRow(l.fingerprint, host.fingerprint.isEmpty ? l.none : host.fingerprint, mono: true),
        KeyValueRow(l.lanAddresses, host.lanAddrs.isEmpty ? l.none : host.lanAddrs.join(', '), mono: true),
        const SizedBox(height: Gap.md),
        Row(children: [
          AppButton(label: l.connect, icon: Icons.power_rounded, onPressed: onOpen),
          const Spacer(),
          AppButton(label: l.forget, emphasis: ActionEmphasis.quiet, destructive: true, onPressed: onForget),
        ]),
      ]),
    );
  }
}
