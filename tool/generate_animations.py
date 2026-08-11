#!/usr/bin/env python3
"""Generates the bundled Lottie animations for the exercise library.

These are *schematic* motion graphics, not rotoscoped human figures: a ring
that contracts and releases for pelvic floor work, a body bar that hinges for
strength movements, a travelling dot for cardio, and a four-phase circle for
breathing. They are deliberately abstract - they communicate tempo, range and
phase, which is what a user actually needs to follow along, and they weigh a
couple of kilobytes each instead of several megabytes.

They are also the contract that the production assets must satisfy. When
illustrated or 3D animations are commissioned, they drop into the same paths
with the same frame rate and the same in/out points, and nothing in the app
changes. See docs/ANIMATION_ARCHITECTURE.md.

Usage:
    python3 tool/generate_animations.py
"""

from __future__ import annotations

import json
import math
import os
from typing import Any

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "animations")

FPS = 30
SIZE = 300

EMERALD = [0.063, 0.725, 0.506, 1]
NAVY = [0.043, 0.106, 0.169, 1]
SLATE = [0.580, 0.639, 0.722, 1]
AMBER = [0.961, 0.620, 0.043, 1]


def ease_in() -> dict[str, Any]:
    return {"x": [0.4], "y": [0.0]}


def ease_out() -> dict[str, Any]:
    return {"x": [0.6], "y": [1.0]}


def keyframes(points: list[tuple[int, list[float]]]) -> list[dict[str, Any]]:
    """Builds a keyframe list with smooth easing between every point."""
    frames: list[dict[str, Any]] = []
    for index, (time, value) in enumerate(points):
        frame: dict[str, Any] = {"t": time, "s": value}
        if index < len(points) - 1:
            frame["i"] = ease_out()
            frame["o"] = ease_in()
        frames.append(frame)
    return frames


def transform(
    position: list[float],
    scale: Any = None,
    opacity: Any = None,
    rotation: Any = None,
) -> dict[str, Any]:
    return {
        "o": opacity if opacity is not None else {"a": 0, "k": 100},
        "r": rotation if rotation is not None else {"a": 0, "k": 0},
        "p": {"a": 0, "k": position + [0]},
        "a": {"a": 0, "k": [0, 0, 0]},
        "s": scale if scale is not None else {"a": 0, "k": [100, 100, 100]},
    }


def ellipse(size: list[float], stroke: list[float] | None, width: float,
            fill: list[float] | None = None) -> dict[str, Any]:
    items: list[dict[str, Any]] = [
        {"ty": "el", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": size},
         "nm": "ellipse", "d": 1}
    ]
    if fill is not None:
        items.append({"ty": "fl", "c": {"a": 0, "k": fill},
                      "o": {"a": 0, "k": 100}, "r": 1, "nm": "fill"})
    if stroke is not None:
        items.append({"ty": "st", "c": {"a": 0, "k": stroke},
                      "o": {"a": 0, "k": 100}, "w": {"a": 0, "k": width},
                      "lc": 2, "lj": 2, "nm": "stroke"})
    items.append({"ty": "tr", "p": {"a": 0, "k": [0, 0]},
                  "a": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [100, 100]},
                  "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}})
    return {"ty": "gr", "it": items, "nm": "group"}


def rounded_rect(size: list[float], radius: float, fill: list[float],
                 opacity: float = 100) -> dict[str, Any]:
    return {
        "ty": "gr",
        "nm": "group",
        "it": [
            {"ty": "rc", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": size},
             "r": {"a": 0, "k": radius}, "nm": "rect", "d": 1},
            {"ty": "fl", "c": {"a": 0, "k": fill},
             "o": {"a": 0, "k": opacity}, "r": 1, "nm": "fill"},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]},
             "a": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [100, 100]},
             "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}},
        ],
    }


def layer(index: int, name: str, shapes: list[dict[str, Any]],
          ks: dict[str, Any], duration: int) -> dict[str, Any]:
    return {
        "ddd": 0, "ind": index, "ty": 4, "nm": name, "sr": 1,
        "ks": ks, "ao": 0, "shapes": shapes,
        "ip": 0, "op": duration, "st": 0, "bm": 0,
    }


def document(name: str, duration: int, layers: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "v": "5.7.4", "fr": FPS, "ip": 0, "op": duration,
        "w": SIZE, "h": SIZE, "nm": name, "ddd": 0,
        "assets": [], "layers": layers,
    }


# ---------------------------------------------------------------------------
# Motion designs, one per exercise family
# ---------------------------------------------------------------------------

