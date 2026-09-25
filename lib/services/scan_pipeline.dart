import 'dart:isolate';
import 'dart:typed_data';

import '../config.dart';
import 'hash_store.dart';
import 'image_hash.dart';

/// صورة مرشحة للفحص — مستقلة عن مصدرها (المعرض أو اختبار).
abstract class ScanCandidate {
  String get id;

  /// صورة مصغرة مشفرة (JPEG) للبصمة والمودل والعرض.
  Future<Uint8List?> thumbnailBytes();

  /// مسار الملف الأصلي (لكشف الوجوه بدقة كاملة).
  Future<String?> filePath();
}

/// كاشف وجوه.
abstract class FaceChecker {
  Future<bool> hasFace(String path);
}

/// مصنّف المعايدات.
abstract class GreetingScorer {
  /// false إذا ملف المودل مش موجود.
  bool get isAvailable;

  /// احتمال أنها معايدة (0..1)، أو null إذا فشل.
  Future<double?> score(Uint8List imageBytes);
}

/// ليش انعلّمت الصورة كمعايدة.
enum MatchReason {
  /// شبه صورة انمسحت قبل.
  learned,

  /// المودل قرر.
  model,
}

class ScanMatch {
  const ScanMatch({
    required this.candidate,
    required this.hash,
    required this.reason,
    required this.score,
  });

  final ScanCandidate candidate;
  final int hash;
  final MatchReason reason;
  final double score;
}

/// إحصائيات الفحص لحد اللحظة.
class ScanStats {
  int processed = 0;
  int skippedKept = 0;
  int protectedFaces = 0;
  int learned = 0;
  int model = 0;
  int failed = 0;

  int get matched => learned + model;
}

/// حدث تقدم يطلع من الفحص بعد كل صورة.
class ScanProgress {
  const ScanProgress({required this.total, required this.stats, this.match});

  final int total;
  final ScanStats stats;

  /// النتيجة الجديدة إذا الصورة الحالية طلعت معايدة.
  final ScanMatch? match;
}

typedef HashFunction = Future<int?> Function(Uint8List bytes);

Future<int?> _hashInBackground(Uint8List bytes) =>
    Isolate.run(() => ImageHash.fromBytes(bytes));

/// ترتيب الفحص (الترتيب مهم):
/// 1. قائمة "ما تعلّم عليها" → تجاهل.
/// 2. فيها وجه → محمية دايمًا.
/// 3. قائمة "المحذوفات" → معايدة مباشرة.
/// 4. المودل → معايدة إذا الاحتمال ≥ العتبة.
class ScanPipeline {
  ScanPipeline({
    required this.store,
    required this.faces,
    required this.scorer,
    this.threshold = AppConfig.greetingThreshold,
    HashFunction? hasher,
  }) : _hash = hasher ?? _hashInBackground;

  final DecisionStore store;
  final FaceChecker faces;
  final GreetingScorer scorer;
  final double threshold;
  final HashFunction _hash;

  /// يفحص الصور وحدة وحدة. إلغاء الاشتراك بالـ Stream بيوقف الفحص.
  Stream<ScanProgress> run(List<ScanCandidate> candidates) async* {
    final stats = ScanStats();
    final total = candidates.length;
    for (final candidate in candidates) {
      ScanMatch? match;
      try {
        match = await _check(candidate, stats);
      } catch (_) {
        stats.failed++;
      }
      stats.processed++;
      yield ScanProgress(total: total, stats: stats, match: match);
    }
  }

  Future<ScanMatch?> _check(ScanCandidate candidate, ScanStats stats) async {
    final thumb = await candidate.thumbnailBytes();
    if (thumb == null) {
      stats.failed++;
      return null;
    }
    final hash = await _hash(thumb);
    if (hash == null) {
      stats.failed++;
      return null;
    }

    // 1. المستخدم قال قبل إنها مش معايدة.
    if (store.matches(hash, Decision.kept)) {
      stats.skippedKept++;
      return null;
    }

    // 2. الوجوه محمية دايمًا — حتى لو كانت معايدة.
    final path = await candidate.filePath();
    if (await faces.hasFaceOrUnknown(path)) {
      stats.protectedFaces++;
      return null;
    }

    // 3. شبه معايدة انمسحت قبل.
    if (store.matches(hash, Decision.deleted)) {
      stats.learned++;
      return ScanMatch(
        candidate: candidate,
        hash: hash,
        reason: MatchReason.learned,
        score: 1,
      );
    }

    // 4. المودل.
    if (!scorer.isAvailable) return null;
    final score = await scorer.score(thumb);
    if (score != null && score >= threshold) {
      stats.model++;
      return ScanMatch(
        candidate: candidate,
        hash: hash,
        reason: MatchReason.model,
        score: score,
      );
    }
    return null;
  }
}

extension on FaceChecker {
  /// بدون مسار ما بنقدر نتأكد — فالأسلم نعتبرها محمية.
  Future<bool> hasFaceOrUnknown(String? path) async =>
      path == null ? true : await hasFace(path);
}
