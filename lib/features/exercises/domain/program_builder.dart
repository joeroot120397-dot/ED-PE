import 'dart:math' as math;

import '../../assessment/domain/assessment_result.dart';
import '../../assessment/domain/root_cause.dart';
import 'exercise.dart';
import 'exercise_library.dart';
import 'training_program.dart';

/// Turns an [AssessmentResult] into a 12-week training programme.
///
/// Pure and deterministic - the same result always produces the same plan,
/// which is what makes `test/exercises/program_builder_test.dart` meaningful.
///
/// ## Design rules
/// * Pelvic floor work runs almost every day. It is the highest-yield,
///   lowest-cost intervention and the reason the app exists.
/// * Everything else is *earned* by a root cause clearing 40% confidence, so
///   a man whose only issue is anxiety is not handed a leg day he will skip.
/// * Total weekly load is capped. An unrealistic plan is an abandoned plan.
abstract final class ProgramBuilder {
  static const int _phaseLength = 4;
  static const int _maxSessionMinutes = 40;

  static TrainingProgram build(AssessmentResult result, {DateTime? startedOn}) {
    final DateTime start = startedOn ?? DateTime.now();
    final Map<RootCause, double> conf = <RootCause, double>{
      for (final CauseConfidence c in result.causes) c.cause: c.confidence,
    };

    double of(RootCause c) => conf[c] ?? 0;

    final bool needsCardio =
        math.max(
          math.max(of(RootCause.cardiovascular), of(RootCause.obesityRelated)),
          math.max(
            of(RootCause.diabetesRelated),
            of(RootCause.sedentaryLifestyle),
          ),
        ) >=
        40;
    final bool needsStrength =
        math.max(
              of(RootCause.obesityRelated),
              of(RootCause.sedentaryLifestyle),
            ) >=
            40 ||
        of(RootCause.pelvicFloorWeakness) >= 55;
    final bool needsCalm =
        math.max(of(RootCause.anxietyRelated), of(RootCause.sleepDeficiency)) >=
        40;
    final bool needsMobility =
        of(RootCause.sedentaryLifestyle) >= 40 ||
        of(RootCause.pelvicFloorWeakness) >= 55;
    final bool peFocus = result.scores.peRiskScore >= 45;

    final List<ProgramPhase> phases = <ProgramPhase>[
      _phase(
        index: 1,
        name: 'Foundation',
        focus:
            'Find the muscle, build the habit. Volume stays deliberately '
            'low so the pattern is correct before it is loaded.',
        needsCardio: needsCardio,
        needsStrength: needsStrength,
        needsCalm: needsCalm,
        needsMobility: needsMobility,
        peFocus: peFocus,
      ),
      _phase(
        index: 2,
        name: 'Build',
        focus:
            'Add endurance holds, fast pulses and real load. This is the '
            'phase where most men first notice a change.',
        needsCardio: needsCardio,
        needsStrength: needsStrength,
        needsCalm: needsCalm,
        needsMobility: needsMobility,
        peFocus: peFocus,
      ),
      _phase(
        index: 3,
        name: 'Transfer',
        focus:
            'Move the strength into standing, loaded and moving positions '
            'so it shows up where it counts.',
        needsCardio: needsCardio,
        needsStrength: needsStrength,
        needsCalm: needsCalm,
        needsMobility: needsMobility,
        peFocus: peFocus,
      ),
    ];

    return TrainingProgram(
      phases: phases,
      rationale: _rationale(
        result,
        needsCardio: needsCardio,
        needsStrength: needsStrength,
        needsCalm: needsCalm,
        needsMobility: needsMobility,
      ),
      startedOn: DateTime(start.year, start.month, start.day),
    );
  }

  // ------------------------------------------------------------------
  static ProgramPhase _phase({
    required int index,
    required String name,
    required String focus,
    required bool needsCardio,
    required bool needsStrength,
    required bool needsCalm,
    required bool needsMobility,
    required bool peFocus,
  }) {
    final List<DailySession> week = <DailySession>[
      for (int day = 1; day <= 7; day++)
        _session(
          day: day,
          phase: index,
          needsCardio: needsCardio,
          needsStrength: needsStrength,
          needsCalm: needsCalm,
          needsMobility: needsMobility,
          peFocus: peFocus,
        ),
    ];

    return ProgramPhase(
      index: index,
      name: name,
      focus: focus,
      startWeek: (index - 1) * _phaseLength + 1,
      endWeek: index * _phaseLength,
      week: week,
    );
  }

