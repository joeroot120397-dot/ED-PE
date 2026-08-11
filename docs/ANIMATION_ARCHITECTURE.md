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

`tool/generate_animations.py` produces 22 schematic Lottie files, roughly
4 KB each, from five parameterised motion designs:

| Design | Used for | What it shows |
| --- | --- | --- |
| `pelvic_ring` | Kegels, reverse Kegels | A ring contracting inward (or widening, for reverse) with a muscle-activation glow, timed to the actual prescription |
| `hinge` | Bridges, thrusts, squats, lunges, planks | A body bar hinging up and down with a hip marker and ground line |
| `travel` | Walking, jogging, cycling, swimming | A dot travelling a loop with a pulsing heart-rate ring |
| `lengthen` | Hip opener, butterfly, hamstring, side plank, dead bug | A limb rotating open around a joint and holding |
| `breath` | Box breathing, diaphragmatic, stress reset | A circle following the literal breath count, phase by phase |

These are deliberately abstract rather than badly-drawn humans. They
communicate **tempo, range and phase**, which is what a user actually needs
to follow along, and they are honest about being diagrams. A 4 KB schematic
that loops correctly beats a 3 MB character animation that is subtly wrong
about the movement.

The timings are the prescriptions. `kegel_long_hold` holds for 300 frames
at 30 fps — a real ten-second hold, so a user can breathe along with it.
`box_breathing` is four 120-frame phases: an actual 4-4-4-4 count.

Regenerate with:

```bash
python3 tool/generate_animations.py
```

The generator is committed so the assets are reproducible rather than
mystery binaries.

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
| Canvas | 300 × 300, transparent background |
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
