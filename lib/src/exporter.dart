import 'dart:isolate';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:screen_recorder/src/frame.dart';

class Exporter {
  final List<Frame> _frames = [];
  List<Frame> get frames => _frames;

  void onNewFrame(Frame frame) {
    _frames.add(frame);
  }

  void clear() {
    _frames.clear();
  }

  bool get hasFrames => _frames.isNotEmpty;

  Future<List<RawFrame>?> exportFrames() async {
    if (_frames.isEmpty) {
      return null;
    }
    final bytesImages = <RawFrame>[];
    for (final frame in _frames) {
      final bytesImage = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (bytesImage != null) {
        bytesImages.add(RawFrame(42, bytesImage));
      } else {
        print('Skipped frame while enconding');
      }
    }
    return bytesImages;
  }

  void exportGif({required Function(List<int>?) onFinished, Function(int, int)? onProgress}) async {
    final frames = await exportFrames();
    if (frames == null) {
      return null;
    }

    final progressPort = ReceivePort();
    final resultPort = ReceivePort();

    progressPort.listen((message) {
      if (message is int) {
        onProgress?.call(message, frames.length);
      }
    });

    await Isolate.spawn(
      _exportGif,
      [frames, progressPort.sendPort, resultPort.sendPort],
    );
    onFinished(resultPort.first as List<int>?);
  }

  static Future<List<int>?> _exportGif(List params) async {
    final animation = image.Animation();
    animation.backgroundColor = Colors.transparent.value;
    SendPort progressPort = params[1];
    SendPort resultPort = params[2];
    int i = 0;
    for (final frame in params[0]) {
      // Send i to main isolate
      progressPort.send(i);

      final iAsBytes = frame.image.buffer.asUint8List();
      final decodedImage = image.decodePng(iAsBytes);

      if (decodedImage == null) {
        print('Skipped frame while enconding');
        continue;
      }
      decodedImage.duration = frame.durationInMillis;
      animation.addFrame(decodedImage);
      i++;
    }
    resultPort.send(image.encodeGifAnimation(animation));
    return image.encodeGifAnimation(animation);
  }
}

class RawFrame {
  RawFrame(this.durationInMillis, this.image);

  final int durationInMillis;
  final ByteData image;
}
