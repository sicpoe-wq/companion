#!/usr/bin/env python3
"""Derive a full expression set from a single consistent portrait (YuNet landmarks + local warps)."""
from __future__ import annotations

import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path("/workspace/companion")
OUT = ROOT / "assets" / "portraits"
MODEL = Path(__file__).parent / "models" / "yunet.onnx"


def scrub_logo(im: Image.Image) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = int(w * 0.68), int(h * 0.90), w, h
    region = im.crop((x0, y0, x1, y1))
    src = im.crop((x0, max(0, y0 - int(h * 0.10)), x1, y0)).resize(region.size, Image.Resampling.BICUBIC)
    src = src.filter(ImageFilter.GaussianBlur(4))
    mask = Image.new("L", region.size, 0)
    draw = ImageDraw.Draw(mask)
    rw, rh = region.size
    for y in range(rh):
        t = y / max(1, rh - 1)
        draw.line([(0, y), (rw, y)], fill=int(255 * min(1.0, t * 1.6)))
    left = Image.new("L", region.size, 255)
    ld = ImageDraw.Draw(left)
    fade = max(12, rw // 5)
    for x in range(fade):
        ld.line([(x, 0), (x, rh)], fill=int(255 * (x / fade)))
    mask = Image.composite(mask, Image.new("L", region.size, 0), left)
    im.paste(src, (x0, y0), mask)
    return im


def detect(bgr: np.ndarray):
    h, w = bgr.shape[:2]
    det = cv2.FaceDetectorYN_create(str(MODEL), "", (w, h), score_threshold=0.5)
    det.setInputSize((w, h))
    _, faces = det.detect(bgr)
    if faces is None or len(faces) == 0:
        raise RuntimeError("no face")
    f = max(faces, key=lambda r: r[2] * r[3])
    box = tuple(map(int, f[:4]))
    lm = {
        "reye": (float(f[4]), float(f[5])),
        "leye": (float(f[6]), float(f[7])),
        "nose": (float(f[8]), float(f[9])),
        "rmouth": (float(f[10]), float(f[11])),
        "lmouth": (float(f[12]), float(f[13])),
    }
    return box, lm


def skin_color(rgb: np.ndarray, lm) -> tuple[int, int, int]:
    # Sample cheek (below and slightly outside the eyes).
    h, w = rgb.shape[:2]
    samples = []
    mid_x = (lm["reye"][0] + lm["leye"][0]) / 2
    eye_y = (lm["reye"][1] + lm["leye"][1]) / 2
    mouth_y = (lm["rmouth"][1] + lm["lmouth"][1]) / 2
    pts = [
        (lm["reye"][0] - 40, eye_y + 50),
        (lm["leye"][0] + 40, eye_y + 50),
        (mid_x, (eye_y + mouth_y) / 2),
        (lm["nose"][0], lm["nose"][1] - 20),
    ]
    for x, y in pts:
        x, y = int(x), int(y)
        if 4 <= x < w - 4 and 4 <= y < h - 4:
            samples.append(rgb[y - 3 : y + 3, x - 3 : x + 3].reshape(-1, 3).mean(0))
    c = np.mean(samples, axis=0) if samples else np.array([180, 140, 120])
    return tuple(int(v) for v in c)


FACE_MASK: np.ndarray | None = None


def face_mask(shape, box, lm) -> np.ndarray:
    """Feathered ellipse over the face only (forehead to chin), so warps never
    move the neck, collar, hair edges or background."""
    h, w = shape[:2]
    x, y, bw, bh = box
    cx = (lm["reye"][0] + lm["leye"][0]) / 2
    cy = y + bh * 0.52
    m = np.zeros((h, w), np.float32)
    cv2.ellipse(m, (int(cx), int(cy)), (int(bw * 0.46), int(bh * 0.56)), 0, 0, 360, 1.0, -1)
    return cv2.GaussianBlur(m, (0, 0), bw * 0.06)


def inverse_warp(rgb: np.ndarray, movers: list[tuple[float, float, float, float, float]]) -> np.ndarray:
    """movers: (cx, cy, dx, dy, radius) — dest pixel p comes from p - weighted displacement."""
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    dx_acc = np.zeros((h, w), np.float32)
    dy_acc = np.zeros((h, w), np.float32)
    w_acc = np.zeros((h, w), np.float32)
    for cx, cy, ddx, ddy, radius in movers:
        dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        wt = np.clip(1.0 - dist / radius, 0, 1)
        # smooth falloff
        wt = wt * wt * (3 - 2 * wt)
        dx_acc += wt * ddx
        dy_acc += wt * ddy
        w_acc += wt
    # normalize overlapping movers, but keep the max influence (don't dilute)
    # Using summed weights already interpolates; that's ok.
    if FACE_MASK is not None:
        dx_acc *= FACE_MASK
        dy_acc *= FACE_MASK
    map_x = (xx - dx_acc).astype(np.float32)
    map_y = (yy - dy_acc).astype(np.float32)
    return cv2.remap(rgb, map_x, map_y, interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)


def overlay_blush(im: Image.Image, lm, amount: float) -> Image.Image:
    if amount <= 0:
        return im
    w, h = im.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    eye_y = (lm["reye"][1] + lm["leye"][1]) / 2
    eye_d = np.hypot(lm["leye"][0] - lm["reye"][0], lm["leye"][1] - lm["reye"][1])
    rw = eye_d * 0.48
    rh = eye_d * 0.26
    alpha = int(28 + 40 * amount)
    color = (190, 95, 95, alpha)
    for ex, ey in (lm["reye"], lm["leye"]):
        sign = -1 if ex < lm["nose"][0] else 1
        cx, cy = ex + sign * eye_d * 0.22, ey + eye_d * 0.55
        d.ellipse((cx - rw, cy - rh, cx + rw, cy + rh), fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(18))
    base = im.convert("RGBA")
    return Image.alpha_composite(base, layer).convert("RGB")


def draw_open_mouth(im: Image.Image, lm, openness: float, teeth: bool) -> Image.Image:
    if openness <= 0:
        return im
    layer = im.convert("RGBA")
    overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    rx, ry = lm["rmouth"]
    lx, ly = lm["lmouth"]
    mx, my = (rx + lx) / 2, (ry + ly) / 2
    width = np.hypot(lx - rx, ly - ry) * 0.9
    height = width * (0.18 + 0.45 * openness)
    # rotate-ish: just an ellipse at the mouth
    box = (mx - width / 2, my - height / 2 + 2, mx + width / 2, my + height / 2 + 2)
    # Subtle lip opening only — a narrow dark line, heavily blended, no purple blob.
    if openness >= 0.5:
        d.ellipse(box, fill=(70, 30, 35, 110))
        if teeth:
            tbox = (mx - width * 0.28, my - height * 0.08, mx + width * 0.28, my + height * 0.05)
            d.ellipse(tbox, fill=(236, 220, 210, 90))
    else:
        # just slightly darken the lip line
        d.ellipse(box, fill=(90, 40, 45, 50))
    overlay = overlay.filter(ImageFilter.GaussianBlur(2.4))
    return Image.alpha_composite(layer, overlay).convert("RGB")


def draw_blink(im: Image.Image, lm, skin: tuple[int, int, int]) -> Image.Image:
    rgb = np.array(im)
    eye_d = np.hypot(lm["leye"][0] - lm["reye"][0], lm["leye"][1] - lm["reye"][1])
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ew, eh = eye_d * 0.28, eye_d * 0.16
    for ex, ey in (lm["reye"], lm["leye"]):
        # lid
        lid = tuple(max(0, min(255, int(c * 0.88))) for c in skin)
        d.ellipse((ex - ew, ey - eh * 0.7, ex + ew, ey + eh * 0.9), fill=(*lid, 245))
        # lash line
        d.arc((ex - ew, ey - eh * 0.35, ex + ew, ey + eh * 0.7), start=0, end=180, fill=(40, 25, 20, 200), width=2)
    layer = layer.filter(ImageFilter.GaussianBlur(2.0))
    return Image.alpha_composite(im.convert("RGBA"), layer).convert("RGB")


def brow_shift(rgb: np.ndarray, lm, inner_up: float, together: float) -> np.ndarray:
    """Shift a strip above the eyes (inner brows). inner_up > 0 raises the inner brow (sad)."""
    eye_d = float(np.hypot(lm["leye"][0] - lm["reye"][0], lm["leye"][1] - lm["reye"][1]))
    movers = []
    for name, sign in (("reye", 1), ("leye", -1)):
        ex, ey = lm[name]
        # inner brow is toward the nose
        cx = ex + sign * eye_d * 0.12
        cy = ey - eye_d * 0.28
        movers.append((cx, cy, sign * together * 2, -inner_up * 5, eye_d * 0.42))
        # outer brow slightly opposite
        cx2 = ex - sign * eye_d * 0.18
        cy2 = ey - eye_d * 0.28
        movers.append((cx2, cy2, 0, inner_up * 2, eye_d * 0.35))
    return inverse_warp(rgb, movers)


GRADES = {
    # (r, g, b multipliers, brightness) — gentle colour mood, no geometry change
    "happy": (1.04, 1.01, 0.97, 1.03),
    "laughing": (1.05, 1.02, 0.96, 1.05),
    "excited": (1.05, 1.02, 0.96, 1.05),
    "sad": (0.96, 0.99, 1.05, 0.95),
    "worried": (0.98, 0.99, 1.03, 0.97),
    "angry": (1.05, 0.97, 0.95, 0.98),
    "embarrassed": (1.03, 0.99, 0.99, 1.01),
    "surprised": (1.0, 1.0, 1.01, 1.04),
    "thoughtful": (0.99, 0.99, 1.01, 0.98),
}


def grade(im: Image.Image, kind: str) -> Image.Image:
    g = GRADES.get(kind)
    if not g:
        return im
    a = np.asarray(im).astype(np.float32)
    a *= np.array(g[:3], np.float32) * g[3]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def apply(im: Image.Image, lm, kind: str) -> Image.Image:
    rgb = np.array(im.convert("RGB"))
    skin = skin_color(rgb, lm)
    eye_d = float(np.hypot(lm["leye"][0] - lm["reye"][0], lm["leye"][1] - lm["reye"][1]))
    rx, ry = lm["rmouth"]
    lx, ly = lm["lmouth"]
    mx, my = (rx + lx) / 2, (ry + ly) / 2
    reye, leye = lm["reye"], lm["leye"]

    def smile(amount, cheek=1.0):
        movers = [
            (rx, ry, 0, -amount * 7, eye_d * 0.55),
            (lx, ly, 0, -amount * 7, eye_d * 0.55),
            (mx, my + 6, 0, amount * 2, eye_d * 0.35),
            (reye[0] - 10, reye[1] + eye_d * 0.4, 0, -amount * 3 * cheek, eye_d * 0.5),
            (leye[0] + 10, leye[1] + eye_d * 0.4, 0, -amount * 3 * cheek, eye_d * 0.5),
        ]
        return inverse_warp(rgb, movers)

    def frown(amount):
        movers = [
            (rx, ry, 1, amount * 5, eye_d * 0.5),
            (lx, ly, -1, amount * 5, eye_d * 0.5),
            (mx, my, 0, amount * 2, eye_d * 0.35),
        ]
        return inverse_warp(rgb, movers)

    out = rgb
    blush = 0.0
    open_m = 0.0
    teeth = False
    blink = False

    if kind == "neutral":
        out = rgb
    elif kind == "happy":
        out = smile(0.85)
        blush = 0.35
    elif kind == "laughing":
        out = smile(1.2, cheek=1.25)
        blush = 0.35
        open_m = 0.35
        teeth = False
    elif kind == "sad":
        out = frown(0.8)
        out = brow_shift(out, lm, inner_up=1.0, together=0.2)
        blush = 0.1
    elif kind == "angry":
        out = frown(0.55)
        out = brow_shift(out, lm, inner_up=-0.9, together=0.8)
    elif kind == "surprised":
        movers = [
            ((reye[0] + leye[0]) / 2, (reye[1] + leye[1]) / 2 - eye_d * 0.35, 0, -5, eye_d * 0.6),
            (mx, my + 4, 0, 3, eye_d * 0.45),
        ]
        out = inverse_warp(rgb, movers)
        open_m = 0.0
        teeth = False
    elif kind == "thoughtful":
        movers = [
            (mx, my, 2, 0, eye_d * 0.4),
            (lx, ly, 1, 1, eye_d * 0.35),
        ]
        out = inverse_warp(rgb, movers)
        out = brow_shift(out, lm, inner_up=0.35, together=0.0)
    elif kind == "embarrassed":
        out = smile(0.4, cheek=0.6)
        blush = 0.7
        movers = [
        ]
    elif kind == "excited":
        out = smile(1.05, cheek=1.15)
        blush = 0.3
        # slightly wider eyes (pull lids by shifting around eyes up)
        open_m = 0.0
        teeth = False
    elif kind == "worried":
        out = frown(0.35)
        out = brow_shift(out, lm, inner_up=0.85, together=0.35)
        open_m = 0.2
    elif kind == "blink":
        blink = True
    else:
        raise ValueError(kind)

    im2 = Image.fromarray(out)
    im2 = overlay_blush(im2, lm, blush)
    im2 = grade(im2, kind)
    if blink:
        im2 = draw_blink(im2, lm, skin)
    return im2


KINDS = [
    "neutral",
    "happy",
    "laughing",
    "sad",
    "angry",
    "surprised",
    "thoughtful",
    "embarrassed",
    "excited",
    "worried",
]


def process(cid: str, src: Path):
    global FACE_MASK
    # Bases are pre-cleaned (logo + neck artifacts removed), see tool/base_portraits.
    raw = Image.open(src).convert("RGB")
    bgr = cv2.cvtColor(np.array(raw), cv2.COLOR_RGB2BGR)
    box, lm = detect(bgr)
    FACE_MASK = face_mask(bgr.shape, box, lm)
    print(cid, "face", box, "lm", {k: (round(v[0]), round(v[1])) for k, v in lm.items()})
    for kind in KINDS:
        out = apply(raw, lm, kind)
        dest = OUT / f"{cid}_{kind}.jpg"
        out.save(dest, quality=92, optimize=True)
        print("  wrote", dest.name, dest.stat().st_size)


def main():
    jobs = {
        "aria": Path(__file__).parent / "base_portraits" / "aria_base.png",
        "julian": Path(__file__).parent / "base_portraits" / "julian_base.png",
    }
    if len(sys.argv) > 1:
        jobs = {k: jobs[k] for k in sys.argv[1:] if k in jobs}
    for cid, src in jobs.items():
        process(cid, src)


if __name__ == "__main__":
    main()
