"""تدريب مصنّف المعايدات (MobileNetV3-Small، نقل تعلّم).

شكل البيانات:
    dataset/
      greeting/   صور معايدات (صباح الخير، جمعة مباركة، تهاني…)
      normal/     صور عادية (build_normal.py + صورك الخاصة)

    python train.py --data dataset --epochs 30

المخرج: output/greeting_classifier.keras — مدخله صورة 224×224 RGB بقيم
0..255 (التطبيع جوّا المودل)، ومخرجه [1, 1] = احتمال إنها معايدة.
"""

import argparse
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow import keras

HERE = Path(__file__).parent
IMG = 224
CLASSES = ["normal", "greeting"]  # الترتيب مهم: greeting = 1


def load(data: Path, batch: int, val_split: float, seed: int):
    common = dict(
        directory=data,
        labels="inferred",
        label_mode="binary",
        class_names=CLASSES,
        image_size=(IMG, IMG),
        batch_size=batch,
        validation_split=val_split,
        seed=seed,
    )
    train = keras.utils.image_dataset_from_directory(subset="training", **common)
    val = keras.utils.image_dataset_from_directory(subset="validation", **common)
    return train.prefetch(tf.data.AUTOTUNE), val.prefetch(tf.data.AUTOTUNE)


def class_weights(data: Path) -> dict:
    counts = [sum(1 for p in (data / c).iterdir() if p.is_file()) for c in CLASSES]
    total = sum(counts)
    print("عدد الصور:", dict(zip(CLASSES, counts)))
    return {i: total / (len(counts) * n) for i, n in enumerate(counts)}


def build() -> tuple[keras.Model, keras.Model]:
    augment = keras.Sequential(
        [
            keras.layers.RandomFlip("horizontal"),
            keras.layers.RandomRotation(0.05),
            keras.layers.RandomZoom(0.15),
            keras.layers.RandomContrast(0.2),
        ],
        name="augment",
    )
    base = keras.applications.MobileNetV3Small(
        input_shape=(IMG, IMG, 3),
        include_top=False,
        weights="imagenet",
        include_preprocessing=True,  # بياخد 0..255 مباشرة
    )
    base.trainable = False

    inputs = keras.Input((IMG, IMG, 3))
    x = augment(inputs)
    x = base(x, training=False)
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.3)(x)
    outputs = keras.layers.Dense(1, activation="sigmoid", name="greeting")(x)
    return keras.Model(inputs, outputs), base


def report(model: keras.Model, val, threshold: float) -> None:
    y_true, y_prob = [], []
    for x, y in val:
        y_true.append(y.numpy().ravel())
        y_prob.append(model.predict(x, verbose=0).ravel())
    y_true = np.concatenate(y_true)
    y_prob = np.concatenate(y_prob)
    pred = y_prob >= threshold
    tp = int(np.sum(pred & (y_true == 1)))
    fp = int(np.sum(pred & (y_true == 0)))
    fn = int(np.sum(~pred & (y_true == 1)))
    precision = tp / max(tp + fp, 1)
    recall = tp / max(tp + fn, 1)
    print(f"\nعند العتبة {threshold}: دقة (precision) {precision:.3f}، استرجاع (recall) {recall:.3f}")
    print(f"صور عادية انعلّمت غلط: {fp}، معايدات فاتت: {fn}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", type=Path, default=HERE / "dataset")
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--fine-tune-epochs", type=int, default=10)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--val-split", type=float, default=0.2)
    ap.add_argument("--threshold", type=float, default=0.7, help="نفس AppConfig.greetingThreshold")
    ap.add_argument("--out", type=Path, default=HERE / "output" / "greeting_classifier.keras")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    train, val = load(args.data, args.batch, args.val_split, args.seed)
    weights = class_weights(args.data)
    model, base = build()
    metrics = [keras.metrics.BinaryAccuracy(name="acc"), keras.metrics.Precision(name="precision"), keras.metrics.Recall(name="recall")]
    stop = keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)

    # المرحلة 1: الرأس بس.
    model.compile(optimizer=keras.optimizers.Adam(1e-3), loss="binary_crossentropy", metrics=metrics)
    model.fit(train, validation_data=val, epochs=args.epochs, class_weight=weights, callbacks=[stop])

    # المرحلة 2: ضبط ناعم لآخر طبقات القاعدة.
    if args.fine_tune_epochs > 0:
        base.trainable = True
        for layer in base.layers[:-30]:
            layer.trainable = False
        for layer in base.layers:
            if isinstance(layer, keras.layers.BatchNormalization):
                layer.trainable = False
        model.compile(optimizer=keras.optimizers.Adam(1e-5), loss="binary_crossentropy", metrics=metrics)
        model.fit(train, validation_data=val, epochs=args.fine_tune_epochs, class_weight=weights, callbacks=[stop])

    report(model, val, args.threshold)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    model.save(args.out)
    print(f"\nانحفظ المودل: {args.out}\nالخطوة الجاية: python export.py")


if __name__ == "__main__":
    main()
