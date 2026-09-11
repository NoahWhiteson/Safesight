#!/usr/bin/env python3
"""
Render Safesight share cards to match ScanShareExporter.swift
and assemble a public AI benchmark report from live API results.
"""

from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "docs" / "benchmark"
LOGO = ROOT / "Safesight" / "Assets.xcassets" / "AppLogo.imageset" / "AppLogo.png"

MAX_LONG_EDGE = 1600
PAD = 28


@dataclass
class Hazard:
    title: str
    severity: str
    confidence: int
    status: str
    box: dict  # x,y,width,height normalized


def severity_color(severity: str, fixed: bool = False) -> tuple[int, int, int]:
    if fixed:
        return (51, 173, 115)
    s = severity.lower()
    if s == "high":
        return (235, 71, 64)  # 0.92, 0.28, 0.25
    if s == "medium":
        return (242, 158, 31)  # 0.95, 0.62, 0.12
    return (51, 173, 115)  # 0.20, 0.68, 0.45


def score_color(score: int) -> tuple[int, int, int]:
    if score >= 85:
        return (51, 173, 115)
    if score >= 65:
        return (242, 158, 31)
    return (235, 71, 64)


def load_font(size: float, weight: str = "bold") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    # Prefer SF / Helvetica on macOS for app-like chrome
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSText.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if weight == "bold" else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf" if weight == "bold" else "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size=int(round(size)))
            except OSError:
                continue
    return ImageFont.load_default()


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius: float, fill=None, outline=None, width: int = 1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_annotations(img: Image.Image, hazards: list[Hazard]):
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    occupied: list[tuple[float, float, float, float]] = []
    line = max(2.5, min(w, h) * 0.0035)

    visible = [hz for hz in hazards if hz.status != "dismissed"]
    for index, hz in enumerate(visible):
        bx = hz.box.get("x", 0) * w
        by = hz.box.get("y", 0) * h
        bw = hz.box.get("width", 0) * w
        bh = hz.box.get("height", 0) * h
        box = (bx, by, bx + bw, by + bh)
        color = severity_color(hz.severity, hz.status == "fixed")
        fill = (*color, int(0.18 * 255))
        stroke = (*color, 255)

        inset = line / 2
        rounded_rect(
            draw,
            (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset),
            radius=4,
            fill=fill,
            outline=stroke,
            width=int(round(line)),
        )

        title = f"Fixed · {hz.title}" if hz.status == "fixed" else hz.title
        conf = f"{int(hz.confidence)}%"
        scale = max(0.85, min(w, h) / 390)
        font_size = 11 * scale
        title_font = load_font(font_size, "bold")
        conf_font = load_font(font_size * 0.9, "semibold")

        # Measure
        tw = draw.textlength(title, font=title_font)
        cw = draw.textlength(conf, font=conf_font)
        label_h = 20 * scale
        label_w = min(w * 0.72, tw + cw + 28 * scale)
        label_w = max(56 * scale, label_w)

        candidates = [
            (bx, by - label_h + 1, label_w, label_h),
            (bx, by + bh - 1, label_w, label_h),
            (bx + bw - label_w, by - label_h + 1, label_w, label_h),
            (bx, by + bh / 2 - label_h / 2, label_w, label_h),
        ]

        def clamp(r):
            x, y, rw, rh = r
            x = max(8, min(x, w - 8 - rw))
            y = max(8, min(y, h - 8 - rh))
            return (x, y, rw, rh)

        def intersects(a, b):
            ax, ay, aw, ah = a
            bx_, by_, bw_, bh_ = b
            return not (ax + aw + 3 < bx_ or bx_ + bw_ + 3 < ax or ay + ah + 2 < by_ or by_ + bh_ + 2 < ay)

        placed = None
        for raw in candidates:
            c = clamp(raw)
            if not any(intersects(c, o) for o in occupied):
                placed = c
                break
        if placed is None:
            placed = clamp((bx, min(h - 8 - label_h, by + index * (label_h + 4)), label_w, label_h))

        occupied.append(placed)
        lx, ly, lw, lh = placed
        above = ly + lh / 2 <= by + 2
        # Tab shape approx with rounded rect
        draw.rounded_rectangle(
            (lx, ly, lx + lw, ly + lh),
            radius=4,
            fill=(*color, 255),
        )

        pad = 7 * scale
        conf_w = draw.textlength(conf, font=conf_font)
        title_max = max(0, lw - conf_w - pad * 2.4)
        # Vertical center text
        title_bbox = draw.textbbox((0, 0), title, font=title_font)
        conf_bbox = draw.textbbox((0, 0), conf, font=conf_font)
        th = title_bbox[3] - title_bbox[1]
        ch = conf_bbox[3] - conf_bbox[1]
        draw.text((lx + pad, ly + lh / 2 - th / 2), title, font=title_font, fill=(255, 255, 255, 255))
        draw.text(
            (lx + lw - pad - conf_w, ly + lh / 2 - ch / 2),
            conf,
            font=conf_font,
            fill=(255, 255, 255, int(0.92 * 255)),
        )


