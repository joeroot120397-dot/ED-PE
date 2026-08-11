import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/features/assessment/domain/assessment_result.dart';
import 'package:vitalrise/features/assessment/domain/root_cause.dart';
import 'package:vitalrise/features/assessment/domain/scoring_engine.dart';
import 'package:vitalrise/features/exercises/domain/exercise.dart';
import 'package:vitalrise/features/exercises/domain/exercise_library.dart';
import 'package:vitalrise/features/exercises/domain/program_builder.dart';
import 'package:vitalrise/features/exercises/domain/training_program.dart';

import '../support/answer_builder.dart';

void main() {
  group('exercise library integrity', () {
    test('ids are unique', () {
      final Set<String> ids = ExerciseLibrary.all
          .map((Exercise e) => e.id)
          .toSet();
      expect(ids.length, ExerciseLibrary.all.length);
    });

    test('every exercise carries the safety content the brief requires', () {
      for (final Exercise e in ExerciseLibrary.all) {
        expect(e.instructions, isNotEmpty, reason: e.id);
        expect(e.benefits, isNotEmpty, reason: e.id);
        expect(e.commonMistakes, isNotEmpty, reason: e.id);
        expect(e.safetyTips, isNotEmpty, reason: e.id);
        expect(e.targets, isNotEmpty, reason: e.id);
      }
    });

    test('every exercise has an animation with accessible descriptions', () {
      for (final Exercise e in ExerciseLibrary.all) {
        expect(e.animation.asset, endsWith('.json'), reason: e.id);
        expect(e.animation.startingPosition, isNotEmpty, reason: e.id);
        expect(e.animation.motionPath, isNotEmpty, reason: e.id);
        expect(e.animation.activatedMuscles, isNotEmpty, reason: e.id);
        expect(e.animation.semanticLabel, contains('Starting position'));
      }
    });

    test('animation assets are unique per exercise', () {
      final Set<String> assets = ExerciseLibrary.all
          .map((Exercise e) => e.animation.asset)
          .toSet();
      expect(assets.length, ExerciseLibrary.all.length);
    });

    test('every category is represented', () {
      for (final ExerciseCategory c in ExerciseCategory.values) {
        expect(ExerciseLibrary.byCategory(c), isNotEmpty, reason: c.name);
      }
    });

    test('every root cause has at least one exercise that addresses it', () {
      for (final RootCause cause in RootCause.values) {
        // Blood sugar and vascular causes are handled through cardio and
        // nutrition; every cause must map to something the app can offer.
        expect(ExerciseLibrary.forCause(cause), isNotEmpty, reason: cause.slug);
      }
    });

    test('the exercises named in the product brief all exist', () {
      const List<String> required = <String>[
        'kegel_basic',
        'kegel_quick_pulse',
        'kegel_long_hold',
        'kegel_functional',
        'reverse_kegel',
        'deep_squat',
        'glute_bridge',
        'hip_thrust',
        'lunge',
        'plank',
        'side_plank',
        'dead_bug',
        'brisk_walk',
        'jogging',
        'cycling',
        'swimming',
        'hip_opener',
        'butterfly_stretch',
        'hamstring_stretch',
        'box_breathing',
        'diaphragmatic_breathing',
        'stress_reset',
      ];
      for (final String id in required) {
        expect(() => ExerciseLibrary.byId(id), returnsNormally, reason: id);
      }
    });

    test('dosage estimates are positive and plausible', () {
      for (final Exercise e in ExerciseLibrary.all) {
        expect(e.dosage.estimatedMinutes, greaterThan(0), reason: e.id);
        expect(e.dosage.estimatedMinutes, lessThanOrEqualTo(60), reason: e.id);
        expect(e.dosage.label, isNotEmpty, reason: e.id);
      }
    });

    test('search matches on name and category', () {
      expect(ExerciseLibrary.search('kegel'), isNotEmpty);
      expect(ExerciseLibrary.search('breathing'), isNotEmpty);
      expect(ExerciseLibrary.search(''), hasLength(ExerciseLibrary.all.length));
      expect(ExerciseLibrary.search('zzzz'), isEmpty);
    });
  });

  group('programme structure', () {
    late TrainingProgram severe;
    late TrainingProgram healthy;

    setUp(() {
      severe = ProgramBuilder.build(
        AssessmentEngine.evaluate(AnswerBuilder.severe()),
        startedOn: DateTime(2026, 1, 5), // a Monday
      );
      healthy = ProgramBuilder.build(
        AssessmentEngine.evaluate(AnswerBuilder.healthy()),
        startedOn: DateTime(2026, 1, 5),
      );
    });

    test('runs for twelve weeks across three phases', () {
      expect(severe.phases, hasLength(3));
      expect(severe.totalWeeks, 12);
      expect(severe.phases.map((ProgramPhase p) => p.startWeek), <int>[
        1,
        5,
        9,
      ]);
      expect(severe.phases.map((ProgramPhase p) => p.endWeek), <int>[4, 8, 12]);
    });

    test('every phase has a full seven-day week', () {
      for (final ProgramPhase p in severe.phases) {
        expect(p.week, hasLength(7));
        expect(p.week.map((DailySession d) => d.dayOfWeek), <int>[
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        ]);
      }
    });

    test('pelvic floor work appears on six days of every week', () {
      for (final TrainingProgram program in <TrainingProgram>[
        severe,
        healthy,
      ]) {
        for (final ProgramPhase p in program.phases) {
          final int days = p.week
              .where(
                (DailySession d) => d.items.any(
                  (ProgramItem i) =>
                      i.exercise.category == ExerciseCategory.kegel ||
                      i.exercise.category == ExerciseCategory.reverseKegel,
                ),
              )
              .length;
          expect(days, 6, reason: 'phase ${p.index}');
        }
      }
    });

    test('no session exceeds the time cap', () {
      for (final ProgramPhase p in severe.phases) {
        for (final DailySession d in p.week) {
          expect(
            d.estimatedMinutes,
            lessThanOrEqualTo(45),
            reason: 'phase ${p.index} ${d.dayName}',
          );
        }
      }
    });

    test('difficulty progresses across the phases', () {
      Set<ExerciseDifficulty> difficultiesIn(ProgramPhase p) => p.week
          .expand((DailySession d) => d.items)
          .map((ProgramItem i) => i.exercise.difficulty)
          .toSet();

      expect(
        difficultiesIn(severe.phases[0]),
        isNot(contains(ExerciseDifficulty.advanced)),
      );
      expect(
        difficultiesIn(severe.phases[2]),
        contains(ExerciseDifficulty.advanced),
      );
    });

    test(
      'a man with many drivers gets more weekly volume than one with none',
      () {
        expect(
          severe.phases[1].weeklyMinutes,
          greaterThan(healthy.phases[1].weeklyMinutes),
        );
      },
    );

    test(
      'a healthy profile is not handed cardio or strength it did not earn',
      () {
        final Set<ExerciseCategory> categories = healthy.phases
            .expand((ProgramPhase p) => p.week)
            .expand((DailySession d) => d.items)
            .map((ProgramItem i) => i.exercise.category)
            .toSet();
        expect(categories, isNot(contains(ExerciseCategory.cardio)));
        expect(categories, isNot(contains(ExerciseCategory.strength)));
      },
    );

    test('a sedentary, overweight profile does get cardio and strength', () {
      final TrainingProgram program = ProgramBuilder.build(
        AssessmentEngine.evaluate(
          AnswerBuilder()
              .body(age: 45, heightCm: 175, weightKg: 105, waistCm: 115)
              .choose('d_exercise', 'never')
              .choose('d_sitting', 'over9')
              .choose('e_weight_status', 'obese')
              .build(),
        ),
      );
      final Set<ExerciseCategory> categories = program.phases
          .expand((ProgramPhase p) => p.week)
          .expand((DailySession d) => d.items)
          .map((ProgramItem i) => i.exercise.category)
          .toSet();
      expect(categories, contains(ExerciseCategory.cardio));
      expect(categories, contains(ExerciseCategory.strength));
    });

    test('an anxiety-driven profile gets daily breathing work', () {
      final TrainingProgram program = ProgramBuilder.build(
        AssessmentEngine.evaluate(
          AnswerBuilder()
              .body()
              .choose('f_performance_anxiety', 'severe')
              .choose('c_anticipatory_anxiety', 'severe')
              .choose('d_stress', 'severe')
              .choose('f_work_stress', 'burnout')
              .build(),
        ),
      );
      for (final DailySession d in program.phases.first.week) {
        expect(
          d.items.any(
            (ProgramItem i) =>
                i.exercise.category == ExerciseCategory.breathing,
          ),
          isTrue,
          reason: d.dayName,
        );
      }
    });

    test('the week number and session lookup track the calendar', () {
      final DateTime start = DateTime(2026, 1, 5); // Monday
      expect(severe.weekNumberOn(start), 1);
      expect(severe.weekNumberOn(start.add(const Duration(days: 6))), 1);
      expect(severe.weekNumberOn(start.add(const Duration(days: 7))), 2);
      expect(severe.weekNumberOn(start.add(const Duration(days: 70))), 11);
      // Past the end of the programme it clamps rather than throwing.
      expect(severe.weekNumberOn(start.add(const Duration(days: 400))), 12);

      expect(severe.sessionOn(start).dayOfWeek, 1);
      expect(severe.sessionOn(start.add(const Duration(days: 2))).dayOfWeek, 3);
      expect(severe.phaseForWeek(6).index, 2);
    });

    test('Sunday is a low-load day in every phase', () {
      for (final ProgramPhase p in severe.phases) {
        final DailySession sunday = p.week[6];
        expect(
          sunday.items.any(
            (ProgramItem i) => i.exercise.category == ExerciseCategory.strength,
          ),
          isFalse,
        );
        expect(sunday.estimatedMinutes, lessThan(30));
      }
    });

    test('rest days carry an explanation instead of an empty screen', () {
      for (final ProgramPhase p in healthy.phases) {
        for (final DailySession d in p.week) {
          if (d.isRest) {
            expect(d.restNote, isNotNull);
            expect(d.title, 'Rest day');
          }
        }
      }
    });

    test('building is deterministic', () {
      final AssessmentResult result = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      );
      String render(TrainingProgram p) => p.phases
          .expand((ProgramPhase ph) => ph.week)
          .expand((DailySession d) => d.items)
          .map((ProgramItem i) => '${i.exercise.id}/${i.dosage.label}')
          .join(',');

      expect(
        render(ProgramBuilder.build(result, startedOn: DateTime(2026, 1, 5))),
        render(ProgramBuilder.build(result, startedOn: DateTime(2026, 1, 5))),
      );
    });

    test('the rationale explains the plan in plain language', () {
      expect(severe.rationale, contains('Pelvic floor'));
      expect(severe.rationale.length, greaterThan(120));
      expect(healthy.rationale, isNotEmpty);
    });
  });
}
