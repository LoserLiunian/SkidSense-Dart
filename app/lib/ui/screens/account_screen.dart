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

/// The phone's own sign-in, the desktop's 账号管理 without top-up: who is
/// signed in and where, the balance and what has been spent, the groups a
/// key may go in — read from the backend with this phone's login, no
/// computer needed — and signing out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AppController _app = context.app;

  /// The last good reads: a failed refresh keeps them on screen.
  UserInfo? _user;
  List<TokenGroup>? _groups;

  /// Why the last read of each failed; it stays up while the retry runs.
  /// Each is said for what it is: the groups failing alone leaves the
  /// account read.
  Object? _userError;
  Object? _groupsError;

  /// The first read starts with the page.
  bool _busy = true;
  Future<void>? _reading;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// One read at a time: a pull while the retry runs waits for that one.
  Future<void> _load() => _reading ??= _read().whenComplete(() => _reading = null);

  Future<void> _read() async {
    if (!_busy) setState(() => _busy = true);
    // Both asked at once; the groups failing leaves the balance standing.
    final self = _settle(_app.backend.self());
    final groups = _settle(_app.backend.tokenGroups());
    final (user, userError) = await self;
    final (list, groupsError) = await groups;
    if (!mounted) return;
    setState(() {
      _user = user ?? _user;
      _groups = list ?? _groups;
      _userError = userError;
      _groupsError = groupsError;
      _busy = false;
    });
  }

  static Future<(T?, Object?)> _settle<T>(Future<T> read) async {
    try {
      return (await read, null);
    } catch (error) {
      return (null, error);
    }
  }

  Future<void> _signOut() async {
    final l = context.l10n;
    final ok = await confirm(context, title: l.signOutTitle, body: l.signOutBody, action: l.signOut, destructive: true);
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    await _app.logout();
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Watch(_app.states, builder: (context, state) {
      final user = _user;
      final error = _userError;
      // The same failure twice (no network) is said once, at the top.
      final groupsError = error == null ? _groupsError : null;
      final busy = _busy;
      return AppPage(
        title: l.account,
        onRefresh: _load,
        maxContentWidth: AppPage.readableWidth,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              // Who and where come with the sign-in: shown offline too.
              child: _IdentityCard(
                username: user != null && user.username.isNotEmpty ? user.username : state.user ?? '',
                displayName: user?.displayName,
                userId: user?.id ?? state.userId,
                server: state.baseUrl,
              ),
            ),
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 0),
                child: _ReadFailed(error: error, busy: busy, onRetry: _load),
              ),
            ),
          // Never read: the figures are not guessed at, nor shown empty.
          if (user == null && busy) ...[
            SliverToBoxAdapter(child: SectionHeader(l.accountQuota, hint: l.accountQuotaHint)),
            SliverToBoxAdapter(child: LoadingRow(l.accountLoading)),
          ],
          if (user != null) ...[
            SliverToBoxAdapter(child: SectionHeader(l.accountQuota, hint: l.accountQuotaHint)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: _Figures(balance: usdLabel(user.quotaUsd), used: usdLabel(user.usedQuotaUsd)),
              ),
            ),
            SliverToBoxAdapter(child: SectionHeader(l.accountGroups, hint: l.accountGroupsHint)),
            if (groupsError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                  child: _ReadFailed(error: groupsError, busy: busy, onRetry: _load, title: l.accountGroupsLoadFailed),
                ),
              ),
            SliverToBoxAdapter(child: _Groups(mine: user.group, groups: _groups ?? const [])),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Gap.xl),
              child: GroupedList(children: [
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: context.colors.error),
                  title: Text(l.signOut, style: TextStyle(color: context.colors.error)),
                  subtitle: Text(l.reloginNote),
                  onTap: _signOut,
                ),
              ]),
            ),
          ),
        ],
      );
    });
  }
}

