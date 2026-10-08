// Draws the launcher icons. Run from app/:
//
//   flutter test tool/icons_test.dart
//
// Android also gets an adaptive vector icon (res/drawable/ic_launcher_*.xml,
// drawn from the same geometry); these PNGs are the legacy and iOS forms.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The brand colour behind the glyph, and the glyph's.
const background = Color(0xFF3949AB);
const foreground = Color(0xFFFFFFFF);

/// The `>_` prompt on the 108-unit adaptive-icon grid, centred on (54, 54).
void paintGlyph(Canvas canvas, double unit) {
  final paint = Paint()
    ..color = foreground
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7 * unit
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(
    Path()
      ..moveTo(37 * unit, 40 * unit)
      ..lineTo(51 * unit, 54 * unit)
      ..lineTo(37 * unit, 68 * unit),
    paint,
  );
  canvas.drawLine(Offset(57 * unit, 68 * unit), Offset(71 * unit, 68 * unit), paint);
}

/// [size] px square. [legacy]: Android before 8 draws the icon as given, so
/// it gets its own rounded square and margin; iOS masks a full-bleed square.
Future<List<int>> render(int size, {required bool legacy}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  if (legacy) {
    // The 108 grid with the outer 18 units trimmed, as launchers show it.
    final inset = s * 0.04;
    final rect = Rect.fromLTWH(inset, inset, s - 2 * inset, s - 2 * inset);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.28)), Paint()..color = background);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(s / 84);
    canvas.translate(-54, -54);
    paintGlyph(canvas, 1);
    canvas.restore();
  } else {
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = background);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(s / 80);
    canvas.translate(-54, -54);
    paintGlyph(canvas, 1);
    canvas.restore();
  }
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  test('render launcher icons', skip: !Platform.isMacOS, () async {
    const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final MapEntry(key: density, value: size) in android.entries) {
      File('android/app/src/main/res/mipmap-$density/ic_launcher.png').writeAsBytesSync(await render(size, legacy: true));
    }
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png';
    File(ios).writeAsBytesSync(await render(1024, legacy: false));
    // The App Store refuses an icon with an alpha channel; a round trip
    // through JPEG (at full quality) drops it.
    final jpeg = '${Directory.systemTemp.path}/skidsense-icon.jpg';
    expect((await Process.run('sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '100', ios, '--out', jpeg])).exitCode, 0);
    expect((await Process.run('sips', ['-s', 'format', 'png', jpeg, '--out', ios])).exitCode, 0);
  });
}
