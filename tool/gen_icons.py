"""توليد أيقونات التطبيق من branding/icon_source.png بدون أي قص.

المصدر: أيقونة الأدوات على خلفية صفراء (115×126 بكسل).
- أيقونات المربع (ic_launcher.png) لكل كثافة: الصورة بالكامل مع تمديد حواف
  الخلفية الصفراء — بدون قطع أي جزء من الصورة.
- الأيقونات الدائرية (ic_launcher_round.png): أندرويد يقصّ الأركان بقناع دائري،
  لذلك تُوضع الأدوات داخل دائرة آمنة (80% مننصف القطر) فلا يُقص منها شيء.
- طبقة الأمان للأيقونات التكيفية (adaptive, أندرويد 8+): الأدوات كاملة داخل
  الدائرة المضمونة 66/108، والخلفية صفراء — أي قناع يستخدمه المشغّل لا يقصّ الأدوات.

Usage:  python tool/gen_icons.py
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
SRC = os.path.join(PROJ, "branding", "icon_source.png")
BRAND = os.path.join(PROJ, "branding")
RES = os.path.join(PROJ, "android", "app", "src", "main", "res")

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# لوحة الأيقونة التكيفية = 108dp لكل كثافة
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

BG = (253, 211, 5)  # لون الخلفية الصفراء #FDD305 (متقارب مع ألوان الصورة)


def ink_bbox(im):
    """حدود الأدوات السوداء داخل الصورة."""
    w, h = im.size
    px = im.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            if (r + g + b) / 3 < 110:
                minx = min(minx, x)
                maxx = max(maxx, x)
                miny = min(miny, y)
                maxy = max(maxy, y)
    return minx, miny, maxx, maxy


def padded_square(im, size):
    """تكبير الصورة طولاً إلى `size` ثم تمديد حواف الخلفية أفقياً — بدون قص."""
    w, h = im.size
    nw = max(1, round(w * size / h))
    up = im.resize((nw, size), Image.LANCZOS)
    out = Image.new("RGB", (size, size), BG)
    px_src = up.load()
    px_out = out.load()
    x0 = (size - nw) // 2
    for y in range(size):
        left = px_src[0, y]
        right = px_src[nw - 1, y]
        for x in range(x0):
            px_out[x, y] = left
        for x in range(x0 + nw, size):
            px_out[x, y] = right
    out.paste(up, (x0, 0))
    return out


def tools_layer(im):
    """استخazen الأدوات السوداء كطبقة شفافة (أسود بشفافية ناعمة)."""
    w, h = im.size
    src = im.convert("RGB")
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sp = src.load()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = sp[x, y]
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            a = (205.0 - lum) / 205.0
            if a <= 0.01:
                continue
            op[x, y] = (0, 0, 0, min(255, int(a * 255)))
    return out


def paste_center(canvas, layer, scale):
    """لصق الطبقة في منتصف اللوحة بالحجم المُقيَّس."""
    w, h = layer.size
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = layer.resize((nw, nh), Image.LANCZOS) if scale != 1.0 else layer
    canvas.alpha_composite(small, (int(canvas.size[0] / 2 - nw / 2),
                                   int(canvas.size[1] / 2 - nh / 2)))


def circle_alpha(size):
    """قناع دائري ناعم الحواف بدقة أعلى ثم تصغير."""
    s = size * 4
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, s - 1, s - 1), fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def main():
    src = Image.open(SRC).convert("RGB")
    bbox = ink_bbox(src)
    ink_cx = (bbox[0] + bbox[2]) / 2.0
    ink_cy = (bbox[1] + bbox[3]) / 2.0
    ink_half = max(
        ((bx - ink_cx) ** 2 + (by - ink_cy) ** 2) ** 0.5
        for bx in (bbox[0], bbox[2])
        for by in (bbox[1], bbox[3])
    )
    tools = tools_layer(src)

    # إزاحة مركز الأدوات عن مركز الصورة (لصقها في منتصف اللوحة الجديدة بدقة)
    # paste_center تفترض مركز الطبقة = مركز اللوحة، لذا نُنشئ طبقة بإزاحة محسوبة:
    off_x = ink_cx - src.size[0] / 2.0
    off_y = ink_cy - src.size[1] / 2.0
    if abs(off_x) > 0.5 or abs(off_y) > 0.5:
        shifted = Image.new("RGBA", src.size, (0, 0, 0, 0))
        shifted.alpha_composite(tools, (int(round(off_x)), int(round(off_y))))
        tools = shifted

    for dens, size in LEGACY.items():
        ddir = os.path.join(BRAND, f"mipmap-{dens}")
        os.makedirs(ddir, exist_ok=True)
        # مربع كامل بدون قص
        padded_square(src, size).save(os.path.join(ddir, "ic_launcher.png"))
        # دائري: خلفية صفراء + الأدوات داخل دائرة آمنة (0.40 من الحجم = 80% مننصف القطر)
        circle = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        yellow = Image.new("RGBA", (size, size), BG + (255,))
        circle.paste(yellow, (0, 0), circle_alpha(size))
        paste_center(circle, tools, 0.40 * size / ink_half)
        circle.save(os.path.join(ddir, "ic_launcher_round.png"))
        print("legacy", dens, size)

    for dens, canvas in ADAPTIVE.items():
        ddir = os.path.join(BRAND, f"mipmap-{dens}")
        os.makedirs(ddir, exist_ok=True)
        # طبقة أمامية شفافة: الأدوات كاملة داخل دائرة الأمان 66/108
        fg = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        paste_center(fg, tools, 0.30 * canvas / ink_half)
        fg.save(os.path.join(ddir, "ic_launcher_foreground.png"))
        print("adaptive fg", dens, canvas)

    # أيقونات أندرويد 8+ (تُنسخ إلى res عبر tool/patch_android.py أيضاً)
    axdir = os.path.join(BRAND, "mipmap-anydpi-v26")
    os.makedirs(axdir, exist_ok=True)
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(axdir, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(xml)
    print("adaptive xml written")

    # شعار داخل التطبيق (مربع كامل بدون قص، 512×512)
    padded_square(src, 512).save(os.path.join(PROJ, "assets", "images", "logo.jpg"), quality=92)
    print("in-app logo written")

    # نسخ كل شيء إلى مجلد res المحلي
    for dens in list(LEGACY) + list(ADAPTIVE):
        sdir = os.path.join(BRAND, f"mipmap-{dens}")
        ddir = os.path.join(RES, f"mipmap-{dens}")
        os.makedirs(ddir, exist_ok=True)
        for f in os.listdir(sdir):
            Image.open(os.path.join(sdir, f)).save(os.path.join(ddir, f))
    axres = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(axres, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(axdir, name), encoding="utf-8") as f, \
                open(os.path.join(axres, name), "w", encoding="utf-8", newline="\n") as g:
            g.write(f.read())
    print("copied to res/")
    print("DONE")


if __name__ == "__main__":
    main()