def pelvic_ring(name: str, hold_frames: int, contract_frames: int,
                release_frames: int, invert: bool = False) -> dict[str, Any]:
    """A ring that draws in (or widens, for reverse Kegels) then releases.

    The timing is the prescription: contract, hold, release, rest.
    """
    rest = 20
    total = contract_frames + hold_frames + release_frames + rest
    small, large = (118, 100) if invert else (62, 100)

    scale = {"a": 1, "k": keyframes([
        (0, [large, large, 100]),
        (contract_frames, [small, small, 100]),
        (contract_frames + hold_frames, [small, small, 100]),
        (contract_frames + hold_frames + release_frames, [large, large, 100]),
        (total, [large, large, 100]),
    ])}

    glow = {"a": 1, "k": keyframes([
        (0, [30]),
        (contract_frames, [100]),
        (contract_frames + hold_frames, [100]),
        (contract_frames + hold_frames + release_frames, [30]),
        (total, [30]),
    ])}

    layers = [
        layer(1, "muscle activation", [ellipse([150, 150], None, 0, EMERALD)],
              transform([SIZE / 2, SIZE / 2], scale=scale,
                        opacity={"a": 1, "k": keyframes([
                            (0, [8]),
                            (contract_frames, [26]),
                            (contract_frames + hold_frames, [26]),
                            (contract_frames + hold_frames + release_frames, [8]),
                            (total, [8]),
                        ])}),
              total),
        layer(2, "pelvic floor", [ellipse([170, 170], EMERALD, 14)],
              transform([SIZE / 2, SIZE / 2], scale=scale, opacity=glow), total),
        layer(3, "pelvic outline", [ellipse([230, 230], SLATE, 4)],
              transform([SIZE / 2, SIZE / 2],
                        opacity={"a": 0, "k": 45}), total),
    ]
    return document(name, total, layers)


def hinge(name: str, lift_frames: int, hold_frames: int) -> dict[str, Any]:
    """A body bar hinging up and down - bridges, thrusts, squats, lunges."""
    total = lift_frames * 2 + hold_frames + 18
    low, high = SIZE * 0.66, SIZE * 0.40

    position = {"a": 1, "k": keyframes([
        (0, [SIZE / 2, low, 0]),
        (lift_frames, [SIZE / 2, high, 0]),
        (lift_frames + hold_frames, [SIZE / 2, high, 0]),
        (lift_frames * 2 + hold_frames, [SIZE / 2, low, 0]),
        (total, [SIZE / 2, low, 0]),
    ])}
    rotation = {"a": 1, "k": keyframes([
        (0, [0]),
        (lift_frames, [-12]),
        (lift_frames + hold_frames, [-12]),
        (lift_frames * 2 + hold_frames, [0]),
        (total, [0]),
    ])}

    ks = transform([SIZE / 2, low], rotation=rotation)
    ks["p"] = position

    layers = [
        layer(1, "body", [rounded_rect([190, 26], 13, EMERALD)], ks, total),
        layer(2, "hip marker", [ellipse([34, 34], None, 0, AMBER)], ks, total),
        layer(3, "ground", [rounded_rect([230, 8], 4, SLATE, opacity=55)],
              transform([SIZE / 2, SIZE * 0.80]), total),
    ]
    return document(name, total, layers)


