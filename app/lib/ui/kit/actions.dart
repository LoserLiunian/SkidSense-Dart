import 'package:material_3_expressive/material_3_expressive.dart';

import '../material.dart';
import '../theme/tokens.dart';
import 'feedback.dart';

enum ActionEmphasis {
  /// The one thing the screen is for.
  primary,

  /// Next to a primary action, or the main action of a card.
  tonal,

  /// Alternative actions.
  outlined,

  /// The least prominent.
  quiet,
}

/// A labelled button. M3 Expressive's buttons squish on press and come in
/// a medium size for the main action of a screen.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.emphasis = ActionEmphasis.primary,
    this.busy = false,
    this.large = false,
    this.destructive = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ActionEmphasis emphasis;

  /// Shows a spinner in place of the icon and ignores presses.
  final bool busy;

  /// The screen's main action, a size up.
  final bool large;
  final bool destructive;

  /// Fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final onPress = busy ? null : onPressed;
    final colors = context.colors;
    final leading = busy ? const InlineBusy(size: 18) : (icon == null ? null : Icon(icon));
    Widget button;
    if (context.design.expressive) {
      final style = switch (emphasis) {
        ActionEmphasis.primary => M3EButtonStyle.filled,
        ActionEmphasis.tonal => M3EButtonStyle.tonal,
        ActionEmphasis.outlined => M3EButtonStyle.outlined,
        ActionEmphasis.quiet => M3EButtonStyle.text,
      };
      button = M3EButton(
        onPressed: onPress,
        enabled: onPress != null,
        style: style,
        size: large ? M3EButtonSize.md : M3EButtonSize.sm,
        // Without a selection state the button draws `icon` + `label` only
        // as a pair; a bare label goes in `child`.
        icon: leading,
        label: leading == null ? null : Text(label),
        decoration: destructive && emphasis == ActionEmphasis.primary
            ? M3EButtonDecoration(
                backgroundColor: WidgetStatePropertyAll(colors.error),
                foregroundColor: WidgetStatePropertyAll(colors.onError),
              )
            : destructive
                ? M3EButtonDecoration(foregroundColor: WidgetStatePropertyAll(colors.error))
                : null,
        child: leading == null ? Text(label) : null,
      );
    } else {
      final style = ButtonStyle(
        minimumSize: large ? const WidgetStatePropertyAll(Size(64, 52)) : null,
        backgroundColor: destructive && emphasis == ActionEmphasis.primary ? WidgetStatePropertyAll(colors.error) : null,
        foregroundColor: destructive
            ? WidgetStatePropertyAll(emphasis == ActionEmphasis.primary ? colors.onError : colors.error)
            : null,
      );
      final child = Text(label);
      button = switch (emphasis) {
        ActionEmphasis.primary => leading == null
            ? FilledButton(onPressed: onPress, style: style, child: child)
            : FilledButton.icon(onPressed: onPress, style: style, icon: leading, label: child),
        ActionEmphasis.tonal => leading == null
            ? FilledButton.tonal(onPressed: onPress, style: style, child: child)
            : FilledButton.tonalIcon(onPressed: onPress, style: style, icon: leading, label: child),
        ActionEmphasis.outlined => leading == null
            ? OutlinedButton(onPressed: onPress, style: style, child: child)
            : OutlinedButton.icon(onPressed: onPress, style: style, icon: leading, label: child),
        ActionEmphasis.quiet => leading == null
            ? TextButton(onPressed: onPress, style: style, child: child)
            : TextButton.icon(onPressed: onPress, style: style, icon: leading, label: child),
      };
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// One action in an [ActionGroup] or one option in a [ChoiceGroup].
class GroupItem<T> {
  const GroupItem({required this.label, this.value, this.icon, this.onPressed, this.enabled = true, this.tooltip});

  final String label;
  final T? value;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;
}

/// Related actions side by side — fetch / pull / push. M3 Expressive draws
/// a connected button group whose neighbours give way on press; M3, a row
/// of outlined buttons.
class ActionGroup extends StatelessWidget {
  const ActionGroup({super.key, required this.items, this.busy = false});

  final List<GroupItem<void>> items;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (context.design.expressive) {
      return M3EButtonGroup(
        type: M3EButtonGroupType.connected,
        style: M3EButtonStyle.tonal,
        actions: [
          for (final item in items)
            M3EButtonGroupAction(
              label: Text(item.label),
              icon: item.icon == null ? null : Icon(item.icon),
              enabled: item.enabled && !busy,
              tooltip: item.tooltip,
            ),
        ],
        onSelectedIndexChanged: (index) {
          if (index != null) items[index].onPressed?.call();
        },
      );
    }
    return Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
      for (final item in items)
        OutlinedButton.icon(
          onPressed: item.enabled && !busy ? item.onPressed : null,
          icon: item.icon == null ? const SizedBox.shrink() : Icon(item.icon),
          label: Text(item.label),
        ),
    ]);
  }
}

