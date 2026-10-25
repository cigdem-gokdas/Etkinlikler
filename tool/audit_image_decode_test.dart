// Explicit integration audit of downloaded public API bytes, never run by CI.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('decode downloaded API images with the actual Flutter codec', (
    tester,
  ) async {
    const manifestPath = String.fromEnvironment('AUDIT_MANIFEST');
    if (manifestPath.isEmpty) {
      fail(
        'Run explicitly with --dart-define=AUDIT_MANIFEST=/path/manifest.json',
      );
    }
    final file = File(manifestPath);
    final manifest =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    await tester.runAsync(() async {
      for (final image in manifest['images'] as List<dynamic>) {
        if (image['http'] != 200 || image['curl_exit'] != 0) {
          image['decode'] = 'not-attempted-http-failure';
          continue;
        }
        ui.Codec? codec;
        ui.Image? frame;
        try {
          codec = await ui.instantiateImageCodec(
            File(image['path'] as String).readAsBytesSync(),
          );
          frame = (await codec.getNextFrame()).image;
          image['decode'] = 'valid';
          image['width'] = frame.width;
          image['height'] = frame.height;
        } catch (error) {
          image['decode'] = 'invalid';
          image['decode_error_type'] = error.runtimeType.toString();
        } finally {
          frame?.dispose();
          codec?.dispose();
        }
      }
    });
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    expect(manifest['images'], isNotEmpty);
  });
}
