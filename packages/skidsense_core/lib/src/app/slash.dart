import '../model/host_config.dart';

// The composer's `/` menu as the desktop has it
// (`src/renderer/workbench/slash.ts`, itself the parent project's `tb` / `RU`
// / `UL` / `_U`): the same trigger, order and insertion on both, so a command
// is found the same way on the phone. Offsets are UTF-16 code units, as in
// JavaScript and in a Flutter text selection.

/// A `/` at the start or after whitespace, and the name typed after it, up to the caret.
final RegExp _trigger = RegExp(r'(^|\s)\/([^\s/]*)$');

int _clamp(String text, int? caret) => (caret ?? text.length).clamp(0, text.length);

/// What is being typed after a `/` before [caret] (the end by default);
/// null when the caret is not in a command.
String? slashQuery(String text, [int? caret]) => _trigger.firstMatch(text.substring(0, _clamp(text, caret)))?.group(2);

/// The commands matching [query], best first: the name itself, then a name
/// it starts, then one where it starts a word (`-_.:/`), then one containing
/// it, then a description mentioning it. An alias counts as a name. Ties keep
/// the harness's order.
List<SlashCommand> rankCommands(List<SlashCommand> commands, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return [...commands];
  final ranked = [
    for (var index = 0; index < commands.length; index++)
      if (_rankOf(commands[index], needle) case final rank?) (command: commands[index], index: index, rank: rank),
  ]..sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.index - b.index);
  return [for (final entry in ranked) entry.command];
}

int? _rankOf(SlashCommand command, String needle) {
  int? best;
  for (final name in [command.name, ...command.aliases]) {
    final rank = _nameRank(name.toLowerCase(), needle);
    if (rank != null && (best == null || rank < best)) best = rank;
  }
  if (best != null) return best;
  return (command.description ?? '').toLowerCase().contains(needle) ? 4 : null;
}

int? _nameRank(String name, String needle) {
  if (name == needle) return 0;
  if (name.startsWith(needle)) return 1;
  for (var at = 1; at < name.length; at++) {
    if ('-_.:/'.contains(name[at - 1]) && name.startsWith(needle, at)) return 2;
  }
  return name.contains(needle) ? 3 : null;
}

/// `/name ` in place of the half-typed command before [caret], ready for
/// arguments — not sent. With no command being typed, it is appended. The
/// caret lands after the space.
({String text, int caret}) insertCommand(String text, String name, [int? caret]) {
  final at = _clamp(text, caret);
  final before = text.substring(0, at);
  final match = _trigger.firstMatch(before);
  if (match == null) {
    final next = text.isNotEmpty && !RegExp(r'\s$').hasMatch(text) ? '$text /$name ' : '$text/$name ';
    return (text: next, caret: next.length);
  }
  final head = before.substring(0, match.start + match.group(1)!.length);
  final tail = text.substring(at);
  final inserted = '/$name${RegExp(r'^\s').hasMatch(tail) ? '' : ' '}';
  return (text: head + inserted + tail, caret: head.length + name.length + 2);
}

/// ↑ / ↓ through a list of [length], wrapping at either end.
int stepIndex(int length, int current, int step) {
  if (length == 0) return 0;
  return ((current + step) % length + length) % length;
}