/// Pick one of a few options — a model, an effort level. M3 Expressive: a
/// connected button group with the selection morphing; M3: choice chips
/// (which wrap, where a segmented button would not fit).
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({super.key, required this.items, required this.selected, required this.onSelected});

  final List<GroupItem<T>> items;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final index = items.indexWhere((item) => item.value == selected);
    if (context.design.expressive) {
      return M3EButtonGroup(
        type: M3EButtonGroupType.connected,
        style: M3EButtonStyle.tonal,
        selectedIndex: index < 0 ? null : index,
        selectionRequired: true,
        actions: [
          for (final item in items)
            M3EButtonGroupAction(
              label: Text(item.label),
              icon: item.icon == null ? null : Icon(item.icon),
              enabled: item.enabled,
            ),
        ],
        onSelectedIndexChanged: (next) {
          if (next != null) onSelected(items[next].value);
        },
      );
    }
    return Wrap(spacing: Gap.sm, runSpacing: Gap.xs, children: [
      for (final item in items)
        ChoiceChip(
          label: Text(item.label),
          avatar: item.icon == null ? null : Icon(item.icon, size: 18),
          selected: item.value == selected,
          onSelected: item.enabled ? (_) => onSelected(item.value) : null,
        ),
    ]);
  }
}

/// One entry of the send button's menu.
class SendMenuItem {
  const SendMenuItem({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;
}

/// The composer's send action, with what goes with sending. M3 Expressive:
/// a split button — send on the left, a menu (attach, options) on the
/// right. M3: the menu's entries as icon buttons beside a filled send.
class SendButton extends StatelessWidget {
  const SendButton({
    super.key,
    required this.label,
    required this.onSend,
    required this.menu,
    required this.onMenu,
    this.menuTooltip,
    this.icon = Icons.arrow_upward_rounded,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onSend;
  final List<SendMenuItem> menu;
  final ValueChanged<String> onMenu;
  final String? menuTooltip;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onSend != null && !busy;
    if (context.design.expressive) {
      return M3ESplitButton<String>(
        items: [
          for (final item in menu)
            M3ESplitButtonItem(
              value: item.value,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.icon, size: 20),
                const SizedBox(width: Gap.md),
                Text(item.label),
              ]),
            ),
        ],
        onSelected: onMenu,
        onPressed: enabled ? onSend : null,
        leadingIcon: icon,
        label: label,
        leadingTooltip: label,
        trailingTooltip: menuTooltip,
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final item in menu)
        IconButton(onPressed: () => onMenu(item.value), tooltip: item.label, icon: Icon(item.icon)),
      const SizedBox(width: Gap.xs),
      FilledButton.icon(
        onPressed: enabled ? onSend : null,
        icon: busy ? const InlineBusy(size: 18) : Icon(icon),
        label: Text(label),
      ),
    ]);
  }
}

/// An action for the floating action button slot. With several, M3
/// Expressive opens a FAB menu; M3 shows the first as an extended FAB and
/// the rest in a sheet.
class FabAction {
  const FabAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.actions});

  final List<FabAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final first = actions.first;
    if (context.design.expressive && actions.length > 1) {
      return M3EFabMenu(
        items: [
          for (final action in actions)
            M3EFabMenuItem(icon: Icon(action.icon), label: action.label, onPressed: action.onPressed),
        ],
      );
    }
    if (context.design.expressive) {
      return M3EExtendedFab(
        icon: Icon(first.icon),
        label: first.label,
        onPressed: first.onPressed,
      );
    }
    return FloatingActionButton.extended(
      onPressed: actions.length == 1 ? first.onPressed : () => _showMenu(context),
      icon: Icon(actions.length == 1 ? first.icon : Icons.add_rounded),
      label: Text(first.label),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final action in actions)
            ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              onTap: () {
                Navigator.of(sheet).pop();
                action.onPressed();
              },
            ),
          const SizedBox(height: Gap.sm),
        ]),
      ),
    );
  }
}
