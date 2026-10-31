"""Generate lib/ui/auth/truck_art.dart from branding/truck_source.svg.

Run from anywhere:  python tool/gen_truck_art.py

Splits the illustrations into the layers the login screen animates separately:
the scenery and the driver come from truck_source.svg, the vehicle from
van_source.svg. The van logo is drawn from assets/images/van_logo.png.
"""
import math
import os
import re
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
SOURCE = os.path.join(PROJ, "branding", "truck_source.svg")
VAN = os.path.join(PROJ, "branding", "van_source.svg")
TARGET = os.path.join(PROJ, "lib", "ui", "auth", "truck_art.dart")

NS = "{http://www.w3.org/2000/svg}"
TRUCK_FROM = "FF725E"
TRUCK_TO = "FF7460"
CLOUD_STARTS = ("M669.33,62", "M706.55,180", "M105.41,63.5", "M723.41,133.17", "M211.72,84.75")
NUMBER = re.compile(r"[-+]?(?:\d*\.\d+|\d+)")


def style_value(element, key):
    match = re.search(rf"{key}:([^;\"]+)", element.get("style") or "")
    return match.group(1) if match else None


def color_of(element, inherited_opacity):
    fill = style_value(element, "fill") or element.get("fill") or "#000000"
    fill = "FFFFFF" if fill == "white" else fill.lstrip("#").upper()
    if len(fill) == 3:
        fill = "".join(ch * 2 for ch in fill)
    if fill == TRUCK_FROM:
        fill = TRUCK_TO
    alpha = round(255 * inherited_opacity)
    return f"0x{alpha:02X}{fill}"


def matrix_of(element):
    """translate(a b) rotate(deg) as a point mapper; identity when absent."""
    transform = element.get("transform")
    if not transform:
        return lambda x, y: (x, y)
    tx, ty, deg = (float(v) for v in NUMBER.findall(transform)[:3])
    cos, sin = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return lambda x, y: (x * cos - y * sin + tx, x * sin + y * cos + ty)


def fmt(value):
    return f"{value:.2f}".rstrip("0").rstrip(".")


def polygon(points):
    head, *rest = points
    body = "L".join(f"{fmt(x)},{fmt(y)}" for x, y in rest)
    return f"M{fmt(head[0])},{fmt(head[1])}L{body}Z"


def path_of(element):
    tag = element.tag.replace(NS, "")
    if tag == "path":
        return element.get("d")
    if tag == "rect":
        x, y, w, h = (float(element.get(k)) for k in ("x", "y", "width", "height"))
        apply = matrix_of(element)
        return polygon([apply(x, y), apply(x + w, y), apply(x + w, y + h), apply(x, y + h)])
    if tag == "circle":
        cx, cy, r = (float(element.get(k)) for k in ("cx", "cy", "r"))
        cx, cy = matrix_of(element)(cx, cy)
        a, b, c = fmt(cx - r), fmt(cx + r), fmt(cy)
        return f"M{a},{c}A{fmt(r)},{fmt(r)},0,1,0,{b},{c}A{fmt(r)},{fmt(r)},0,1,0,{a},{c}Z"
    if tag in ("polygon", "polyline"):
        values = [float(v) for v in NUMBER.findall(element.get("points"))]
        return polygon(list(zip(values[0::2], values[1::2])))
    raise ValueError(f"Unsupported element: {tag}")


def shapes_of(element, opacity=1.0):
    """Flatten one child (possibly an opacity group) into (color, path) pairs."""
    if element.tag == f"{NS}g":
        opacity *= float(style_value(element, "opacity") or 1)
        return [shape for child in element for shape in shapes_of(child, opacity)]
    return [(color_of(element, opacity), path_of(element))]


def pick(group, *ranges):
    children = list(group)
    selected = []
    for item in ranges:
        indexes = range(item[0], item[1] + 1) if isinstance(item, tuple) else [item]
        for index in indexes:
            selected.extend(shapes_of(children[index]))
    return selected


def dart_list(name, shapes):
    lines = [f"const {name} = <ArtShape>["]
    lines += [f"  ArtShape({color}, '{path}')," for color, path in shapes]
    lines.append("];")
    return "\n".join(lines)


def main():
    background, _floor, plants, _truck, character = list(ET.parse(SOURCE).getroot())
    van = list(ET.parse(VAN).getroot())

    clouds, buildings = [], []
    for child in background:
        target = clouds if (child.get("d") or "").startswith(CLOUD_STARTS) else buildings
        target.extend(shapes_of(child))

    layers = {
        "artClouds": clouds,
        "artBuildings": buildings,
        "artPlants": [shape for child in plants for shape in shapes_of(child)],
        # Body, bumpers and glass: behind the driver.
        "artVanBack": pick(van, (1, 6)),
        # Window frame, pillar, handles, rail, side window and mirror: in front of the driver.
        "artVanMiddle": pick(van, (7, 22)),
        "artVanRearWheel": pick(van, (23, 27)),
        "artVanFrontWheel": pick(van, (28, 32)),
        # Outlines, headlight and lettering: over the wheels. Index 44 is the logo image.
        "artVanTop": pick(van, (33, 43), 45, 46),
        "artDriverTorso": pick(character, 25, 26),
        "artDriverHead": pick(character, (27, 48)),
    }

    parts = [
        "// مولَّد من branding/truck_source.svg عبر tool/gen_truck_art.py — لا تعدّله يدوياً.",
        "",
        "class ArtShape {",
        "  const ArtShape(this.color, this.path);",
        "",
        "  final int color;",
        "  final String path;",
        "}",
    ]
    for name, shapes in layers.items():
        parts += ["", dart_list(name, shapes)]

    with open(TARGET, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(parts) + "\n")
    print({name: len(shapes) for name, shapes in layers.items()})


if __name__ == "__main__":
    main()
