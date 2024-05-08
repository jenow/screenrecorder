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

  Future<List<int>?> exportGif([Function(int, int)? onFrameExported]) async {
    final frames = await exportFrames();
    if (frames == null) {
      return null;
    }
    return compute(
      _exportGif,
      {
        'frames': frames,
        'onFrameExported': onFrameExported,
      },
    );
  }

  static Future<List<int>?> _exportGif(Map<String, dynamic> params) async {
    final animation = image.Animation();
    animation.backgroundColor = Colors.transparent.value;
    int i = 0;
    for (final frame in params['frames']) {
      if (params['onFrameExported'] != null) {
        params['onFrameExported']!(i, params['frames'].length);
      }
      final iAsBytes = frame.image.buffer.asUint8List();
      final decodedImage = image.decodePng(iAsBytes);

      if (decodedImage == null) {
        print('Skipped frame while enconding');
        continue;
      }
      decodedImage.duration = frame.durationInMillis;
      animation.addFrame(decodedImage);
    }
    return image.encodeGifAnimation(animation);
  }
}

class RawFrame {
  RawFrame(this.durationInMillis, this.image);

  final int durationInMillis;
  final ByteData image;
}
