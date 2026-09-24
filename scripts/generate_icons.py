"""Resize the primary icon master and retain the existing alternate palettes."""

import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
assets = root / "ios/Runner/Assets.xcassets"
metadata = json.loads((assets / "AppIcon.appiconset/Contents.json").read_text())


def render_icon(background, foreground):
    canvas = Image.new("RGB", (1024, 1024), background)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((176, 208, 848, 742), radius=142, fill=foreground)
    draw.polygon([(288, 654), (288, 854), (494, 705)], fill=foreground)
    draw.rounded_rectangle((310, 355, 714, 405), radius=25, fill=background)
    draw.rounded_rectangle((310, 481, 616, 531), radius=25, fill=background)
    return canvas


palettes = {
    "AppIconBlue": ("#355CCE", "#F7F9FF"),
    "AppIconDark": ("#17222C", "#8BDAD7"),
}
with Image.open(root / "assets/branding/app-icon.png") as source:
    if source.width != source.height:
        raise ValueError("The primary icon must be square")
    if source.mode == "RGBA" and source.getchannel("A").getextrema() != (255, 255):
        raise ValueError("The primary icon must be opaque")
    primary = source.convert("RGB")

canvases = {"AppIcon": primary}
canvases.update({name: render_icon(*palette) for name, palette in palettes.items()})
for name, canvas in canvases.items():
    icons = assets / f"{name}.appiconset"
    icons.mkdir(exist_ok=True)
    (icons / "Contents.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    for item in metadata["images"]:
        if "filename" not in item:
            continue
        pixels = round(float(item["size"].split("x")[0]) * float(item["scale"].rstrip("x")))
        canvas.resize((pixels, pixels), Image.Resampling.LANCZOS).save(icons / item["filename"])

canvas = primary
for pixels in (192, 512):
    for name in (f"Icon-{pixels}.png", f"Icon-maskable-{pixels}.png"):
        canvas.resize((pixels, pixels), Image.Resampling.LANCZOS).save(root / "web/icons" / name)
canvas.resize((32, 32), Image.Resampling.LANCZOS).save(root / "web/favicon.png")
print("Generated primary iOS and web icons; retained alternate icon palettes.")
