#!/usr/bin/env python3
"""Generates the bundled Lottie animations for the exercise library.

Each animation is a rigged human figure (see `human_rig.py`) posed and
keyframed for one exercise, so a user can copy the movement rather than
infer it from a diagram. Files stay a few kilobytes because a pose is a set
of joint angles, not a sequence of drawn frames.

Kegels get more than a figure. A pelvic floor contraction is *internal* -
nothing externally visible moves - which is exactly why it is so often done
wrong. So those animations pair the body with a sagittal cutaway showing the
pelvic floor lifting, sync the contraction to the exhale, and mark the
glutes and abdomen as muscles that must stay soft. That combination is the
lesson: the body stays still, the breath keeps moving, the lift is internal.

Usage:
    python3 tool/generate_animations.py
"""

from __future__ import annotations

import json
import math
import os
from typing import Any

from human_rig import (
    AMBER,
    EMERALD,
    SLATE,
    animated,
    disc,
    figure_layers,
    grounded_origin,
    joint_position,
    path_shape,
    pose,
    ring,
    rounded_bar,
    shape_layer,
)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "animations")
FPS = 30


def document(name: str, duration: int, layers: list[dict[str, Any]],
             width: int, height: int) -> dict[str, Any]:
    return {
        "v": "5.7.4", "fr": FPS, "ip": 0, "op": duration,
        "w": width, "h": height, "nm": name, "ddd": 0,
        "assets": [], "layers": layers,
    }


def static(x: float, y: float, duration: int) -> dict[str, Any]:
    return {"a": 0, "k": [x, y, 0]}


def ground(layers: list[dict[str, Any]], y: float, width: float,
           duration: int, centre_x: float) -> None:
    """Appends the floor line *behind* everything already placed.

    Lottie draws the first layer in the array on top, so the ground has to
    be added last and carry the highest index, or the figure stands behind
    the floor it is meant to rest on.
    """
    layers.append(shape_layer(
        max(l["ind"] for l in layers) + 1, "ground",
        [rounded_bar(width, 5, SLATE, opacity=45)],
        duration, position=static(centre_x, y, duration),
    ))


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------

# Lying on the back, knees bent, feet flat - the position every Kegel
# instruction starts from, because gravity assists the lift there.
SUPINE = pose(
    pelvis=90, abdomen=90, chest=90, neck=90, head=90,
    thighNear=-135, shinNear=-27, footNear=-90,
    thighFar=-129, shinFar=-33, footFar=-90,
    armUpperNear=-66, armForeNear=-107,
    armUpperFar=-60, armForeFar=-100,
)

SEATED = pose(
    pelvis=0, abdomen=178, chest=176, neck=178, head=178,
    thighNear=-90, shinNear=-4, footNear=-90,
    thighFar=-86, shinFar=2, footFar=-90,
    armUpperNear=-8, armForeNear=-62,
    armUpperFar=-2, armForeFar=-56,
)

STANDING_TALL = pose(
    armUpperNear=8, armForeNear=10, armUpperFar=-8, armForeFar=-10,
)


# ---------------------------------------------------------------------------
# The pelvic floor cutaway
# ---------------------------------------------------------------------------

