import 'package:skidsense_core/skidsense_core.dart';
import 'package:test/test.dart';

class RecordingSurface implements TerminalSurface {
  final StringBuffer written = StringBuffer();

  @override
  void write(String data) => written.write(data);
}

void main() {
  group('terminal channel', () {
    TerminalChannel channel() =>
        TerminalChannel('claude:1', exitFooter: (exit) => exit.reason ?? 'exit ${exit.code}${exit.signal == null ? '' : ' signal ${exit.signal}'}');

    test('output before the surface is ready is kept and flushed', () {
      final terminal = channel()
        ..onData('claude:1', 'first ')
        ..onData('claude:1', 'second ');
      final surface = RecordingSurface();
      terminal.attach(surface);
      expect(surface.written.toString(), '', reason: 'nothing to draw yet');
      terminal.flush();
      expect(surface.written.toString(), 'first second ');
      terminal.onData('claude:1', 'live');
      expect(surface.written.toString(), 'first second live');
    });

    test('output for another session is ignored', () {
      final surface = RecordingSurface();
      channel()
        ..attach(surface)
        ..onData('codex:2', 'not ours')
        ..flush();
      expect(surface.written.toString(), '');
    });

    test('the buffer is bounded, so a shell cannot flood it', () {
      final terminal = channel();
      for (var i = 0; i < 10; i++) {
        terminal.onData('claude:1', 'x' * 50000);
      }
      final surface = RecordingSurface();
      terminal
        ..attach(surface)
        ..flush();
      expect(surface.written.length, TerminalChannel.bufferLimit);
    });

    test('an exit is drawn as a footer, with the tail of a process that died early', () {
      final surface = RecordingSurface();
      channel()
        ..attach(surface)
        ..onExit(const TerminalExit(key: 'claude:1', code: 1, reason: 'process exited', tail: 'boom\nbye'));
      expect(surface.written.toString(), contains('process exited'));
      expect(surface.written.toString(), contains('boom\r\nbye'));
    });

    test('the event payloads decode', () {
      expect(TerminalEvents.decodeData({'key': 'claude:1', 'data': 'hi'}), ('claude:1', 'hi'));
      expect(TerminalEvents.decodeData({'key': 'claude:1'}), isNull);
      final exit = TerminalEvents.decodeExit({'key': 'claude:1', 'code': 3, 'reason': 'boom'})!;
      expect([exit.key, exit.code, exit.reason, exit.tail], ['claude:1', 3, 'boom', '']);
      // A desktop exit without code is -1, not 0: a spawn that never ran (C2).
      expect(TerminalEvents.decodeExit({'key': 'claude:1', 'signal': 9})!.code, -1);
      expect(TerminalEvents.decodeExit('nonsense'), isNull);
    });
  });

  group('search fold', () {
    SearchProgressPush files(String id, String path, List<int> lines) => SearchProgressPush.fromJson({
          'id': id,
          'kind': 'files',
          'files': [
            {
              'path': path,
              'matches': [
                for (final line in lines) {'line': line, 'column': 0, 'text': 'line $line'},
              ],
            },
          ],
        });

    test('progress accumulates and done carries the total', () {
      final fold = SearchFold('s1', 'needle')
        ..apply(files('s1', 'a.kt', [1, 2]))
        ..apply(files('s1', 'b.kt', [9]));
      expect(fold.state.files, hasLength(2));
      expect(fold.state.matches, 3);
      expect(fold.state.done, isFalse);
      fold.apply(SearchProgressPush.fromJson({'id': 's1', 'kind': 'done', 'totalMatches': 3, 'fileCount': 2}));
      expect(fold.state.done, isTrue);
      expect(fold.state.totalMatches, 3);
    });

    test("another device's search is ignored", () {
      final fold = SearchFold('s1', 'needle')..apply(files('someone-else', 'x.kt', [1]));
      expect(fold.state.files, isEmpty);
    });

    test('an error ends the search with its message', () {
      final fold = SearchFold('s1', 'needle')..apply(SearchProgressPush.fromJson({'id': 's1', 'kind': 'error', 'error': '工作区不可读'}));
      expect(fold.state.done, isTrue);
      expect(fold.state.end, SearchEnd.host);
      expect(fold.state.error, '工作区不可读');
    });

    test('progress after done, or after a cancel, is ignored', () {
      final done = SearchFold('s1', 'needle')
        ..apply(SearchProgressPush.fromJson({'id': 's1', 'kind': 'done', 'totalMatches': 1}))
        ..apply(files('s1', 'late.kt', [2]));
      expect(done.state.files, isEmpty);
      final cancelled = SearchFold('s1', 'needle')
        ..apply(files('s1', 'a.kt', [1]))
        ..cancel()
        ..apply(files('s1', 'b.kt', [2]));
      expect(cancelled.state.files, hasLength(1));
      expect(cancelled.state.cancelled, isTrue);
    });
  });
}
