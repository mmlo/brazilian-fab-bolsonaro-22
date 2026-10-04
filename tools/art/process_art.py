#!/usr/bin/env python3
"""Convert high-resolution generated masters into the game's true low-res pixel art.

The playfield renders at 270x360 logical pixels and is upscaled 2x with nearest
filtering, so every sprite is reduced to its exact in-game pixel size here:
box-filter downscale -> binary alpha -> small per-sprite palette. White
silhouettes (``*_flash.png``) are produced for hit flashes.

    python3 tools/art/process_art.py [/path/to/masters]

Masters default to ~/art_raw (kept outside the project; they are not shipped).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "art_raw"
OUT = ROOT / "assets" / "art"

# name -> (master file, target width in logical px, palette colours)
SPRITES = {
    "player": ("player.png", 28, 28),
    "enemy_drone": ("enemy_drone.png", 22, 20),
    "enemy_lancer": ("enemy_lancer.png", 26, 20),
    "enemy_frigate": ("enemy_frigate.png", 40, 28),
    "enemy_carrier": ("enemy_carrier.png", 70, 32),
    "boss_p1": ("boss_p1.png", 184, 40),
    "boss_p2": ("boss_p2.png", 184, 40),
    "boss_p3": ("boss_p3.png", 184, 40),
    "stargate": ("stargate.png", 250, 32),
}

# Bullet sheet: 4x4 grid; (row, col) -> (name, target width)
COLORS = ["pink", "orange", "violet", "cyan"]
SHEET_ITEMS = {}
for c, color in enumerate(COLORS):
    SHEET_ITEMS[(0, c)] = (f"orb_{color}", 9)
    SHEET_ITEMS[(1, c)] = (f"rice_{color}", 6)
    SHEET_ITEMS[(2, c)] = (f"big_{color}", 17)
SHEET_ITEMS[(3, 0)] = ("item_star", 11)
SHEET_ITEMS[(3, 1)] = ("item_gem", 10)
SHEET_ITEMS[(3, 2)] = ("item_energy", 10)
SHEET_ITEMS[(3, 3)] = ("shot_player", 5)


def trim(im: Image.Image, threshold: int = 24) -> Image.Image:
    alpha = np.asarray(im)[..., 3]
    ys, xs = np.where(alpha > threshold)
    if len(xs) == 0:
        return im
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def premultiplied_resize(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    arr = np.asarray(im).astype(np.float32) / 255.0
    rgb = arr[..., :3] * arr[..., 3:4]
    pre = np.concatenate([rgb, arr[..., 3:4]], axis=-1)
    small = Image.fromarray((pre * 255).astype(np.uint8), "RGBA").resize(size, Image.BOX)
    s = np.asarray(small).astype(np.float32) / 255.0
    a = s[..., 3:4]
    col = np.where(a > 0.001, s[..., :3] / np.maximum(a, 0.001), 0)
    return Image.fromarray((np.concatenate([np.clip(col, 0, 1), a], -1) * 255).astype(np.uint8), "RGBA")


def pixelize(im: Image.Image, width: int, colors: int, alpha_cut: int = 100, boost: float = 1.08) -> Image.Image:
    im = trim(im.convert("RGBA"))
    height = max(1, round(im.height * width / im.width))
    small = premultiplied_resize(im, (width, height))
    arr = np.asarray(small).copy()
    alpha = arr[..., 3]
    arr[..., 3] = np.where(alpha >= alpha_cut, 255, 0)
    rgb = Image.fromarray(arr[..., :3], "RGB")
    q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.asarray(q).astype(np.float32)
    out = np.clip((out - 128) * boost + 128, 0, 255)
    result = np.concatenate([out.astype(np.uint8), arr[..., 3:4]], axis=-1)
    result[result[..., 3] == 0, :3] = 0
    return Image.fromarray(result, "RGBA")


def flash(im: Image.Image) -> Image.Image:
    arr = np.asarray(im).copy()
    arr[..., :3] = 255
    return Image.fromarray(arr, "RGBA")


def save(im: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{name}.png", optimize=True)
    print(f"{name}: {im.width}x{im.height}")


def main() -> None:
    for name, (file, width, colors) in SPRITES.items():
        path = SRC / file
        if not path.exists():
            print(f"skip {name} (missing {path})")
            continue
        sprite = pixelize(Image.open(path), width, colors, boost=1.18 if name.startswith("enemy_") else 1.08)
        save(sprite, name)
        if name.startswith(("enemy_", "boss_", "player")):
            save(flash(sprite), f"{name}_flash")

    sheet_path = SRC / "bullets_sheet.png"
    if sheet_path.exists():
        sheet = Image.open(sheet_path).convert("RGBA")
        cw, ch = sheet.width // 4, sheet.height // 4
        for (row, col), (name, width) in SHEET_ITEMS.items():
            cell = sheet.crop((col * cw, row * ch, (col + 1) * cw, (row + 1) * ch))
            save(pixelize(cell, width, 12, alpha_cut=90, boost=1.12), name)

    bg_path = SRC / "bg_nebula.png"
    if bg_path.exists():
        bg = Image.open(bg_path).convert("RGB").resize((270, 480), Image.BOX)
        bg = bg.quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        arr = np.asarray(bg).astype(np.float32) * 0.82
        tile = Image.fromarray(arr.astype(np.uint8), "RGB")
        loop = Image.new("RGB", (270, 960))
        loop.paste(tile, (0, 0))
        loop.paste(tile.transpose(Image.FLIP_TOP_BOTTOM), (0, 480))
        save(loop.convert("RGBA"), "bg_nebula")

    title_path = SRC / "title_art.png"
    if title_path.exists():
        title = Image.open(title_path).convert("RGB").resize((640, 360), Image.BOX)
        save(title.convert("RGBA"), "title_art")


if __name__ == "__main__":
    main()
