import 'dart:async';
import 'dart:io';

import 'package:skidsense_core/skidsense_core.dart';

import '../../state/appearance.dart';
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
import 'account_screen.dart';
import 'gallery_screen.dart';

/// Account, appearance (the design style lives here), security, this
/// computer's devices and their permissions.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    if (context.app.state.activeHost != null) unawaited(context.app.loadDevices());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final services = context.services;
    final app = services.controller;
    return ValueListenableBuilder(
      valueListenable: services.appearance,
      builder: (context, appearance, _) => Watch(app.states, builder: (context, state) {
        void update(Appearance next) => unawaited(services.appearance.update(next));
        // What the backend does not know it never grants (spec §9).
        final known = Scopes.known(state.serverScopes);
        return AppPage(
          title: l.settingsTitle,
          slivers: [
            // --- appearance -----------------------------------------------------
            SliverToBoxAdapter(child: SectionHeader(l.appearance)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: Row(children: [
                  Expanded(
                    child: _StylePreview(
                      style: DesignStyle.material3,
                      title: l.styleM3,
                      hint: l.styleM3Hint,
                      selected: appearance.style == DesignStyle.material3,
                      onTap: () => update(appearance.copyWith(style: DesignStyle.material3)),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: _StylePreview(
                      style: DesignStyle.expressive,
                      title: l.styleM3E,
                      hint: l.styleM3EHint,
                      selected: appearance.style == DesignStyle.expressive,
                      onTap: () => update(appearance.copyWith(style: DesignStyle.expressive)),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.themeMode, style: context.text.labelLarge),
                  const SizedBox(height: Gap.sm),
                  ChoiceGroup<ThemeMode>(
                    items: [
                      GroupItem(value: ThemeMode.system, label: l.themeSystem, icon: Icons.brightness_auto_outlined),
                      GroupItem(value: ThemeMode.light, label: l.themeLight, icon: Icons.light_mode_outlined),
                      GroupItem(value: ThemeMode.dark, label: l.themeDark, icon: Icons.dark_mode_outlined),
                    ],
                    selected: appearance.mode,
                    onSelected: (mode) => update(appearance.copyWith(mode: mode)),
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(l.seedColor, style: context.text.labelLarge),
                  const SizedBox(height: Gap.sm),
                  Wrap(spacing: Gap.md, runSpacing: Gap.sm, children: [
                    for (final (index, seed) in seedChoices.indexed)
                      _Swatch(
                        color: seed,
                        label: l.seedColorOption(index + 1),
                        selected: appearance.seed == seed && !(appearance.dynamicColor && Platform.isAndroid),
                        onTap: () => update(appearance.copyWith(seed: seed, dynamicColor: false)),
                      ),
                  ]),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.md),
                child: GroupedList(children: [
                  if (Platform.isAndroid)
                    SwitchListTile(
                      title: Text(l.dynamicColor),
                      subtitle: Text(l.dynamicColorHint),
                      value: appearance.dynamicColor,
                      onChanged: (value) => update(appearance.copyWith(dynamicColor: value)),
                    ),
                  _MenuTile<DynamicSchemeVariant>(
                    title: l.colorVariant,
                    value: appearance.variant,
                    onSelected: (value) => update(appearance.copyWith(variant: value)),
                    options: {
                      DynamicSchemeVariant.tonalSpot: l.variantTonalSpot,
                      DynamicSchemeVariant.vibrant: l.variantVibrant,
                      DynamicSchemeVariant.expressive: l.variantExpressive,
                      DynamicSchemeVariant.fidelity: l.variantFidelity,
                      DynamicSchemeVariant.neutral: l.variantNeutral,
                    },
                  ),
                  _MenuTile<AppContrast>(
                    title: l.contrast,
                    value: appearance.contrast,
                    onSelected: (value) => update(appearance.copyWith(contrast: value)),
                    options: {
                      AppContrast.standard: l.contrastStandard,
                      AppContrast.medium: l.contrastMedium,
                      AppContrast.high: l.contrastHigh,
                    },
                  ),
                  _MenuTile<AppLanguage>(
                    title: l.language,
                    value: appearance.language,
                    onSelected: (value) => update(appearance.copyWith(language: value)),
                    // Each language in its own name, so it can be found
                    // whatever the app speaks now.
                    options: {
                      AppLanguage.system: l.languageSystem,
                      AppLanguage.simplifiedChinese: l.languageZhHans,
                      AppLanguage.traditionalChinese: l.languageZhHant,
                      AppLanguage.english: l.languageEn,
                    },
                  ),
                ]),
              ),
            ),

            // --- account ----------------------------------------------------------
            SliverToBoxAdapter(child: SectionHeader(l.account)),
            SliverToBoxAdapter(
              child: GroupedList(children: [
                // The balance, the groups and signing out are a page of their own.
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(state.user ?? l.none),
                  subtitle: Text(state.baseUrl),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
                ),
              ]),
            ),

            // --- security ---------------------------------------------------------
            SliverToBoxAdapter(child: SectionHeader(l.security, hint: l.keyProtected)),
            SliverToBoxAdapter(
              child: GroupedList(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: Text(l.biometricLock),
                  subtitle: Text(l.biometricLockHint),
                  value: state.biometricLock,
                  onChanged: (value) => unawaited(app.setBiometricLock(value)),
                ),
              ]),
            ),

            // --- this computer's devices ------------------------------------------------
            SliverToBoxAdapter(
              child: SectionHeader(
                state.activeHost == null ? l.permissions : l.devicesOnHost(state.activeHost!.displayName),
              ),
            ),
            if (state.activeHost == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: InlineBanner(message: l.devicesConnectFirst, tone: BannerTone.info),
                ),
              )
            else ...[
              if (state.welcome != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.effectiveScopes, style: context.text.bodySmall),
                      const SizedBox(height: Gap.sm),
                      Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
                        for (final scope in Scopes.all)
                          if (known.contains(scope) || state.canScope(scope))
                            FilterChip(
                              label: Text(l.scope(scope)),
                              selected: state.canScope(scope),
                              onSelected: null,
                            ),
                      ]),
                      if (!state.canScope(Scopes.terminal))
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(l.terminalScopeNote, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                        ),
                      // As much as the terminal, and said as plainly (spec §8.5).
                      if (state.canScope(Scopes.settings) || known.contains(Scopes.settings))
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(
                            state.canScope(Scopes.settings) ? l.settingsScopeWarning : l.settingsScopeNote,
                            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ),
                    ]),
                  ),
                ),
              SliverToBoxAdapter(
                child: GroupedList(children: [
                  for (final device in state.devices) _DeviceTile(device: device, thisDevice: device.deviceId == state.activeHost?.deviceId),
                ]),
              ),
            ],

            // --- about --------------------------------------------------------------------
            SliverToBoxAdapter(child: SectionHeader(l.about)),
            SliverToBoxAdapter(
              child: GroupedList(children: [
                ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l.appName), subtitle: Text(l.version(services.device.appVersion))),
                ListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: Text(l.componentGallery),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GalleryScreen())),
                ),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

