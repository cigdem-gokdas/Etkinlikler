// Run explicitly with --dart-define=CAPTURE_INTRO=true. Not part of CI tests.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:etkinlik_kesif/app/launch/launch_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('export controlled intro frames', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_INTRO')) return;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: const LaunchIntro(child: ColoredBox(color: Color(0xFFFAFAF8))),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/mobilab_logo.png'),
        key.currentContext!,
      ),
    );
    var previous = 0;
    for (final millis in [400, 1050, 1320, 1580]) {
      await tester.pump(Duration(milliseconds: millis - previous));
      await tester.pump();
      previous = millis;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: 2);
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/reports/final-motion/intro-frames/$millis-ms.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        frame.dispose();
      });
    }
    await tester.pumpAndSettle();
  });
}
