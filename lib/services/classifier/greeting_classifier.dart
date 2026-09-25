import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../config.dart';
import '../image_hash.dart';
import '../scan_pipeline.dart';

/// مصنّف المعايدات بمودل TFLite.
///
/// التشغيل نفسه بخيط معزول (IsolateInterpreter)، وتجهيز الصورة (فك +
/// تصغير) كمان بـ Isolate منفصل، فالواجهة ما بتعلّق.
///
/// شكل المودل المتوقع (من `training/export.py`):
/// - مدخل `[1, 224, 224, 3]` float32 بقيم بكسلات خام 0..255
///   (التطبيع جوّا المودل)، أو uint8 للمودلات المكمّمة كليًا.
/// - مخرج `[1, 1]` = احتمال معايدة، أو `[1, 2]` = [عادية، معايدة].
class TfliteGreetingClassifier implements GreetingScorer {
  TfliteGreetingClassifier._(
    this._interpreter,
    this._isolate,
    this._inputSize,
    this._uint8Input,
    this._outputShape,
  );

  final Interpreter _interpreter;
  final IsolateInterpreter _isolate;
  final int _inputSize;
  final bool _uint8Input;
  final List<int> _outputShape;

  /// يحمّل المودل من الأصول. يرجع null إذا الملف مش موجود أو خربان —
  /// والتطبيق بيكمّل بوضع "التعلم من المحذوفات" بس.
  static Future<TfliteGreetingClassifier?> load({
    String asset = AppConfig.modelAsset,
  }) async {
    try {
      final data = await rootBundle.load(asset);
      final interpreter = Interpreter.fromBuffer(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        options: InterpreterOptions()..threads = 2,
      );
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      final isolate = await IsolateInterpreter.create(
        address: interpreter.address,
      );
      return TfliteGreetingClassifier._(
        interpreter,
        isolate,
        input.shape.length == 4 ? input.shape[1] : AppConfig.modelInputSize,
        input.type == TensorType.uint8,
        output.shape,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool get isAvailable => true;

  @override
  Future<double?> score(Uint8List imageBytes) async {
    final size = _inputSize;
    final uint8 = _uint8Input;
    final input = await Isolate.run(() => preprocess(imageBytes, size, uint8));
    if (input == null) return null;

    final classes = _outputShape.isEmpty ? 1 : _outputShape.last;
    final output = [List<double>.filled(classes, 0)];
    await _isolate.run(input, output);
    final values = output.first;
    final p = classes >= 2 ? values[1] : values[0];
    return p.clamp(0.0, 1.0).toDouble();
  }

  /// يفك الصورة ويصغّرها لمربع ويرجع بايتات المدخل.
  static ByteBuffer? preprocess(Uint8List bytes, int size, bool uint8) {
    final decoded = ImageHash.safeDecode(bytes);
    if (decoded == null) return null;
    final resized = img.copyResize(
      decoded,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    final count = size * size * 3;
    if (uint8) {
      final out = Uint8List(count);
      var i = 0;
      for (final px in resized) {
        out[i++] = px.r.toInt();
        out[i++] = px.g.toInt();
        out[i++] = px.b.toInt();
      }
      return out.buffer;
    }
    final out = Float32List(count);
    var i = 0;
    for (final px in resized) {
      out[i++] = px.r.toDouble();
      out[i++] = px.g.toDouble();
      out[i++] = px.b.toDouble();
    }
    return out.buffer;
  }

  Future<void> close() async {
    await _isolate.close();
    _interpreter.close();
  }
}

/// بديل لما المودل مش موجود.
class NoModelScorer implements GreetingScorer {
  const NoModelScorer();

  @override
  bool get isAvailable => false;

  @override
  Future<double?> score(Uint8List imageBytes) async => null;
}
