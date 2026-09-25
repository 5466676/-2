import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'scan_pipeline.dart';

/// حماية الوجوه بـ ML Kit (على الجهاز، بدون إنترنت).
///
/// الإعداد متحفظ: وضع الدقة وحد أدنى صغير لحجم الوجه، لأن غلطة "ما شفنا
/// الوجه" معناها ممكن تنمسح صورة شخصية — وهاد أسوأ من إنه تفوتنا معايدة.
class MlKitFaceChecker implements FaceChecker {
  MlKitFaceChecker()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            minFaceSize: 0.05,
          ),
        );

  final FaceDetector _detector;

  @override
  Future<bool> hasFace(String path) async {
    try {
      final faces = await _detector.processImage(InputImage.fromFilePath(path));
      return faces.isNotEmpty;
    } catch (_) {
      // إذا الكشف فشل ما منخاطر: الصورة محمية.
      return true;
    }
  }

  Future<void> close() => _detector.close();
}
