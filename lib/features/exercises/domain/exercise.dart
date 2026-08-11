import 'package:meta/meta.dart';

import '../../assessment/domain/root_cause.dart';

enum ExerciseCategory {
  kegel(
    'Pelvic floor',
    'Direct training for the muscles behind rigidity and '
        'ejaculatory control.',
  ),
  reverseKegel(
    'Relaxation',
    'Teaches the pelvic floor to let go - the half '
        'most men never train.',
  ),
  strength(
    'Strength',
    'Compound lifts that drive circulation and hormonal '
        'response through the hips and legs.',
  ),
  core('Core', 'A stable trunk is what lets the pelvic floor generate force.'),
  cardio(
    'Cardio',
    'Endothelial training. The lining of your arteries adapts '
        'to this faster than almost anything else.',
  ),
  mobility(
    'Mobility',
    'Releases the hip and adductor tension that keeps the '
        'pelvic floor guarded.',
  ),
  breathing(
    'Breathing',
    'Shifts you out of the adrenaline state that blocks '
        'an erection.',
  );

  const ExerciseCategory(this.label, this.rationale);

  final String label;
  final String rationale;
}

enum ExerciseDifficulty {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const ExerciseDifficulty(this.label);
  final String label;
}

/// A prescription: how much of the exercise to do in one session.
@immutable
class ExerciseDosage {
  const ExerciseDosage({
    required this.sets,
    this.reps,
    this.holdSeconds,
    this.durationMinutes,
    this.restSeconds = 30,
  });

  final int sets;
  final int? reps;
  final int? holdSeconds;
  final int? durationMinutes;
  final int restSeconds;

  /// Human-readable prescription, e.g. "3 x 10, 5s hold".
  String get label {
    final List<String> parts = <String>[];
    if (durationMinutes != null) {
      parts.add('$durationMinutes min');
      if (sets > 1) parts.insert(0, '$sets x');
    } else if (reps != null) {
      parts.add('$sets x $reps');
    } else {
      parts.add('$sets sets');
    }
    if (holdSeconds != null) parts.add('${holdSeconds}s hold');
    return parts.join(', ');
  }

  /// Rough time cost of one session, used to build a realistic daily plan.
  int get estimatedMinutes {
    if (durationMinutes != null) return durationMinutes! * sets;
    final int perRep = (holdSeconds ?? 2) + 2;
    final int work = sets * (reps ?? 10) * perRep;
    final int rest = (sets - 1).clamp(0, 100) * restSeconds;
    return ((work + rest) / 60).ceil();
  }
}

/// Metadata describing the animation that accompanies an exercise.
///
/// The app never hard-codes a Lottie path at a call site; it goes through
/// this so a missing asset degrades to the illustrated fallback rather than
/// throwing. See `docs/ANIMATION_ARCHITECTURE.md`.
@immutable
class ExerciseAnimation {
  const ExerciseAnimation({
    required this.asset,
    required this.startingPosition,
    required this.motionPath,
    required this.activatedMuscles,
    this.loopSegment,
    this.defaultSpeed = 1.0,
  });

  final String asset;

  /// Rendered as the caption under the "start" frame.
  final String startingPosition;

  /// Describes the movement so the animation is understandable with sound
  /// off and readable by a screen reader.
  final String motionPath;

  /// Highlighted in the muscle-activation overlay.
  final List<String> activatedMuscles;

  /// Optional `[startFrame, endFrame]` sub-range to loop.
  final List<int>? loopSegment;

  final double defaultSpeed;

  String get semanticLabel =>
      'Animation. Starting position: $startingPosition. Movement: $motionPath. '
      'Muscles working: ${activatedMuscles.join(', ')}.';
}

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.summary,
    required this.instructions,
    required this.benefits,
    required this.dosage,
    required this.animation,
    required this.commonMistakes,
    required this.safetyTips,
    required this.targets,
    this.equipment = 'None',
    this.contraindications = const <String>[],
  });

  final String id;
  final String name;
  final ExerciseCategory category;
  final ExerciseDifficulty difficulty;
  final String summary;

  /// Ordered, numbered steps.
  final List<String> instructions;

  final List<String> benefits;
  final ExerciseDosage dosage;
  final ExerciseAnimation animation;
  final List<String> commonMistakes;
  final List<String> safetyTips;

  /// Root causes this exercise is prescribed for. Drives programme building.
  final List<RootCause> targets;

  final String equipment;
  final List<String> contraindications;

  bool addresses(RootCause cause) => targets.contains(cause);
}
