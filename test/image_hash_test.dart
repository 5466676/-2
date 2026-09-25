import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/services/image_hash.dart';
import 'package:image/image.dart' as img;

/// صورة فيها تدرج أفقي + مربع بمكان معيّن.
img.Image _pattern({int size = 200, int boxX = 40, bool flip = false}) {
  final image = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var v = (x * 255 ~/ size);
      if (flip) v = 255 - v;
      final inBox = x >= boxX && x < boxX + 50 && y >= 60 && y < 110;
      image.setPixelRgb(x, y, inBox ? 255 - v : v, v, (v + y) % 256);
    }
  }
  return image;
}

void main() {
  test('distance counts differing bits', () {
    expect(ImageHash.distance(0, 0), 0);
    expect(ImageHash.distance(0, 1), 1);
    expect(ImageHash.distance(0, -1), 64);
    expect(ImageHash.distance(0x0F, 0xF0), 8);
  });

  test('same image at different sizes and JPEG quality hashes close', () {
    final original = _pattern();
    final a = ImageHash.fromImage(original);
    final resized = img.copyResize(original, width: 480, height: 480);
    final jpeg = img.encodeJpg(resized, quality: 40);
    final b = ImageHash.fromBytes(jpeg)!;
    expect(ImageHash.distance(a, b), lessThanOrEqualTo(4));
  });

  test('different images hash far apart', () {
    final a = ImageHash.fromImage(_pattern());
    final b = ImageHash.fromImage(_pattern(flip: true));
    expect(ImageHash.distance(a, b), greaterThan(20));
  });

  test('undecodable bytes give null', () {
    expect(ImageHash.fromBytes(img.encodePng(_pattern()).sublist(0, 10)),
        isNull);
  });
}
