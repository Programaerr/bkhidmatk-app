"""Patch the freshly generated android/ folder for «بخدمتك».

Run from anywhere:  python tool/patch_android.py
The project root is inferred from this file's location, so it also works
on the GitHub Actions Linux runner.
"""
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
AND = os.path.join(PROJ, "android")
MAIN = os.path.join(AND, "app", "src", "main")
BRAND = os.path.join(PROJ, "branding")
LABEL = "بخدمتك"


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)


def log(*a):
    try:
        print(*a)
    except Exception:
        print(" ".join(str(x).encode("ascii", "replace").decode("ascii") for x in a))


if not os.path.isdir(AND):
    log("android/ not found - run flutter create first")
    sys.exit(1)

# ---------------- AndroidManifest ----------------
mp = os.path.join(MAIN, "AndroidManifest.xml")
if not os.path.exists(mp):
    log("manifest missing")
    sys.exit(1)

m = read(mp)

perm = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.VIBRATE"/>

    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.SENDTO"/>
            <data android:scheme="smsto"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.SEND"/>
            <data android:mimeType="*/*"/>
        </intent>
    </queries>
"""

# idempotent: drop a previous injected block
m = re.sub(r"\n?\s*<uses-permission[^>]*/>\n?", "\n", m)
m = re.sub(r"\n?\s*<queries>.*?</queries>\n?", "\n", m, flags=re.S)

m = re.sub(
    r"<manifest([^>]*)>",
    lambda mo: "<manifest" + mo.group(1) + ">" + perm,
    m,
    count=1,
)
m = re.sub(r'android:label="[^"]*"', f'android:label="{LABEL}"', m, count=1)
if "android:label=" not in m:
    m = m.replace("<application", f'<application\n        android:label="{LABEL}"', 1)

write(mp, m)
log("manifest patched")

# ---------------- launch colours ----------------
colors = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="launch_bg">#FFD400</color>
    <color name="launch_bg_dark">#0B0B0D</color>
</resources>
"""
write(os.path.join(MAIN, "res", "values", "colors.xml"), colors)

for night, color in ((False, "@color/launch_bg"), (True, "@color/launch_bg_dark")):
    folder = os.path.join(MAIN, "res", "values-night" if night else "values")
    sp = os.path.join(folder, "styles.xml")
    if not os.path.exists(sp):
        continue
    s = read(sp)
    s = s.replace("@drawable/launch_background", color)
    s = s.replace("@android:color/white", color)
    write(sp, s)
    log("styles patched:", os.path.basename(folder))

# ---------------- launcher icons ----------------
if os.path.isdir(BRAND):
    for d in os.listdir(BRAND):
        src_dir = os.path.join(BRAND, d)
        if not (d.startswith("mipmap-") and os.path.isdir(src_dir)):
            continue
        dst_dir = os.path.join(MAIN, "res", d)
        os.makedirs(dst_dir, exist_ok=True)
        for f in os.listdir(src_dir):
            shutil.copyfile(os.path.join(src_dir, f), os.path.join(dst_dir, f))
    log("icons copied")

# ---------------- gradle: minSdk 23 ----------------
for name in ("build.gradle.kts", "build.gradle"):
    gp = os.path.join(AND, "app", name)
    if not os.path.exists(gp):
        continue
    g = read(gp)
    if name.endswith(".kts"):
        g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(23, flutter.minSdkVersion)", g)
    else:
        g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", g)
    write(gp, g)
    log("gradle patched:", gp)

# ---------------- JVM memory ----------------
gprops = os.path.join(AND, "gradle.properties")
if os.path.exists(gprops):
    gp = read(gprops)
    if "org.gradle.jvmargs" in gp:
        gp = re.sub(r"org\.gradle\.jvmargs=.*", "org.gradle.jvmargs=-Xmx3072m -XX:MaxMetaspaceSize=1024m", gp)
    else:
        gp += "\norg.gradle.jvmargs=-Xmx3072m -XX:MaxMetaspaceSize=1024m\n"
    write(gprops, gp)
    log("gradle.properties patched")

log("DONE")
