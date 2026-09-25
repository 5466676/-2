// يولّد لقطات شاشة للواجهات الحقيقية ببيانات تجريبية.
//
//   flutter test tool/screenshots_test.dart --update-goldens \
//     --dart-define=FONTS_DIR=/path/to/fonts
//
// FONTS_DIR لازم يحتوي ar400.ttf و ar500.ttf و ar700.ttf (Noto Sans Arabic).
// اللقطات بتنكتب بـ docs/screenshots/.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greeting_cleaner/main.dart';
import 'package:greeting_cleaner/services/gallery_service.dart';
import 'package:greeting_cleaner/services/hash_store.dart';
import 'package:greeting_cleaner/services/scan_pipeline.dart';
import 'package:greeting_cleaner/state/cleaner_controller.dart';
import 'package:provider/provider.dart';

const _fontsDir = String.fromEnvironment('FONTS_DIR');

class _Candidate implements ScanCandidate {
  _Candidate(this.id, this.bytes);

  @override
  final String id;
  final Uint8List bytes;

  @override
  Future<Uint8List?> thumbnailBytes() async => bytes;

  @override
  Future<String?> filePath() async => id;
}

class _Gallery extends GalleryService {
  _Gallery(this.images);

  final List<ScanCandidate> images;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<ScanCandidate>> imagesForMonth(int year, int month) async =>
      images;

  @override
  Future<List<String>> delete(List<ScanCandidate> candidates) async =>
      candidates.map((c) => c.id).toList();
}

class _Faces implements FaceChecker {
  @override
  Future<bool> hasFace(String path) async => path.startsWith('face');
}

class _Scorer implements GreetingScorer {
  @override
  bool get isAvailable => true;

  @override
  Future<double?> score(Uint8List imageBytes) async =>
      _scores[imageBytes.lengthInBytes] ?? 0.1;
}

final _scores = <int, double>{};

const _greetings = [
  'صباح الخير',
  'جمعة مباركة',
  'مساء الورد',
  'عيد مبارك',
  'رمضان كريم',
  'تصبحون على خير',
  'صباح الفل',
  'كل عام وأنتم بخير',
];

Future<Uint8List> _render(
  void Function(Canvas c, Size s) paint, {
  Size size = const Size(256, 256),
}) async {
  final rec = ui.PictureRecorder();
  paint(Canvas(rec), size);
  final image = await rec
      .endRecording()
      .toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Uint8List> _greeting(int i, Random r) => _render((c, s) {
      final hue = (i * 47.0) % 360;
      final rect = Offset.zero & s;
      c.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HSVColor.fromAHSV(1, hue, 0.55, 0.98).toColor(),
              HSVColor.fromAHSV(1, (hue + 50) % 360, 0.8, 0.7).toColor(),
            ],
          ).createShader(rect),
      );
      // ورود
      for (var k = 0; k < 7; k++) {
        final center = Offset(r.nextDouble() * 256, 150 + r.nextDouble() * 110);
        final petal = HSVColor.fromAHSV(1, r.nextDouble() * 360, 0.7, 1)
            .toColor();
        for (var p = 0; p < 5; p++) {
          final a = p * 2 * pi / 5;
          c.drawCircle(center + Offset(cos(a), sin(a)) * 11, 9,
              Paint()..color = petal);
        }
        c.drawCircle(center, 6, Paint()..color = Colors.yellow.shade600);
      }
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        fontFamily: 'Roboto',
        fontSize: 34,
        fontWeight: FontWeight.w700,
      ))
        ..pushStyle(ui.TextStyle(
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 6, offset: Offset(1, 2))],
        ))
        ..addText(_greetings[i % _greetings.length]);
      final para = pb.build()..layout(const ui.ParagraphConstraints(width: 236));
      c.drawParagraph(para, const Offset(10, 40));
    });

Future<Uint8List> _photo(int i, Random r) => _render((c, s) {
      final rect = Offset.zero & s;
      c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6EC6FF), Color(0xFFE3F2FD)],
          ).createShader(rect),
      );
      c.drawCircle(Offset(60 + r.nextDouble() * 140, 70), 26,
          Paint()..color = const Color(0xFFFFE082));
      final ground = Path()
        ..moveTo(0, 170 + r.nextDouble() * 30)
        ..quadraticBezierTo(128, 120 + r.nextDouble() * 40, 256, 180)
        ..lineTo(256, 256)
        ..lineTo(0, 256)
        ..close();
      c.drawPath(ground, Paint()..color = Color.lerp(
          const Color(0xFF558B2F), const Color(0xFF8D6E63), r.nextDouble())!);
    });

Future<void> _loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final w in ['ar400', 'ar500', 'ar700']) {
    final bytes = File('$_fontsDir/$w.ttf').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons))))
      .load();
}

Future<void> _settleImages(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      await precacheImage((el.widget as Image).image, el);
    }
  });
  await tester.pump();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settleImages(tester);
  await expectLater(
    find.byType(GreetingCleanerApp),
    matchesGoldenFile('../docs/screenshots/$name.png'),
  );
}

void main() {
  testWidgets('screenshots', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final candidates = <ScanCandidate>[];
    await tester.runAsync(() async {
      await _loadFonts();
      final r = Random(7);
      for (var i = 0; i < 44; i++) {
        final isGreeting = i % 11 != 3 && i % 11 != 8;
        final bytes = isGreeting ? await _greeting(i, r) : await _photo(i, r);
        final id = i % 13 == 5 ? 'face$i' : 'img$i';
        _scores[bytes.lengthInBytes] =
            isGreeting ? 0.72 + r.nextDouble() * 0.27 : 0.1;
        candidates.add(_Candidate(id, bytes));
      }
    });

    final gate = Completer<void>();
    var hashed = 0;
    final store = DecisionStore(maxDistance: 0);
    await store.record(Decision.deleted, [1]); // الصورة الأولى "متعلَّمة"
    await store.record(Decision.kept, [9]);
    final controller = CleanerController(
      gallery: _Gallery(candidates),
      store: store,
      pipeline: ScanPipeline(
        store: store,
        faces: _Faces(),
        scorer: _Scorer(),
        hasher: (b) async {
          hashed++;
          if (hashed == 27) await gate.future;
          return hashed;
        },
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const GreetingCleanerApp(),
      ),
    );
    await _shot(tester, '1_permission');

    await controller.requestPermission();
    await _shot(tester, '2_pick_month');

    unawaited(controller.startScan(2026, 9));
    for (var i = 0; i < 60; i++) {
      await tester.pump();
    }
    await _shot(tester, '3_scanning');

    gate.complete();
    for (var i = 0; i < 60; i++) {
      await tester.pump();
    }
    final ids = controller.matches.map((m) => m.candidate.id).toList();
    controller.toggle(ids[4]);
    controller.toggle(ids[9]);
    await _shot(tester, '4_results');

    await tester.longPress(find.byType(GestureDetector).at(2));
    await tester.pumpAndSettle();
    await _shot(tester, '5_viewer');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    await _shot(tester, '6_confirm');

    await tester.tap(find.text('امسح').last);
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await _shot(tester, '7_done');
  });
}