/// A setting with a few values: the current one as supporting text, the
/// others in a menu.
class _MenuTile<T> extends StatelessWidget {
  const _MenuTile({required this.title, required this.value, required this.options, required this.onSelected});

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        alignmentOffset: const Offset(Gap.lg, 0),
        menuChildren: [
          for (final MapEntry(key: option, value: label) in options.entries)
            MenuItemButton(
              leadingIcon: Icon(option == value ? Icons.check_rounded : null),
              onPressed: () => onSelected(option),
              child: Text(label),
            ),
        ],
        builder: (context, controller, _) => ListTile(
          title: Text(title),
          subtitle: Text(options[value] ?? ''),
          trailing: const Icon(Icons.unfold_more_rounded),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
        ),
      );
}

/// A design style, shown as itself: each card is drawn in the theme it names.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style, required this.title, required this.hint, required this.selected, required this.onTap});

  final DesignStyle style;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expressive = style == DesignStyle.expressive;
    final radius = expressive ? 28.0 : 12.0;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // A miniature of the style: its shapes and its weight.
            SizedBox(
              height: 64,
              child: Stack(children: [
                Positioned(
                  left: 0,
                  top: 0,
                  right: 24,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(expressive ? 13 : 13)),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 30,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(color: colors.tertiaryContainer, borderRadius: BorderRadius.circular(expressive ? 10 : 15)),
                  ),
                ),
                Positioned(
                  left: 38,
                  bottom: 0,
                  right: 0,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(expressive ? 16 : 4)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Gap.md),
            Text(title, style: context.text.titleSmall?.copyWith(fontWeight: expressive ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 2),
            Text(hint, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label, required this.selected, required this.onTap});

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final expressive = context.design.expressive;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.design.motion.spatialFast.duration,
          curve: context.design.motion.spatialFast.curve,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(selected && expressive ? 16 : 24),
            border: Border.all(color: selected ? context.colors.onSurface : Colors.transparent, width: 3),
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.thisDevice});

  final DeviceRow device;
  final bool thisDevice;

  Future<void> _rename(BuildContext context) async {
    final l = context.l10n;
    final name = await promptText(context, title: l.rename, label: l.name, action: l.save, initial: device.name);
    if (name == null || !context.mounted) return;
    try {
      await context.app.renameDevice(device.deviceId, name);
    } catch (error) {
      if (context.mounted) showMessage(context, l.error(error));
    }
  }

  Future<void> _permissions(BuildContext context) async {
    await showAppSheet<void>(context, builder: (_) => _ScopesSheet(device: device));
  }

  Future<void> _revoke(BuildContext context) async {
    final l = context.l10n;
    final ok = await confirm(context, title: l.revokeTitle(device.name), body: l.revokeBody, action: l.revoke, destructive: true);
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    try {
      await context.app.revokeDevice(device.deviceId);
      if (thisDevice) navigator.popUntil((route) => route.isFirst);
    } catch (error) {
      if (context.mounted) showMessage(context, l.error(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = switch (device.status) {
      'pending' => l.deviceStatusPending,
      'active' => l.deviceStatusActive,
      'revoked' => l.deviceStatusRevoked,
      _ => device.status,
    };
    final lastSeen = device.lastSeenAt;
    return ListTile(
      leading: Icon(device.platform == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded),
      title: Row(children: [
        Flexible(child: Text(device.name.isEmpty ? device.deviceId : device.name, overflow: TextOverflow.ellipsis)),
        if (thisDevice) ...[const SizedBox(width: Gap.sm), StatusBadge(l.thisDevice, tone: StatusTone.done)],
      ]),
      subtitle: Text([
        status,
        if (lastSeen != null && lastSeen > 0) l.lastSeen(l.ago(DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000))),
        device.scopes.isEmpty ? l.noScopes : device.scopes.map(l.scope).join(', '),
      ].join(' · ')),
      isThreeLine: true,
      trailing: device.status == 'revoked'
          ? null
          : PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (action) => switch (action) {
                'rename' => _rename(context),
                'permissions' => _permissions(context),
                _ => _revoke(context),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l.rename)),
                PopupMenuItem(value: 'permissions', child: Text(l.permissions)),
                PopupMenuItem(value: 'revoke', child: Text(l.revoke, style: TextStyle(color: context.colors.error))),
              ],
            ),
    );
  }
}

