#!/usr/bin/env python3
"""Simulate Pocket Dragon growth timelines and render preview snapshots."""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass, field
from pathlib import Path


PROFILES = {
    "engineer": {
        "apps": {"code": 0.72, "creative": 0.05},
        "colors": {"dark": 0.45, "cool": 0.34, "warm": 0.08, "nature": 0.03},
        "foods": ["meteor_berries", "smoked_sun_meat"],
        "pets_per_day": 2,
    },
    "designer": {
        "apps": {"creative": 0.62, "code": 0.08},
        "colors": {"warm": 0.28, "cool": 0.24, "nature": 0.10, "dark": 0.12},
        "foods": ["moon_sugar", "meteor_berries", "fern_sprouts"],
        "pets_per_day": 4,
    },
    "night-owl": {
        "apps": {"code": 0.35, "creative": 0.15},
        "colors": {"dark": 0.70, "cool": 0.18, "warm": 0.04, "nature": 0.02},
        "foods": ["moon_sugar", "meteor_berries"],
        "pets_per_day": 1,
    },
    "balanced": {
        "apps": {"code": 0.26, "creative": 0.24},
        "colors": {"cool": 0.25, "warm": 0.20, "nature": 0.18, "dark": 0.16},
        "foods": ["meteor_berries", "smoked_sun_meat", "fern_sprouts", "moon_sugar"],
        "pets_per_day": 3,
    },
}

FOODS = {
    "meteor_berries": {"name": "Meteor berries", "exposure": "cool", "energy": 8, "curiosity": 1.2, "confidence": 0.2},
    "smoked_sun_meat": {"name": "Smoked sun-meat", "exposure": "warm", "energy": 12, "curiosity": 0.2, "confidence": 1.5},
    "fern_sprouts": {"name": "Crunchy fern sprouts", "exposure": "nature", "energy": 9, "curiosity": 1.0, "confidence": 0.4},
    "moon_sugar": {"name": "Moon sugar", "exposure": "creative", "energy": 16, "curiosity": 1.6, "confidence": 0.1},
}

MILESTONES = [0, 3, 7, 14, 30, 60, 180]


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def blend(a: str, b: str, t: float) -> str:
    t = clamp(t)
    av = tuple(int(a[i : i + 2], 16) for i in (1, 3, 5))
    bv = tuple(int(b[i : i + 2], 16) for i in (1, 3, 5))
    out = tuple(round(x + (y - x) * t) for x, y in zip(av, bv))
    return "#" + "".join(f"{x:02x}" for x in out)


def stage_for_day(day: int) -> str:
    if day < 4:
        return "Hatchling"
    if day < 15:
        return "Juvenile"
    if day < 31:
        return "Adolescent"
    if day < 61:
        return "Adult"
    return "Elder"


@dataclass
class Creature:
    name: str = "Pebble"
    hunger: float = 18
    affection: float = 76
    energy: float = 82
    curiosity: float = 58
    confidence: float = 34
    exposure: dict[str, float] = field(
        default_factory=lambda: {"warm": 0.0, "cool": 0.35, "nature": 0.0, "dark": 0.0, "creative": 0.0, "code": 0.0}
    )
    favorite_food: str = "Meteor berries"

    def add_exposure(self, kind: str, amount: float) -> None:
        for key in self.exposure:
            self.exposure[key] = clamp(self.exposure[key] * 0.997 + (amount if key == kind else 0))

    def traits(self, day: int) -> dict[str, object]:
        body = "#67d8f4"
        body = blend(body, "#ff8a73", self.exposure["warm"] * 0.55)
        body = blend(body, "#76dd8a", self.exposure["nature"] * 0.50)
        body = blend(body, "#7f75db", self.exposure["dark"] * 0.45)
        wing = blend("#43c2e7", "#a88cff", max(self.exposure["creative"], self.exposure["dark"]) * 0.55)
        dominant = max(("warm", "cool", "nature", "dark", "creative", "code"), key=lambda k: self.exposure[k])
        return {
            "stage": stage_for_day(day),
            "maturity": clamp(day / 60),
            "body": body,
            "wing": wing,
            "dominant": dominant,
            "horn": "swept" if day >= 31 or self.exposure["code"] > 0.22 else "short",
            "markings": [k for k, v in self.exposure.items() if v > 0.20],
            "favoriteFood": self.favorite_food,
        }


