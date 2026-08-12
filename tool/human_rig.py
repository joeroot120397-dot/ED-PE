#!/usr/bin/env python3
"""A forward-kinematics human figure, emitted as Lottie shape layers.

Why a rig rather than drawn frames: Lottie parents one layer to another and
composes their transforms, which is exactly a bone hierarchy. Rotating the
thigh carries the shin, the foot and everything below it, so a pose is just
a set of joint angles and the file stays a few kilobytes instead of the
megabytes a rotoscoped or video demonstration would cost.

Authoring convention
--------------------
Every bone points from its proximal joint toward its distal one, and its
rest direction is *down the screen*. An angle is therefore the direction the
bone points, in degrees, clockwise from straight down:

      0 = down      90 = left      180 = up      -90 = right

Poses are written in **world** angles, because "the thigh points up and to
the right" is something you can picture and check against a photograph,
while the local angle relative to a rotated parent is not. `figure_layers`
converts world to local by subtracting the parent's world angle, which is
the arithmetic that makes the hierarchy work.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any, Iterable, Sequence

# Palette. The body is drawn in slate rather than the brand navy because the
# player sits on a near-navy card in dark mode - navy on navy is invisible.
SLATE = [0.580, 0.639, 0.722, 1]
# Limbs are a shade darker than the trunk. Without the tonal step the near
# arm disappears into the torso it overlaps and the figure reads as armless.
SLATE_LIMB = [0.435, 0.498, 0.588, 1]
EMERALD = [0.063, 0.725, 0.506, 1]
AMBER = [0.961, 0.620, 0.043, 1]


@dataclass(frozen=True)
class Bone:
    """One segment of the skeleton.

    `length` is both the drawn length and the distance to the child joint, so
    a child attaches at `[0, parent.length]` unless it overrides `offset`.
    """

    name: str
    parent: str | None
    length: float
    width: float
    shape: str = "limb"  # limb | head | torso | hip | none
    far: bool = False
    offset: tuple[float, float] | None = None


# Proportions are roughly seven-and-a-half heads tall, which is what reads as
# an adult rather than a child or a heroic figure.
SKELETON: tuple[Bone, ...] = (
    Bone("pelvis", None, 0, 0, shape="hip"),
    Bone("abdomen", "pelvis", 26, 30, shape="torso"),
    Bone("chest", "abdomen", 32, 34, shape="torso"),
    Bone("neck", "chest", 9, 11),
    Bone("head", "neck", 30, 30, shape="head"),
    # Far-side limbs are offset a little so they read as depth rather than as
    # a single thick limb, and are drawn behind everything else.
    Bone("armUpperFar", "chest", 32, 11, far=True, offset=(4, 32)),
    Bone("armForeFar", "armUpperFar", 30, 10, far=True),
    Bone("thighFar", "pelvis", 44, 15, far=True, offset=(4, 0)),
    Bone("shinFar", "thighFar", 42, 12, far=True),
    Bone("footFar", "shinFar", 17, 9, far=True),
    Bone("armUpperNear", "chest", 32, 11, offset=(-2, 32)),
    Bone("armForeNear", "armUpperNear", 30, 10),
    Bone("thighNear", "pelvis", 44, 15, offset=(-2, 0)),
    Bone("shinNear", "thighNear", 42, 12),
    Bone("footNear", "shinNear", 17, 9),
)

BY_NAME: dict[str, Bone] = {b.name: b for b in SKELETON}

# Painter's order, farthest first. Lottie draws the *first* layer in the array
# on top, so this list is reversed at emission time.
DRAW_ORDER: tuple[str, ...] = (
    "armUpperFar", "armForeFar", "thighFar", "shinFar", "footFar",
    "pelvis", "abdomen", "chest", "neck", "head",
    "thighNear", "shinNear", "footNear", "armUpperNear", "armForeNear",
)

STANDING: dict[str, float] = {
    "pelvis": 0, "abdomen": 180, "chest": 180, "neck": 180, "head": 180,
    "armUpperFar": -6, "armForeFar": -8, "armUpperNear": 6, "armForeNear": 8,
    "thighFar": 0, "shinFar": 0, "footFar": -90,
    "thighNear": 0, "shinNear": 0, "footNear": -90,
}


def pose(**overrides: float) -> dict[str, float]:
    """A full pose: the standing rest pose with the named joints replaced."""
    unknown = set(overrides) - set(STANDING)
    if unknown:
        raise KeyError(f"no such joint: {sorted(unknown)}")
    return {**STANDING, **overrides}


def direction(angle_deg: float) -> tuple[float, float]:
    """Unit vector a bone at `angle_deg` points along, in screen space."""
    r = math.radians(angle_deg)
    return (-math.sin(r), math.cos(r))


def _ease_in() -> dict[str, Any]:
    return {"x": [0.4], "y": [0.0]}


def _ease_out() -> dict[str, Any]:
    return {"x": [0.6], "y": [1.0]}


def keyframes(points: Sequence[tuple[float, list[float]]]) -> list[dict[str, Any]]:
    """Eased keyframe list. Duplicate timestamps are dropped, keeping the
    first, because Lottie treats a zero-length segment as a discontinuity and
    some renderers snap through it."""
    frames: list[dict[str, Any]] = []
    seen: set[int] = set()
    ordered = sorted(points, key=lambda p: p[0])
    for index, (time, value) in enumerate(ordered):
        t = round(time)
        if t in seen:
            continue
        seen.add(t)
        frame: dict[str, Any] = {"t": t, "s": list(value)}
        if index < len(ordered) - 1:
            frame["i"] = _ease_out()
            frame["o"] = _ease_in()
        frames.append(frame)
    return frames


def animated(points: Sequence[tuple[float, list[float]]]) -> dict[str, Any]:
    """An animated property, collapsed to a static one when it never moves.

    Collapsing matters beyond file size: a property that is flagged animated
    but never changes still forces the renderer to interpolate it every
    frame, and it makes "does this file actually move" untestable.
    """
    values = [tuple(v) for _, v in points]
    if len(set(values)) <= 1:
        return {"a": 0, "k": list(points[0][1])}
    return {"a": 1, "k": keyframes(points)}


def capsule(width: float, length: float, colour: list[float],
            opacity: float = 100) -> dict[str, Any]:
    """A limb: a rounded bar from the joint at (0,0) down to (0, length)."""
    return {
        "ty": "gr", "nm": "limb",
        "it": [
            {"ty": "rc", "d": 1, "nm": "bar",
             "p": {"a": 0, "k": [0, length / 2]},
             "s": {"a": 0, "k": [width, length + width]},
             "r": {"a": 0, "k": width / 2}},
            {"ty": "fl", "nm": "fill", "r": 1,
             "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity}},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
             "o": {"a": 0, "k": 100}},
        ],
    }


def torso_shape(width: float, length: float, colour: list[float],
                opacity: float = 100) -> dict[str, Any]:
    return {
        "ty": "gr", "nm": "torso",
        "it": [
            {"ty": "rc", "d": 1, "nm": "block",
             "p": {"a": 0, "k": [0, length / 2]},
             "s": {"a": 0, "k": [width, length + width * 0.5]},
             "r": {"a": 0, "k": width * 0.42}},
            {"ty": "fl", "nm": "fill", "r": 1,
             "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity}},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
             "o": {"a": 0, "k": 100}},
        ],
    }


def rounded_bar(width: float, height: float, colour: list[float],
                radius: float | None = None, opacity: float = 100,
                centre: list[float] | None = None) -> dict[str, Any]:
    """A plain rounded rectangle of exactly the size asked for.

    Distinct from `torso_shape`, which pads its height to give the trunk its
    shoulders - padding that turns a thin ground line into a slab.
    """
    return {
        "ty": "gr", "nm": "bar",
        "it": [
            {"ty": "rc", "d": 1, "nm": "rect",
             "p": {"a": 0, "k": centre or [0, 0]},
             "s": {"a": 0, "k": [width, height]},
             "r": {"a": 0, "k": min(radius if radius is not None
                                    else height / 2, min(width, height) / 2)}},
            {"ty": "fl", "nm": "fill", "r": 1,
             "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity}},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
             "o": {"a": 0, "k": 100}},
        ],
    }


def disc(diameter: float, colour: list[float], centre: list[float] | None = None,
         opacity: float = 100) -> dict[str, Any]:
    return {
        "ty": "gr", "nm": "disc",
        "it": [
            {"ty": "el", "d": 1, "nm": "ellipse",
             "p": {"a": 0, "k": centre or [0, 0]},
             "s": {"a": 0, "k": [diameter, diameter]}},
            {"ty": "fl", "nm": "fill", "r": 1,
             "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity}},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
             "o": {"a": 0, "k": 100}},
        ],
    }


def ring(diameter: float, colour: list[float], width: float,
         opacity: float = 100, dash: float | None = None) -> dict[str, Any]:
    stroke: dict[str, Any] = {
        "ty": "st", "nm": "stroke", "lc": 2, "lj": 2,
        "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity},
        "w": {"a": 0, "k": width},
    }
    if dash is not None:
        stroke["d"] = [
            {"n": "d", "nm": "dash", "v": {"a": 0, "k": dash}},
            {"n": "g", "nm": "gap", "v": {"a": 0, "k": dash}},
        ]
    return {
        "ty": "gr", "nm": "ring",
        "it": [
            {"ty": "el", "d": 1, "nm": "ellipse", "p": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [diameter, diameter]}},
            stroke,
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0},
             "o": {"a": 0, "k": 100}},
        ],
    }


def _vertices(points: Sequence[tuple[float, float]], smooth: float,
              closed: bool) -> dict[str, Any]:
    """Catmull-Rom style tangents, so a list of points becomes a smooth curve
    without having to hand-author bezier handles."""
    pts = [list(p) for p in points]
    n = len(pts)
    tangents_in: list[list[float]] = []
    tangents_out: list[list[float]] = []
    for i in range(n):
        prev = pts[i - 1] if (i > 0 or closed) else pts[i]
        nxt = pts[(i + 1) % n] if (i < n - 1 or closed) else pts[i]
        dx = (nxt[0] - prev[0]) * smooth
        dy = (nxt[1] - prev[1]) * smooth
        tangents_out.append([dx, dy])
        tangents_in.append([-dx, -dy])
    return {"i": tangents_in, "o": tangents_out, "v": pts, "c": closed}


def path_shape(frames: Sequence[tuple[float, Sequence[tuple[float, float]]]],
               colour: list[float], width: float, smooth: float = 0.25,
               closed: bool = False, fill: list[float] | None = None,
               opacity: float = 100) -> dict[str, Any]:
    """A bezier path, optionally morphing between point sets over time.

    Every frame must supply the same number of points - Lottie interpolates
    vertex-by-vertex and silently misbehaves when the counts differ, so this
    is checked rather than trusted.
    """
    counts = {len(pts) for _, pts in frames}
    if len(counts) != 1:
        raise ValueError(f"path frames must share a vertex count, got {counts}")

    if len(frames) == 1:
        ks: dict[str, Any] = {"a": 0, "k": _vertices(frames[0][1], smooth, closed)}
    else:
        keys: list[dict[str, Any]] = []
        ordered = sorted(frames, key=lambda f: f[0])
        for index, (time, pts) in enumerate(ordered):
            key: dict[str, Any] = {
                "t": round(time),
                "s": [_vertices(pts, smooth, closed)],
            }
            if index < len(ordered) - 1:
                key["i"] = _ease_out()
                key["o"] = _ease_in()
            keys.append(key)
        ks = {"a": 1, "k": keys}

    items: list[dict[str, Any]] = [{"ty": "sh", "ind": 0, "nm": "path", "ks": ks}]
    if fill is not None:
        items.append({"ty": "fl", "nm": "fill", "r": 1,
                      "c": {"a": 0, "k": fill}, "o": {"a": 0, "k": opacity}})
    if width > 0:
        items.append({"ty": "st", "nm": "stroke", "lc": 2, "lj": 2,
                      "c": {"a": 0, "k": colour}, "o": {"a": 0, "k": opacity},
                      "w": {"a": 0, "k": width}})
    items.append({"ty": "tr", "p": {"a": 0, "k": [0, 0]},
                  "a": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [100, 100]},
                  "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}})
    return {"ty": "gr", "nm": "path group", "it": items}


def shape_layer(ind: int, name: str, shapes: list[dict[str, Any]],
                duration: int, position: dict[str, Any],
                anchor: list[float] | None = None,
                rotation: dict[str, Any] | None = None,
                scale: dict[str, Any] | None = None,
                opacity: dict[str, Any] | None = None,
                parent: int | None = None) -> dict[str, Any]:
    layer: dict[str, Any] = {
        "ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1, "ao": 0,
        "ks": {
            "o": opacity or {"a": 0, "k": 100},
            "r": rotation or {"a": 0, "k": 0},
            "p": position,
            "a": {"a": 0, "k": (anchor or [0, 0]) + [0]},
            "s": scale or {"a": 0, "k": [100, 100, 100]},
        },
        "shapes": shapes,
        "ip": 0, "op": duration, "st": 0, "bm": 0,
    }
    if parent is not None:
        layer["parent"] = parent
    return layer


def figure_layers(
    first_ind: int,
    duration: int,
    poses: Sequence[tuple[float, dict[str, float]]],
    origin: Sequence[tuple[float, list[float]]],
    scale: float = 100,
    active: Iterable[str] = (),
    breathing: Sequence[tuple[float, float]] | None = None,
) -> list[dict[str, Any]]:
    """Builds the whole figure as parented Lottie layers.

    `poses` are `(frame, world-angle map)` pairs; `origin` positions the
    pelvis over time. `active` names bones drawn in emerald to mark the
    muscle actually working. `breathing` is `(frame, chest scale percent)`,
    applied to the chest only, so the ribcage lifts without the limbs
    inheriting a scale that would visibly stretch them.
    """
    active_set = set(active)
    unknown = active_set - set(BY_NAME)
    if unknown:
        raise KeyError(f"no such joint to activate: {sorted(unknown)}")

    for _, p in poses:
        missing = set(BY_NAME) - set(p)
        if missing:
            raise KeyError(f"pose is missing joints: {sorted(missing)}")

    # Lowest ind draws on top, so allocate indices along the reversed
    # painter's order and keep the array in the same order.
    order = list(reversed(DRAW_ORDER))
    ind_of = {name: first_ind + i for i, name in enumerate(order)}

    layers: list[dict[str, Any]] = []
    for name in order:
        bone = BY_NAME[name]
        if name in active_set:
            colour = EMERALD
        elif bone.shape == "limb":
            colour = SLATE_LIMB
        else:
            colour = SLATE
        opacity_pct = 55 if bone.far else 100

        shapes: list[dict[str, Any]] = []
        if bone.shape == "limb":
            shapes.append(capsule(bone.width, bone.length, colour, opacity_pct))
        elif bone.shape == "torso":
            shapes.append(torso_shape(bone.width, bone.length, colour,
                                      opacity_pct))
        elif bone.shape == "head":
            shapes.append(disc(bone.width, colour,
                               centre=[0, bone.length * 0.40],
                               opacity=opacity_pct))
        elif bone.shape == "hip":
            shapes.append(torso_shape(32, 12, colour, opacity_pct))

        if bone.parent is None:
            position = animated([(t, list(v) + [0]) for t, v in origin])
            rotation = animated([(t, [p[name]]) for t, p in poses])
            layer_scale = {"a": 0, "k": [scale, scale, 100]}
            parent_ind = None
        else:
            parent = BY_NAME[bone.parent]
            attach = bone.offset or (0, parent.length)
            position = {"a": 0, "k": [attach[0], attach[1], 0]}
            rotation = animated(
                [(t, [p[name] - p[bone.parent]]) for t, p in poses]
            )
            layer_scale = None
            parent_ind = ind_of[bone.parent]

        if name == "chest" and breathing:
            layer_scale = animated(
                [(t, [pct, 100, 100]) for t, pct in breathing]
            )

        layers.append(shape_layer(
            ind_of[name], name, shapes, duration,
            position=position, rotation=rotation, scale=layer_scale,
            parent=parent_ind,
        ))

    return layers


def grounded_origin(p: dict[str, float], x: float, floor_y: float,
                    scale: float = 1.0,
                    contacts: Sequence[str] = ("footNear", "footFar"),
                    ) -> list[float]:
    """Pelvis position that puts the lowest contact point on the floor.

    The rig is rooted at the pelvis, so posing a squat by dropping the root
    drops the feet through the floor with it. Every grounded movement
    therefore derives its root position from the pose instead of hard-coding
    it: work out where the contact points land relative to the pelvis, then
    place the pelvis so the lowest one rests on the floor. This is the
    difference between a figure that squats and one that sinks.
    """
    lowest = max(
        joint_position(p, c, (0.0, 0.0), scale, distal=True)[1]
        for c in contacts
    )
    return [x, floor_y - lowest]


def joint_position(p: dict[str, float], bone_name: str,
                   origin: tuple[float, float], scale: float = 1.0,
                   distal: bool = False) -> tuple[float, float]:
    """Where a joint ends up on the canvas for a given pose.

    Used to pin annotations - a "keep this soft" marker over the glutes, a
    highlight over the pelvic floor - to the body rather than to a guessed
    coordinate that drifts the moment a pose is adjusted.
    """
    chain: list[str] = []
    cursor: str | None = bone_name
    while cursor is not None:
        chain.append(cursor)
        cursor = BY_NAME[cursor].parent
    chain.reverse()

    x, y = origin
    for index, name in enumerate(chain):
        bone = BY_NAME[name]
        if bone.parent is not None:
            attach = bone.offset or (0, BY_NAME[bone.parent].length)
            parent_angle = p[bone.parent]
            # The attachment offset is expressed in the parent's local frame,
            # so rotate it by the parent's world angle before stepping.
            # (ux, uy) is the parent's local +y axis, (px, py) its local +x.
            ux, uy = direction(parent_angle)
            px, py = uy, -ux
            x += (attach[0] * px + attach[1] * ux) * scale
            y += (attach[0] * py + attach[1] * uy) * scale
        if distal and index == len(chain) - 1:
            dx, dy = direction(p[name])
            x += dx * bone.length * scale
            y += dy * bone.length * scale
    return (x, y)