class _ScopesSheet extends StatefulWidget {
  const _ScopesSheet({required this.device});

  final DeviceRow device;

  @override
  State<_ScopesSheet> createState() => _ScopesSheetState();
}

class _ScopesSheetState extends State<_ScopesSheet> {
  late final Set<String> _scopes = {...widget.device.scopes};
  bool _busy = false;
  Object? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The device's own scopes with the switches applied: one this build has
      // no switch for stays the device's (spec §8.5).
      await context.app.setDeviceScopes(widget.device.deviceId, [
        for (final scope in Scopes.all) if (_scopes.contains(scope)) scope,
        for (final scope in widget.device.scopes) if (!Scopes.isScope(scope)) scope,
      ]);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final known = Scopes.known(context.app.state.serverScopes);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(l.permissions, subtitle: l.serverScopesNote),
        // A switch for what the backend knows, and for what the device holds.
        for (final scope in Scopes.all)
          if (known.contains(scope) || widget.device.scopes.contains(scope))
            CheckboxListTile(
              title: Text(l.scope(scope)),
              subtitle: scope == Scopes.settings ? Text(l.settingsScopeLocked) : null,
              value: _scopes.contains(scope),
              // Opened on the computer alone (spec §8.5): here it can only be
              // closed — the server half widened would only mislead.
              onChanged: scope == Scopes.settings && !widget.device.scopes.contains(scope)
                  ? null
                  : (value) => setState(() => value == true ? _scopes.add(scope) : _scopes.remove(scope)),
            ),
        if (_error != null) Padding(padding: const EdgeInsets.all(Gap.lg), child: InlineBanner(message: l.error(_error))),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, 0),
          child: AppButton(label: l.savePermissions, busy: _busy, expand: true, onPressed: _save),
        ),
      ]),
    );
  }
}
