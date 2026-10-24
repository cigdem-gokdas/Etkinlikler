import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class TestImageCompleter extends ImageStreamCompleter {
  void deliver(ImageInfo info) => setImage(info);
}

class ControlledImage extends ImageProvider<ControlledImage> {
  final completer = TestImageCompleter();
  int loads = 0;
  @override
  Future<ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    ControlledImage key,
    ImageDecoderCallback decode,
  ) {
    loads++;
    return completer;
  }

  Future<void> emit(int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    completer.deliver(ImageInfo(image: image));
  }

  void fail() => completer.reportError(
    context: ErrorDescription('fixture'),
    exception: StateError('broken image'),
  );
}