def pelvic_inset(first_ind: int, duration: int, origin: tuple[float, float],
                 phases: list[tuple[float, float]],
                 invert: bool = False) -> list[dict[str, Any]]:
    """A sagittal cutaway of the male pelvis with a lifting pelvic floor.

    `phases` is `(frame, lift)` where lift runs 0 (fully released) to 1
    (fully contracted). The floor is drawn as a hammock slung between the
    pubic bone at the front and the tailbone at the back; contracting it
    raises the sling and draws it forward, which is the movement a user
    cannot see on their own body and therefore cannot copy without this.

    `invert` swaps the direction for reverse Kegels, where the floor drops
    and widens instead - a genuinely different movement, not a weaker one.
    """
    cx, cy = origin

    def floor_curve(lift: float) -> list[tuple[float, float]]:
        # The pubic end is fixed; the sling between it and the tailbone rises
        # and draws forward as it contracts.
        drop = -lift if invert else lift
        sag = 26 - drop * 30
        forward = drop * 6
        return [
            (cx - 58, cy + 16),
            (cx - 34 - forward, cy + 16 + sag * 0.78),
            (cx - 6 - forward, cy + 18 + sag),
            (cx + 22, cy + 16 + sag * 0.7),
            (cx + 46, cy + 8),
        ]

    def bladder_centre(lift: float) -> list[float]:
        drop = -lift if invert else lift
        return [cx - 14, cy - 28 - drop * 5, 0]

    # Built top-of-stack first. Lottie draws the *first* layer in the array
    # on top, so the panel has to be appended last or it tints everything it
    # is supposed to sit behind.
    layers: list[dict[str, Any]] = []
    ind = first_ind

    # A lift indicator that only shows while the floor is actually raised.
    layers.append(shape_layer(
        ind, "lift direction",
        [path_shape([(0, [(-9, 9), (0, -3), (9, 9)])],
                    AMBER if invert else EMERALD, 6, smooth=0.0)],
        duration,
        position=animated(
            [(t, [cx - 6, cy + 54 - v * 14, 0]) for t, v in phases]
        ),
        opacity=animated([(t, [10 + v * 80]) for t, v in phases]),
        rotation={"a": 0, "k": 180 if invert else 0},
    ))
    ind += 1

    layers.append(shape_layer(
        ind, "pelvic floor",
        [path_shape([(t, floor_curve(v)) for t, v in phases],
                    EMERALD, 9, smooth=0.28)],
        duration, position=static(0, 0, duration),
    ))
    ind += 1

    # The bladder rests on the floor, so it rises with it. Showing it move is
    # what makes "lift" legible as a direction rather than as a squeeze.
    layers.append(shape_layer(
        ind, "bladder", [disc(48, SLATE, opacity=45)], duration,
        position=animated([(t, bladder_centre(v)) for t, v in phases]),
    ))
    ind += 1

    # Pubic bone at the front and sacrum/tailbone at the back - the two
    # anchors the sling is slung between.
    layers.append(shape_layer(
        ind, "pubic bone", [disc(18, SLATE, opacity=75)], duration,
        position=static(cx - 58, cy + 16, duration),
    ))
    ind += 1
    layers.append(shape_layer(
        ind, "tailbone", [rounded_bar(13, 38, SLATE, opacity=75)], duration,
        position=static(cx + 50, cy - 12, duration),
        rotation={"a": 0, "k": -18},
    ))
    ind += 1

    layers.append(shape_layer(
        ind, "inset panel",
        [rounded_bar(168, 152, SLATE, radius=20, opacity=12)], duration,
        position=static(cx - 4, cy, duration),
    ))

    return layers


