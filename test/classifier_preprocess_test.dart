import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/services/classifier/greeting_classifier.dart';
import 'package:image/image.dart' as img;

void main() {
  final source = img.encodePng(
    img.Image(width: 50, height: 30)..clear(img.ColorRgb8(10, 20, 30)),
  );

  test('float input is raw 0..255 RGB at the model size', () {
    final buffer =
        TfliteGreetingClassifier.preprocess(source, 8, false)!.asFloat32List();
    expect(buffer.length, 8 * 8 * 3);
    expect(buffer.sublist(0, 3), [10, 20, 30]);
  });

  test('uint8 input keeps raw bytes', () {
    final buffer =
        TfliteGreetingClassifier.preprocess(source, 4, true)!.asUint8List();
    expect(buffer.length, 4 * 4 * 3);
    expect(buffer.sublist(0, 3), [10, 20, 30]);
  });

  test('garbage bytes give null', () {
    expect(
      TfliteGreetingClassifier.preprocess(Uint8List(5), 8, false),
      isNull,
    );
  });
}
