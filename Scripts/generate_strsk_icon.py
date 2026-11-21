"""Render the original STRSK mark and iOS icon variants. Requires Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw


def mark(canvas, foreground):
    """Draw cut bars forming an angular S, with a small offset accent."""
    scale = canvas.width / 1024
    draw = ImageDraw.Draw(canvas)
    paths = (
        ((178, 373), (402, 192), (797, 192), (725, 293), (442, 293), (308, 399), (659, 399),
         (844, 547), (738, 634), (619, 523), (375, 523)),
        ((180, 660), (288, 572), (410, 679), (655, 679), (733, 615), (844, 704),
         (696, 824), (223, 824), (300, 718)),
    )
    for path in paths:
        draw.polygon([(round(x * scale), round(y * scale)) for x, y in path], fill=foreground)


assets = Path(__file__).resolve().parents[1] / "Luma" / "Assets.xcassets"
for variant, background, foreground in (
    ("Light", "#16171A", "#DAFF60"),
    ("Dark", "#0A0B0D", "#DAFF60"),
    ("Tinted", "#191919", "#EEEEEE"),
):
    icon = Image.new("RGB", (2048, 2048), background)
    mark(icon, foreground)
    icon.resize((1024, 1024), Image.Resampling.LANCZOS).save(
        assets / "AppIcon.appiconset" / f"AppIcon-{variant}.png",
        optimize=True,
    )

mark_set = assets / "STRSKMark.imageset"
mark_set.mkdir(exist_ok=True)
logo = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
mark(logo, "#DAFF60")
logo.resize((256, 256), Image.Resampling.LANCZOS).save(mark_set / "STRSKMark.png", optimize=True)
