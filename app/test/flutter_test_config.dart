import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Goldens ignore glyph antialiasing, which macOS releases rasterize a
/// little differently: measured between two releases, ~0.35% of pixels
/// moved by 1–15 levels of 255 and none by more than 63.
///
/// An image passes when
/// - no more than [_AntialiasTolerantComparator.strongTolerance] of its
///   pixels differ by more than [_AntialiasTolerantComparator.strongDelta]
///   in any channel (a changed character, icon or colour moves far more,
///   and far more pixels), and
/// - no more than [_AntialiasTolerantComparator.anyTolerance] differ at all
///   (a subtle shift across the whole screen, such as a tone change, is
///   caught here).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _AntialiasTolerantComparator(comparator.basedir.resolve('golden_test.dart'));
  }
  await testMain();
}

class _AntialiasTolerantComparator extends LocalFileComparator {
  _AntialiasTolerantComparator(super.testFile);

  static const strongDelta = 64;
  static const strongTolerance = 0.00002;
  static const anyTolerance = 0.01;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final result = await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (result.passed) {
      result.dispose();
      return true;
    }
    final strong = await _strongShare(imageBytes, Uint8List.fromList(goldenBytes));
    if (strong != null && strong <= strongTolerance && result.diffPercent <= anyTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(
      '$error\n'
      '${strong == null ? '' : 'Pixels off by more than $strongDelta/255: ${(strong * 100).toStringAsFixed(4)}% '
          '(allowed ${(strongTolerance * 100).toStringAsFixed(4)}%).'}',
    );
  }

  /// The share of pixels whose largest channel difference exceeds
  /// [strongDelta]; null when the images are not the same size.
  static Future<double?> _strongShare(Uint8List a, Uint8List b) async {
    final (pa, wa, ha) = await _rgba(a);
    final (pb, wb, hb) = await _rgba(b);
    if (wa != wb || ha != hb) return null;
    var strong = 0;
    for (var i = 0; i < pa.length; i += 4) {
      for (var c = 0; c < 4; c++) {
        if ((pa[i + c] - pb[i + c]).abs() > strongDelta) {
          strong++;
          break;
        }
      }
    }
    return strong / (wa * ha);
  }

  static Future<(Uint8List, int, int)> _rgba(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final (width, height) = (image.width, image.height);
    image.dispose();
    codec.dispose();
    return (data!.buffer.asUint8List(), width, height);
  }
}
