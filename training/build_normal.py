"""تجهيز كلاس الصور العادية (normal) من صور COCO val2017.

بينزّل أرشيف COCO val2017 (~800MB، مرة وحدة بس، بينحفظ بـ cache/)،
وبياخد عينة عشوائية ويصغّرها ويحطها بـ dataset/normal/.

    python build_normal.py --count 3000
"""

import argparse
import io
import random
import zipfile
from pathlib import Path

import requests
from PIL import Image
from tqdm import tqdm

COCO_URL = "http://images.cocodataset.org/zips/val2017.zip"
HERE = Path(__file__).parent


def download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".part")
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        total = int(r.headers.get("content-length", 0))
        with open(tmp, "wb") as f, tqdm(total=total, unit="B", unit_scale=True, desc="COCO") as bar:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
                bar.update(len(chunk))
    tmp.rename(dest)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--count", type=int, default=3000, help="كم صورة عادية")
    ap.add_argument("--out", type=Path, default=HERE / "dataset" / "normal")
    ap.add_argument("--size", type=int, default=256, help="أطول ضلع بعد التصغير")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    archive = HERE / "cache" / "val2017.zip"
    download(COCO_URL, archive)

    args.out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        names = [n for n in z.namelist() if n.lower().endswith(".jpg")]
        random.Random(args.seed).shuffle(names)
        for name in tqdm(names[: args.count], desc="normal"):
            with Image.open(io.BytesIO(z.read(name))) as im:
                im = im.convert("RGB")
                im.thumbnail((args.size, args.size))
                im.save(args.out / f"coco_{Path(name).stem}.jpg", quality=90)

    print(f"جاهز: {len(list(args.out.glob('*.jpg')))} صورة بـ {args.out}")


if __name__ == "__main__":
    main()
