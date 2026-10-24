// Run with: flutter test tool/generate_app_icons.dart
// Rasterizes the Melo mark directly for crisp platform assets; the SVG and
// Android vector foreground are hand-kept copies of the same geometry.
// Python with Pillow is used only to strip the iOS PNG alpha channel.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_colors.dart';
import 'package:melo/shared/widgets/melo_mark.dart';

const _android = 'android/app/src/main/res';
const _ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
String _hex(ui.Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Future<void> _png(String path, int size, {bool round = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(size / 108);
  final background = ui.Paint()..color = AppColors.paper;
  if (round) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 0, 108, 108),
        const ui.Radius.circular(26),
      ),
      background,
    );
  } else {
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 108, 108), background);
  }
  canvas
    ..translate(23, 23)
    ..scale(0.62);
  const MeloMarkPainter().paint(
    canvas,
    const ui.Size.square(MeloMarkPainter.grid),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate platform icons from the shared palette', () async {
    await Directory('assets/branding').create(recursive: true);
    await _png('assets/branding/app-icon.png', 1024);
    await _png('assets/branding/app-icon-preview.png', 512, round: true);
    const densities = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in densities.entries) {
      await _png(
        '$_android/mipmap-${entry.key}/ic_launcher.png',
        entry.value,
        round: true,
      );
    }
    final contents =
        jsonDecode(await File('$_ios/Contents.json').readAsString())
            as Map<String, dynamic>;
    for (final entry
        in (contents['images'] as List).cast<Map<String, dynamic>>()) {
      final size = double.parse((entry['size'] as String).split('x').first);
      final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
      await _png('$_ios/${entry['filename']}', (size * scale).round());
    }
    await File('$_android/values/colors.xml').writeAsString(
      '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="paper">${_hex(AppColors.paper)}</color>
    <color name="seal">${_hex(AppColors.paper)}</color>
</resources>
''',
    );
    // App Store icons must have no alpha channel, even when fully opaque.
    final conversion = await Process.run('python', [
      '-c',
      'from pathlib import Path; from PIL import Image; '
          'paths = list(Path("$_ios").glob("*.png")) + [Path("assets/branding/app-icon.png")]; '
          '[Image.open(p).convert("RGB").save(p) for p in paths]',
    ]);
    if (conversion.exitCode != 0) {
      throw StateError('Could not export opaque icons: ${conversion.stderr}');
    }
  });
}
