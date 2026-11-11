#!/usr/bin/env python3
"""Generate consistent semi-realistic expression portraits via Pollinations Classic."""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(os.environ.get("PORTRAIT_OUT", "/workspace/companion/assets/portraits"))
OUT.mkdir(parents=True, exist_ok=True)
LOG = Path("/tmp/companion_logs/portraits.jsonl")
LOG.parent.mkdir(parents=True, exist_ok=True)

GAP = 47
TIMEOUT = 150

# Locked to the portrait we already approved, so later expressions stay on-model.
ARIA = (
    "portrait of Aria, a 28-year-old adult woman, mature features, clearly an adult, "
    "three-quarter view looking back toward the camera, both hazel-green eyes visible, "
    "pale-warm skin with a soft natural blush, oval face, faint freckles, slender brows, "
    "straight nose, medium lips, long chestnut-brown hair loosely tied back with a braid "
    "falling over her left shoulder and soft strands around her face, a tiny gold stud earring, "
    "wearing a modest olive-sage textured knit sweater with a gathered round neckline that "
    "covers both shoulders and the chest, fully clothed, "
    "soft painterly semi-realistic style, soft window light, muted sage-beige textured wall, "
    "head-and-shoulders crop, highly detailed, no text, no watermark, no logo"
)

JULIAN = (
    "portrait of Julian, a 29-year-old adult man, mature features, clearly an adult, "
    "three-quarter view looking toward the camera, both deep brown eyes visible, "
    "light-medium warm skin, squarish-oval face, short textured dark brown hair slightly wavy on top, "
    "thick brows, straight nose, light natural stubble, "
    "wearing a modest navy crewneck sweater that covers both shoulders and the chest, fully clothed, "
    "soft painterly semi-realistic style, soft window light, muted warm gray textured wall, "
    "head-and-shoulders crop, highly detailed, no text, no watermark, no logo"
)

EXPR = {
    "neutral": "a relaxed, gentle, closed-mouth neutral expression, calm eyes, face at rest",
    "happy": "a warm genuine closed-mouth smile, raised cheeks, kind happy eyes",
    "laughing": "laughing, mouth slightly open with a hint of upper teeth, joyful crinkled eyes, delighted",
    "sad": "a sad expression, downturned mouth, slightly glistening eyes, inner brows raised, subdued",
    "angry": "an annoyed, angry expression, furrowed brows drawn together, tight jaw, narrowed eyes, closed mouth",
    "surprised": "a surprised expression, wide open eyes, raised brows, slightly open mouth, startled",
    "thoughtful": "a thoughtful pensive expression, eyes slightly aside, lips softly pressed, considering something",
    "embarrassed": "an embarrassed shy look, eyes slightly down, blushing cheeks, a small sheepish smile",
    "excited": "an excited look, big bright smile, sparkling wider eyes, raised brows, energetic",
    "worried": "a worried anxious expression, brows drawn together and slightly raised, tense uncertain mouth",
    "blink": "the same relaxed neutral face but with both eyes gently closed, relaxed eyelids, visible lashes, peaceful",
}

CHARACTERS = {
    "aria": {"identity": ARIA, "seed": 42017},
    "julian": {"identity": JULIAN, "seed": 77129},
}

STAMP = Path("/tmp/companion_logs/last_image_at")


def log(obj):
    with LOG.open("a") as f:
        f.write(json.dumps(obj) + "\n")
    print(json.dumps(obj), flush=True)


def wait_gap():
    now = time.time()
    last = float(STAMP.read_text()) if STAMP.exists() else 0
    delay = GAP - (now - last)
    if delay > 0:
        print(f"waiting {delay:.1f}s for rate limit", flush=True)
        time.sleep(delay)


