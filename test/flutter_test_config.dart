import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The largest difference in one color channel (0-255) that a golden
/// comparison ignores.
///
/// macOS versions antialias glyph edges a little differently: CI (macOS 26)
/// and a macOS 15 workstation differ by at most 13 per channel, on at most
/// 61 edge pixels per image (2026-10-29). A layout change moves glyphs and
/// gives differences near 255.
const goldenChannelTolerance = 32;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final comparator = goldenFileComparator;
  if (comparator is LocalFileComparator) {
    goldenFileComparator = _EdgeTolerantComparator(
      // basedir is the directory of the test file; any file in it works.
      Uri.parse('${comparator.basedir}flutter_test_config.dart'),
    );
  }
  await testMain();
}

class _EdgeTolerantComparator extends LocalFileComparator {
  _EdgeTolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = Uint8List.fromList(await getGoldenBytes(golden));
    final result =
        await GoldenFileComparator.compareLists(imageBytes, goldenBytes);
    if (result.passed) {
      result.dispose();
      return true;
    }
    if (await _withinTolerance(imageBytes, goldenBytes)) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<bool> _withinTolerance(Uint8List a, Uint8List b) async {
  final imageA = await _decode(a);
  final imageB = await _decode(b);
  try {
    if (imageA.width != imageB.width || imageA.height != imageB.height) {
      return false;
    }
    final pixelsA = (await imageA.toByteData())!.buffer.asUint8List();
    final pixelsB = (await imageB.toByteData())!.buffer.asUint8List();
    for (var i = 0; i < pixelsA.length; i++) {
      if ((pixelsA[i] - pixelsB[i]).abs() > goldenChannelTolerance) {
        return false;
      }
    }
    return true;
  } finally {
    imageA.dispose();
    imageB.dispose();
  }
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
