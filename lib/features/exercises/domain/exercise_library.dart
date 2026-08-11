import '../../assessment/domain/root_cause.dart';
import 'exercise.dart';

/// The VitalRise exercise database.
///
/// Content is bundled rather than fetched so the app is fully usable
/// offline and on first launch. Supabase carries the same rows (see
/// `supabase/migrations/0003_seed_content.sql`) and overrides this list when
/// a newer `content_version` is published, which lets us ship copy fixes
/// without an app store release.
abstract final class ExerciseLibrary {
  static const List<Exercise> all = <Exercise>[
    // ================================================================
    // Pelvic floor - the core of the programme
    // ================================================================
    Exercise(
      id: 'kegel_basic',
      name: 'Basic Kegel contraction',
      category: ExerciseCategory.kegel,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The foundation. Find the muscle, contract it cleanly, and '
          'let it go completely.',
      instructions: <String>[
        'Lie on your back with knees bent and feet flat. Gravity works with '
            'you in this position, which is why beginners start here.',
        'Find the muscle: it is the one you would use to stop urine midstream '
            'or to stop yourself passing wind. Do not practise on an actual '
            'urine stream - that trains the wrong reflex.',
        'Squeeze and lift inward and upward, as though drawing the base of '
            'the penis and the anus toward your navel.',
        'Hold for 3 seconds while breathing normally.',
        'Release fully for 5 seconds. The release matters as much as the '
            'squeeze - it is a separate skill.',
        'Repeat for the prescribed reps.',
      ],
      benefits: <String>[
        'Strengthens the ischiocavernosus muscle, which spikes blood pressure '
            'inside the erection and produces rigidity',
        'Strengthens the bulbospongiosus, which gates ejaculation',
        'Builds the body awareness that every later exercise depends on',
      ],
      dosage: ExerciseDosage(
        sets: 3,
        reps: 10,
        holdSeconds: 3,
        restSeconds: 30,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/kegel_basic.json',
        startingPosition:
            'Lying on the back, knees bent, feet flat, spine '
            'neutral, hands resting on the lower belly',
        motionPath:
            'The pelvic floor draws upward and inward for three '
            'seconds, then lowers back to a fully relaxed resting position',
        activatedMuscles: <String>[
          'Ischiocavernosus',
          'Bulbospongiosus',
          'Levator ani',
        ],
      ),
      commonMistakes: <String>[
        'Squeezing the glutes, thighs or abdominals instead. Put a hand on '
            'each and check they stay soft.',
        'Holding your breath. If you cannot talk through the hold, you are '
            'bracing, not contracting.',
        'Pushing down instead of lifting up. Bearing down is the opposite '
            'movement and can worsen symptoms over time.',
        'Skipping the relaxation phase. A pelvic floor that never releases '
            'becomes tight and weak, not strong.',
      ],
      safetyTips: <String>[
        'Stop if you feel pelvic or tailbone pain.',
        'If you have chronic pelvic pain, start with Reverse Kegels instead '
            'and speak to a pelvic health physiotherapist.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'kegel_quick_pulse',
      name: 'Quick pulses',
      category: ExerciseCategory.kegel,
      difficulty: ExerciseDifficulty.intermediate,
      summary:
          'Trains the fast-twitch fibres that produce the reflex clamp '
          'used to hold back ejaculation.',
      instructions: <String>[
        'Sit upright on a firm chair, feet flat, weight evenly on both sit '
            'bones.',
        'Contract the pelvic floor as fast and hard as you can.',
        'Release just as fast. One pulse is roughly one second in total.',
        'Perform 10 pulses in a continuous run, then rest 30 seconds.',
        'Quality collapses quickly - stop the set the moment the pulses stop '
            'feeling crisp.',
      ],
      benefits: <String>[
        'Recruits type II fast-twitch fibres, which respond to speed rather '
            'than duration',
        'Builds the rapid on-off control used in the stop-start technique',
        'Improves reflex response at the point of high arousal',
      ],
      dosage: ExerciseDosage(
        sets: 3,
        reps: 10,
        holdSeconds: 1,
        restSeconds: 30,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/kegel_quick_pulse.json',
        startingPosition: 'Seated upright, feet flat, hands on thighs',
        motionPath:
            'Rapid on-off pulses of the pelvic floor at roughly one '
            'per second, with full release between each',
        activatedMuscles: <String>[
          'Bulbospongiosus (fast-twitch)',
          'Levator ani',
        ],
        defaultSpeed: 1.0,
      ),
      commonMistakes: <String>[
        'Pulsing at half effort. Speed and intensity are the whole point.',
        'Not releasing fully between pulses, so tension accumulates.',
        'Continuing past the point where the contraction feels vague.',
      ],
      safetyTips: <String>[
        'Do not add these until basic contractions feel effortless.',
        'Fatigue here is normal; pain is not.',
      ],
      targets: <RootCause>[RootCause.pelvicFloorWeakness],
    ),
    Exercise(
      id: 'kegel_long_hold',
      name: 'Long holds',
      category: ExerciseCategory.kegel,
      difficulty: ExerciseDifficulty.intermediate,
      summary:
          'Endurance work for the slow-twitch fibres that keep an '
          'erection firm through the whole act.',
      instructions: <String>[
        'Lie or sit, whichever lets you keep the contraction clean.',
        'Contract to roughly 60 percent of maximum - not an all-out squeeze.',
        'Hold for 10 seconds, breathing steadily the entire time.',
        'Release completely and rest for 10 seconds.',
        'Build toward 10-second holds over several weeks. If the contraction '
            'fades before time, shorten the hold rather than pushing through.',
      ],
      benefits: <String>[
        'Trains endurance in the slow-twitch fibres that sustain rigidity',
        'Directly targets the loss of firmness partway through intercourse',
        'Improves venous occlusion - the mechanism that keeps blood in',
      ],
      dosage: ExerciseDosage(
        sets: 3,
        reps: 8,
        holdSeconds: 10,
        restSeconds: 45,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/kegel_long_hold.json',
        startingPosition:
            'Supine, knees bent, one hand on the belly to '
            'monitor breathing',
        motionPath:
            'A sustained ten-second lift held at moderate intensity, '
            'then a slow full release over three seconds',
        activatedMuscles: <String>[
          'Levator ani (slow-twitch)',
          'Ischiocavernosus',
        ],
      ),
      commonMistakes: <String>[
        'Contracting at 100 percent, which cannot be sustained for ten '
            'seconds and turns into breath-holding.',
        'Letting the contraction quietly fade while the timer runs.',
        'Releasing in a sudden drop rather than a controlled lowering.',
      ],
      safetyTips: <String>[
        'Never do these during urination.',
        'If you get an aching pelvic floor for more than a day afterwards, '
            'halve the volume.',
      ],
      targets: <RootCause>[RootCause.pelvicFloorWeakness],
    ),
    Exercise(
      id: 'kegel_functional',
      name: 'Functional Kegels',
      category: ExerciseCategory.kegel,
      difficulty: ExerciseDifficulty.advanced,
      summary:
          'Contractions under load and in real positions, so the '
          'strength transfers out of the exercise mat.',
      instructions: <String>[
        'Start standing. Perform a 5-second hold while completely upright.',
        'Progress to a bodyweight squat: contract at the bottom of the squat, '
            'hold through the ascent.',
        'Progress to a split stance or lunge hold with a 5-second contraction.',
        'Final progression: contract during movement - walking, stepping up, '
            'or the top of a glute bridge.',
        'Move through the four stages over weeks, not within a single session.',
      ],
      benefits: <String>[
        'Transfers pelvic floor strength into upright, loaded, moving '
            'positions - which is where sex happens',
        'Coordinates the pelvic floor with the deep core and glutes',
        'Removes the "only works lying down" ceiling that stalls most men',
      ],
      dosage: ExerciseDosage(sets: 3, reps: 8, holdSeconds: 5, restSeconds: 45),
      animation: ExerciseAnimation(
        asset: 'assets/animations/kegel_functional.json',
        startingPosition:
            'Standing tall, feet hip-width, ribs stacked over '
            'pelvis',
        motionPath:
            'A pelvic floor contraction is held through a slow squat '
            'descent and ascent, maintaining tension throughout the range',
        activatedMuscles: <String>[
          'Levator ani',
          'Transverse abdominis',
          'Gluteus maximus',
          'Adductors',
        ],
      ),
      commonMistakes: <String>[
        'Adding load before the basic hold is solid, which recruits the glutes '
            'to do the work.',
        'Bracing the abdomen hard, which pushes down on the pelvic floor.',
        'Losing the contraction at the hardest point of the movement and not '
            'noticing.',
      ],
      safetyTips: <String>[
        'Only progress here after 3-4 weeks of consistent basic work.',
        'Any downward pressure or bulging sensation means back off a stage.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'reverse_kegel',
      name: 'Reverse Kegels',
      category: ExerciseCategory.reverseKegel,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The lengthening half. Teaches the pelvic floor to release - '
          'which is what actually delays ejaculation.',
      instructions: <String>[
        'Lie on your back, knees bent, or sit on the edge of a chair leaning '
            'slightly forward.',
        'Inhale slowly through the nose into your belly and lower ribs.',
        'As you inhale, let the pelvic floor widen and drop, as though you '
            'were gently allowing it to open. Think "soften and spread", not '
            '"push".',
        'Hold that relaxed, lengthened state for 5 seconds.',
        'Exhale and return to a neutral resting position - not a contraction.',
        'A useful cue: the feeling just before you start to urinate, when the '
            'floor lets go.',
      ],
      benefits: <String>[
        'A chronically tight pelvic floor is a common and badly missed cause '
            'of premature ejaculation and pelvic pain',
        'Restores the full contract-relax range, which is what strength '
            'actually requires',
        'Downregulates the nervous system alongside the muscle',
      ],
      dosage: ExerciseDosage(sets: 3, reps: 8, holdSeconds: 5, restSeconds: 30),
      animation: ExerciseAnimation(
        asset: 'assets/animations/reverse_kegel.json',
        startingPosition:
            'Supine with knees bent and supported, or seated '
            'leaning slightly forward with forearms on thighs',
        motionPath:
            'On the inhale the diaphragm descends and the pelvic '
            'floor lengthens and widens downward; on the exhale it returns to '
            'neutral without contracting',
        activatedMuscles: <String>[
          'Levator ani (eccentric lengthening)',
          'Diaphragm',
          'Obturator internus',
        ],
        defaultSpeed: 0.75,
      ),
      commonMistakes: <String>[
        'Bearing down hard as if straining on the toilet. This is a gentle '
            'release, not a push.',
        'Holding the breath, which makes lengthening impossible.',
        'Expecting to feel a lot. A subtle sense of "letting go" is correct.',
      ],
      safetyTips: <String>[
        'Stop immediately if you feel pressure in the rectum or perineum.',
        'If you have a hernia or haemorrhoids, keep the effort very light.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.anxietyRelated,
      ],
    ),

    // ================================================================
    // Strength
    // ================================================================
    Exercise(
      id: 'deep_squat',
      name: 'Deep squat',
      category: ExerciseCategory.strength,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The single best driver of pelvic circulation and the acute '
          'testosterone response to training.',
      instructions: <String>[
        'Stand with feet slightly wider than shoulder-width, toes turned out '
            'about 15 degrees.',
        'Take a breath into the belly and brace lightly.',
        'Sit down and back, letting the knees track over the toes. Aim for '
            'hips below knee level if your mobility allows.',
        'Keep the chest up and the whole foot in contact with the floor.',
        'Drive through the mid-foot to stand, squeezing the glutes at the top.',
        'Move slowly on the way down - three seconds - and normally on the '
            'way up.',
      ],
      benefits: <String>[
        'Large-muscle work produces an acute rise in testosterone and growth '
            'hormone',
        'Pumps blood through the pelvic and hip vasculature',
        'Strengthens the glutes and adductors that share fascial connections '
            'with the pelvic floor',
      ],
      dosage: ExerciseDosage(sets: 3, reps: 12, restSeconds: 60),
      animation: ExerciseAnimation(
        asset: 'assets/animations/deep_squat.json',
        startingPosition:
            'Standing, feet slightly wider than shoulder-width, '
            'toes slightly out, arms extended forward for balance',
        motionPath:
            'Hips travel down and back until the thighs pass parallel, '
            'knees tracking over the toes, then drive vertically to standing',
        activatedMuscles: <String>[
          'Gluteus maximus',
          'Quadriceps',
          'Adductor magnus',
          'Pelvic floor (co-contraction)',
        ],
      ),
      commonMistakes: <String>[
        'Knees collapsing inward at the bottom.',
        'Heels lifting - usually an ankle mobility issue; elevate the heels '
            'slightly while you work on it.',
        'Rounding the lower back at depth ("butt wink"). Stop at the depth '
            'you can hold a neutral spine.',
      ],
      safetyTips: <String>[
        'Bodyweight only until the movement is clean.',
        'Skip if you have an unmanaged knee or hip injury.',
      ],
      targets: <RootCause>[
        RootCause.sedentaryLifestyle,
        RootCause.pelvicFloorWeakness,
        RootCause.obesityRelated,
      ],
    ),
    Exercise(
      id: 'glute_bridge',
      name: 'Glute bridge',
      category: ExerciseCategory.strength,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The most direct pairing of glute strength with pelvic floor '
          'activation, and it works from day one.',
      instructions: <String>[
        'Lie on your back, knees bent, feet flat and hip-width apart, heels '
            'about a hand-span from your glutes.',
        'Exhale and press through the heels to lift the hips until the body '
            'forms a straight line from knee to shoulder.',
        'Squeeze the glutes hard at the top and hold 2 seconds.',
        'Lower slowly, one vertebra at a time.',
        'Progression: add a pelvic floor contraction at the top of each rep.',
      ],
      benefits: <String>[
        'Strengthens the glutes, which stabilise the pelvis that the pelvic '
            'floor anchors to',
        'Increases blood flow through the pelvic region',
        'Counteracts the hip flexor shortening caused by sitting',
      ],
      dosage: ExerciseDosage(
        sets: 3,
        reps: 15,
        holdSeconds: 2,
        restSeconds: 45,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/glute_bridge.json',
        startingPosition:
            'Supine, knees bent to about 90 degrees, feet flat '
            'and hip-width, arms at the sides',
        motionPath:
            'The pelvis tilts then lifts until hips, knees and '
            'shoulders form a straight line, holds, and lowers with control',
        activatedMuscles: <String>[
          'Gluteus maximus',
          'Hamstrings',
          'Pelvic floor',
          'Transverse abdominis',
        ],
      ),
      commonMistakes: <String>[
        'Overextending the lower back at the top instead of finishing with '
            'the glutes.',
        'Pushing through the toes rather than the heels, which shifts work to '
            'the hamstrings.',
        'Letting the knees drift apart.',
      ],
      safetyTips: <String>[
        'If you feel this in your lower back, lower the range and squeeze the '
            'glutes harder before lifting.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'hip_thrust',
      name: 'Hip thrust',
      category: ExerciseCategory.strength,
      difficulty: ExerciseDifficulty.intermediate,
      summary:
          'A loaded bridge through a much larger range. The strongest '
          'glute builder there is.',
      instructions: <String>[
        'Sit on the floor with your upper back against a bench or sofa edge, '
            'just under the shoulder blades.',
        'Feet flat, shins vertical at the top of the movement.',
        'Tuck the chin slightly and keep the ribs down.',
        'Drive through the heels to lift the hips to full extension.',
        'Squeeze hard for 2 seconds at the top, then lower under control.',
        'Add load across the hips once 15 clean bodyweight reps are easy.',
      ],
      benefits: <String>[
        'Builds the posterior chain through a fuller range than the bridge',
        'Improves pelvic stability under load',
        'Strong compound stimulus for hormonal response',
      ],
      dosage: ExerciseDosage(
        sets: 4,
        reps: 10,
        holdSeconds: 2,
        restSeconds: 75,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/hip_thrust.json',
        startingPosition:
            'Upper back supported on a bench, hips low, knees '
            'bent, feet planted',
        motionPath:
            'Hips drive upward to full extension with shins vertical, '
            'pause at lockout, then lower to just above the floor',
        activatedMuscles: <String>[
          'Gluteus maximus',
          'Gluteus medius',
          'Hamstrings',
          'Adductors',
        ],
      ),
      commonMistakes: <String>[
        'Hyperextending the lumbar spine to fake a higher lockout.',
        'Letting the bench sit too high on the back, which limits the range.',
        'Feet too close, turning it into a quad exercise.',
      ],
      safetyTips: <String>[
        'Pad any external load across the hips.',
        'Avoid if you have unmanaged lower back pain.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
        RootCause.obesityRelated,
      ],
      equipment: 'Bench or sofa; optional weight',
    ),
    Exercise(
      id: 'lunge',
      name: 'Forward lunge',
      category: ExerciseCategory.strength,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Single-leg work that opens the hip flexors sitting spends all '
          'day shortening.',
      instructions: <String>[
        'Stand tall, feet hip-width apart, hands on hips.',
        'Step forward roughly one and a half of your foot lengths.',
        'Lower straight down until both knees are near 90 degrees. The back '
            'knee hovers just above the floor.',
        'Keep the torso upright - resist leaning forward.',
        'Push through the front heel to return to standing.',
        'Alternate legs. Reps are per leg.',
      ],
      benefits: <String>[
        'Actively lengthens the hip flexors that pull the pelvis out of '
            'position',
        'Corrects side-to-side strength imbalance that destabilises the pelvis',
        'Improves balance and hip control',
      ],
      dosage: ExerciseDosage(sets: 3, reps: 10, restSeconds: 60),
      animation: ExerciseAnimation(
        asset: 'assets/animations/lunge.json',
        startingPosition:
            'Standing tall, feet hip-width, hands on hips, gaze '
            'forward',
        motionPath:
            'One leg steps forward and both knees bend to 90 degrees '
            'as the torso stays vertical, then the front heel drives back to '
            'standing',
        activatedMuscles: <String>[
          'Quadriceps',
          'Gluteus maximus',
          'Hip flexors (lengthening)',
          'Core stabilisers',
        ],
      ),
      commonMistakes: <String>[
        'Steps too short, which drives the front knee far past the toes.',
        'Leaning the torso forward over the front thigh.',
        'Letting the front knee cave inward.',
      ],
      safetyTips: <String>[
        'Hold a wall or chair for balance while learning.',
        'Reduce depth if you feel knee pain.',
      ],
      targets: <RootCause>[
        RootCause.sedentaryLifestyle,
        RootCause.obesityRelated,
      ],
    ),

    // ================================================================
    // Core
    // ================================================================
    Exercise(
      id: 'plank',
      name: 'Front plank',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Trains the deep core to work with the pelvic floor rather '
          'than pressing down on it.',
      instructions: <String>[
        'Set up on forearms and toes, elbows directly under the shoulders.',
        'Form one straight line from head to heels.',
        'Tuck the pelvis very slightly so the lower back is flat, not arched.',
        'Breathe normally throughout - the whole point is bracing without '
            'holding your breath.',
        'Hold for time, stopping the moment the hips sag or hike.',
      ],
      benefits: <String>[
        'Builds the transverse abdominis, which co-contracts with the pelvic '
            'floor automatically',
        'Teaches intra-abdominal pressure control - the difference between '
            'supporting the pelvic floor and crushing it',
        'Stabilises the pelvis for every other exercise in the programme',
      ],
      dosage: ExerciseDosage(
        sets: 3,
        holdSeconds: 30,
        reps: 1,
        restSeconds: 45,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/plank.json',
        startingPosition:
            'Prone on forearms and toes, elbows under '
            'shoulders, body in a straight line',
        motionPath:
            'An isometric hold; the highlighted overlay shows the deep '
            'core and pelvic floor co-contracting while the ribcage stays down',
        activatedMuscles: <String>[
          'Transverse abdominis',
          'Rectus abdominis',
          'Pelvic floor',
          'Shoulder stabilisers',
        ],
      ),
      commonMistakes: <String>[
        'Hips sagging, which loads the lower back instead of the core.',
        'Hips too high, which makes it easy and pointless.',
        'Holding the breath and bearing down - this pushes on the pelvic '
            'floor and undoes Kegel work.',
      ],
      safetyTips: <String>[
        'Drop to the knees rather than losing the line.',
        'Stop at any lower back pain.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'side_plank',
      name: 'Side plank',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.intermediate,
      summary: 'Loads the lateral chain that keeps the pelvis level.',
      instructions: <String>[
        'Lie on one side, elbow directly under the shoulder, legs stacked.',
        'Lift the hips until the body forms a straight line from head to feet.',
        'Keep the top hip pressed forward - it wants to roll back.',
        'Breathe steadily and hold.',
        'Swap sides. Reps are per side.',
      ],
      benefits: <String>[
        'Strengthens the obliques and quadratus lumborum that control pelvic '
            'tilt',
        'Corrects the side-to-side imbalance most desk workers develop',
        'Adds rotational stability the front plank does not train',
      ],
      dosage: ExerciseDosage(
        sets: 2,
        reps: 2,
        holdSeconds: 25,
        restSeconds: 40,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/side_plank.json',
        startingPosition:
            'Side-lying on one forearm, elbow under shoulder, '
            'feet stacked, top arm on the hip',
        motionPath:
            'The hips lift into a straight side-line and hold, then '
            'lower with control',
        activatedMuscles: <String>[
          'Obliques',
          'Quadratus lumborum',
          'Gluteus medius',
        ],
      ),
      commonMistakes: <String>[
        'Letting the hips drop toward the floor as the hold goes on.',
        'Rotating the chest toward the ground.',
        'Shoulder collapsing into the joint - press the floor away.',
      ],
      safetyTips: <String>[
        'Bend the bottom knee to regress the hold.',
        'Skip if you have a shoulder injury.',
      ],
      targets: <RootCause>[RootCause.sedentaryLifestyle],
    ),
    Exercise(
      id: 'dead_bug',
      name: 'Dead bug',
      category: ExerciseCategory.core,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Core control while the limbs move - the pattern that keeps '
          'the pelvis stable during sex.',
      instructions: <String>[
        'Lie on your back, arms straight up toward the ceiling, hips and '
            'knees bent to 90 degrees.',
        'Press the lower back gently into the floor and keep it there. This '
            'is the whole exercise.',
        'Exhale and slowly extend the opposite arm and leg toward the floor.',
        'Stop before the lower back lifts. That point is your current range.',
        'Inhale and return to the start. Alternate sides.',
      ],
      benefits: <String>[
        'Trains anti-extension core control without loading the spine',
        'Coordinates breathing with core bracing, which the pelvic floor '
            'depends on',
        'Safe entry point for men with back pain who cannot plank',
      ],
      dosage: ExerciseDosage(sets: 3, reps: 10, restSeconds: 45),
      animation: ExerciseAnimation(
        asset: 'assets/animations/dead_bug.json',
        startingPosition:
            'Supine with arms vertical and hips and knees bent '
            'to 90 degrees, lower back flat to the floor',
        motionPath:
            'Opposite arm and leg extend slowly toward the floor and '
            'return, while the lumbar spine stays pinned throughout',
        activatedMuscles: <String>[
          'Transverse abdominis',
          'Rectus abdominis',
          'Hip flexors (eccentric)',
        ],
      ),
      commonMistakes: <String>[
        'Letting the lower back arch off the floor - the single mistake that '
            'makes this exercise useless.',
        'Moving too fast.',
        'Holding the breath instead of exhaling on extension.',
      ],
      safetyTips: <String>[
        'Reduce the range before you compromise the back position.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),

    // ================================================================
    // Cardiovascular
    // ================================================================
    Exercise(
      id: 'brisk_walk',
      name: 'Brisk walking',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The most underrated intervention in this app. Thirty minutes '
          'most days measurably improves erectile function.',
      instructions: <String>[
        'Walk at a pace where you can talk but not sing - roughly 100 steps '
            'per minute.',
        'Aim for 30 minutes continuously; two 15-minute blocks also work.',
        'Land mid-foot, keep the posture tall, let the arms swing.',
        'Target 5 days a week.',
      ],
      benefits: <String>[
        'Improves endothelial function - the lining of blood vessels that '
            'releases the nitric oxide an erection runs on',
        'Lowers blood pressure and improves insulin sensitivity',
        'Reduces cortisol, which directly opposes testosterone',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 30),
      animation: ExerciseAnimation(
        asset: 'assets/animations/brisk_walk.json',
        startingPosition: 'Standing tall, shoulders relaxed, gaze forward',
        motionPath:
            'A steady walking gait at a brisk cadence with a natural '
            'arm swing',
        activatedMuscles: <String>[
          'Calves',
          'Hamstrings',
          'Glutes',
          'Cardiovascular system',
        ],
      ),
      commonMistakes: <String>[
        'Strolling. If your breathing does not change, the vessels do not '
            'adapt.',
        'Doing it once a week. Endothelial adaptation needs frequency.',
      ],
      safetyTips: <String>[
        'Build up gradually if you have been inactive.',
        'Stop for chest pain, unusual breathlessness or dizziness and seek '
            'medical advice.',
      ],
      targets: <RootCause>[
        RootCause.cardiovascular,
        RootCause.sedentaryLifestyle,
        RootCause.obesityRelated,
        RootCause.diabetesRelated,
      ],
    ),
    Exercise(
      id: 'jogging',
      name: 'Jogging',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.intermediate,
      summary:
          'Higher intensity, stronger vascular adaptation, more time '
          'efficient than walking.',
      instructions: <String>[
        'Warm up with 5 minutes of walking.',
        'Jog at a conversational pace for the prescribed time.',
        'If you cannot hold a full sentence, slow down.',
        'Beginners: alternate 2 minutes jogging with 1 minute walking and '
            'shift the ratio over weeks.',
        'Cool down with 5 minutes of walking.',
      ],
      benefits: <String>[
        'Raises VO2 max, which correlates strongly with erectile function',
        'Efficient calorie burn for reducing visceral fat',
        'Boosts mood via endorphin and endocannabinoid release',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 25),
      animation: ExerciseAnimation(
        asset: 'assets/animations/jogging.json',
        startingPosition:
            'Standing tall with a slight forward lean from the '
            'ankles',
        motionPath:
            'A running gait at moderate cadence with a mid-foot '
            'strike under the centre of mass',
        activatedMuscles: <String>[
          'Quadriceps',
          'Hamstrings',
          'Calves',
          'Glutes',
          'Cardiovascular system',
        ],
      ),
      commonMistakes: <String>[
        'Going too hard too soon, which usually ends in a shin or knee injury '
            'and a stalled programme.',
        'Overstriding, landing with the heel well ahead of the body.',
      ],
      safetyTips: <String>[
        'Get medical clearance first if you are over 40, sedentary, or have '
            'any cardiac risk factor.',
        'Increase weekly volume by no more than 10 percent.',
      ],
      targets: <RootCause>[
        RootCause.cardiovascular,
        RootCause.obesityRelated,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'cycling',
      name: 'Cycling',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Excellent low-impact cardio - with one caveat about saddle '
          'pressure that matters a great deal here.',
      instructions: <String>[
        'Use a saddle with a central cut-out or a noseless design. This is '
            'not optional advice for this audience.',
        'Set saddle height so the knee is slightly bent at the bottom of the '
            'stroke.',
        'Keep your weight on the sit bones, not the perineum.',
        'Stand out of the saddle for 30 seconds every 10 minutes.',
        'Ride at a pace that raises breathing but allows conversation.',
      ],
      benefits: <String>[
        'Strong cardiovascular stimulus with no impact on the joints',
        'Builds the quadriceps and glutes',
        'Sustainable for men carrying extra weight',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 35),
      animation: ExerciseAnimation(
        asset: 'assets/animations/cycling.json',
        startingPosition:
            'Seated on the saddle with weight on the sit bones, '
            'hands relaxed on the bars',
        motionPath:
            'A smooth circular pedal stroke at a cadence around 80 '
            'revolutions per minute',
        activatedMuscles: <String>[
          'Quadriceps',
          'Glutes',
          'Calves',
          'Cardiovascular system',
        ],
      ),
      commonMistakes: <String>[
        'Riding a narrow, nosed saddle for hours. Prolonged perineal pressure '
            'compresses the pudendal nerve and the arteries feeding the penis, '
            'and is one of the few exercise habits that can genuinely make '
            'symptoms worse.',
        'Saddle too low, which increases perineal pressure.',
        'Never standing up on long rides.',
      ],
      safetyTips: <String>[
        'Any numbness or tingling in the genitals means stop and change the '
            'saddle or fit before riding again.',
        'Cap continuous seated riding at about 3 hours a week while symptoms '
            'are active.',
      ],
      targets: <RootCause>[
        RootCause.cardiovascular,
        RootCause.obesityRelated,
        RootCause.diabetesRelated,
      ],
      equipment: 'Bicycle or stationary bike; cut-out saddle recommended',
      contraindications: <String>[
        'Existing perineal numbness or pudendal nerve symptoms',
      ],
    ),
    Exercise(
      id: 'swimming',
      name: 'Swimming',
      category: ExerciseCategory.cardio,
      difficulty: ExerciseDifficulty.intermediate,
      summary:
          'Full-body cardio with zero joint load and zero perineal '
          'pressure.',
      instructions: <String>[
        'Choose any stroke you can sustain; front crawl and breaststroke both '
            'work.',
        'Swim continuously for the prescribed time, resting at the wall as '
            'needed.',
        'Focus on exhaling fully underwater - it doubles as breathing '
            'practice.',
        'Build from 15 to 30 minutes over several weeks.',
      ],
      benefits: <String>[
        'Cardiovascular conditioning with no impact and no saddle pressure',
        'Engages the full posterior chain and core',
        'The horizontal position and rhythmic breathing are strongly '
            'calming for the nervous system',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 30),
      animation: ExerciseAnimation(
        asset: 'assets/animations/swimming.json',
        startingPosition: 'Horizontal in the water, body long, head neutral',
        motionPath:
            'Alternating arm strokes with a steady flutter kick and '
            'rhythmic breathing to one side',
        activatedMuscles: <String>[
          'Latissimus dorsi',
          'Deltoids',
          'Core',
          'Glutes',
          'Cardiovascular system',
        ],
      ),
      commonMistakes: <String>[
        'Lifting the head to breathe, which drops the hips and doubles the '
            'effort.',
        'Holding the breath instead of exhaling continuously underwater.',
      ],
      safetyTips: <String>[
        'Never swim alone if you are not a confident swimmer.',
      ],
      targets: <RootCause>[
        RootCause.cardiovascular,
        RootCause.obesityRelated,
        RootCause.anxietyRelated,
      ],
      equipment: 'Pool access',
    ),

    // ================================================================
    // Mobility
    // ================================================================
    Exercise(
      id: 'hip_opener',
      name: 'Kneeling hip flexor stretch',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Undoes the single most common postural consequence of sitting '
          'all day.',
      instructions: <String>[
        'Kneel on one knee with the other foot flat in front, both knees near '
            '90 degrees. Pad the down knee.',
        'Tuck the pelvis under by squeezing the glute on the kneeling side. '
            'This is what makes the stretch work.',
        'Shift your weight gently forward until you feel a stretch at the '
            'front of the kneeling hip.',
        'Hold 30 seconds, breathing slowly.',
        'To deepen it, raise the arm on the kneeling side overhead and lean '
            'slightly away.',
        'Swap sides.',
      ],
      benefits: <String>[
        'Releases hip flexors that pull the pelvis into a forward tilt',
        'A forward-tilted pelvis puts the pelvic floor at a mechanical '
            'disadvantage, so this makes Kegels work better',
        'Reduces the compensatory lower back tension that comes with it',
      ],
      dosage: ExerciseDosage(
        sets: 2,
        reps: 2,
        holdSeconds: 30,
        restSeconds: 15,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/hip_opener.json',
        startingPosition:
            'Half-kneeling, front foot flat, rear knee padded, '
            'torso upright',
        motionPath:
            'The pelvis tucks under, then the body shifts slowly '
            'forward and holds at the point of stretch',
        activatedMuscles: <String>[
          'Iliopsoas (lengthening)',
          'Rectus femoris (lengthening)',
          'Gluteus maximus (active)',
        ],
      ),
      commonMistakes: <String>[
        'Arching the lower back to lean forward, which stretches the spine '
            'instead of the hip.',
        'Forgetting the posterior pelvic tilt, which removes most of the '
            'benefit.',
        'Pushing into pain rather than a firm stretch.',
      ],
      safetyTips: <String>[
        'Cushion the kneeling knee.',
        'Ease off if you feel a pinch at the front of the hip socket.',
      ],
      targets: <RootCause>[
        RootCause.sedentaryLifestyle,
        RootCause.pelvicFloorWeakness,
      ],
    ),
    Exercise(
      id: 'butterfly_stretch',
      name: 'Butterfly stretch',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Opens the adductors and groin, which sit directly on the '
          'pelvic floor.',
      instructions: <String>[
        'Sit tall with the soles of your feet together and heels drawn '
            'comfortably toward you.',
        'Hold the ankles, not the toes. Sit up on the sit bones - use a '
            'cushion if you round backwards.',
        'Let the knees fall toward the floor under their own weight.',
        'Breathe slowly. On each exhale allow a little more release.',
        'Hold 45 seconds. Do not bounce.',
      ],
      benefits: <String>[
        'Releases adductor tension that restricts pelvic floor movement',
        'Improves circulation through the groin',
        'Tight adductors are strongly associated with a guarded, '
            'over-contracted pelvic floor',
      ],
      dosage: ExerciseDosage(
        sets: 2,
        reps: 1,
        holdSeconds: 45,
        restSeconds: 20,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/butterfly_stretch.json',
        startingPosition:
            'Seated upright, soles of the feet together, hands '
            'holding the ankles',
        motionPath:
            'The knees lower gradually toward the floor while the '
            'spine stays long; the position is held and released slowly',
        activatedMuscles: <String>[
          'Adductor group (lengthening)',
          'Gracilis',
          'Pelvic floor (releasing)',
        ],
      ),
      commonMistakes: <String>[
        'Pressing the knees down with the hands, which triggers a protective '
            'contraction.',
        'Rounding the lower back.',
        'Bouncing.',
      ],
      safetyTips: <String>[
        'Sit on a folded towel to tilt the pelvis forward if the position is '
            'hard to hold.',
        'Groin pain means stop.',
      ],
      targets: <RootCause>[
        RootCause.pelvicFloorWeakness,
        RootCause.sedentaryLifestyle,
      ],
    ),
    Exercise(
      id: 'hamstring_stretch',
      name: 'Supine hamstring stretch',
      category: ExerciseCategory.mobility,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Tight hamstrings tuck the pelvis under and flatten the '
          'lumbar curve, which weakens pelvic floor mechanics.',
      instructions: <String>[
        'Lie on your back with one knee bent, that foot flat on the floor.',
        'Raise the other leg and hold behind the thigh, or loop a towel '
            'around the foot.',
        'Straighten the raised leg as far as a firm stretch, not pain.',
        'Keep the lower back in contact with the floor throughout.',
        'Hold 30 seconds, then swap sides.',
      ],
      benefits: <String>[
        'Restores neutral pelvic alignment, which improves Kegel mechanics',
        'Reduces lower back tension',
        'Safer than a standing toe-touch, which loads the lumbar spine',
      ],
      dosage: ExerciseDosage(
        sets: 2,
        reps: 2,
        holdSeconds: 30,
        restSeconds: 15,
      ),
      animation: ExerciseAnimation(
        asset: 'assets/animations/hamstring_stretch.json',
        startingPosition:
            'Supine, one knee bent with the foot flat, the '
            'other leg raised and supported behind the thigh',
        motionPath:
            'The raised leg extends slowly at the knee until a stretch '
            'is felt along the back of the thigh, then holds',
        activatedMuscles: <String>['Hamstring group (lengthening)', 'Calves'],
      ),
      commonMistakes: <String>[
        'Lifting the lower back off the floor to get the leg higher.',
        'Locking the knee aggressively.',
        'Holding the breath.',
      ],
      safetyTips: <String>[
        'Any nerve-like tingling down the leg means release immediately - '
            'that is not a muscle stretch.',
      ],
      targets: <RootCause>[RootCause.sedentaryLifestyle],
      equipment: 'Optional towel or strap',
    ),

    // ================================================================
    // Breathing / nervous system
    // ================================================================
    Exercise(
      id: 'box_breathing',
      name: 'Box breathing',
      category: ExerciseCategory.breathing,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'Four equal counts. The fastest reliable way to drop out of '
          'the adrenaline state that blocks an erection.',
      instructions: <String>[
        'Sit upright or lie down. Rest one hand on your belly.',
        'Inhale through the nose for a count of 4.',
        'Hold, relaxed, for a count of 4.',
        'Exhale through the mouth for a count of 4.',
        'Hold empty for a count of 4.',
        'Repeat for 5 minutes. Slow the count as it becomes comfortable.',
      ],
      benefits: <String>[
        'Shifts the autonomic balance toward the parasympathetic branch - and '
            'erections are a parasympathetic event',
        'Lowers circulating adrenaline, which physically constricts the '
            'arteries that fill the penis',
        'A portable tool you can use minutes before sex',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 5),
      animation: ExerciseAnimation(
        asset: 'assets/animations/box_breathing.json',
        startingPosition: 'Seated upright or lying down, one hand on the belly',
        motionPath:
            'A square traces one side per four-count phase: inhale, '
            'hold, exhale, hold',
        activatedMuscles: <String>['Diaphragm', 'Intercostals'],
        defaultSpeed: 1.0,
      ),
      commonMistakes: <String>[
        'Straining on the holds. Every phase should feel unhurried.',
        'Breathing into the chest rather than the belly.',
        'Giving up after a minute - the shift usually takes three.',
      ],
      safetyTips: <String>[
        'Shorten the breath holds if you feel lightheaded.',
        'Skip the holds entirely if you have uncontrolled high blood pressure '
            'or a respiratory condition.',
      ],
      targets: <RootCause>[RootCause.anxietyRelated, RootCause.sleepDeficiency],
    ),
    Exercise(
      id: 'diaphragmatic_breathing',
      name: 'Diaphragmatic breathing',
      category: ExerciseCategory.breathing,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'The breath the pelvic floor moves with. Doubles as the '
          'foundation for Reverse Kegels.',
      instructions: <String>[
        'Lie on your back with knees bent. One hand on the chest, one on the '
            'belly.',
        'Inhale slowly through the nose for 4 seconds. Only the belly hand '
            'should rise.',
        'Feel the lower ribs widen sideways as well.',
        'Exhale through pursed lips for 6 seconds - a longer exhale is what '
            'drives the calming response.',
        'Continue for 10 minutes.',
      ],
      benefits: <String>[
        'The diaphragm and pelvic floor move as a piston pair; restoring one '
            'restores the other',
        'A longer exhale raises vagal tone and lowers heart rate',
        'Reduces the chronic bracing pattern behind a tight pelvic floor',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 10),
      animation: ExerciseAnimation(
        asset: 'assets/animations/diaphragmatic_breathing.json',
        startingPosition:
            'Supine, knees bent, one hand on the chest and one '
            'on the abdomen',
        motionPath:
            'The abdomen rises and the lower ribs widen on a '
            'four-second inhale, then fall through a six-second exhale, with '
            'the pelvic floor descending and returning in time',
        activatedMuscles: <String>[
          'Diaphragm',
          'Transverse abdominis',
          'Pelvic floor (synchronised)',
        ],
        defaultSpeed: 0.75,
      ),
      commonMistakes: <String>[
        'Chest breathing - if the top hand moves more than the bottom one, '
            'the pattern has not changed yet.',
        'Forcing the belly out with the abdominal muscles instead of letting '
            'the diaphragm do it.',
        'An exhale that is shorter than the inhale.',
      ],
      safetyTips: <String>[
        'Dizziness means you are over-breathing; return to a normal rhythm '
            'for a minute.',
      ],
      targets: <RootCause>[
        RootCause.anxietyRelated,
        RootCause.pelvicFloorWeakness,
        RootCause.sleepDeficiency,
      ],
    ),
    Exercise(
      id: 'stress_reset',
      name: 'Pre-intimacy stress reset',
      category: ExerciseCategory.breathing,
      difficulty: ExerciseDifficulty.beginner,
      summary:
          'A five-minute routine to run before sex, built to interrupt '
          'the performance-anxiety loop.',
      instructions: <String>[
        'Two minutes of diaphragmatic breathing, exhale longer than inhale.',
        'One minute of progressive release: tense and release the jaw, then '
            'shoulders, then glutes, then the pelvic floor. Tension hides in '
            'those four places.',
        'One minute of sensory grounding: name five things you can feel '
            'physically right now. This pulls attention out of self-monitoring '
            'and back into the body.',
        'One minute of reframing: the goal for this encounter is contact and '
            'pleasure, not a performance outcome. Say it deliberately.',
        'Use it before intimacy, or any time you notice the anxious spiral '
            'starting.',
      ],
      benefits: <String>[
        'Breaks the spectator loop - watching yourself perform is itself the '
            'mechanism that prevents arousal',
        'Lowers adrenaline at the exact moment it would otherwise block blood '
            'flow',
        'Gives you something concrete to do instead of bracing for failure',
      ],
      dosage: ExerciseDosage(sets: 1, durationMinutes: 5),
      animation: ExerciseAnimation(
        asset: 'assets/animations/stress_reset.json',
        startingPosition:
            'Seated or standing somewhere private, eyes closed '
            'or softly focused',
        motionPath:
            'A four-stage guided sequence: breathing, progressive '
            'tension release, sensory grounding, then reframing',
        activatedMuscles: <String>['Diaphragm', 'Whole-body tension release'],
        defaultSpeed: 0.5,
      ),
      commonMistakes: <String>[
        'Turning it into another performance to get right.',
        'Skipping it on the nights you most need it.',
        'Expecting one session to fix a pattern built over years.',
      ],
      safetyTips: <String>[
        'If anxiety around sex is severe or persistent, a sex therapist or '
            'psychologist will get you further than any app.',
      ],
      targets: <RootCause>[RootCause.anxietyRelated],
    ),
  ];

  static Exercise byId(String id) => all.firstWhere((Exercise e) => e.id == id);

  static List<Exercise> byCategory(ExerciseCategory category) =>
      all.where((Exercise e) => e.category == category).toList();

  static List<Exercise> forCause(RootCause cause) =>
      all.where((Exercise e) => e.addresses(cause)).toList();

  static List<Exercise> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (Exercise e) =>
              e.name.toLowerCase().contains(q) ||
              e.summary.toLowerCase().contains(q) ||
              e.category.label.toLowerCase().contains(q),
        )
        .toList();
  }
}
