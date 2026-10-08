import '../material.dart';
import '../theme/tokens.dart';

/// Ask before doing something that cannot be undone.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError) : null,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Ask for one line of text — a new name, a commit message.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String initial = '',
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialog) => _TextPrompt(title: title, label: label, action: action, initial: initial, maxLines: maxLines),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.label, required this.action, required this.initial, required this.maxLines});

  final String title;
  final String label;
  final String action;
  final String initial;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _text,
          autofocus: true,
          maxLines: widget.maxLines,
          minLines: 1,
          decoration: InputDecoration(labelText: widget.label),
          onSubmitted: widget.maxLines == 1 ? (value) => Navigator.of(context).pop(value) : null,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          ValueListenableBuilder(
            valueListenable: _text,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty ? null : () => Navigator.of(context).pop(value.text.trim()),
              child: Text(widget.action),
            ),
          ),
        ],
      );
}

/// A modal sheet whose content scrolls, sized to its content up to most of
/// the screen.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
          child: builder(sheet),
        ),
      ),
    );

/// The heading of a sheet's content.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.text.titleLarge),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ),
        ]),
      );
}
