"""تحويل المودل المدرّب لـ TFLite وكتابته بـ assets/models/ مباشرة.

    python export.py

التكميم ديناميكي (الأوزان int8، المدخل والمخرج float32) — حجم أصغر ~4 مرات
بدون ما يتغير شكل المدخل اللي التطبيق بيتوقعه.
"""

import argparse
import tempfile
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow import keras

HERE = Path(__file__).parent
DEFAULT_OUT = HERE.parent / "assets" / "models" / "greeting_classifier.tflite"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", type=Path, default=HERE / "output" / "greeting_classifier.keras")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--no-quantize", action="store_true", help="بدون تكميم (float32 كامل)")
    args = ap.parse_args()

    model = keras.models.load_model(args.model)

    # Keras 3: التصدير عبر SavedModel أضمن من from_keras_model.
    with tempfile.TemporaryDirectory() as tmp:
        model.export(tmp)
        converter = tf.lite.TFLiteConverter.from_saved_model(tmp)
        if not args.no_quantize:
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite = converter.convert()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(tflite)

    # تحقق سريع: نفس الشكل اللي التطبيق بيتوقعه.
    interp = tf.lite.Interpreter(model_content=tflite)
    interp.allocate_tensors()
    inp = interp.get_input_details()[0]
    out = interp.get_output_details()[0]
    assert list(inp["shape"]) == [1, 224, 224, 3], inp["shape"]
    assert out["shape"][-1] in (1, 2), out["shape"]
    interp.set_tensor(inp["index"], np.random.uniform(0, 255, inp["shape"]).astype(inp["dtype"]))
    interp.invoke()
    p = float(interp.get_tensor(out["index"]).ravel()[-1])
    assert 0.0 <= p <= 1.0, p

    print(f"انكتب {args.out} ({args.out.stat().st_size / 1e6:.1f} MB)")
    print(f"مدخل {list(inp['shape'])} {inp['dtype'].__name__}، مخرج {list(out['shape'])}")


if __name__ == "__main__":
    main()
