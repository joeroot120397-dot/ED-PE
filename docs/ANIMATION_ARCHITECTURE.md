# Animation architecture

Every exercise in the library has an animation. This document covers how
they are produced, how they are played, and what a production art pass has
to deliver to drop in without touching code.

## The contract

`ExerciseAnimation` (`lib/features/exercises/domain/exercise.dart`) is the
only thing the app knows about an animation:

```dart
ExerciseAnimation(
  asset: 'assets/animations/kegel_basic.json',
  startingPosition: 'Lying on the back, knees bent, feet flat...',
  motionPath: 'The pelvic floor draws upward and inward for three seconds...',
  activatedMuscles: ['Ischiocavernosus', 'Bulbospongiosus', 'Levator ani'],
  defaultSpeed: 1.0,
)
```

No screen ever hard-codes an asset path. Everything goes through this
struct, which means a missing or malformed file degrades to the described
fallback instead of throwing.

`startingPosition` and `motionPath` are not decoration. They are:

- the captions under the player,
- the `semanticLabel` a screen reader announces in place of the animation,
- the fallback content when the asset fails to load,
- part of the coach's retrieval corpus.

A blind user gets a complete description of every exercise from these two
fields alone. A test asserts both are non-empty for every exercise.

## What ships today

`tool/generate_animations.py` produces 22 Lottie files — a **rigged human
figure** posed and keyframed per exercise, 12–24 KB each.

### The rig

`tool/human_rig.py` builds a forward-kinematics skeleton out of Lottie's
own layer parenting. Lottie composes a child layer's transform with its
parent's, which *is* a bone hierarchy: rotating the thigh carries the shin,
the foot and everything below it. So a pose is fifteen joint angles, not a
drawn frame, and a whole exercise stays kilobytes rather than the megabytes
a rotoscoped or video demonstration would cost.

Bones point from proximal joint to distal, resting straight down the
screen, and angles are the direction the bone points, clockwise from down:

```
0 = down      90 = left      180 = up      -90 = right
```

Poses are authored in **world** angles and converted to parent-relative
locals at emission. That is deliberate: "the thigh points up and to the
right" can be pictured and checked against a photograph, while the same
angle relative to an already-rotated parent cannot.

Three things the rig handles that a naive version gets wrong:

- **Ground contact.** The rig is rooted at the pelvis, so posing a squat by
  dropping the root drops the feet through the floor with it. Grounded
  movements derive the root from the pose via `grounded_origin`, placing the
  pelvis so the lowest contact point rests on the floor.
- **Draw order.** Lottie draws the *first* layer in the array on top, so
  far-side limbs, the inset panel and the ground line are emitted last.
  Getting this backwards puts the floor in front of the figure.
- **Breathing** scales the chest across its width, not along its length.
  Scaling the length telescopes the torso and reads as a shrug.

### Why Kegels get more than a figure

A pelvic floor contraction is **internal — nothing externally visible
moves.** That is exactly why it is so commonly done wrong, and it means a
body alone teaches nothing. The Kegel animations therefore carry four
things at once:

| Element | Teaches |
| --- | --- |
| Supine figure, knees bent, held still | The setup position, and that the body does *not* move |
| Sagittal cutaway | The actual movement: the floor slung between pubic bone and tailbone lifting and drawing forward, the bladder riding up with it |
| Ribcage that keeps moving throughout | Breathe normally — including through the hold |
| Dashed amber rings on glutes and abdomen | The muscles that must stay soft |

That last pair is the whole point. Glute, thigh and abdominal substitution
and breath-holding are the failure modes named in every exercise's
`commonMistakes`, so the animation marks the muscles that should *not* work
as explicitly as the one that should. `reverse_kegel` runs the cutaway
inverted — the floor drops and widens, a genuinely different movement
rather than a weaker one.