def simulate(profile_name: str, days: int, seed: int) -> dict[str, object]:
    rng = random.Random(seed)
    profile = PROFILES[profile_name]
    creature = Creature()
    snapshots: list[dict[str, object]] = []

    for day in range(days + 1):
        if day in MILESTONES or day == days:
            snapshots.append({"day": day, "stats": creature.__dict__.copy(), "traits": creature.traits(day)})

        for _ in range(12):
            color_kind = weighted_choice(profile["colors"], rng)
            creature.add_exposure(color_kind, rng.uniform(0.003, 0.009))
            for app_kind, weight in profile["apps"].items():
                if rng.random() < weight:
                    creature.add_exposure(app_kind, rng.uniform(0.002, 0.006))
                    if app_kind == "code":
                        creature.confidence = min(100, creature.confidence + 0.05)
                    if app_kind == "creative":
                        creature.curiosity = min(100, creature.curiosity + 0.06)

        for _ in range(profile["pets_per_day"]):
            creature.affection = min(100, creature.affection + rng.uniform(0.4, 1.2))

        if rng.random() < 0.85:
            food_id = rng.choice(profile["foods"])
            food = FOODS[food_id]
            creature.favorite_food = food["name"]
            creature.add_exposure(food["exposure"], 0.018)
            creature.energy = min(100, creature.energy + food["energy"] * 0.05)
            creature.curiosity = min(100, creature.curiosity + food["curiosity"] * 0.05)
            creature.confidence = min(100, creature.confidence + food["confidence"] * 0.05)

        creature.energy = clamp(creature.energy / 100 - 0.006, 0, 1) * 100
        creature.hunger = min(100, creature.hunger + rng.uniform(2.0, 5.5))

    return {"profile": profile_name, "days": days, "seed": seed, "snapshots": snapshots}


def weighted_choice(weights: dict[str, float], rng: random.Random) -> str:
    total = sum(weights.values())
    pick = rng.random() * total
    cursor = 0.0
    for key, weight in weights.items():
        cursor += weight
        if pick <= cursor:
            return key
    return next(iter(weights))


def sprite_html(traits: dict[str, object]) -> str:
    body = traits["body"]
    wing = traits["wing"]
    markings = set(traits["markings"])
    glow = "box-shadow: 0 0 12px #d8ccff;" if "dark" in markings else ""
    moss = "<i style='left:40px;top:48px;background:#4fb96e'></i><i style='left:72px;top:44px;background:#4fb96e'></i>" if "nature" in markings else ""
    return f"""
    <div class="sprite" style="{glow}">
      <i style="left:8px;top:72px;width:44px;height:12px;background:{body}"></i>
      <i style="left:44px;top:50px;width:96px;height:48px;background:{body}"></i>
      <i style="left:108px;top:34px;width:36px;height:34px;background:{body}"></i>
      <i style="left:136px;top:42px;width:30px;height:18px;background:{body}"></i>
      <i style="left:66px;top:26px;width:42px;height:52px;background:{wing}"></i>
      <i style="left:116px;top:28px;width:18px;height:8px;background:#ffdc75"></i>
      <i style="left:136px;top:34px;width:14px;height:8px;background:#ffdc75"></i>
      <i style="left:126px;top:44px;width:12px;height:12px;background:#33272d"></i>
      <i style="left:130px;top:45px;width:4px;height:4px;background:#fff"></i>
      <i style="left:64px;top:90px;width:14px;height:34px;background:{body}"></i>
      <i style="left:104px;top:90px;width:14px;height:34px;background:{body}"></i>
      <i style="left:50px;top:82px;width:58px;height:18px;background:#ffdc75"></i>
      {moss}
    </div>"""


def render_html(result: dict[str, object]) -> str:
    cards = []
    for snap in result["snapshots"]:
        traits = snap["traits"]
        exposures = snap["stats"]["exposure"]
        exposure_text = " ".join(f"{k}:{v:.2f}" for k, v in exposures.items())
        cards.append(
            f"""
            <section>
              <h2>Day {snap["day"]}: {traits["stage"]}</h2>
              {sprite_html(traits)}
              <p><b>Dominant:</b> {traits["dominant"]} · <b>Food:</b> {traits["favoriteFood"]}</p>
              <p>{exposure_text}</p>
            </section>
            """
        )
    return f"""<!doctype html>
<meta charset="utf-8">
<title>Pocket Dragon Growth Simulation</title>
<style>
body {{ margin: 24px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f6f2ec; color: #3d3035; }}
main {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 18px; }}
section {{ background: #fffaf2; border: 3px solid #4b3a3f; border-radius: 10px; padding: 14px; }}
h1, h2 {{ margin: 0 0 10px; }}
p {{ font-size: 12px; line-height: 1.35; }}
.sprite {{ position: relative; width: 180px; height: 135px; image-rendering: pixelated; margin: 10px 0; }}
.sprite i {{ position: absolute; display: block; border: 4px solid #4b3a3f; box-sizing: border-box; }}
</style>
<h1>{result["profile"]} profile, {result["days"]} days</h1>
<main>{''.join(cards)}</main>"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=sorted(PROFILES), default="balanced")
    parser.add_argument("--days", type=int, default=180)
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--out", default="simulations/out")
    args = parser.parse_args()

    result = simulate(args.profile, args.days, args.seed)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{args.profile}_{args.days}d_seed{args.seed}"
    (out_dir / f"{stem}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (out_dir / f"{stem}.html").write_text(render_html(result), encoding="utf-8")
    print(out_dir / f"{stem}.html")


if __name__ == "__main__":
    main()
