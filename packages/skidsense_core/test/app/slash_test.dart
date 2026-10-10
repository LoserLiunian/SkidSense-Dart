import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

/// The composer's `/` menu, case for case as the desktop checks its own
/// (`scripts/verify-slash.ts`, 输入框：触发、排序、填入): the two must find
/// and fill a command the same way.
void main() {
  String names(List<SlashCommand> list) => list.map((command) => command.name).join(',');

  group('trigger', () {
    test('a / at the start, with nothing typed yet', () => expect(slashQuery('/'), ''));
    test('a few letters typed', () => expect(slashQuery('/com'), 'com'));
    test('a / after a space triggers too', () => expect(slashQuery('帮我 /re'), 're'));
    test('a / inside a path does not', () {
      expect(slashQuery('src/main'), isNull);
      expect(slashQuery('/Users/me'), isNull);
    });
    test('a space after the name closes it', () => expect(slashQuery('/review '), isNull));
    test('the caret decides', () {
      expect(slashQuery('/rev 其余', 4), 'rev');
      expect(slashQuery('/rev 其余', 7), isNull);
    });
  });

  group('order', () {
    const list = [
      SlashCommand(name: 'git:review', source: 'command'),
      SlashCommand(name: 'preview', source: 'command'),
      SlashCommand(name: 'reviewer', source: 'skill'),
      SlashCommand(name: 'review', source: 'builtin'),
      SlashCommand(name: 'deploy', description: 'Run the review checklist, then ship', source: 'command'),
      SlashCommand(name: 'code-review', aliases: ['cr'], source: 'command'),
      SlashCommand(name: 'compact', source: 'builtin'),
    ];

    test('the same > a prefix > a word start > contained > the description',
        () => expect(names(rankCommands(list, 'review')), 'review,reviewer,git:review,code-review,preview,deploy'));
    test('an alias counts as a name', () => expect(names(rankCommands(list, 'cr')), 'code-review'));
    test('case does not matter', () => expect(names(rankCommands(list, 'COMP')), 'compact'));
    test('nothing typed keeps the order', () => expect(names(rankCommands(list, '')), names(list)));
    test('no match is nothing', () => expect(rankCommands(list, 'zzz'), isEmpty));
  });

  group('filling in', () {
    test('picked: `/name `, the caret after the space', () {
      final filled = insertCommand('/rev', 'review');
      expect((filled.text, filled.caret), ('/review ', 8));
    });
    test('mid-sentence, the command being typed is replaced', () {
      final middle = insertCommand('先 /co 然后', 'compact', 5);
      expect((middle.text, middle.caret), ('先 /compact 然后', 11));
    });
    test('with no command being typed, it goes at the end', () {
      expect(insertCommand('随便说点', 'compact').text, '随便说点 /compact ');
      expect(insertCommand('', 'compact').text, '/compact ');
    });
    test('↑ ↓ wrap at either end', () {
      expect(stepIndex(3, 2, 1), 0);
      expect(stepIndex(3, 0, -1), 2);
      expect(stepIndex(0, 0, 1), 0);
    });
  });
}
