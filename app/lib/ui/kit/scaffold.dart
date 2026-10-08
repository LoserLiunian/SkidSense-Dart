import '../layout/window.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// A screen whose content scrolls under a collapsing top app bar.
///
/// M3: the medium top app bar. M3 Expressive: the large flexible one, with
/// the emphasized headline and a subtitle line under it (where the
/// connection status lives).
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.floatingActionButton,
    this.bottom,
    this.onRefresh,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  /// Pinned under the content (a composer).
  final Widget? bottom;

  /// Pull to refresh.
  final Future<void> Function()? onRefresh;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final expressive = context.design.expressive;
    final colors = context.colors;
    final Widget appBar;
    // The collapsed title sits after the back button when there is one.
    final inset = leading != null || (automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false));
    final flexible = _FlexibleTitle(
      title: title,
      subtitle: subtitle,
      inset: inset,
      // M3 Expressive: the large bar's bigger, emphasized headline; M3: the
      // medium bar's.
      headline: expressive ? context.text.headlineMedium : context.text.headlineSmall,
    );
    if (expressive) {
      appBar = SliverAppBar.large(
        // The title inside marks itself as the header; the whole bar would
        // be one oversized node.
        excludeHeaderSemantics: true,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: [...actions, const SizedBox(width: Gap.xs)],
        expandedHeight: subtitle == null ? 152 : 176,
        flexibleSpace: flexible,
        backgroundColor: colors.surface,
      );
    } else {
      appBar = SliverAppBar(
        pinned: true,
        excludeHeaderSemantics: true,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        expandedHeight: subtitle == null ? 112 : 136,
        flexibleSpace: flexible,
      );
    }
    Widget scroll = CustomScrollView(slivers: [
      appBar,
      ...slivers,
      SliverPadding(padding: EdgeInsets.only(bottom: floatingActionButton == null ? Gap.xl : 96)),
    ]);
    if (onRefresh != null) scroll = RefreshIndicator(onRefresh: onRefresh!, edgeOffset: 120, child: scroll);
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: bottom == null ? scroll : Column(children: [Expanded(child: scroll), bottom!]),
    );
  }
}

class _FlexibleTitle extends StatelessWidget {
  const _FlexibleTitle({required this.title, this.subtitle, required this.inset, required this.headline});

  final String title;
  final Widget? subtitle;
  final bool inset;
  final TextStyle? headline;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final range = settings == null ? 1.0 : (settings.maxExtent - settings.minExtent);
    final t = settings == null || range <= 0 ? 0.0 : ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
    final colors = context.colors;
    final big = headline?.copyWith(color: colors.onSurface);
    final small = context.text.titleLarge?.copyWith(color: colors.onSurface);
    return SafeArea(
      bottom: false,
      child: Stack(children: [
        // Collapsed: the title in the bar itself, next to the back button.
        Positioned(
          left: inset ? 72 : Gap.lg,
          right: 96,
          top: 0,
          height: kToolbarHeight,
          // Only the visible one of the two titles is read out.
          child: ExcludeSemantics(
            excluding: t >= 0.5,
            child: Opacity(
              opacity: (1 - t * 3).clamp(0.0, 1.0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(header: true, child: Text(title, style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ),
            ),
          ),
        ),
        // Expanded: the headline, and the subtitle under it.
        Positioned(
          left: Gap.lg,
          right: Gap.lg,
          bottom: Gap.lg,
          child: Opacity(
            opacity: t,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(
                excluding: t < 0.5,
                child: Semantics(header: true, child: Text(title, style: big, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Gap.xs),
                DefaultTextStyle.merge(
                  style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  child: subtitle!,
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A screen with a fixed body (a transcript, a terminal), whose top bar does
/// not collapse.
class FixedPage extends StatelessWidget {
  const FixedPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;
  final Widget? bottom;
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expressive = context.design.expressive;
    return Scaffold(
      appBar: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        toolbarHeight: subtitle == null ? kToolbarHeight : 64,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null)
            DefaultTextStyle.merge(
              style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              child: subtitle!,
            ),
        ]),
        titleTextStyle: (expressive ? context.text.titleLarge : context.text.titleLarge)?.copyWith(color: colors.onSurface),
      ),
      body: bottom == null ? body : Column(children: [Expanded(child: body), bottom!]),
    );
  }
}

class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Top-level destinations, where the window puts them: a navigation bar at
/// the bottom of a phone, a rail down the side of anything wider.
class AdaptiveNavigation extends StatelessWidget {
  const AdaptiveNavigation({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.body,
    this.railLeading,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget body;
  final Widget? railLeading;

  @override
  Widget build(BuildContext context) {
    final window = WindowClass.of(context);
    if (window.isCompact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: onSelected,
          destinations: [
            for (final item in items)
              NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(children: [
        SafeArea(
          right: false,
          child: NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: onSelected,
            leading: railLeading,
            groupAlignment: context.design.expressive ? -0.6 : -1,
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}