/// Who is signed in, the way a paired computer's card shows a computer.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.username, required this.displayName, required this.userId, required this.server});

  final String username;
  final String? displayName;
  final int userId;
  final String server;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final design = context.design;
    final name = displayName?.trim() ?? '';
    final initial = username.isEmpty ? '?' : String.fromCharCode(username.runes.first).toUpperCase();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: colors.primaryContainer,
                shape: design.expressive
                    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(design.shapes.large))
                    : const CircleBorder(),
              ),
              // A monogram in a box of fixed size: it does not grow with the text.
              child: Text(
                initial,
                textScaler: TextScaler.noScaling,
                style: context.text.titleMedium?.copyWith(color: colors.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // The badge beside the name, under it when the two do not fit.
              Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(username.isEmpty ? l.none : username, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                StatusBadge(l.accountSignedIn, tone: StatusTone.done),
              ]),
              if (name.isNotEmpty && name != username)
                Text(name, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: Gap.md),
        KeyValueRow(l.accountUserId, userId > 0 ? '$userId' : l.none),
        KeyValueRow(l.serverAddress, server.isEmpty ? l.none : server),
      ]),
    );
  }
}

/// The balance and what has been spent, side by side — one over the other
/// where the two figures do not fit beside each other (large text).
class _Figures extends StatelessWidget {
  const _Figures({required this.balance, required this.used});

  final String balance;
  final String used;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = _Figure.valueStyle(context);
    return LayoutBuilder(builder: (context, constraints) {
      final first = _Figure(label: l.accountBalance, value: balance, emphasized: true);
      final second = _Figure(label: l.accountUsed, value: used);
      // Each figure on one line, inside its card's padding.
      final room = (constraints.maxWidth - Gap.md) / 2 - Gap.lg * 2;
      final scaler = MediaQuery.textScalerOf(context);
      final fits = [balance, used].every((value) {
        final painter = TextPainter(text: TextSpan(text: value, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
          ..layout();
        final width = painter.width;
        painter.dispose();
        return width <= room;
      });
      if (!fits) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, const SizedBox(height: Gap.md), second]);
      }
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: first),
          const SizedBox(width: Gap.md),
          Expanded(child: second),
        ]),
      );
    });
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.emphasized = false});

  final String label;
  final String value;

  /// The balance: the figure the page is for.
  final bool emphasized;

  /// Figures in columns of equal width, so they line up.
  static TextStyle? valueStyle(BuildContext context) =>
      context.text.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: AppCard(
        tone: emphasized ? colors.primaryContainer : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.text.labelLarge?.copyWith(color: emphasized ? colors.onPrimaryContainer : colors.onSurfaceVariant)),
          const SizedBox(height: Gap.xs),
          Text(value, style: valueStyle(context)?.copyWith(color: emphasized ? colors.onPrimaryContainer : colors.onSurface)),
        ]),
      ),
    );
  }
}

/// The groups a key may go in, the account's own first: what each is for
/// and what it multiplies a call's price by.
class _Groups extends StatelessWidget {
  const _Groups({required this.mine, required this.groups});

  final String mine;
  final List<TokenGroup> groups;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final own = groups.where((group) => group.name == mine).firstOrNull;
    final rows = [
      // The account's group, from its own record when the list lacks it.
      if (own != null) own else if (mine.isNotEmpty) TokenGroup(name: mine),
      for (final group in groups) if (group.name != mine) group,
    ];
    return GroupedList(children: [
      for (final group in rows)
        ListTile(
          title: Wrap(spacing: Gap.sm, runSpacing: Gap.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(group.name),
            if (group.name == mine) StatusBadge(l.accountGroupYours, tone: StatusTone.done),
          ]),
          subtitle: group.desc.isEmpty || group.desc.toLowerCase() == group.name.toLowerCase() ? null : Text(group.desc),
          trailing: group.ratio == null && group.ratioLabel == null
              ? null
              : Semantics(
                  label: l.accountGroupRatio(l.groupRatio(group)),
                  child: ExcludeSemantics(
                    child: Text(
                      l.groupRatio(group),
                      style: context.text.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
        ),
    ]);
  }
}

/// A read that failed: the backend out of reach (no network, or the server
/// down) said as such, anything else in its own words — with a retry.
class _ReadFailed extends StatelessWidget {
  const _ReadFailed({required this.error, required this.busy, required this.onRetry, this.title});

  final Object error;
  final bool busy;
  final VoidCallback onRetry;

  /// What was not read; the account by default.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final offline = error is BackendException && (error as BackendException).code == 'unreachable';
    return InlineBanner(
      tone: offline ? BannerTone.info : BannerTone.error,
      icon: offline ? Icons.cloud_off_rounded : null,
      title: offline ? l.accountOffline : title ?? l.accountLoadFailed,
      message: offline ? l.accountOfflineBody : l.error(error),
      action: AppButton(label: l.retry, emphasis: ActionEmphasis.tonal, busy: busy, onPressed: onRetry),
    );
  }
}