def mark():
    STAMP.write_text(str(time.time()))


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
        alpha = int(255 * min(1.0, t * 1.6))
        draw.line([(0, y), (rw, y)], fill=alpha)
    left = Image.new("L", region.size, 255)
    ld = ImageDraw.Draw(left)
    fade = max(12, rw // 5)
    for x in range(fade):
        a = int(255 * (x / fade))
        ld.line([(x, 0), (x, rh)], fill=a)
    mask = Image.composite(mask, Image.new("L", region.size, 0), left)
    im.paste(src, (x0, y0), mask)
    return im


def build_prompt(identity: str, ev: str, expression: str) -> str:
    # Expression FIRST so caches that key on a URL prefix cannot collapse all faces.
    return (
        f"EXPRESSION {ev.upper()}: {expression}. "
        f"Keep the same person, same hair, same clothes, same lighting, same background, same pose; "
        f"change ONLY the facial expression. {identity}"
    )


def fetch(prompt: str, seed: int) -> bytes:
    qs = urllib.parse.urlencode(
        {
            "width": "768",
            "height": "768",
            "seed": str(seed),
            "nologo": "true",
        }
    )
    url = "https://image.pollinations.ai/prompt/" + urllib.parse.quote(prompt, safe="") + "?" + qs
    req = urllib.request.Request(
        url,
        headers={"Accept": "image/*", "User-Agent": "CompanionApp/1.0 (portrait-pack)"},
    )
    last_err = None
    for attempt in range(1, 6):
        wait_gap()
        mark()
        t0 = time.time()
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                data = r.read()
                ctype = r.headers.get("content-type", "")
                elapsed = round(time.time() - t0, 1)
                if r.status == 200 and data[:2] == b"\xff\xd8" and len(data) > 8000:
                    log({"ok": True, "bytes": len(data), "secs": elapsed, "ctype": ctype, "attempt": attempt, "url_len": len(url)})
                    return data
                last_err = f"bad body status={r.status} ctype={ctype} n={len(data)}"
        except urllib.error.HTTPError as e:
            ra = e.headers.get("Retry-After") if e.headers else None
            body = e.read()
            if body[:2] == b"\xff\xd8" and len(body) > 8000:
                log({"ok": True, "bytes": len(body), "secs": round(time.time() - t0, 1), "status": e.code, "note": "jpeg-on-error"})
                return body
            last_err = f"HTTP {e.code} retry-after={ra} body={body[:200]!r}"
            if e.code in (402, 429, 503):
                try:
                    extra = int(float(ra)) + 2 if ra else GAP
                except ValueError:
                    extra = GAP
                print(f"rate limited, sleeping {extra}s", flush=True)
                time.sleep(extra)
                mark()
                continue
        except Exception as e:
            last_err = f"{type(e).__name__}: {e}"
        log({"ok": False, "attempt": attempt, "error": last_err})
        time.sleep(8 * attempt)
    raise RuntimeError(last_err or "failed")


def main():
    # Default: skip files that already exist UNLESS --force
    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    jobs = []
    for cid, meta in CHARACTERS.items():
        for ev, ed in EXPR.items():
            jobs.append((cid, ev, meta["seed"], build_prompt(meta["identity"], ev, ed)))
    if only:
        jobs = [j for j in jobs if f"{j[0]}:{j[1]}" in only]

    for cid, ev, seed, prompt in jobs:
        dest = OUT / f"{cid}_{ev}.jpg"
        if dest.exists() and dest.stat().st_size > 8000 and not force:
            print(f"skip existing {dest.name}", flush=True)
            continue
        print(f"generating {dest.name} seed={seed}", flush=True)
        data = fetch(prompt, seed)
        tmp = dest.with_suffix(".tmp.jpg")
        tmp.write_bytes(data)
        im = Image.open(tmp)
        im = scrub_logo(im)
        im.save(dest, format="JPEG", quality=90, optimize=True)
        tmp.unlink(missing_ok=True)
        print(f"saved {dest} {dest.stat().st_size} bytes", flush=True)
    print("done", flush=True)


if __name__ == "__main__":
    main()