def travel(name: str, cycle: int) -> dict[str, Any]:
    """A dot travelling a loop with a pulsing trail - cardio work."""
    total = cycle
    radius = 88
    steps = 12
    points: list[tuple[int, list[float]]] = []
    for step in range(steps + 1):
        angle = (step / steps) * 2 * math.pi - math.pi / 2
        points.append((
            round(step * total / steps),
            [SIZE / 2 + radius * math.cos(angle),
             SIZE / 2 + radius * math.sin(angle), 0],
        ))

    pulse = {"a": 1, "k": keyframes([
        (0, [100, 100, 100]),
        (total // 4, [126, 126, 100]),
        (total // 2, [100, 100, 100]),
        (3 * total // 4, [126, 126, 100]),
        (total, [100, 100, 100]),
    ])}

    ks = transform([SIZE / 2, SIZE / 2])
    ks["p"] = {"a": 1, "k": keyframes(points)}

    layers = [
        layer(1, "athlete", [ellipse([38, 38], None, 0, EMERALD)], ks, total),
        layer(2, "heart rate", [ellipse([64, 64], None, 0, AMBER)],
              transform([SIZE / 2, SIZE / 2], scale=pulse,
                        opacity={"a": 0, "k": 22}), total),
        layer(3, "track", [ellipse([176, 176], SLATE, 5)],
              transform([SIZE / 2, SIZE / 2],
                        opacity={"a": 0, "k": 40}), total),
    ]
    return document(name, total, layers)


def lengthen(name: str, reach_frames: int, hold_frames: int) -> dict[str, Any]:
    """A limb rotating open and holding - mobility and stretching."""
    total = reach_frames * 2 + hold_frames + 15
    rotation = {"a": 1, "k": keyframes([
        (0, [0]),
        (reach_frames, [52]),
        (reach_frames + hold_frames, [52]),
        (reach_frames * 2 + hold_frames, [0]),
        (total, [0]),
    ])}

    ks = {
        "o": {"a": 0, "k": 100},
        "r": rotation,
        "p": {"a": 0, "k": [SIZE / 2, SIZE * 0.62, 0]},
        "a": {"a": 0, "k": [-70, 0, 0]},
        "s": {"a": 0, "k": [100, 100, 100]},
    }

    layers = [
        layer(1, "limb", [rounded_rect([150, 22], 11, EMERALD)], ks, total),
        layer(2, "joint", [ellipse([40, 40], None, 0, NAVY)],
              transform([SIZE / 2 - 70, SIZE * 0.62]), total),
        layer(3, "torso", [rounded_rect([26, 130], 13, SLATE, opacity=70)],
              transform([SIZE / 2 - 70, SIZE * 0.40]), total),
    ]
    return document(name, total, layers)


def breath(name: str, inhale: int, hold_in: int, exhale: int,
           hold_out: int) -> dict[str, Any]:
    """A circle following the exact breath prescription, phase by phase."""
    total = inhale + hold_in + exhale + hold_out
    t1, t2, t3 = inhale, inhale + hold_in, inhale + hold_in + exhale

    scale = {"a": 1, "k": keyframes([
        (0, [46, 46, 100]),
        (t1, [100, 100, 100]),
        (t2, [100, 100, 100]),
        (t3, [46, 46, 100]),
        (total, [46, 46, 100]),
    ])}
    opacity = {"a": 1, "k": keyframes([
        (0, [45]),
        (t1, [100]),
        (t2, [100]),
        (t3, [45]),
        (total, [45]),
    ])}

    layers = [
        layer(1, "breath", [ellipse([180, 180], None, 0, EMERALD)],
              transform([SIZE / 2, SIZE / 2], scale=scale,
                        opacity={"a": 1, "k": keyframes([
                            (0, [12]),
                            (t1, [30]),
                            (t2, [30]),
                            (t3, [12]),
                            (total, [12]),
                        ])}),
              total),
        layer(2, "breath ring", [ellipse([180, 180], EMERALD, 10)],
              transform([SIZE / 2, SIZE / 2], scale=scale, opacity=opacity),
              total),
        layer(3, "guide", [ellipse([200, 200], SLATE, 3)],
              transform([SIZE / 2, SIZE / 2],
                        opacity={"a": 0, "k": 35}), total),
    ]
    return document(name, total, layers)


# ---------------------------------------------------------------------------
# One entry per exercise id in ExerciseLibrary
# ---------------------------------------------------------------------------

ANIMATIONS = {
    # Pelvic floor - timings mirror the prescribed hold and release.
    "kegel_basic": lambda: pelvic_ring("Basic Kegel", hold_frames=90,
                                       contract_frames=20, release_frames=25),
    "kegel_quick_pulse": lambda: pelvic_ring("Quick pulses", hold_frames=6,
                                             contract_frames=8,
                                             release_frames=8),
    "kegel_long_hold": lambda: pelvic_ring("Long hold", hold_frames=300,
                                           contract_frames=30,
                                           release_frames=45),
    "kegel_functional": lambda: hinge("Functional Kegel", lift_frames=34,
                                      hold_frames=150),
    "reverse_kegel": lambda: pelvic_ring("Reverse Kegel", hold_frames=150,
                                         contract_frames=45,
                                         release_frames=45, invert=True),

    # Strength
    "deep_squat": lambda: hinge("Deep squat", lift_frames=30, hold_frames=20),
    "glute_bridge": lambda: hinge("Glute bridge", lift_frames=26,
                                  hold_frames=60),
    "hip_thrust": lambda: hinge("Hip thrust", lift_frames=28, hold_frames=60),
    "lunge": lambda: hinge("Lunge", lift_frames=32, hold_frames=16),

    # Core
    "plank": lambda: hinge("Plank", lift_frames=40, hold_frames=200),
    "side_plank": lambda: lengthen("Side plank", reach_frames=35,
                                   hold_frames=180),
    "dead_bug": lambda: lengthen("Dead bug", reach_frames=40, hold_frames=20),

    # Cardio
    "brisk_walk": lambda: travel("Brisk walk", cycle=150),
    "jogging": lambda: travel("Jogging", cycle=110),
    "cycling": lambda: travel("Cycling", cycle=90),
    "swimming": lambda: travel("Swimming", cycle=130),

    # Mobility
    "hip_opener": lambda: lengthen("Hip opener", reach_frames=45,
                                   hold_frames=180),
    "butterfly_stretch": lambda: lengthen("Butterfly stretch",
                                          reach_frames=50, hold_frames=270),
    "hamstring_stretch": lambda: lengthen("Hamstring stretch",
                                          reach_frames=45, hold_frames=180),

    # Breathing - frame counts are the literal 4-4-4-4 and 4-0-6-0 counts.
    "box_breathing": lambda: breath("Box breathing", inhale=120, hold_in=120,
                                    exhale=120, hold_out=120),
    "diaphragmatic_breathing": lambda: breath("Diaphragmatic breathing",
                                              inhale=120, hold_in=6,
                                              exhale=180, hold_out=6),
    "stress_reset": lambda: breath("Stress reset", inhale=150, hold_in=30,
                                   exhale=210, hold_out=30),
}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in sorted(ANIMATIONS.items()):
        path = os.path.join(OUT_DIR, f"{name}.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(build(), handle, separators=(",", ":"))
        print(f"wrote {os.path.relpath(path)}")
    print(f"\n{len(ANIMATIONS)} animations generated.")


if __name__ == "__main__":
    main()