def draw_logo(img: Image.Image):
    w, h = img.size
    side = max(36, min(w, h) * 0.072)
    rect = (PAD, PAD, PAD + side, PAD + side)
    if LOGO.exists():
        logo = Image.open(LOGO).convert("RGBA")
        logo = logo.resize((int(side), int(side)), Image.Resampling.LANCZOS)
        # White template
        alpha = logo.split()[-1]
        white = Image.new("RGBA", logo.size, (255, 255, 255, 0))
        white.putalpha(alpha)
        # Difference blend against photo (approx ScanScreen blendMode.difference)
        region = img.crop(rect).convert("RGBA")
        blended = ImageChops.difference(region, white)
        # Keep logo alpha
        blended.putalpha(alpha)
        img.paste(blended, (PAD, PAD), blended)
    else:
        draw = ImageDraw.Draw(img)
        font = load_font(side * 0.55, "bold")
        draw.text((PAD + side * 0.25, PAD + side * 0.15), "S", font=font, fill=(255, 255, 255, 230))


def draw_score(img: Image.Image, score: int):
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    clamped = max(0, min(100, int(score)))
    scale = max(0.75, min(w, h) / 420)
    diameter = 88 * scale
    line = 7.5 * scale
    bottom_inset = PAD + 18 * scale
    cx = w / 2
    cy = h - bottom_inset - diameter / 2

    # Soft white disk
    disk_r = diameter / 2 + 8 * scale
    draw.ellipse((cx - disk_r, cy - disk_r, cx + disk_r, cy + disk_r), fill=(255, 255, 255, int(0.94 * 255)))

    # Track
    track_bbox = (cx - diameter / 2, cy - diameter / 2, cx + diameter / 2, cy + diameter / 2)
    draw.ellipse(track_bbox, outline=(0, 0, 0, int(0.06 * 255)), width=int(round(line)))

    # Progress arc via pieslice mask trick
    progress = clamped / 100
    if progress > 0:
        # Pillow arcs: 0° is 3-o'clock, clockwise positive... we need from -90°
        start = -90
        end = -90 + 360 * progress
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        od = ImageDraw.Draw(overlay)
        od.arc(track_bbox, start=start, end=end, fill=(*score_color(clamped), 255), width=int(round(line)))
        img.alpha_composite(overlay)

    score_font = load_font(28 * scale, "bold")
    sub_font = load_font(11 * scale, "semibold")
    score_text = str(clamped)
    sub_text = "/ 100"
    sb = draw.textbbox((0, 0), score_text, font=score_font)
    ub = draw.textbbox((0, 0), sub_text, font=sub_font)
    sw, sh = sb[2] - sb[0], sb[3] - sb[1]
    uw, uh = ub[2] - ub[0], ub[3] - ub[1]
    stack_h = sh + 1 + uh
    score_y = cy - stack_h / 2
    draw.text((cx - sw / 2, score_y), score_text, font=score_font, fill=(20, 20, 20, 255))
    draw.text((cx - uw / 2, score_y + sh + 1), sub_text, font=sub_font, fill=(115, 115, 115, 255))


def render_share_card(photo_path: Path, result: dict, out_path: Path) -> Path:
    src = Image.open(photo_path).convert("RGB")
    # EXIF orientation
    try:
        from PIL import ImageOps
        src = ImageOps.exif_transpose(src) or src
    except Exception:
        pass

    sw, sh = src.size
    scale = min(1.0, MAX_LONG_EDGE / max(sw, sh))
    canvas_size = (int(sw * scale), int(sh * scale))
    # 2x like UIGraphicsImageRendererFormat.scale = 2
    render = src.resize((canvas_size[0] * 2, canvas_size[1] * 2), Image.Resampling.LANCZOS).convert("RGBA")
    rw, rh = render.size

    # Vignettes
    top = Image.new("RGBA", render.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    for i in range(int(rh * 0.18)):
        a = int(0.32 * 255 * (1 - i / (rh * 0.18)))
        td.line([(0, i), (rw, i)], fill=(0, 0, 0, a))
    render = Image.alpha_composite(render, top)

    bot = Image.new("RGBA", render.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bot)
    start_y = int(rh * 0.62)
    for y in range(start_y, rh):
        t = (y - start_y) / max(1, rh - start_y)
        # 0 until 0.55 of gradient span then to 0.28 — approximate linear from mid
        # Simple: fade 0 -> 0.28 over bottom 38%
        a = int(0.28 * 255 * t)
        bd.line([(0, y), (rw, y)], fill=(0, 0, 0, a))
    render = Image.alpha_composite(render, bot)

    hazards = []
    for h in result.get("hazards") or []:
        box = h.get("boundingBox") or h.get("box") or {}
        hazards.append(
            Hazard(
                title=h.get("title") or "Hazard",
                severity=h.get("severity") or "medium",
                confidence=int(h.get("confidence") or 0),
                status=(h.get("status") or "open").lower(),
                box=box,
            )
        )

    draw_annotations(render, hazards)
    draw_logo(render)
    draw_score(render, int(result.get("score") or 0))

    out = render.convert("RGB")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.suffix.lower() in {".jpg", ".jpeg"}:
        out.save(out_path, "JPEG", quality=90, optimize=True)
    else:
        out.save(out_path, "PNG", optimize=True)
    return out_path


def main():
    kitchen_json = BENCH / "result-kitchen.json"
    kitchen_photo = BENCH / "source-kitchen.jpg"
    with open(kitchen_json) as f:
        result = json.load(f)

    out = BENCH / "share-kitchen.png"
    render_share_card(kitchen_photo, result, out)
    print("wrote", out, out.stat().st_size)


if __name__ == "__main__":
    main()