def soft_marker(ind: int, centre: tuple[float, float], diameter: float,
                duration: int, cycle: int) -> dict[str, Any]:
    """A dashed ring over a muscle that must stay relaxed.

    Glute, thigh and abdominal substitution is the single most common way a
    Kegel goes wrong, so the muscles that should *not* work are marked as
    explicitly as the one that should.
    """
    return shape_layer(
        ind, "stays soft",
        [ring(diameter, AMBER, 3, opacity=100, dash=5)], duration,
        position=static(centre[0], centre[1], duration),
        opacity=animated([
            (0, [30]), (cycle // 2, [85]), (cycle, [30]),
        ]),
    )


# ---------------------------------------------------------------------------
# Exercise families
# ---------------------------------------------------------------------------

W_INSET, H_INSET = 460, 250
W_PLAIN, H_PLAIN = 380, 280


def kegel(name: str, contract: int, hold: int, release: int, rest: int,
          invert: bool = False) -> dict[str, Any]:
    """A supine Kegel: still body, moving breath, lifting pelvic floor."""
    total = contract + hold + release + rest
    t1 = contract
    t2 = contract + hold
    t3 = contract + hold + release

    lift = [(0, 0.0), (t1, 1.0), (t2, 1.0), (t3, 0.0), (total, 0.0)]

    # Breathing continues right through the hold. "Hold for three seconds
    # while breathing normally" is an instruction users routinely break, and
    # a chest that freezes during the hold would teach exactly the wrong
    # thing, so the ribcage keeps moving on its own cycle throughout.
    breath_cycle = 76
    breathing: list[tuple[float, float]] = []
    frame = 0.0
    while frame < total:
        breathing.append((frame, 100))
        breathing.append((frame + breath_cycle * 0.45, 107))
        frame += breath_cycle
    breathing.append((total, 100))

    origin = (158.0, 150.0)
    poses = [(0, SUPINE), (total, SUPINE)]

    layers: list[dict[str, Any]] = []
    figure = figure_layers(
        1, total, poses, [(0, list(origin)), (total, list(origin))],
        breathing=breathing, scale=118,
    )
    layers.extend(figure)
    next_ind = max(l["ind"] for l in figure) + 1

    # Pinned to the rig rather than to guessed coordinates, so the markers
    # follow if the pose is ever adjusted.
    hip = joint_position(SUPINE, "pelvis", origin, scale=1.18)
    belly = joint_position(SUPINE, "abdomen", origin, scale=1.18,
                          distal=True)

    # Glutes sit behind and below the pelvis; the abdominal wall sits above
    # the trunk. Both are marked because both are what men squeeze instead.
    layers.append(soft_marker(next_ind, (hip[0] + 26, hip[1] + 16), 32,
                              total, breath_cycle))
    layers.append(soft_marker(next_ind + 1,
                              ((hip[0] + belly[0]) / 2, belly[1] - 20), 34,
                              total, breath_cycle))
    next_ind += 2

    # The working muscle, on the body, where it actually is.
    layers.append(shape_layer(
        next_ind, "pelvic floor on body",
        [disc(26, EMERALD)], total,
        position=static(hip[0] - 2, hip[1] + 20, total),
        opacity=animated([(t, [18 + v * 72]) for t, v in lift]),
        scale=animated([(t, [100 - v * 18, 100 - v * 18, 100])
                        for t, v in lift]),
    ))
    next_ind += 1

    layers.extend(pelvic_inset(next_ind, total, (356, 126), lift,
                               invert=invert))
    ground(layers, 204, 262, total, 150)

    return document(name, total, layers, W_INSET, H_INSET)


def kegel_standing(name: str, contract: int, hold: int, release: int,
                   rest: int) -> dict[str, Any]:
    """The functional Kegel: bracing the floor before load, on your feet."""
    total = contract + hold + release + rest
    t1, t2, t3 = contract, contract + hold, contract + hold + release
    lift = [(0, 0.0), (t1, 1.0), (t2, 1.0), (t3, 0.0), (total, 0.0)]

    origin = (150.0, 126.0)
    poses = [(0, STANDING_TALL), (total, STANDING_TALL)]

    breathing = [(0, 100), (t1, 100), (t2, 104), (total, 100)]

    layers: list[dict[str, Any]] = []
    figure = figure_layers(
        1, total, poses, [(0, list(origin)), (total, list(origin))],
        breathing=breathing,
    )
    layers.extend(figure)
    next_ind = max(l["ind"] for l in figure) + 1

    hip = joint_position(STANDING_TALL, "pelvis", origin)
    layers.append(soft_marker(next_ind, (hip[0] + 16, hip[1] + 6), 28,
                              total, 70))
    next_ind += 1
    layers.append(shape_layer(
        next_ind, "pelvic floor on body", [disc(24, EMERALD)], total,
        position=static(hip[0], hip[1] + 14, total),
        opacity=animated([(t, [18 + v * 72]) for t, v in lift]),
    ))
    next_ind += 1

    layers.extend(pelvic_inset(next_ind, total, (356, 126), lift))
    ground(layers, 222, 200, total, 142)
    return document(name, total, layers, W_INSET, H_INSET)


def movement(name: str, poses: list[tuple[float, dict[str, float]]],
             origin: list[tuple[float, list[float]]], total: int,
             active: tuple[str, ...] = (),
             floor_y: float | None = 246,
             floor_width: float = 260,
             breathing: list[tuple[float, float]] | None = None,
             width: int = W_PLAIN, height: int = H_PLAIN) -> dict[str, Any]:
    """A plain exercise: the figure moving through its prescribed range."""
    layers: list[dict[str, Any]] = list(figure_layers(
        1, total, poses, origin, active=active, breathing=breathing,
    ))
    if floor_y is not None:
        ground(layers, floor_y, floor_width, total, width / 2)
    return document(name, total, layers, width, height)


def breath_figure(name: str, inhale: int, hold_in: int, exhale: int,
                  hold_out: int) -> dict[str, Any]:
    """A seated figure breathing to the prescription, with a phase ring.

    The ring is the timer; the ribcage is the instruction. Diaphragmatic
    breathing fails when the chest leads, so the belly marker expands first
    and further than the chest does.
    """
    total = inhale + hold_in + exhale + hold_out
    t1, t2, t3 = inhale, inhale + hold_in, inhale + hold_in + exhale

    origin = (150.0, 144.0)
    poses = [(0, SEATED), (total, SEATED)]
    breathing = [(0, 100), (t1, 108), (t2, 108), (t3, 100), (total, 100)]

    layers: list[dict[str, Any]] = []
    figure = figure_layers(
        1, total, poses, [(0, list(origin)), (total, list(origin))],
        breathing=breathing,
    )
    layers.extend(figure)
    ind = max(l["ind"] for l in figure) + 1

    hip = joint_position(SEATED, "abdomen", origin)
    waist = joint_position(SEATED, "abdomen", origin, distal=True)
    belly = ((hip[0] + waist[0]) / 2, (hip[1] + waist[1]) / 2)
    layers.append(shape_layer(
        ind, "belly", [disc(30, EMERALD)], total,
        position=static(belly[0] - 14, belly[1], total),
        opacity={"a": 0, "k": 55},
        scale=animated([
            (0, [100, 100, 100]), (t1, [128, 128, 100]),
            (t2, [128, 128, 100]), (t3, [100, 100, 100]),
            (total, [100, 100, 100]),
        ]),
    ))
    ind += 1

    layers.append(shape_layer(
        ind, "phase ring", [ring(120, EMERALD, 8)], total,
        position=static(356, 126, total),
        scale=animated([
            (0, [52, 52, 100]), (t1, [104, 104, 100]),
            (t2, [104, 104, 100]), (t3, [52, 52, 100]),
            (total, [52, 52, 100]),
        ]),
        opacity=animated([
            (0, [45]), (t1, [100]), (t2, [100]), (t3, [45]), (total, [45]),
        ]),
    ))
    ind += 1
    layers.append(shape_layer(
        ind, "phase guide", [ring(128, SLATE, 3)], total,
        position=static(356, 126, total), opacity={"a": 0, "k": 35},
    ))
    ground(layers, 222, 200, total, 142)
    return document(name, total, layers, W_INSET, H_INSET)


def gait(name: str, cycle: int, lean: float, knee_lift: float,
         arm_swing: float, bounce: float, cycles: int = 2) -> dict[str, Any]:
    """A walking or running cycle.

    Four poses per stride with the legs in antiphase reads as locomotion;
    the vertical bounce is what stops it looking like a puppet sliding on
    rails.
    """
    total = cycle * cycles
    quarter = cycle / 4

    def stride(phase: float) -> dict[str, float]:
        """`phase` in turns. The near leg leads the far leg by half a cycle."""
        near = math.sin(2 * math.pi * phase)
        far = math.sin(2 * math.pi * (phase + 0.5))
        near_knee = max(0.0, -math.cos(2 * math.pi * phase))
        far_knee = max(0.0, -math.cos(2 * math.pi * (phase + 0.5)))
        return pose(
            pelvis=-lean * 0.3, abdomen=180 - lean, chest=180 - lean,
            neck=180 - lean * 0.6, head=180 - lean * 0.4,
            thighNear=-near * knee_lift,
            shinNear=near_knee * knee_lift * 1.1,
            footNear=-90 + near * 12,
            thighFar=-far * knee_lift,
            shinFar=far_knee * knee_lift * 1.1,
            footFar=-90 + far * 12,
            armUpperNear=far * arm_swing,
            armForeNear=far * arm_swing + 26,
            armUpperFar=near * arm_swing,
            armForeFar=near * arm_swing + 26,
        )

    poses: list[tuple[float, dict[str, float]]] = []
    origin: list[tuple[float, list[float]]] = []
    steps = 8 * cycles
    for i in range(steps + 1):
        t = i * total / steps
        phase = i / 8
        p = stride(phase)
        poses.append((t, p))
        # Grounded on whichever foot is lower, so the stride reads as steps
        # rather than as a figure hovering along a sine wave. `bounce` then
        # lifts the whole body for the flight phase of a run, which is a
        # real feature of running and not of walking.
        base = grounded_origin(p, 190.0, 248.0)
        lift = max(0.0, math.sin(4 * math.pi * phase)) * bounce
        origin.append((t, [base[0], base[1] - lift]))

    return movement(name, poses, origin, total, floor_y=250,
                    floor_width=300, width=W_PLAIN, height=H_PLAIN)


def cycling(name: str, cycle: int, cycles: int = 3) -> dict[str, Any]:
    """Seated pedalling: the feet track a circle, so the knees and hips
    follow it rather than swinging freely."""
    total = cycle * cycles
    poses: list[tuple[float, dict[str, float]]] = []
    steps = 8 * cycles
    for i in range(steps + 1):
        t = i * total / steps
        angle = 2 * math.pi * (i / 8)
        near = math.sin(angle)
        far = math.sin(angle + math.pi)
        # Angles above 180 lean the trunk forward onto the bars; below 180
        # would recline it, which is a different machine entirely.
        poses.append((t, pose(
            pelvis=16, abdomen=206, chest=210, neck=196, head=192,
            thighNear=-72 - near * 26, shinNear=32 + near * 30, footNear=-88,
            thighFar=-72 - far * 26, shinFar=32 + far * 30, footFar=-88,
            armUpperNear=-104, armForeNear=-100,
            armUpperFar=-100, armForeFar=-96,
        )))
    root = (170.0, 150.0)
    origin = [(0, list(root)), (total, list(root))]

    layers = list(figure_layers(1, total, poses, origin))
    ind = max(l["ind"] for l in layers) + 1

    # Without a bike the figure reads as a man sitting in mid-air. The crank
    # circle is derived from where the feet actually travel rather than
    # guessed, so the pedals line up with the legs that are turning them.
    tips = [joint_position(p, "footNear", root, distal=True) for _, p in poses]
    cx = sum(x for x, _ in tips) / len(tips)
    cy = sum(y for _, y in tips) / len(tips)
    radius = max(
        math.hypot(x - cx, y - cy) for x, y in tips
    )

    layers.append(shape_layer(
        ind, "crank", [ring(radius * 2, SLATE, 4, opacity=55)], total,
        position=static(cx, cy, total),
    ))
    layers.append(shape_layer(
        ind + 1, "saddle", [rounded_bar(46, 8, SLATE, opacity=70)], total,
        position=static(root[0] + 4, root[1] + 12, total),
    ))
    ground(layers, 250, 300, total, W_PLAIN / 2)
    return document(name, total, layers, W_PLAIN, H_PLAIN)


def swim(name: str, cycle: int, cycles: int = 2) -> dict[str, Any]:
    """Front crawl: horizontal body, arms cycling over, legs fluttering."""
    total = cycle * cycles
    poses: list[tuple[float, dict[str, float]]] = []
    steps = 8 * cycles
    for i in range(steps + 1):
        t = i * total / steps
        kick = math.sin(2 * math.pi * (i / 8) * 2)
        # The recovering arm travels a full circle rather than swinging on a
        # sine, so the angle accumulates instead of reversing - a sine would
        # make the arm row back and forth, which is not a stroke.
        turn = (i / 8) * 360
        poses.append((t, pose(
            pelvis=92, abdomen=92, chest=90, neck=88, head=88,
            # Legs stay in line with the trunk; the flutter is small. Bending
            # the knee to a right angle would read as kneeling, not kicking.
            thighNear=-88 + kick * 11, shinNear=-88 + kick * 20, footNear=-86,
            thighFar=-88 - kick * 11, shinFar=-88 - kick * 20, footFar=-86,
            armUpperNear=90 - turn, armForeNear=80 - turn,
            armUpperFar=270 - turn, armForeFar=260 - turn,
        )))
    origin = [(0, [200.0, 150.0]), (total, [200.0, 150.0])]
    return movement(name, poses, origin, total, floor_y=None)


def main() -> None:
    animations = build()
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, doc in sorted(animations.items()):
        path = os.path.join(OUT_DIR, f"{name}.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(doc, handle, separators=(",", ":"))
        print(f"wrote {os.path.relpath(path)}")
    print(f"\n{len(animations)} animations generated.")


def build() -> dict[str, dict[str, Any]]:
    return {
        # ---- Pelvic floor: timings are the literal prescription ----
        "kegel_basic": kegel("Basic Kegel", contract=22, hold=90,
                             release=26, rest=150),
        "kegel_long_hold": kegel("Long hold", contract=30, hold=300,
                                 release=45, rest=180),
        "kegel_quick_pulse": kegel("Quick pulses", contract=7, hold=4,
                                   release=7, rest=10),
        "kegel_functional": kegel_standing("Functional Kegel", contract=26,
                                           hold=120, release=30, rest=90),
        "reverse_kegel": kegel("Reverse Kegel", contract=45, hold=120,
                               release=45, rest=120, invert=True),

        # ---- Strength ----
        "deep_squat": squat(),
        "glute_bridge": glute_bridge(),
        "hip_thrust": hip_thrust(),
        "lunge": lunge(),

        # ---- Core ----
        "plank": plank(),
        "side_plank": side_plank(),
        "dead_bug": dead_bug(),

        # ---- Cardio ----
        "brisk_walk": gait("Brisk walk", cycle=76, lean=3, knee_lift=26,
                           arm_swing=18, bounce=4),
        "jogging": gait("Jogging", cycle=52, lean=8, knee_lift=44,
                        arm_swing=34, bounce=11),
        "cycling": cycling("Cycling", cycle=44),
        "swimming": swim("Swimming", cycle=72),

        # ---- Mobility ----
        "hip_opener": hip_opener(),
        "butterfly_stretch": butterfly(),
        "hamstring_stretch": hamstring(),

        # ---- Breathing: frame counts are the literal counts ----
        "box_breathing": breath_figure("Box breathing", inhale=120,
                                       hold_in=120, exhale=120, hold_out=120),
        "diaphragmatic_breathing": breath_figure(
            "Diaphragmatic breathing", inhale=120, hold_in=8, exhale=180,
            hold_out=8),
        "stress_reset": breath_figure("Stress reset", inhale=150, hold_in=30,
                                      exhale=210, hold_out=30),
    }


# ---------------------------------------------------------------------------
# Individual movements
# ---------------------------------------------------------------------------

def squat() -> dict[str, Any]:
    top = pose(armUpperNear=-84, armForeNear=-88,
               armUpperFar=-78, armForeFar=-82)
    # The trunk leans *forward* over the thighs and the shin travels forward
    # over the foot. Leaning back is the error this animation must not teach.
    bottom = pose(
        pelvis=14, abdomen=202, chest=206, neck=190, head=188,
        thighNear=-150, shinNear=-24, footNear=-90,
        thighFar=-146, shinFar=-28, footFar=-90,
        armUpperNear=-96, armForeNear=-100,
        armUpperFar=-90, armForeFar=-94,
    )
    total = 108
    poses = [(0, top), (34, bottom), (56, bottom), (90, top), (total, top)]
    origin = [(t, grounded_origin(p, 190.0, 248.0)) for t, p in poses]
    return movement("Deep squat", poses, origin, total,
                    active=("thighNear", "thighFar"), floor_y=250)


def glute_bridge() -> dict[str, Any]:
    down = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-138, shinNear=-24, footNear=-90,
        thighFar=-132, shinFar=-30, footFar=-90,
        armUpperNear=-78, armForeNear=-86,
        armUpperFar=-74, armForeFar=-82,
    )
    up = pose(
        pelvis=74, abdomen=76, chest=84, neck=88, head=90,
        thighNear=-158, shinNear=-16, footNear=-90,
        thighFar=-152, shinFar=-22, footFar=-90,
        armUpperNear=-78, armForeNear=-86,
        armUpperFar=-74, armForeFar=-82,
    )
    total = 152
    poses = [(0, down), (26, up), (86, up), (112, down), (total, down)]
    origin = [(0, [170.0, 200.0]), (26, [170.0, 172.0]),
              (86, [170.0, 172.0]), (112, [170.0, 200.0]),
              (total, [170.0, 200.0])]
    return movement("Glute bridge", poses, origin, total,
                    active=("pelvis",), floor_y=236, floor_width=300)


def hip_thrust() -> dict[str, Any]:
    down = pose(
        pelvis=64, abdomen=54, chest=42, neck=60, head=58,
        thighNear=-120, shinNear=-30, footNear=-90,
        thighFar=-114, shinFar=-36, footFar=-90,
        armUpperNear=-40, armForeNear=-70,
        armUpperFar=-34, armForeFar=-64,
    )
    up = pose(
        pelvis=40, abdomen=36, chest=32, neck=54, head=52,
        thighNear=-96, shinNear=-6, footNear=-90,
        thighFar=-92, shinFar=-12, footFar=-90,
        armUpperNear=-40, armForeNear=-70,
        armUpperFar=-34, armForeFar=-64,
    )
    total = 148
    poses = [(0, down), (28, up), (88, up), (116, down), (total, down)]
    origin = [(0, [176.0, 196.0]), (28, [176.0, 172.0]),
              (88, [176.0, 172.0]), (116, [176.0, 196.0]),
              (total, [176.0, 196.0])]
    return movement("Hip thrust", poses, origin, total,
                    active=("pelvis",), floor_y=238, floor_width=300)


def lunge() -> dict[str, Any]:
    tall = pose(armUpperNear=4, armForeNear=6, armUpperFar=-4, armForeFar=-6)
    down = pose(
        pelvis=-4, abdomen=178, chest=176, neck=178, head=178,
        thighNear=-124, shinNear=-4, footNear=-90,
        thighFar=-40, shinFar=64, footFar=-52,
        armUpperNear=-22, armForeNear=-18, armUpperFar=22, armForeFar=26,
    )
    total = 128
    poses = [(0, tall), (36, down), (60, down), (96, tall), (total, tall)]
    origin = [(t, grounded_origin(p, 186.0, 248.0)) for t, p in poses]
    return movement("Lunge", poses, origin, total,
                    active=("thighNear",), floor_y=252, floor_width=300)


def plank() -> dict[str, Any]:
    # Elbows under shoulders, forearms flat, one straight line from the ears
    # to the heels. The trunk rises a few degrees toward the head and the
    # legs fall a few toward the toes, which is what a real plank does -
    # the ankle simply cannot sit as high as the shoulder.
    hold = pose(
        pelvis=94, abdomen=96, chest=96, neck=92, head=92,
        thighNear=-85, shinNear=-85, footNear=-20,
        thighFar=-83, shinFar=-83, footFar=-18,
        armUpperNear=0, armForeNear=90,
        armUpperFar=2, armForeFar=92,
    )
    # A held position still has to breathe, or it reads as a frozen image
    # and the user cannot tell the animation is playing.
    total = 200
    poses = [(0, hold), (total, hold)]
    base = grounded_origin(hold, 196.0, 228.0,
                           contacts=("footNear", "footFar", "armForeNear"))
    origin = [(0, base), (total, base)]
    return movement("Plank", poses, origin, total,
                    active=("abdomen",), floor_y=230, floor_width=310,
                    breathing=[(0, 100), (50, 105), (100, 100),
                               (150, 105), (total, 100)])


def side_plank() -> dict[str, Any]:
    # Seen from the side a side plank silhouettes almost identically to a
    # front plank, so the raised top arm is what distinguishes it.
    hold = pose(
        pelvis=94, abdomen=96, chest=96, neck=92, head=92,
        thighNear=-86, shinNear=-86, footNear=-30,
        thighFar=-84, shinFar=-84, footFar=-28,
        armUpperNear=0, armForeNear=88,
        armUpperFar=178, armForeFar=178,
    )
    total = 190
    poses = [(0, hold), (total, hold)]
    base = grounded_origin(hold, 196.0, 228.0,
                           contacts=("footNear", "footFar", "armForeNear"))
    origin = [(0, base), (total, base)]
    return movement("Side plank", poses, origin, total,
                    active=("abdomen",), floor_y=230, floor_width=310,
                    breathing=[(0, 100), (48, 104), (95, 100),
                               (142, 104), (total, 100)])


def dead_bug() -> dict[str, Any]:
    centre = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-180, shinNear=-90, footNear=-60,
        thighFar=-180, shinFar=-90, footFar=-60,
        armUpperNear=170, armForeNear=172,
        armUpperFar=170, armForeFar=172,
    )
    extended = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-118, shinNear=-104, footNear=-70,
        thighFar=-180, shinFar=-90, footFar=-60,
        armUpperNear=170, armForeNear=172,
        armUpperFar=120, armForeFar=112,
    )
    other = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-180, shinNear=-90, footNear=-60,
        thighFar=-118, shinFar=-104, footFar=-70,
        armUpperNear=120, armForeNear=112,
        armUpperFar=170, armForeFar=172,
    )
    total = 176
    poses = [(0, centre), (34, extended), (58, centre), (92, other),
             (116, centre), (total, centre)]
    origin = [(0, [180.0, 190.0]), (total, [180.0, 190.0])]
    return movement("Dead bug", poses, origin, total,
                    active=("abdomen",), floor_y=228, floor_width=300)


