"""Compose Reddit PNGs from tracked native screenshots. Requires Pillow on macOS."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
SOURCES = HERE.parent / "screenshots"
OUTPUT = HERE / "images"
FONT_ROOT = Path("/System/Library/Fonts/Supplemental")
WIDTH, HEIGHT = 1600, 1200


def font(size, bold=False):
    name = "Arial Bold.ttf" if bold else "Arial.ttf"
    return ImageFont.truetype(str(FONT_ROOT / name), size)


def label(draw, xy, text, size, color, bold=False):
    face = font(size, bold)
    bounds = draw.textbbox(xy, text, font=face)
    assert bounds[0] >= 0 and bounds[2] <= WIDTH and bounds[3] <= HEIGHT, text
    draw.text(xy, text, font=face, fill=color)


def screenshot(image, name, box):
    source = Image.open(SOURCES / name).convert("RGBA")
    source.thumbnail((box[2], box[3]), Image.Resampling.LANCZOS)
    image.paste(source, box[:2], source)


def overview(dark=False):
    background = "#1B1916" if dark else "#F4F0E8"
    foreground = "#F6F1E8" if dark else "#29261F"
    muted = "#BFB6A9" if dark else "#6B6256"
    accent = "#E8AC60" if dark else "#87531C"
    image = Image.new("RGB", (WIDTH, HEIGHT), background)
    draw = ImageDraw.Draw(image)
    label(draw, (84, 34), "HUSK  /  NATIVE MAC APP", 22, accent, True)
    title = "A closer look at your storage." if dark else "See what fills your Mac."
    label(draw, (80, 78), title, 70, foreground, True)
    label(draw, (84, 170), "Explore folders. Inspect candidates. Review before Trash.", 30, muted)
    name = "storage-map-dark.png" if dark else "storage-map-light.png"
    screenshot(image, name, (84, 250, 1432, 860))
    label(draw, (84, 1143), "REAL APP UI  /  EXAMPLE DATA", 21, accent, True)
    label(draw, (915, 1143), "Experimental. Sizes are estimates.", 24, muted)
    filename = "02-storage-map-dark.png" if dark else "01-storage-map-light.png"
    image.save(OUTPUT / filename, optimize=True)


def review_detail():
    image = Image.new("RGB", (WIDTH, HEIGHT), "#F4F0E8")
    draw = ImageDraw.Draw(image)
    label(draw, (84, 34), "HUSK  /  CLEANUP REVIEW", 22, "#87531C", True)
    label(draw, (80, 78), "Review the actual paths.", 70, "#29261F", True)
    label(draw, (84, 170), "Choose what to move to Trash, with the details in front of you.", 30, "#6B6256")

    steps = [
        ("01", "Inspect the path and risk", ["See which folder is involved", "and why it needs review."]),
        ("02", "Select the items you want", ["Recommendations start unselected.", "You choose what enters the plan."]),
        ("03", "Review, then confirm", ["The next step reviews your selection", "before moving items to Trash."]),
    ]
    for index, (number, title, lines) in enumerate(steps):
        y = 322 + index * 212
        draw.line((84, y - 24, 774, y - 24), fill="#CFC7B9", width=2)
        label(draw, (84, y), number, 25, "#87531C", True)
        label(draw, (150, y - 5), title, 35, "#29261F", True)
        for line_index, line in enumerate(lines):
            label(draw, (150, y + 54 + line_index * 39), line, 28, "#6B6256")

    source = Image.open(SOURCES / "storage-map-light.png").convert("RGBA")
    crop = source.crop((1114, 262, 1570, 929))
    crop = crop.resize((561, 821), Image.Resampling.LANCZOS)
    image.paste(crop, (955, 274), crop)
    label(draw, (84, 999), "Husk does not empty Trash.", 29, "#29261F", True)
    label(draw, (84, 1045), "Space usually frees after you empty it.", 27, "#6B6256")
    label(draw, (84, 1143), "REAL APP UI  /  EXAMPLE DATA", 21, "#87531C", True)
    label(draw, (994, 1143), "Recommendations panel detail", 24, "#6B6256")
    image.save(OUTPUT / "03-review-paths.png", optimize=True)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    overview()
    overview(dark=True)
    review_detail()
    for path in sorted(OUTPUT.glob("*.png")):
        print(f"{path.name}: {Image.open(path).size}, {path.stat().st_size:,} bytes")
