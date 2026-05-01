#!/usr/bin/env python3
"""Generate deterministic pixel-art Snoot icons with transparent backgrounds."""

from __future__ import annotations

import os
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "Snoot.iconset"
RESOURCES = ROOT / "Snoot.app" / "Contents" / "Resources"
LANDING = ROOT / "landing"


COLORS = {
    "clear": (0, 0, 0, 0),
    "ink": (18, 5, 8, 255),
    "deep": (4, 3, 4, 255),
    "body": (22, 19, 22, 255),
    "shade": (58, 19, 25, 255),
    "red": (213, 29, 46, 255),
    "rose": (247, 82, 98, 255),
    "bone": (242, 236, 228, 255),
    "warm": (255, 225, 190, 255),
}


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    payload = b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)),
            chunk(b"IEND", b""),
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def write_icns(path: Path, pngs: dict[str, Path]) -> None:
    chunks = []
    for kind, png_path in pngs.items():
        payload = png_path.read_bytes()
        chunks.append(kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload)
    body = b"".join(chunks)
    path.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


def draw_rect(grid: list[list[str]], x: int, y: int, w: int, h: int, color: str) -> None:
    for yy in range(y, y + h):
        if yy < 0 or yy >= len(grid):
            continue
        for xx in range(x, x + w):
            if 0 <= xx < len(grid[yy]):
                grid[yy][xx] = color


def base_grid() -> list[list[str]]:
    grid = [["clear" for _ in range(32)] for _ in range(32)]

    # Wing and tail sit behind the head silhouette.
    draw_rect(grid, 4, 16, 7, 3, "ink")
    draw_rect(grid, 2, 15, 4, 3, "ink")
    draw_rect(grid, 1, 13, 3, 3, "red")
    draw_rect(grid, 4, 17, 7, 1, "shade")
    draw_rect(grid, 6, 9, 9, 3, "ink")
    draw_rect(grid, 5, 11, 11, 5, "ink")
    draw_rect(grid, 7, 10, 6, 2, "rose")
    draw_rect(grid, 7, 12, 7, 3, "red")

    # Head, cheek, and snoot.
    draw_rect(grid, 12, 8, 11, 3, "ink")
    draw_rect(grid, 9, 11, 17, 8, "ink")
    draw_rect(grid, 8, 15, 19, 6, "ink")
    draw_rect(grid, 11, 9, 11, 2, "body")
    draw_rect(grid, 10, 12, 14, 7, "body")
    draw_rect(grid, 11, 15, 16, 5, "body")
    draw_rect(grid, 13, 10, 7, 2, "shade")
    draw_rect(grid, 12, 12, 6, 2, "red")
    draw_rect(grid, 22, 15, 6, 4, "ink")
    draw_rect(grid, 22, 16, 5, 2, "shade")
    draw_rect(grid, 27, 17, 1, 1, "deep")
    draw_rect(grid, 13, 18, 5, 1, "red")

    # Horns and crest.
    draw_rect(grid, 12, 3, 3, 6, "ink")
    draw_rect(grid, 20, 4, 3, 6, "ink")
    draw_rect(grid, 13, 4, 1, 4, "bone")
    draw_rect(grid, 21, 5, 1, 4, "bone")
    draw_rect(grid, 13, 3, 2, 1, "warm")
    draw_rect(grid, 21, 4, 2, 1, "warm")
    draw_rect(grid, 9, 9, 2, 3, "red")
    draw_rect(grid, 7, 12, 2, 3, "red")
    draw_rect(grid, 6, 15, 2, 3, "red")

    # Eye and tiny tooth.
    draw_rect(grid, 18, 12, 5, 5, "deep")
    draw_rect(grid, 19, 13, 3, 3, "bone")
    draw_rect(grid, 21, 14, 2, 3, "red")
    draw_rect(grid, 20, 13, 1, 1, "warm")
    draw_rect(grid, 23, 19, 2, 2, "bone")

    # Neck/body hint so the menu icon reads as a pet, not just a logo mark.
    draw_rect(grid, 10, 21, 12, 4, "ink")
    draw_rect(grid, 12, 21, 9, 3, "body")
    draw_rect(grid, 13, 21, 5, 1, "shade")
    draw_rect(grid, 14, 24, 3, 2, "bone")
    draw_rect(grid, 18, 24, 3, 2, "bone")
    return grid


def render(size: int) -> list[tuple[int, int, int, int]]:
    grid = base_grid()
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(size):
        gy = min(31, int(y * 32 / size))
        for x in range(size):
            gx = min(31, int(x * 32 / size))
            pixels.append(COLORS[grid[gy][gx]])
    return pixels


def main() -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    RESOURCES.mkdir(parents=True, exist_ok=True)
    LANDING.mkdir(parents=True, exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    for filename, size in sizes.items():
        write_png(ICONSET / filename, size, size, render(size))
    write_png(RESOURCES / "SnootStatusIcon.png", 64, 64, render(64))
    write_png(LANDING / "snoot-mark.png", 512, 512, render(512))
    write_icns(
        RESOURCES / "Snoot.icns",
        {
            "icp4": ICONSET / "icon_16x16.png",
            "icp5": ICONSET / "icon_32x32.png",
            "icp6": ICONSET / "icon_32x32@2x.png",
            "ic07": ICONSET / "icon_128x128.png",
            "ic08": ICONSET / "icon_256x256.png",
            "ic09": ICONSET / "icon_512x512.png",
            "ic10": ICONSET / "icon_512x512@2x.png",
        },
    )
    print(f"generated {len(sizes) + 3} Snoot assets")


if __name__ == "__main__":
    main()