Two tests in `test/core/assets_test.dart` pin this: every animation must
contain the named rig joints, and every pelvic-floor exercise must contain
the cutaway layers. The library shipped once with abstract shapes — a
pulsing ring for a Kegel, a hinging bar for a squat — and while they were
legible, you cannot copy a form cue from a rectangle.

The timings are the prescriptions. `kegel_long_hold` holds for 300 frames
at 30 fps — a real ten-second hold, so a user can breathe along with it.
`box_breathing` is four 120-frame phases: an actual 4-4-4-4 count.

Regenerate with:

```bash
python3 tool/generate_animations.py
```

The generator is committed so the assets are reproducible rather than
mystery binaries, and CI regenerates and diffs them: a hand-edited
animation the generator would not produce is a drift bug, because the next
regeneration would silently revert it.

## The player

`ExerciseAnimationPlayer` provides everything the brief calls for:

- **Play / pause**
- **Speed control** cycling 0.5× / 0.75× / 1.0× / 1.5×, starting at the
  exercise's `defaultSpeed` — reverse Kegels and breathing default to slower
  because rushing them defeats the purpose
- **Scrubbable progress bar** (dragging pauses, as users expect)
- **Starting position** and **movement** captions
- **Muscle activation** chips with a toggle

### Failure handling

If the asset is missing or malformed, `Lottie.errorBuilder` returns
`_AnimationFallback` — an icon plus the `motionPath` text — and the state
flag flips in a post-frame callback so the rebuild is legal. Transport
controls disable rather than disappear, so the layout does not jump.

A broken animation must never cost the user their instructions. The steps,
mistakes and safety notes are all below the player and unaffected.

`test/core/assets_test.dart` guards against this ever being needed
accidentally: it asserts every referenced file exists, parses as valid
Lottie via `LottieComposition.fromBytes`, contains at least one animated
property, and stays under 200 KB.

## Replacing with production art

A commissioned illustrated or 3D pass drops in with no code change if it
satisfies:

| Requirement | Value |
| --- | --- |
| Format | Lottie JSON (Bodymovin export) |
| Frame rate | 30 fps |
| Canvas | Square or 16:10, transparent background (current files are 380×280 and 460×250) |
| Loop | Seamless — first and last frame identical |
| Duration | Match the prescribed tempo, not an arbitrary length |
| Size | Under 200 KB per file (enforced by test) |
| Path | Same filename in `assets/animations/` |
| Features | No expressions, no external images, no fonts |

Colours should read on both light and dark surfaces. The current palette
uses emerald `#10B981` for the active tissue, amber `#F59E0B` for the focal
marker and slate `#94A3B8` for context.

If the art direction changes so much that `motionPath` or
`startingPosition` no longer describe what is shown, update those strings in
the same commit. They are the accessible description, and a mismatch is an
accessibility bug, not a copy nit.

### If you go 3D instead

The brief allows a 3D animated character as an alternative. Two viable
routes:

1. **Pre-render to Lottie or sprite sheets.** Keeps the current player, the
   current tests and the current file sizes. Recommended.
2. **Real-time rendering** via `model_viewer_plus` or a Rive state machine.
   Costs tens of megabytes of assets and a much heavier runtime. Only worth
   it if interactive camera control becomes a product requirement.

Either way, `ExerciseAnimation` stays the interface; only the widget that
consumes `asset` changes.

## Anatomy illustrations

Separate from exercise animations: five static SVGs in
`assets/illustrations/`, rendered with `flutter_svg`.

They are drawn as clinical schematics with a labelled colour key, and they
sit on an explicit white card even in dark mode. Recolouring them for dark
mode would break the colour coding — red for arteries, blue for veins,
emerald for erectile tissue — which is doing real explanatory work.

Two constraints worth knowing:

- **`flutter_svg` does not support `<marker>`.** Arrowheads must be drawn as
  explicit polygons. The blood-flow diagram originally used markers and the
  arrows rendered headless.
- Every file carries `<title>` and `aria-label`, and every topic carries a
  `semanticLabel` in Dart that fully describes the diagram. Tests assert all
  three.
