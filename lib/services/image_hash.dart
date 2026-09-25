import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// بصمة dHash (64 بت) — بتتحمل تغيير الحجم والضغط، فنفس المعايدة
/// المبعوتة من أكثر من جروب بتعطي بصمة قريبة جدًا.
class ImageHash {
  ImageHash._();

  /// يحسب البصمة من بايتات صورة مشفرة (JPEG/PNG…). يرجع null إذا ما انفكت.
  static int? fromBytes(Uint8List bytes) {
    final decoded = safeDecode(bytes);
    if (decoded == null) return null;
    return fromImage(decoded);
  }

  /// مكتبة image بترمي استثناء مع الملفات المقطوعة بدل ما ترجع null.
  static img.Image? safeDecode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// يصغّر الصورة لـ 9×8 رمادي، وكل بت = هل البكسل أفتح من اللي جنبه.
  static int fromImage(img.Image image) {
    final small = img.copyResize(
      img.grayscale(image.clone()),
      width: 9,
      height: 8,
      interpolation: img.Interpolation.average,
    );
    var hash = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = small.getPixel(x, y).r;
        final right = small.getPixel(x + 1, y).r;
        hash = (hash << 1) | (left > right ? 1 : 0);
      }
    }
    return hash;
  }

  /// عدد البتات المختلفة بين بصمتين (0..64).
  static int distance(int a, int b) {
    var x = a ^ b;
    var count = 0;
    while (x != 0) {
      x &= x - 1;
      count++;
    }
    return count;
  }
}