  static DailySession _session({
    required int day,
    required int phase,
    required bool needsCardio,
    required bool needsStrength,
    required bool needsCalm,
    required bool needsMobility,
    required bool peFocus,
  }) {
    final List<ProgramItem> items = <ProgramItem>[];

    // Sunday is a deliberate rest day in every phase - except for the
    // breathing work, which is recovery rather than load.
    final bool isRestDay = day == 7;

    if (!isRestDay) {
      items.addAll(_pelvicFloorBlock(phase, day, peFocus));
    }

    if (needsStrength && !isRestDay && (day == 2 || day == 5)) {
      items.addAll(_strengthBlock(phase));
    }

    if (needsCardio && (day == 1 || day == 3 || day == 6)) {
      items.add(_cardioItem(phase));
    }

    if (needsMobility && (day == 3 || day == 7)) {
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('hip_opener'),
          dosage: ExerciseLibrary.byId('hip_opener').dosage,
        ),
      );
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('butterfly_stretch'),
          dosage: ExerciseLibrary.byId('butterfly_stretch').dosage,
          note: 'Especially valuable if Kegels feel tense rather than strong.',
        ),
      );
    }

    if (needsCalm) {
      final Exercise breath = day == 7 || phase == 1
          ? ExerciseLibrary.byId('diaphragmatic_breathing')
          : ExerciseLibrary.byId('box_breathing');
      items.add(
        ProgramItem(
          exercise: breath,
          dosage: breath.dosage,
          note: day == 7 ? 'Recovery focus - keep it slow.' : null,
        ),
      );
      if (phase >= 2 && (day == 2 || day == 5)) {
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('stress_reset'),
            dosage: ExerciseLibrary.byId('stress_reset').dosage,
            note: 'Rehearse it now so it is automatic when you need it.',
          ),
        );
      }
    }

    final List<ProgramItem> capped = _capLoad(items);

    return DailySession(
      dayOfWeek: day,
      title: _sessionTitle(day, capped, isRestDay: isRestDay),
      items: capped,
      restNote: capped.isEmpty
          ? 'Full rest. Muscle adapts between sessions, not during them - a '
                'skipped rest day costs you progress.'
          : null,
    );
  }

  static List<ProgramItem> _pelvicFloorBlock(int phase, int day, bool peFocus) {
    final List<ProgramItem> items = <ProgramItem>[];

    switch (phase) {
      case 1:
        final Exercise basic = ExerciseLibrary.byId('kegel_basic');
        items.add(
          ProgramItem(
            exercise: basic,
            dosage: const ExerciseDosage(
              sets: 3,
              reps: 8,
              holdSeconds: 3,
              restSeconds: 30,
            ),
            note:
                'Form over volume. If you cannot isolate it, stop and re-read '
                'the technique notes.',
          ),
        );
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('reverse_kegel'),
            dosage: const ExerciseDosage(
              sets: 2,
              reps: 6,
              holdSeconds: 5,
              restSeconds: 30,
            ),
            note: 'The release is a separate skill from the squeeze.',
          ),
        );
      case 2:
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('kegel_long_hold'),
            dosage: const ExerciseDosage(
              sets: 3,
              reps: 8,
              holdSeconds: 8,
              restSeconds: 45,
            ),
          ),
        );
        if (peFocus || day.isEven) {
          items.add(
            ProgramItem(
              exercise: ExerciseLibrary.byId('kegel_quick_pulse'),
              dosage: const ExerciseDosage(
                sets: 3,
                reps: 10,
                holdSeconds: 1,
                restSeconds: 30,
              ),
              note: peFocus
                  ? 'This is the direct trainer for ejaculatory control - do not '
                        'skip it.'
                  : null,
            ),
          );
        }
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('reverse_kegel'),
            dosage: const ExerciseDosage(
              sets: 2,
              reps: 8,
              holdSeconds: 5,
              restSeconds: 30,
            ),
          ),
        );
      default:
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('kegel_functional'),
            dosage: const ExerciseDosage(
              sets: 3,
              reps: 8,
              holdSeconds: 5,
              restSeconds: 45,
            ),
            note: 'Only progress a stage when the current one feels clean.',
          ),
        );
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('kegel_long_hold'),
            dosage: const ExerciseDosage(
              sets: 3,
              reps: 8,
              holdSeconds: 10,
              restSeconds: 45,
            ),
          ),
        );
        if (peFocus) {
          items.add(
            ProgramItem(
              exercise: ExerciseLibrary.byId('kegel_quick_pulse'),
              dosage: const ExerciseDosage(
                sets: 4,
                reps: 10,
                holdSeconds: 1,
                restSeconds: 30,
              ),
            ),
          );
        }
        items.add(
          ProgramItem(
            exercise: ExerciseLibrary.byId('reverse_kegel'),
            dosage: const ExerciseDosage(
              sets: 2,
              reps: 8,
              holdSeconds: 6,
              restSeconds: 30,
            ),
          ),
        );
    }
    return items;
  }

  static List<ProgramItem> _strengthBlock(int phase) {
    final List<ProgramItem> items = <ProgramItem>[
      ProgramItem(
        exercise: ExerciseLibrary.byId('glute_bridge'),
        dosage: ExerciseDosage(
          sets: phase == 1 ? 2 : 3,
          reps: phase == 1 ? 12 : 15,
          holdSeconds: 2,
          restSeconds: 45,
        ),
      ),
      ProgramItem(
        exercise: ExerciseLibrary.byId('deep_squat'),
        dosage: ExerciseDosage(
          sets: phase == 1 ? 2 : 3,
          reps: phase == 1 ? 10 : 12,
          restSeconds: 60,
        ),
      ),
    ];

    if (phase >= 2) {
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('plank'),
          dosage: ExerciseDosage(
            sets: 3,
            reps: 1,
            holdSeconds: phase == 2 ? 30 : 45,
            restSeconds: 45,
          ),
          note:
              'Breathe through the hold. Bearing down works against your '
              'Kegel training.',
        ),
      );
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('dead_bug'),
          dosage: const ExerciseDosage(sets: 2, reps: 10, restSeconds: 45),
        ),
      );
    }
    if (phase >= 3) {
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('hip_thrust'),
          dosage: const ExerciseDosage(
            sets: 4,
            reps: 10,
            holdSeconds: 2,
            restSeconds: 75,
          ),
        ),
      );
      items.add(
        ProgramItem(
          exercise: ExerciseLibrary.byId('lunge'),
          dosage: const ExerciseDosage(sets: 3, reps: 10, restSeconds: 60),
        ),
      );
    }
    return items;
  }

  static ProgramItem _cardioItem(int phase) {
    final Exercise ex = ExerciseLibrary.byId('brisk_walk');
    return ProgramItem(
      exercise: ex,
      dosage: ExerciseDosage(
        sets: 1,
        durationMinutes: switch (phase) {
          1 => 20,
          2 => 30,
          _ => 35,
        },
      ),
      note: phase >= 2
          ? 'Swap for jogging, cycling or swimming if you prefer - match the '
                'time, not the activity. If you cycle, read the saddle note.'
          : 'Pace matters more than distance: brisk enough to change your '
                'breathing.',
    );
  }

  /// Drops trailing optional work once a session exceeds the time cap.
  /// Pelvic floor work is added first and therefore never trimmed.
  static List<ProgramItem> _capLoad(List<ProgramItem> items) {
    final List<ProgramItem> kept = <ProgramItem>[];
    int minutes = 0;
    for (final ProgramItem item in items) {
      final int cost = item.dosage.estimatedMinutes;
      if (kept.isNotEmpty && minutes + cost > _maxSessionMinutes) continue;
      kept.add(item);
      minutes += cost;
    }
    return kept;
  }

  static String _sessionTitle(
    int day,
    List<ProgramItem> items, {
    required bool isRestDay,
  }) {
    if (items.isEmpty) return 'Rest day';
    if (isRestDay) return 'Active recovery';

    final Set<ExerciseCategory> cats = items
        .map((ProgramItem i) => i.exercise.category)
        .toSet();
    if (cats.contains(ExerciseCategory.strength)) {
      return 'Pelvic floor + strength';
    }
    if (cats.contains(ExerciseCategory.cardio)) {
      return 'Pelvic floor + cardio';
    }
    if (cats.contains(ExerciseCategory.mobility)) {
      return 'Pelvic floor + mobility';
    }
    return 'Pelvic floor focus';
  }

  static String _rationale(
    AssessmentResult result, {
    required bool needsCardio,
    required bool needsStrength,
    required bool needsCalm,
    required bool needsMobility,
  }) {
    final StringBuffer sb = StringBuffer()
      ..write(
        'Pelvic floor training runs six days a week because it is the '
        'highest-yield thing you can do, whatever your root causes turned '
        'out to be. ',
      );

    final List<String> added = <String>[];
    if (needsCardio) {
      added.add(
        'cardio three times a week, because your circulation and '
        'metabolic answers scored high enough to matter',
      );
    }
    if (needsStrength) {
      added.add(
        'two strength sessions, to build the glutes and core the '
        'pelvic floor anchors to',
      );
    }
    if (needsMobility) {
      added.add(
        'hip and groin mobility, because tight hips put the pelvic '
        'floor at a mechanical disadvantage',
      );
    }
    if (needsCalm) {
      added.add(
        'daily breathing work, because an erection is a '
        'parasympathetic event and adrenaline is its direct opponent',
      );
    }

    if (added.isEmpty) {
      sb.write(
        'Nothing else scored high enough to justify adding load, so '
        'your plan stays deliberately short. A programme you finish beats a '
        'programme that looks impressive.',
      );
    } else {
      sb.write('On top of that you have ${_joinNaturally(added)}. ');
      sb.write(
        'Anything that did not score above 40% was left out on '
        'purpose - a plan you actually finish beats one that looks '
        'comprehensive.',
      );
    }
    return sb.toString();
  }

  static String _joinNaturally(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join('; ')}; and '
        '${parts.last}';
  }
}
