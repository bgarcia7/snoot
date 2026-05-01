#!/usr/bin/env python3
"""Import a generated Snoot silhouette into the app icon resources."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ICONSET = ROOT / "Snoot.iconset"
RESOURCES = ROOT / "Snoot.app" / "Contents" / "Resources"
LANDING = ROOT / "landing"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


Pixel = tuple[int, int, int, int]


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path: Path) -> tuple[int, int, list[Pixel]]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise SystemExit(f"Not a PNG: {path}")
    offset = len(PNG_SIGNATURE)
    width = height = color_type = bit_depth = interlace = None
    idat = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            break
    if width is None or height is None:
        raise SystemExit("PNG missing IHDR")
    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise SystemExit("Importer supports non-interlaced 8-bit RGB/RGBA PNGs only.")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(idat))
    rows: list[bytearray] = []
    idx = 0
    prior = bytearray(stride)
    for _y in range(height):
        filter_type = raw[idx]
        idx += 1
        row = bytearray(raw[idx : idx + stride])
        idx += stride
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            up = prior[i]
            up_left = prior[i - channels] if i >= channels else 0
            if filter_type == 1:
                row[i] = (row[i] + left) & 255
            elif filter_type == 2:
                row[i] = (row[i] + up) & 255
            elif filter_type == 3:
                row[i] = (row[i] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                row[i] = (row[i] + paeth(left, up, up_left)) & 255
            elif filter_type != 0:
                raise SystemExit(f"Unsupported PNG filter: {filter_type}")
        rows.append(row)
        prior = row

    pixels: list[Pixel] = []
    for row in rows:
        for x in range(width):
            base = x * channels
            r, g, b = row[base], row[base + 1], row[base + 2]
            a = row[base + 3] if channels == 4 else 255
            pixels.append((r, g, b, a))
    return width, height, pixels


def write_png(path: Path, width: int, height: int, pixels: list[Pixel]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y * width + x])
    payload = b"".join(
        [
            PNG_SIGNATURE,
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


def alpha_for_pixel(pixel: Pixel) -> int:
    r, g, b, a = pixel
    if a == 0:
        return 0
    green_key = g > 145 and g > r * 1.25 and g > b * 1.25
    if green_key:
        return 0
    # Turn tiny white eye/highlight pixels into holes so a template icon stays a silhouette.
    if r > 205 and g > 205 and b > 205:
        return 0
    return 255


def resize_alpha(alpha: list[int], width: int, height: int, out_w: int, out_h: int) -> list[int]:
    resized: list[int] = []
    for y in range(out_h):
        src_y = min(height - 1, int(y * height / out_h))
        for x in range(out_w):
            src_x = min(width - 1, int(x * width / out_w))
            resized.append(alpha[src_y * width + src_x])
    return resized


def resize_rgba(pixels: list[Pixel], width: int, height: int, size: int) -> list[Pixel]:
    resized: list[Pixel] = []
    for y in range(size):
        src_y = min(height - 1, int(y * height / size))
        for x in range(size):
            src_x = min(width - 1, int(x * width / size))
            resized.append(pixels[src_y * width + src_x])
    return resized


def make_template(source: Path, out: Path) -> None:
    width, height, pixels = read_png(source)
    alpha = [alpha_for_pixel(pixel) for pixel in pixels]
    points = [(i % width, i // width) for i, value in enumerate(alpha) if value > 0]
    if not points:
        raise SystemExit("No silhouette found after removing the chroma-key background.")

    min_x = min(x for x, _y in points)
    max_x = max(x for x, _y in points)
    min_y = min(y for _x, y in points)
    max_y = max(y for _x, y in points)
    crop_w = max_x - min_x + 1
    crop_h = max_y - min_y + 1
    cropped: list[int] = []
    for y in range(min_y, max_y + 1):
        cropped.extend(alpha[y * width + min_x : y * width + max_x + 1])

    master = 1024
    target = 720
    if crop_w >= crop_h:
        scaled_w = target
        scaled_h = max(1, round(crop_h * target / crop_w))
    else:
        scaled_h = target
        scaled_w = max(1, round(crop_w * target / crop_h))
    scaled_alpha = resize_alpha(cropped, crop_w, crop_h, scaled_w, scaled_h)
    canvas: list[Pixel] = [(0, 0, 0, 0)] * (master * master)
    start_x = (master - scaled_w) // 2
    start_y = (master - scaled_h) // 2
    for y in range(scaled_h):
        for x in range(scaled_w):
            a = scaled_alpha[y * scaled_w + x]
            if a:
                canvas[(start_y + y) * master + start_x + x] = (0, 0, 0, a)
    write_png(out, master, master, canvas)


def export_variants(template: Path) -> None:
    width, height, pixels = read_png(template)
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
    ICONSET.mkdir(exist_ok=True)
    RESOURCES.mkdir(parents=True, exist_ok=True)
    LANDING.mkdir(exist_ok=True)
    for name, size in sizes.items():
        write_png(ICONSET / name, size, size, resize_rgba(pixels, width, height, size))
    write_png(RESOURCES / "SnootStatusIcon.png", 64, 64, resize_rgba(pixels, width, height, 64))
    write_png(LANDING / "snoot-mark.png", 512, 512, resize_rgba(pixels, width, height, 512))
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    if not args.source.exists():
        raise SystemExit(f"Source image not found: {args.source}")

    ASSETS.mkdir(exist_ok=True)
    source_copy = ASSETS / "snoot-icon-imagegen-source.png"
    source_copy.write_bytes(args.source.read_bytes())
    template = ASSETS / "snoot-icon-template.png"
    make_template(source_copy, template)
    export_variants(template)
    print(f"Imported Snoot silhouette from {args.source}")


if __name__ == "__main__":
    main()
