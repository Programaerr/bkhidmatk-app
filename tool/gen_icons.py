"""توليد كل أيقونات التطبيق وشعاره من صورة الشعار الجديدة (branding/logo_source.jpg).

الشعار أصفر على خلفية سوداء، فتكون خلفية كل الأيقونات سوداء وتوضع كلمة «جايك» في وسطها بقياس
يناسب كل منصة، دون قص أي جزء منها:
- أندرويد: القديمة المربعة والدائرية، والتكيفية (الطبقة الأمامية داخل منطقة الأمان 66/108).
- آيفون وماك: كل المقاسات من Contents.json (آيفون بلا شفافية).
- الويب: 192 و512 و«maskable» والأيقونة الصغيرة.
- ويندوز: app_icon.ico.
- شاشة البدء في أندرويد، وشعار داخل التطبيق (assets/images/logo.jpg).

Usage:  python tool/gen_icons.py
"""
import json
import os
import re

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
BRAND = os.path.join(PROJ, "branding")
SRC = os.path.join(BRAND, "logo_source.jpg")
RES = os.path.join(PROJ, "android", "app", "src", "main", "res")

BLACK = (0, 0, 0)
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def artwork(im):
    """الشعار وحده، مقصوصاً على حدوده من الخلفية السوداء."""
    gray = im.convert("L").point(lambda v: 255 if v > 40 else 0)
    box = gray.getbbox()
    return im.crop(box)


def compose(art, size, width_ratio, circle=False, height_ratio=0.62):
    """لوحة سوداء مربعة والشعار في وسطها بعرض width_ratio من عرضها (ولا يتجاوز height_ratio ارتفاعاً)."""
    w, h = art.size
    scale = min(size * width_ratio / w, size * height_ratio / h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    out = Image.new("RGB", (size, size), BLACK)
    out.paste(art.resize((nw, nh), Image.LANCZOS), ((size - nw) // 2, (size - nh) // 2))
    if not circle:
        return out
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    rgba = out.convert("RGBA")
    rgba.putalpha(mask.resize((size, size), Image.LANCZOS))
    return rgba


def save(img, *path, **kwargs):
    target = os.path.join(PROJ, *path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    img.save(target, **kwargs)


def main():
    art = artwork(Image.open(SRC).convert("RGB"))
    print("artwork", art.size)

    # --- أندرويد ---
    for dens, size in LEGACY.items():
        d = os.path.join("android", "app", "src", "main", "res", f"mipmap-{dens}")
        save(compose(art, size, 0.84), d, "ic_launcher.png")
        save(compose(art, size, 0.66, circle=True), d, "ic_launcher_round.png")
    for dens, size in ADAPTIVE.items():
        d = os.path.join("android", "app", "src", "main", "res", f"mipmap-{dens}")
        # داخل دائرة الأمان 66/108 مهما كان قناع المشغّل
        save(compose(art, size, 0.54, height_ratio=0.40), d, "ic_launcher_foreground.png")
    colors = os.path.join(RES, "values", "colors.xml")
    text = open(colors, encoding="utf-8").read()
    text = re.sub(r'(<color name="ic_launcher_background">)[^<]*(</color>)', r"\g<1>#000000\g<2>", text)
    text = re.sub(r'(<color name="launch_bg">)[^<]*(</color>)', r"\g<1>#000000\g<2>", text)
    open(colors, "w", encoding="utf-8", newline="\n").write(text)

    # شاشة البدء: خلفية سوداء والشعار في وسطها
    save(compose(art, 720, 0.70, height_ratio=0.40), "android", "app", "src", "main", "res",
         "drawable-nodpi", "launch_logo.png")
    launch = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@color/launch_bg" />\n'
        '    <item>\n'
        '        <bitmap android:gravity="center" android:src="@drawable/launch_logo" />\n'
        '    </item>\n'
        '</layer-list>\n'
    )
    for d in ("drawable", "drawable-v21"):
        with open(os.path.join(RES, d, "launch_background.xml"), "w", encoding="utf-8", newline="\n") as f:
            f.write(launch)

    # --- آيفون ---
    ios = os.path.join("ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for name in os.listdir(os.path.join(PROJ, ios)):
        m = re.match(r"Icon-App-([\d.]+)x[\d.]+@(\d)x\.png", name)
        if m:
            px = round(float(m.group(1)) * int(m.group(2)))
            save(compose(art, px, 0.80), ios, name)  # RGB بلا شفافية، كما تشترط آبل

    # --- ماك ---
    mac = os.path.join("macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(os.path.join(PROJ, mac)):
        for name in os.listdir(os.path.join(PROJ, mac)):
            m = re.match(r"app_icon_(\d+)\.png", name)
            if m:
                save(compose(art, int(m.group(1)), 0.76), mac, name)

    # --- الويب ---
    save(compose(art, 192, 0.84), "web", "icons", "Icon-192.png")
    save(compose(art, 512, 0.84), "web", "icons", "Icon-512.png")
    save(compose(art, 192, 0.62, height_ratio=0.40), "web", "icons", "Icon-maskable-192.png")
    save(compose(art, 512, 0.62, height_ratio=0.40), "web", "icons", "Icon-maskable-512.png")
    save(compose(art, 64, 0.88), "web", "favicon.png")
    manifest = os.path.join(PROJ, "web", "manifest.json")
    data = json.load(open(manifest, encoding="utf-8"))
    data["background_color"] = "#000000"
    data["theme_color"] = "#000000"
    json.dump(data, open(manifest, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=4)

    # --- ويندوز ---
    ico = compose(art, 256, 0.80)
    ico.save(os.path.join(PROJ, "windows", "runner", "resources", "app_icon.ico"),
             sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    # --- شعار داخل التطبيق: الشاشة الأولى والوصل والأعمال ---
    save(compose(art, 512, 0.80), "assets", "images", "logo.jpg", quality=94)
    print("DONE")


if __name__ == "__main__":
    main()
