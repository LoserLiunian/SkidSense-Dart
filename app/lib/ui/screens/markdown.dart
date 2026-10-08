import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../kit/containers.dart';
import '../material.dart';
import '../theme/tokens.dart';

/// Agent replies are Markdown. This draws the part that matters on a phone
/// — paragraphs, headings, lists, quotes, fenced code, inline `code`,
/// **bold**, *italic* and links — and leaves anything else as the text it
/// is. Selectable throughout.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = _parse(source);
    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: Gap.sm),
          _block(context, blocks[index]),
        ],
      ]),
    );
  }

  Widget _block(BuildContext context, _Block block) {
    final text = context.text;
    final colors = context.colors;
    switch (block.kind) {
      case _Kind.code:
        return _CodeBlock(code: block.text, language: block.info);
      case _Kind.heading:
        final style = switch (block.level) {
          1 => text.titleLarge,
          2 => text.titleMedium,
          _ => text.titleSmall,
        };
        return Text.rich(_inline(context, block.text, style));
      case _Kind.quote:
        return Container(
          padding: const EdgeInsetsDirectional.only(start: Gap.md),
          decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: colors.outlineVariant, width: 3))),
          child: Text.rich(_inline(context, block.text, text.bodyMedium?.copyWith(color: colors.onSurfaceVariant))),
        );
      case _Kind.list:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (marker, item, depth) in block.items)
            Padding(
              padding: EdgeInsetsDirectional.only(start: depth * 16.0, bottom: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 22, child: Text(marker, style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant))),
                Expanded(child: Text.rich(_inline(context, item, text.bodyMedium))),
              ]),
            ),
        ]);
      case _Kind.rule:
        return const Divider();
      case _Kind.paragraph:
        return Text.rich(_inline(context, block.text, text.bodyMedium?.copyWith(height: 1.5)));
    }
  }

  static final RegExp _inlinePattern = RegExp(r'(`[^`]+`)|(\*\*[^*]+\*\*)|(__[^_]+__)|(\*[^*\s][^*]*\*)|(\[[^\]]+\]\([^)\s]+\))');

  TextSpan _inline(BuildContext context, String source, TextStyle? style) {
    final colors = context.colors;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _inlinePattern.allMatches(source)) {
      if (match.start > last) spans.add(TextSpan(text: source.substring(last, match.start)));
      final token = match.group(0)!;
      if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: monoFamilyFallback,
            backgroundColor: colors.surfaceContainerHighest,
            color: colors.onSurface,
          ),
        ));
      } else if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(text: token.substring(2, token.length - 2), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (token.startsWith('*')) {
        spans.add(TextSpan(text: token.substring(1, token.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        final label = token.substring(1, token.indexOf(']'));
        final url = token.substring(token.indexOf('(') + 1, token.length - 1);
        spans.add(TextSpan(
          text: label,
          style: TextStyle(color: colors.primary, decoration: TextDecoration.underline),
          // Links in agent output are copied, not opened: the text is the
          // agent's, and following it from here is not the app's call.
          recognizer: TapGestureRecognizer()..onTap = () => Clipboard.setData(ClipboardData(text: url)),
        ));
      }
      last = match.end;
    }
    if (last < source.length) spans.add(TextSpan(text: source.substring(last)));
    return TextSpan(style: style, children: spans);
  }

  static final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$');
  static final RegExp _fence = RegExp(r'^\s*(```|~~~)\s*([\w+-]*)');
  static final RegExp _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

  static List<_Block> _parse(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_Block>[];
    final paragraph = <String>[];
    void flush() {
      if (paragraph.isEmpty) return;
      blocks.add(_Block(_Kind.paragraph, paragraph.join('\n')));
      paragraph.clear();
    }

    var index = 0;
    while (index < lines.length) {
      final line = lines[index];
      final fence = _fence.firstMatch(line);
      if (fence != null) {
        flush();
        final marker = fence.group(1)!;
        final code = <String>[];
        index += 1;
        while (index < lines.length && !lines[index].trimLeft().startsWith(marker)) {
          code.add(lines[index]);
          index += 1;
        }
        blocks.add(_Block(_Kind.code, code.join('\n'), info: fence.group(2)));
        index += 1;
        continue;
      }
      if (line.trim().isEmpty) {
        flush();
        index += 1;
        continue;
      }
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        flush();
        blocks.add(_Block(_Kind.heading, heading.group(2)!, level: heading.group(1)!.length));
        index += 1;
        continue;
      }
      if (_rule.hasMatch(line)) {
        flush();
        blocks.add(const _Block(_Kind.rule, ''));
        index += 1;
        continue;
      }
      if (line.trimLeft().startsWith('>')) {
        flush();
        final quote = <String>[];
        while (index < lines.length && lines[index].trimLeft().startsWith('>')) {
          quote.add(lines[index].trimLeft().substring(1).trimLeft());
          index += 1;
        }
        blocks.add(_Block(_Kind.quote, quote.join('\n')));
        continue;
      }
      if (_bullet.hasMatch(line)) {
        flush();
        final items = <(String, String, int)>[];
        while (index < lines.length) {
          final match = _bullet.firstMatch(lines[index]);
          if (match == null) {
            // A wrapped continuation of the previous item.
            if (items.isNotEmpty && lines[index].trim().isNotEmpty && lines[index].startsWith('  ')) {
              final (marker, text, depth) = items.removeLast();
              items.add((marker, '$text ${lines[index].trim()}', depth));
              index += 1;
              continue;
            }
            break;
          }
          final marker = match.group(2)!;
          items.add((RegExp(r'^\d').hasMatch(marker) ? marker : '•', match.group(3)!, (match.group(1)!.length / 2).floor().clamp(0, 4)));
          index += 1;
        }
        blocks.add(_Block(_Kind.list, '', items: items));
        continue;
      }
      paragraph.add(line);
      index += 1;
    }
    flush();
    return blocks;
  }
}

enum _Kind { paragraph, heading, code, quote, list, rule }

class _Block {
  const _Block(this.kind, this.text, {this.level = 0, this.info, this.items = const []});

  final _Kind kind;
  final String text;
  final int level;
  final String? info;
  final List<(String, String, int)> items;
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) => Stack(children: [
        MonoBlock(code, maxHeight: 420),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
          ),
        ),
      ]);
}