def hip_opener() -> dict[str, Any]:
    start = pose(
        pelvis=-6, abdomen=176, chest=174, neck=178, head=178,
        thighNear=-128, shinNear=-8, footNear=-90,
        thighFar=-30, shinFar=70, footFar=-46,
        armUpperNear=-30, armForeNear=-28, armUpperFar=-24, armForeFar=-22,
    )
    deep = pose(
        pelvis=-14, abdomen=168, chest=164, neck=176, head=176,
        thighNear=-136, shinNear=-6, footNear=-90,
        thighFar=-16, shinFar=80, footFar=-40,
        armUpperNear=-34, armForeNear=-32, armUpperFar=-28, armForeFar=-26,
    )
    total = 210
    poses = [(0, start), (48, deep), (162, deep), (200, start),
             (total, start)]
    origin = [(0, [186.0, 168.0]), (48, [186.0, 178.0]),
              (162, [186.0, 178.0]), (200, [186.0, 168.0]),
              (total, [186.0, 168.0])]
    return movement("Hip opener", poses, origin, total,
                    active=("thighFar",), floor_y=248, floor_width=300)


def butterfly() -> dict[str, Any]:
    start = pose(
        pelvis=0, abdomen=178, chest=176, neck=178, head=178,
        thighNear=-58, shinNear=-134, footNear=-150,
        thighFar=-54, shinFar=-130, footFar=-146,
        armUpperNear=-46, armForeNear=-96, armUpperFar=-42, armForeFar=-92,
    )
    deep = pose(
        pelvis=-10, abdomen=164, chest=158, neck=172, head=170,
        thighNear=-48, shinNear=-140, footNear=-156,
        thighFar=-44, shinFar=-136, footFar=-152,
        armUpperNear=-54, armForeNear=-104, armUpperFar=-50, armForeFar=-100,
    )
    total = 300
    poses = [(0, start), (56, deep), (238, deep), (288, start),
             (total, start)]
    origin = [(0, [180.0, 186.0]), (total, [180.0, 186.0])]
    return movement("Butterfly stretch", poses, origin, total,
                    active=("thighNear", "thighFar"),
                    floor_y=238, floor_width=300)


def hamstring() -> dict[str, Any]:
    start = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-176, shinNear=-172, footNear=-96,
        thighFar=-134, shinFar=-26, footFar=-90,
        armUpperNear=-150, armForeNear=-158,
        armUpperFar=-146, armForeFar=-154,
    )
    deep = pose(
        pelvis=90, abdomen=90, chest=90, neck=90, head=90,
        thighNear=-200, shinNear=-196, footNear=-120,
        thighFar=-134, shinFar=-26, footFar=-90,
        armUpperNear=-166, armForeNear=-176,
        armUpperFar=-162, armForeFar=-172,
    )
    total = 240
    poses = [(0, start), (52, deep), (188, deep), (228, start),
             (total, start)]
    origin = [(0, [176.0, 196.0]), (total, [176.0, 196.0])]
    return movement("Hamstring stretch", poses, origin, total,
                    active=("thighNear",), floor_y=232, floor_width=300)


if __name__ == "__main__":
    main()
