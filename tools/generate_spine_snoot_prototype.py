#!/usr/bin/env python3
"""Generate a deterministic Moon Velvet Snoot Spine prototype pack.

This is not a replacement for final commissioned art. It gives us a real,
rerunnable Spine-style skeleton/data target: layered transparent regions,
stage skeleton JSON, branch skins, shared animation names, and a preview sheet.
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "spine" / "moon_velvet"
IMAGES = OUT / "images"
ATLAS = OUT / "atlas"
RENDERED = OUT / "rendered"


RGBA = tuple[int, int, int, int]


def hex_rgba(value: str, alpha: int = 255) -> RGBA:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def mix(a: RGBA, b: RGBA, t: float) -> RGBA:
    t = max(0.0, min(1.0, t))
    return (
        round(a[0] + (b[0] - a[0]) * t),
        round(a[1] + (b[1] - a[1]) * t),
        round(a[2] + (b[2] - a[2]) * t),
        round(a[3] + (b[3] - a[3]) * t),
    )


def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[RGBA]) -> None:
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


class Canvas:
    def __init__(self, width: int, height: int, scale: int = 3) -> None:
        self.width = width
        self.height = height
        self.scale = scale
        self.w = width * scale
        self.h = height * scale
        self.pixels: list[RGBA] = [(0, 0, 0, 0)] * (self.w * self.h)

    def _blend(self, x: int, y: int, color: RGBA) -> None:
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        sr, sg, sb, sa = color
        if sa <= 0:
            return
        idx = y * self.w + x
        dr, dg, db, da = self.pixels[idx]
        a = sa / 255.0
        inv = 1.0 - a
        out_a = sa + da * inv
        if out_a <= 0:
            self.pixels[idx] = (0, 0, 0, 0)
            return
        self.pixels[idx] = (
            round(sr * a + dr * inv),
            round(sg * a + dg * inv),
            round(sb * a + db * inv),
            round(out_a),
        )

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, inner: RGBA, outer: RGBA | None = None, angle: float = 0) -> None:
        s = self.scale
        cx *= s
        cy *= s
        rx *= s
        ry *= s
        outer = outer or inner
        angle = math.radians(angle)
        ca, sa = math.cos(angle), math.sin(angle)
        pad = 2 * s
        min_x = max(0, int(cx - rx - pad))
        max_x = min(self.w - 1, int(cx + rx + pad))
        min_y = max(0, int(cy - ry - pad))
        max_y = min(self.h - 1, int(cy + ry + pad))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                dx = x - cx
                dy = y - cy
                px = (dx * ca + dy * sa) / max(rx, 1)
                py = (-dx * sa + dy * ca) / max(ry, 1)
                d = math.sqrt(px * px + py * py)
                if d <= 1.0:
                    edge = max(0.0, min(1.0, (1.0 - d) * 4.0))
                    shade = min(1.0, d * 0.9 + max(0.0, py) * 0.14)
                    color = mix(inner, outer, shade)
                    self._blend(x, y, (color[0], color[1], color[2], round(color[3] * edge)))

    def capsule(self, x1: float, y1: float, x2: float, y2: float, radius: float, color: RGBA) -> None:
        s = self.scale
        x1 *= s
        y1 *= s
        x2 *= s
        y2 *= s
        radius *= s
        min_x = max(0, int(min(x1, x2) - radius - s))
        max_x = min(self.w - 1, int(max(x1, x2) + radius + s))
        min_y = max(0, int(min(y1, y2) - radius - s))
        max_y = min(self.h - 1, int(max(y1, y2) + radius + s))
        vx = x2 - x1
        vy = y2 - y1
        length_sq = max(vx * vx + vy * vy, 1.0)
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                t = max(0.0, min(1.0, ((x - x1) * vx + (y - y1) * vy) / length_sq))
                px = x1 + vx * t
                py = y1 + vy * t
                d = math.hypot(x - px, y - py)
                if d <= radius:
                    edge = min(1.0, (radius - d) / max(1.0, s * 0.75))
                    self._blend(x, y, (color[0], color[1], color[2], round(color[3] * edge)))

    def polygon(self, points: list[tuple[float, float]], color: RGBA) -> None:
        s = self.scale
        pts = [(x * s, y * s) for x, y in points]
        min_x = max(0, int(min(p[0] for p in pts) - s))
        max_x = min(self.w - 1, int(max(p[0] for p in pts) + s))
        min_y = max(0, int(min(p[1] for p in pts) - s))
        max_y = min(self.h - 1, int(max(p[1] for p in pts) + s))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                inside = False
                j = len(pts) - 1
                for i, (xi, yi) in enumerate(pts):
                    xj, yj = pts[j]
                    if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi):
                        inside = not inside
                    j = i
                if inside:
                    self._blend(x, y, color)

    def sparkle(self, cx: float, cy: float, radius: float, color: RGBA) -> None:
        self.capsule(cx - radius, cy, cx + radius, cy, max(0.6, radius * 0.18), color)
        self.capsule(cx, cy - radius, cx, cy + radius, max(0.6, radius * 0.18), color)
        self.ellipse(cx, cy, radius * 0.28, radius * 0.28, color)

    def downsample(self) -> list[RGBA]:
        if self.scale == 1:
            return self.pixels
        out: list[RGBA] = []
        area = self.scale * self.scale
        for y in range(self.height):
            for x in range(self.width):
                r = g = b = a = 0
                for sy in range(self.scale):
                    start = (y * self.scale + sy) * self.w + x * self.scale
                    for sx in range(self.scale):
                        pr, pg, pb, pa = self.pixels[start + sx]
                        r += pr
                        g += pg
                        b += pb
                        a += pa
                out.append((round(r / area), round(g / area), round(b / area), round(a / area)))
        return out


@dataclass(frozen=True)
class Part:
    name: str
    path: str
    width: int
    height: int
    pixels: list[RGBA]


@dataclass(frozen=True)
class Stage:
    key: str
    display: str
    scale: float
    head: float
    snout: float
    horn: float
    wing: float
    tail: float
    poise: float


PALETTE = {
    "ink": hex_rgba("#07050B"),
    "velvet": hex_rgba("#17101F"),
    "velvet_lift": hex_rgba("#2C2039"),
    "velvet_shadow": hex_rgba("#0C0712"),
    "belly": hex_rgba("#F8E7C7"),
    "belly_shadow": hex_rgba("#DDBB91"),
    "wing": hex_rgba("#3A3148", 220),
    "wing_lift": hex_rgba("#6D5778", 190),
    "gold": hex_rgba("#F5CE73"),
    "rose": hex_rgba("#D99A73"),
    "rose_dark": hex_rgba("#9A5C5D"),
    "ivory": hex_rgba("#FFF3D9"),
    "glow": hex_rgba("#FFE7A1", 210),
    "mauve": hex_rgba("#B78AA5", 190),
}

BRANCH_TINTS = {
    "warm": "FFC18AFF",
    "cool": "AFCBFFFF",
    "nature": "B9D8A6FF",
    "dark": "8D78B8FF",
    "creative": "E0A0D8FF",
    "code": "9FE8FFFF",
}

STAGES = [
    Stage("hatchling", "Hatchling", 0.70, 1.22, 0.58, 0.36, 0.48, 0.58, 0.10),
    Stage("juvenile", "Juvenile", 0.82, 1.10, 0.76, 0.58, 0.70, 0.76, 0.28),
    Stage("adolescent", "Adolescent", 0.96, 1.00, 0.92, 0.82, 0.92, 0.96, 0.50),
    Stage("adult", "Adult", 1.10, 0.94, 1.10, 1.00, 1.12, 1.12, 0.76),
    Stage("elder", "Elder", 1.14, 0.92, 1.20, 1.18, 1.06, 1.22, 1.00),
]


def part_canvas(width: int, height: int) -> Canvas:
    return Canvas(max(8, width), max(8, height), 3)


def body(stage: Stage) -> Part:
    w = round(168 * stage.scale)
    h = round(96 * stage.scale * (1.05 - stage.poise * 0.08))
    c = part_canvas(w + 28, h + 28)
    cx, cy = c.width * 0.51, c.height * 0.52
    c.ellipse(cx, cy + 5, w * 0.54, h * 0.48, PALETTE["ink"], PALETTE["velvet_shadow"])
    c.ellipse(cx, cy, w * 0.50, h * 0.44, PALETTE["velvet_lift"], PALETTE["velvet_shadow"])
    c.ellipse(cx - w * 0.15, cy - h * 0.18, w * 0.23, h * 0.16, hex_rgba("#4A3359", 115), hex_rgba("#22172D", 40))
    for i, offset in enumerate((-0.28, -0.05, 0.18)):
        c.sparkle(cx + w * offset, cy - h * (0.25 + i * 0.02), 2.2 + stage.poise * 1.4, hex_rgba("#F9D98E", 74 + round(stage.poise * 55)))
    return Part("body", f"{stage.key}/body", c.width, c.height, c.downsample())


def belly(stage: Stage) -> Part:
    w = round(74 * stage.scale * (1.08 - stage.poise * 0.08))
    h = round(56 * stage.scale)
    c = part_canvas(w + 18, h + 18)
    c.ellipse(c.width * 0.50, c.height * 0.52, w * 0.45, h * 0.43, PALETTE["belly"], PALETTE["belly_shadow"])
    c.ellipse(c.width * 0.43, c.height * 0.37, w * 0.20, h * 0.12, hex_rgba("#FFF7E6", 160), hex_rgba("#F8E7C7", 40))
    return Part("belly", f"{stage.key}/belly", c.width, c.height, c.downsample())


def head(stage: Stage) -> Part:
    w = round(92 * stage.scale * stage.head)
    h = round(78 * stage.scale * stage.head)
    c = part_canvas(w + 28, h + 28)
    cx, cy = c.width * 0.50, c.height * 0.52
    c.ellipse(cx, cy + 4, w * 0.48, h * 0.48, PALETTE["ink"], PALETTE["velvet_shadow"])
    c.ellipse(cx, cy, w * 0.44, h * 0.43, PALETTE["velvet_lift"], PALETTE["velvet_shadow"])
    c.ellipse(cx - w * 0.14, cy - h * 0.18, w * 0.18, h * 0.12, hex_rgba("#5C4168", 110), hex_rgba("#24172E", 55))
    return Part("head", f"{stage.key}/head", c.width, c.height, c.downsample())


def snout(stage: Stage) -> Part:
    w = round(66 * stage.scale * stage.snout)
    h = round(40 * stage.scale * (0.98 + stage.poise * 0.05))
    c = part_canvas(w + 24, h + 20)
    cy = c.height * 0.53
    left = 8
    right = c.width - 8
    upper = cy - h * 0.38
    lower = cy + h * 0.36
    nose_upper = cy - h * 0.25
    nose_lower = cy + h * 0.22
    outline = [
        (left + 4, upper + 2),
        (right - h * 0.34, nose_upper - 1),
        (right, cy - h * 0.08),
        (right - 1, cy + h * 0.13),
        (right - h * 0.34, nose_lower + 1),
        (left + 3, lower),
    ]
    main = [
        (left + 8, upper + 5),
        (right - h * 0.38, nose_upper + 3),
        (right - 7, cy - h * 0.06),
        (right - 8, cy + h * 0.10),
        (right - h * 0.38, nose_lower - 3),
        (left + 8, lower - 4),
    ]
    c.polygon(outline, PALETTE["ink"])
    c.ellipse(left + h * 0.35, cy + 1, h * 0.37, h * 0.39, PALETTE["ink"])
    c.ellipse(right - h * 0.12, cy + 1, h * 0.20, h * 0.23, PALETTE["ink"])
    c.polygon(main, PALETTE["velvet_lift"])
    c.ellipse(left + h * 0.37, cy - 1, h * 0.32, h * 0.33, PALETTE["velvet_lift"], PALETTE["velvet"])
    c.ellipse(right - h * 0.16, cy, h * 0.15, h * 0.17, PALETTE["velvet"], PALETTE["velvet_shadow"])
    c.ellipse(c.width * 0.42, cy - h * 0.16, w * 0.25, h * 0.10, hex_rgba("#684A75", 95), hex_rgba("#21152C", 30))
    c.ellipse(right - h * 0.15, cy - h * 0.08, h * 0.045, h * 0.035, hex_rgba("#07050B", 220))
    c.capsule(c.width * 0.58, cy + h * 0.22, right - h * 0.28, cy + h * 0.17, max(1.0, h * 0.025), hex_rgba("#090710", 135))
    return Part("snout", f"{stage.key}/snout", c.width, c.height, c.downsample())


def tail(stage: Stage) -> Part:
    w = round(112 * stage.scale * stage.tail)
    h = round(52 * stage.scale)
    c = part_canvas(w + 28, h + 30)
    cy = c.height * 0.52
    c.capsule(c.width - 12, cy - 2, c.width * 0.42, cy + 8, h * 0.18, PALETTE["ink"])
    c.capsule(c.width * 0.44, cy + 7, 20, cy - 12, h * 0.13, PALETTE["ink"])
    c.capsule(c.width - 15, cy - 5, c.width * 0.44, cy + 5, h * 0.13, PALETTE["velvet_lift"])
    c.capsule(c.width * 0.45, cy + 5, 23, cy - 12, h * 0.10, PALETTE["velvet"])
    c.ellipse(17, cy - 13, h * 0.12, h * 0.12, PALETTE["rose"], PALETTE["rose_dark"])
    return Part("tail", f"{stage.key}/tail", c.width, c.height, c.downsample())


def wing(stage: Stage, front: bool) -> Part:
    w = round(72 * stage.scale * stage.wing)
    h = round(74 * stage.scale * stage.wing)
    c = part_canvas(w + 26, h + 26)
    left = 10
    top = 10
    right = c.width - 12
    low = c.height - 12
    peak = c.width * (0.43 if front else 0.55)
    c.polygon([(left + 3, low - 4), (peak, top + 2), (right, low * 0.72), (c.width * 0.58, low - 5)], PALETTE["ink"])
    c.polygon([(left + 8, low - 8), (peak, top + 10), (right - 8, low * 0.72), (c.width * 0.58, low - 10)], PALETTE["wing"])
    c.capsule(left + 12, low - 9, peak, top + 12, 2.5 + stage.scale, PALETTE["wing_lift"])
    c.capsule(peak, top + 13, right - 10, low * 0.70, 2.0 + stage.scale, hex_rgba("#9482A2", 110))
    return Part("wing_front" if front else "wing_back", f"{stage.key}/{'wing_front' if front else 'wing_back'}", c.width, c.height, c.downsample())


def horn(stage: Stage, front: bool) -> Part:
    w = round(23 * stage.scale * (0.8 + stage.horn * 0.6))
    h = round(58 * stage.scale * stage.horn)
    c = part_canvas(w + 18, h + 18)
    base_y = c.height - 8
    tip_x = c.width * (0.54 if front else 0.42)
    c.polygon([(7, base_y), (c.width - 8, base_y - 2), (tip_x, 7)], PALETTE["ink"])
    c.polygon([(10, base_y - 4), (c.width - 11, base_y - 5), (tip_x, 13)], PALETTE["ivory"])
    c.polygon([(tip_x - 4, 13), (tip_x + 4, 13), (tip_x, 7)], PALETTE["rose"])
    return Part("horn_front" if front else "horn_back", f"{stage.key}/{'horn_front' if front else 'horn_back'}", c.width, c.height, c.downsample())


def crest(stage: Stage) -> Part:
    w = round(72 * stage.scale)
    h = round(34 * stage.scale * (0.7 + stage.poise * 0.5))
    c = part_canvas(w + 16, h + 16)
    count = 3 + round(stage.poise * 2)
    for i in range(count):
        x = 12 + i * (w / max(2, count - 0.4))
        spike = h * (0.42 + i * 0.06)
        c.polygon([(x - 5, c.height - 9), (x + 7, c.height - 9), (x + 2, c.height - 9 - spike)], PALETTE["ink"])
        c.polygon([(x - 2, c.height - 12), (x + 5, c.height - 12), (x + 2, c.height - 12 - spike * 0.75)], PALETTE["rose"])
    return Part("crest", f"{stage.key}/crest", c.width, c.height, c.downsample())


def eye(stage: Stage, closed: bool) -> Part:
    w = round(28 * stage.scale * (1.2 - stage.poise * 0.12))
    h = round(24 * stage.scale)
    c = part_canvas(w + 14, h + 14)
    cx, cy = c.width * 0.50, c.height * 0.50
    if closed:
        c.capsule(8, cy + 1, c.width - 8, cy - 1, max(1.3, h * 0.09), PALETTE["gold"])
    else:
        c.ellipse(cx, cy, w * 0.38, h * 0.40, hex_rgba("#090710"), hex_rgba("#090710"))
        c.ellipse(cx + 1, cy, w * 0.27, h * 0.30, PALETTE["gold"], hex_rgba("#C58544"))
        c.ellipse(cx + 2, cy + 1, w * 0.12, h * 0.18, hex_rgba("#090710"))
        c.ellipse(cx - w * 0.09, cy - h * 0.10, w * 0.07, h * 0.07, hex_rgba("#FFF8DB", 230))
    return Part("eye_closed" if closed else "eye_open", f"{stage.key}/{'eye_closed' if closed else 'eye_open'}", c.width, c.height, c.downsample())


def leg(stage: Stage, near: bool) -> Part:
    w = round(32 * stage.scale)
    h = round(42 * stage.scale * (0.9 + stage.poise * 0.1))
    c = part_canvas(w + 14, h + 14)
    c.capsule(c.width * 0.46, 8, c.width * 0.48, c.height - 17, w * 0.24, PALETTE["ink"])
    c.capsule(c.width * 0.48, 10, c.width * 0.50, c.height - 19, w * 0.18, PALETTE["velvet_lift"] if near else PALETTE["velvet"])
    c.ellipse(c.width * 0.58, c.height - 13, w * 0.36, h * 0.15, PALETTE["ink"])
    c.ellipse(c.width * 0.60, c.height - 15, w * 0.29, h * 0.10, PALETTE["velvet_lift"] if near else PALETTE["velvet"])
    c.capsule(c.width * 0.45, c.height - 10, c.width * 0.78, c.height - 10, w * 0.055, PALETTE["ivory"])
    return Part("leg_near" if near else "leg_far", f"{stage.key}/{'leg_near' if near else 'leg_far'}", c.width, c.height, c.downsample())


def cheek(stage: Stage) -> Part:
    w = round(30 * stage.scale)
    h = round(20 * stage.scale)
    c = part_canvas(w + 10, h + 10)
    c.ellipse(c.width * 0.5, c.height * 0.5, w * 0.34, h * 0.30, hex_rgba("#D99A73", 112), hex_rgba("#9A5C5D", 30))
    return Part("cheek", f"{stage.key}/cheek", c.width, c.height, c.downsample())


def glow_marks(stage: Stage) -> Part:
    w = round(70 * stage.scale)
    h = round(30 * stage.scale)
    c = part_canvas(w + 12, h + 12)
    alpha = 60 + round(stage.poise * 80)
    c.sparkle(c.width * 0.28, c.height * 0.42, 3.0 + stage.poise * 1.2, hex_rgba("#F9D98E", alpha))
    c.sparkle(c.width * 0.52, c.height * 0.58, 2.0 + stage.poise * 1.4, hex_rgba("#F5CE73", alpha))
    c.sparkle(c.width * 0.72, c.height * 0.37, 2.4 + stage.poise * 1.0, hex_rgba("#FFE7A1", alpha))
    return Part("glow_marks", f"{stage.key}/glow_marks", c.width, c.height, c.downsample())


def parts_for_stage(stage: Stage) -> dict[str, Part]:
    generated = [
        tail(stage),
        wing(stage, front=False),
        leg(stage, near=False),
        body(stage),
        belly(stage),
        wing(stage, front=True),
        leg(stage, near=True),
        head(stage),
        snout(stage),
        horn(stage, front=False),
        horn(stage, front=True),
        crest(stage),
        cheek(stage),
        glow_marks(stage),
        eye(stage, closed=False),
        eye(stage, closed=True),
    ]
    return {part.name: part for part in generated}


def setup(stage: Stage, parts: dict[str, Part]) -> tuple[list[dict], list[dict], dict[str, dict[str, float]]]:
    body_w = parts["body"].width
    body_h = parts["body"].height
    head_w = parts["head"].width
    head_h = parts["head"].height
    snout_w = parts["snout"].width
    wing_w = parts["wing_front"].width
    wing_h = parts["wing_front"].height
    root_y = 42 * stage.scale
    coords = {
        "body": {"x": 0, "y": root_y + body_h * 0.32},
        "tail": {"x": -body_w * 0.42, "y": root_y + body_h * 0.28, "rotation": -10 - stage.poise * 8},
        "wing_back": {"x": -body_w * 0.10, "y": root_y + body_h * 0.60, "rotation": -10},
        "leg_far": {"x": -body_w * 0.20, "y": root_y - parts["leg_far"].height * 0.04, "rotation": 2},
        "belly": {"x": body_w * 0.10, "y": root_y + body_h * 0.24},
        "wing_front": {"x": body_w * 0.02, "y": root_y + body_h * 0.58, "rotation": 8},
        "leg_near": {"x": body_w * 0.24, "y": root_y - parts["leg_near"].height * 0.04, "rotation": -2},
        "head": {"x": body_w * (0.42 + stage.poise * 0.08), "y": root_y + body_h * (0.66 + stage.poise * 0.03), "rotation": 1 + stage.poise * 4},
        "snout": {"x": body_w * (0.42 + stage.poise * 0.08) + head_w * 0.29 + snout_w * 0.20, "y": root_y + body_h * 0.64, "rotation": -2},
        "horn_back": {"x": body_w * 0.39, "y": root_y + body_h * 0.92, "rotation": -18},
        "horn_front": {"x": body_w * 0.60, "y": root_y + body_h * 0.93, "rotation": 12},
        "crest": {"x": body_w * 0.45, "y": root_y + body_h * 1.04, "rotation": 7},
        "cheek": {"x": body_w * 0.66, "y": root_y + body_h * 0.60},
        "glow_marks": {"x": -body_w * 0.04, "y": root_y + body_h * 0.54},
        "eye": {"x": body_w * 0.59, "y": root_y + body_h * 0.73},
    }
    bones = [{"name": "root"}]
    for name, loc in coords.items():
        parent = "root"
        length = 20
        if name in {"snout", "horn_back", "horn_front", "crest", "cheek", "eye"}:
            parent = "head"
            hx = coords["head"]["x"]
            hy = coords["head"]["y"]
            loc = {**loc, "x": loc["x"] - hx, "y": loc["y"] - hy}
        elif name in {"tail", "wing_back", "wing_front", "belly", "leg_far", "leg_near", "glow_marks"}:
            parent = "body"
            bx = coords["body"]["x"]
            by = coords["body"]["y"]
            loc = {**loc, "x": loc["x"] - bx, "y": loc["y"] - by}
        bones.append({
            "name": name,
            "parent": parent,
            "length": length,
            "x": round(loc["x"], 2),
            "y": round(loc["y"], 2),
            "rotation": round(loc.get("rotation", 0), 2),
        })
    slots = [
        {"name": "tail", "bone": "tail", "attachment": "tail"},
        {"name": "wing_back", "bone": "wing_back", "attachment": "wing_back"},
        {"name": "leg_far", "bone": "leg_far", "attachment": "leg_far"},
        {"name": "body", "bone": "body", "attachment": "body"},
        {"name": "belly", "bone": "belly", "attachment": "belly"},
        {"name": "glow_marks", "bone": "glow_marks", "attachment": "glow_marks", "blend": "screen"},
        {"name": "wing_front", "bone": "wing_front", "attachment": "wing_front"},
        {"name": "leg_near", "bone": "leg_near", "attachment": "leg_near"},
        {"name": "head", "bone": "head", "attachment": "head"},
        {"name": "snout", "bone": "snout", "attachment": "snout"},
        {"name": "horn_back", "bone": "horn_back", "attachment": "horn_back"},
        {"name": "horn_front", "bone": "horn_front", "attachment": "horn_front"},
        {"name": "crest", "bone": "crest", "attachment": "crest"},
        {"name": "cheek", "bone": "cheek", "attachment": "cheek", "blend": "screen"},
        {"name": "eye", "bone": "eye", "attachment": "eye_open"},
    ]
    preview_coords = coords
    preview_coords["eye_open"] = preview_coords["eye"]
    preview_coords["eye_closed"] = preview_coords["eye"]
    return bones, slots, preview_coords


def attachment(part: Part) -> dict:
    return {
        "type": "region",
        "path": part.path,
        "width": part.width,
        "height": part.height,
    }


def skeleton_json(stage: Stage, parts: dict[str, Part]) -> dict:
    bones, slots, _ = setup(stage, parts)
    default_attachments = {}
    for slot in slots:
        slot_name = slot["name"]
        if slot_name == "eye":
            default_attachments[slot_name] = {
                "eye_open": attachment(parts["eye_open"]),
                "eye_closed": attachment(parts["eye_closed"]),
            }
        else:
            default_attachments[slot_name] = {slot_name: attachment(parts[slot_name])}
    skins = [{"name": "default", "attachments": default_attachments}]
    for name, color in BRANCH_TINTS.items():
        skins.append(
            {
                "name": name,
                "attachments": {
                    "crest": {"crest": {**attachment(parts["crest"]), "color": color}},
                    "cheek": {"cheek": {**attachment(parts["cheek"]), "color": color}},
                    "glow_marks": {"glow_marks": {**attachment(parts["glow_marks"]), "color": color}},
                    "eye": {
                        "eye_open": {**attachment(parts["eye_open"]), "color": color},
                        "eye_closed": {**attachment(parts["eye_closed"]), "color": color},
                    },
                },
            }
        )
    stage_motion = 1.0 + stage.poise * 0.35
    return {
        "skeleton": {
            "hash": f"moon-velvet-{stage.key}-prototype-v1",
            "spine": "4.2.0",
            "x": -210,
            "y": -12,
            "width": 460,
            "height": 300,
            "fps": 30,
            "images": "./images/",
        },
        "bones": bones,
        "slots": slots,
        "skins": skins,
        "events": {
            "soft_chime": {"string": "soft_chime"},
            "stage_glow": {"string": "stage_glow"},
        },
        "animations": {
            "idle_calm": {
                "bones": {
                    "body": {"translate": [{"time": 0, "y": 0}, {"time": 1.2, "y": 3 * stage_motion}, {"time": 2.4, "y": 0}]},
                    "head": {"rotate": [{"time": 0, "angle": -1}, {"time": 1.2, "angle": 2.5}, {"time": 2.4, "angle": -1}]},
                    "tail": {"rotate": [{"time": 0, "angle": -2}, {"time": 1.2, "angle": 3}, {"time": 2.4, "angle": -2}]},
                    "wing_front": {"rotate": [{"time": 0, "angle": -1}, {"time": 1.2, "angle": 2}, {"time": 2.4, "angle": -1}]},
                    "wing_back": {"rotate": [{"time": 0, "angle": 1}, {"time": 1.2, "angle": -2}, {"time": 2.4, "angle": 1}]},
                },
                "slots": {"eye": {"attachment": [{"time": 0, "name": "eye_open"}, {"time": 2.05, "name": "eye_closed"}, {"time": 2.18, "name": "eye_open"}]}},
            },
            "walk": {
                "bones": {
                    "body": {"translate": [{"time": 0, "y": 0}, {"time": 0.24, "y": 4}, {"time": 0.48, "y": 0}]},
                    "head": {"rotate": [{"time": 0, "angle": 1}, {"time": 0.24, "angle": -2}, {"time": 0.48, "angle": 1}]},
                    "leg_near": {"rotate": [{"time": 0, "angle": -9}, {"time": 0.24, "angle": 11}, {"time": 0.48, "angle": -9}]},
                    "leg_far": {"rotate": [{"time": 0, "angle": 9}, {"time": 0.24, "angle": -11}, {"time": 0.48, "angle": 9}]},
                    "tail": {"rotate": [{"time": 0, "angle": 6}, {"time": 0.24, "angle": -7}, {"time": 0.48, "angle": 6}]},
                }
            },
            "look_curious": {
                "bones": {
                    "head": {"rotate": [{"time": 0, "angle": 0}, {"time": 0.35, "angle": -8}, {"time": 1.1, "angle": -5}, {"time": 1.7, "angle": 0}]},
                    "snout": {"rotate": [{"time": 0, "angle": 0}, {"time": 0.35, "angle": -4}, {"time": 1.7, "angle": 0}]},
                    "crest": {"rotate": [{"time": 0, "angle": 0}, {"time": 0.35, "angle": 5}, {"time": 1.7, "angle": 0}]},
                }
            },
            "curl_sleep": {
                "bones": {
                    "head": {"translate": [{"time": 0, "x": 0, "y": 0}, {"time": 1.0, "x": -20, "y": -24}], "rotate": [{"time": 0, "angle": 0}, {"time": 1.0, "angle": 18}]},
                    "tail": {"rotate": [{"time": 0, "angle": 0}, {"time": 1.0, "angle": 24}]},
                    "body": {"translate": [{"time": 0, "y": 0}, {"time": 1.0, "y": -3}]},
                },
                "slots": {"eye": {"attachment": [{"time": 0, "name": "eye_open"}, {"time": 0.45, "name": "eye_closed"}]}},
            },
            "stage_reveal": {
                "bones": {
                    "root": {"scale": [{"time": 0, "x": 0.85, "y": 0.85}, {"time": 0.5, "x": 1.08, "y": 1.08}, {"time": 0.95, "x": 1, "y": 1}]},
                    "wing_front": {"rotate": [{"time": 0, "angle": -8}, {"time": 0.45, "angle": 8}, {"time": 0.95, "angle": 0}]},
                    "wing_back": {"rotate": [{"time": 0, "angle": 8}, {"time": 0.45, "angle": -8}, {"time": 0.95, "angle": 0}]},
                },
                "slots": {"glow_marks": {"color": [{"time": 0, "color": "FFE7A100"}, {"time": 0.45, "color": "FFE7A1FF"}, {"time": 0.95, "color": "FFE7A199"}]}},
                "events": [{"time": 0.45, "name": "stage_glow"}],
            },
        },
    }


def paste(dst: Canvas, part: Part, center_x: float, center_y: float, opacity: float = 1.0) -> None:
    x0 = round(center_x - part.width / 2)
    y0 = round(center_y - part.height / 2)
    s = dst.scale
    for py in range(part.height):
        for px in range(part.width):
            color = part.pixels[py * part.width + px]
            if color[3] == 0:
                continue
            color = (color[0], color[1], color[2], round(color[3] * opacity))
            for sy in range(s):
                for sx in range(s):
                    dst._blend((x0 + px) * s + sx, (y0 + py) * s + sy, color)


def render_stage_preview(stage: Stage, parts: dict[str, Part], width: int = 390, height: int = 300) -> list[RGBA]:
    c = Canvas(width, height, 2)
    _, slots, coords = setup(stage, parts)
    origin_x = width * 0.43
    origin_y = height * 0.82
    for slot in slots:
        name = slot["name"]
        part_name = "eye_open" if name == "eye" else name
        loc = coords[part_name] if part_name in coords else coords[name]
        x = origin_x + loc["x"]
        y = origin_y - loc["y"]
        opacity = 0.78 if "wing" in part_name else 1.0
        paste(c, parts[part_name], x, y, opacity)
    return c.downsample()


def write_preview(all_parts: dict[str, dict[str, Part]]) -> None:
    tile_w, tile_h = 390, 300
    gap = 22
    width = tile_w * len(STAGES) + gap * (len(STAGES) + 1)
    height = tile_h + 86
    c = Canvas(width, height, 1)
    background = hex_rgba("#0D0B12")
    c.pixels = [background] * (width * height)
    for index, stage in enumerate(STAGES):
        preview = render_stage_preview(stage, all_parts[stage.key], tile_w, tile_h)
        write_png(RENDERED / f"{stage.key}.png", tile_w, tile_h, preview)
        x0 = gap + index * (tile_w + gap)
        y0 = 28
        for y in range(tile_h):
            for x in range(tile_w):
                color = preview[y * tile_w + x]
                if color[3] == 0:
                    continue
                c._blend(x0 + x, y0 + y, color)
        # Underline each stage with the accent intensity it unlocks.
        rose = hex_rgba("#D99A73", 220)
        gold = hex_rgba("#F5CE73", 220)
        c.capsule(x0 + 96, height - 34, x0 + tile_w - 96, height - 34, 2.5, mix(rose, gold, stage.poise))
    write_png(OUT / "moon_velvet_stage_preview.png", width, height, c.pixels)


def write_atlas(stage: Stage, parts: dict[str, Part]) -> None:
    page_width = 1024
    padding = 4
    x = padding
    y = padding
    row_h = 0
    placements: list[tuple[Part, int, int]] = []
    for part in parts.values():
        if x + part.width + padding > page_width:
            x = padding
            y += row_h + padding
            row_h = 0
        placements.append((part, x, y))
        x += part.width + padding
        row_h = max(row_h, part.height)
    page_height = 1
    while page_height < y + row_h + padding:
        page_height *= 2
    page = [(0, 0, 0, 0)] * (page_width * page_height)
    for part, px, py in placements:
        for yy in range(part.height):
            for xx in range(part.width):
                page[(py + yy) * page_width + px + xx] = part.pixels[yy * part.width + xx]
    page_name = f"{stage.key}.png"
    write_png(ATLAS / page_name, page_width, page_height, page)
    lines = [
        page_name,
        f"size: {page_width},{page_height}",
        "format: RGBA8888",
        "filter: Linear,Linear",
        "repeat: none",
    ]
    for part, px, py in placements:
        lines.extend(
            [
                part.path,
                "  rotate: false",
                f"  xy: {px}, {py}",
                f"  size: {part.width}, {part.height}",
                f"  orig: {part.width}, {part.height}",
                "  offset: 0, 0",
                "  index: -1",
            ]
        )
    (ATLAS / f"{stage.key}.atlas").write_text("\n".join(lines) + "\n")


def write_manifest() -> None:
    manifest = {
        "name": "Moon Velvet Snoot Spine Prototype",
        "status": "prototype",
        "source": "tools/generate_spine_snoot_prototype.py",
        "stages": [stage.key for stage in STAGES],
        "sharedAnimations": ["idle_calm", "walk", "look_curious", "curl_sleep", "stage_reveal"],
        "skins": ["default", *BRANCH_TINTS.keys()],
        "runtimeContract": {
            "stage": "one of hatchling, juvenile, adolescent, adult, elder",
            "dominantSkin": "default or one branch skin",
            "animation": "shared animation name across every stage skeleton",
            "eventNames": ["soft_chime", "stage_glow"],
        },
        "notes": [
            "Region PNGs are deliberately layered and transparent for Spine import.",
            "The JSON uses official Spine-style bones, slots, skins, region attachments, and bone/slot timelines.",
            "Final production should replace generated placeholder art with authored/commissioned layered art while preserving names.",
        ],
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    IMAGES.mkdir(parents=True, exist_ok=True)
    ATLAS.mkdir(parents=True, exist_ok=True)
    RENDERED.mkdir(parents=True, exist_ok=True)
    all_parts: dict[str, dict[str, Part]] = {}
    for stage in STAGES:
        parts = parts_for_stage(stage)
        all_parts[stage.key] = parts
        for part in parts.values():
            write_png(IMAGES / f"{part.path}.png", part.width, part.height, part.pixels)
        (OUT / f"snoot_{stage.key}.json").write_text(json.dumps(skeleton_json(stage, parts), indent=2) + "\n")
        write_atlas(stage, parts)
    write_preview(all_parts)
    write_manifest()
    print(f"generated Moon Velvet Spine prototype pack at {OUT}")


if __name__ == "__main__":
    main()
