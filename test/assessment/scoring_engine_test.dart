import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/features/assessment/domain/assessment_models.dart';
import 'package:vitalrise/features/assessment/domain/assessment_result.dart';
import 'package:vitalrise/features/assessment/domain/question_bank.dart';
import 'package:vitalrise/features/assessment/domain/root_cause.dart';
import 'package:vitalrise/features/assessment/domain/scoring_engine.dart';

import '../support/answer_builder.dart';

void main() {
  group('question bank integrity', () {
    test('question ids are unique', () {
      final Set<String> ids = QuestionBank.all
          .map((AssessmentQuestion q) => q.id)
          .toSet();
      expect(ids.length, QuestionBank.all.length);
    });

    test('option values are unique within each question', () {
      for (final AssessmentQuestion q in QuestionBank.all) {
        final Set<String> values = q.options
            .map((AnswerOption o) => o.value)
            .toSet();
        expect(values.length, q.options.length, reason: 'duplicate in ${q.id}');
      }
    });

    test('every single-choice question offers a zero-burden answer', () {
      // Without one, a man with no problems could never score well - the
      // scale would have a floor above zero.
      for (final AssessmentQuestion q in QuestionBank.all) {
        if (q.kind != AnswerKind.single) continue;
        expect(
          q.options.any((AnswerOption o) => o.burden == 0),
          isTrue,
          reason: '${q.id} has no zero-burden option',
        );
      }
    });

    test('every section has questions', () {
      for (final AssessmentSection s in AssessmentSection.values) {
        expect(QuestionBank.forSection(s), isNotEmpty);
      }
    });

    test('scale questions can produce burden from their bounds', () {
      for (final AssessmentQuestion q in QuestionBank.all) {
        if (q.kind != AnswerKind.scale) continue;
        final double low = q.burdenFromNumber!(q.numeric!.min);
        final double high = q.burdenFromNumber!(q.numeric!.max);
        expect(low, inInclusiveRange(0, 1));
        expect(high, inInclusiveRange(0, 1));
        expect(low, isNot(high));
      }
    });
  });

  group('score direction and bounds', () {
    test('a healthy profile scores high and low-risk', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder.healthy(),
      );

      expect(r.scores.sexualHealthScore, greaterThanOrEqualTo(90));
      expect(r.scores.edRiskScore, lessThanOrEqualTo(5));
      expect(r.scores.peRiskScore, lessThanOrEqualTo(5));
      expect(r.scores.lifestyleScore, greaterThanOrEqualTo(95));
    });

    test('a severe profile scores low and high-risk', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      );

      expect(r.scores.sexualHealthScore, lessThanOrEqualTo(12));
      expect(r.scores.edRiskScore, greaterThanOrEqualTo(85));
      expect(r.scores.peRiskScore, greaterThanOrEqualTo(90));
      expect(r.scores.lifestyleScore, lessThanOrEqualTo(5));
    });

    test('all scores stay within 0..100 for both extremes', () {
      for (final AssessmentResponses responses in <AssessmentResponses>[
        AnswerBuilder.healthy(),
        AnswerBuilder.severe(),
        const AssessmentResponses.empty(),
      ]) {
        final HealthScores s = AssessmentEngine.evaluate(responses).scores;
        for (final int v in <int>[
          s.sexualHealthScore,
          s.edRiskScore,
          s.peRiskScore,
          s.lifestyleScore,
        ]) {
          expect(v, inInclusiveRange(0, 100));
        }
      }
    });

    test('an empty intake does not crash and produces neutral output', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        const AssessmentResponses.empty(),
      );
      expect(r.scores.sexualHealthScore, 100);
      expect(r.causes, hasLength(RootCause.values.length));
      expect(r.headline, isNotEmpty);
      expect(r.summary, isNotEmpty);
    });

    test('scoring is deterministic', () {
      final AssessmentResponses input = AnswerBuilder.severe();
      final DateTime now = DateTime(2026, 3, 1);
      final AssessmentResult a = AssessmentEngine.evaluate(input, now: now);
      final AssessmentResult b = AssessmentEngine.evaluate(input, now: now);

      expect(a.scores.toJson(), b.scores.toJson());
      expect(
        a.causes.map((CauseConfidence c) => c.confidence).toList(),
        b.causes.map((CauseConfidence c) => c.confidence).toList(),
      );
    });

    test('unanswered questions are dropped rather than scored as zero', () {
      // Only one ED question answered, and it is the worst answer. If
      // unanswered questions defaulted to zero burden the risk would be
      // diluted to roughly a fifth of what it should be.
      final AssessmentResponses partial = AnswerBuilder()
          .choose('b_achieve', 'never')
          .build();
      expect(
        AssessmentEngine.evaluate(partial).scores.edRiskScore,
        greaterThanOrEqualTo(90),
      );
    });
  });

  group('root cause analysis', () {
    test('sedentary profile surfaces sedentary lifestyle as a driver', () {
      final AssessmentResponses r = AnswerBuilder()
          .body(weightKg: 95, waistCm: 105)
          .choose('d_exercise', 'never')
          .choose('d_sitting', 'over9')
          .build();

      final double confidence = _confidenceOf(
        AssessmentEngine.evaluate(r),
        RootCause.sedentaryLifestyle,
      );
      expect(confidence, greaterThanOrEqualTo(85));
    });

    test('sleep deprivation surfaces sleep deficiency', () {
      final AssessmentResponses r = AnswerBuilder()
          .body()
          .choose('d_sleep', 'under5')
          .choose('d_stress', 'high')
          .build();

      expect(
        _confidenceOf(AssessmentEngine.evaluate(r), RootCause.sleepDeficiency),
        greaterThanOrEqualTo(80),
      );
    });

    test('preserved morning erections push toward anxiety, not vascular', () {
      // Same erectile difficulty, differing only in morning erections.
      final AssessmentBuilderPair pair = AssessmentBuilderPair(
        psychogenic: AnswerBuilder()
            .body()
            .choose('b_achieve', 'few')
            .choose('b_maintain', 'few')
            .choose('b_loss_during', 'often')
            .number('b_hardness', 4)
            .choose('b_duration', 'recent')
            .choose('b_morning', 'daily')
            .choose('f_performance_anxiety', 'high')
            .build(),
        organic: AnswerBuilder()
            .body()
            .choose('b_achieve', 'few')
            .choose('b_maintain', 'few')
            .choose('b_loss_during', 'often')
            .number('b_hardness', 4)
            .choose('b_duration', 'recent')
            .choose('b_morning', 'never')
            .choose('f_performance_anxiety', 'high')
            .build(),
      );

      final AssessmentResult psych = AssessmentEngine.evaluate(
        pair.psychogenic,
      );
      final AssessmentResult organic = AssessmentEngine.evaluate(pair.organic);

      expect(
        _confidenceOf(psych, RootCause.anxietyRelated),
        greaterThan(_confidenceOf(organic, RootCause.anxietyRelated)),
      );
      expect(
        _confidenceOf(organic, RootCause.cardiovascular),
        greaterThan(_confidenceOf(psych, RootCause.cardiovascular)),
      );
    });

    test('poor ejaculatory control loads the pelvic floor category', () {
      final AssessmentResponses r = AnswerBuilder()
          .body()
          .choose('c_latency', 'under30')
          .choose('c_control', 'unable')
          .choose('b_loss_during', 'always')
          .choose('d_sitting', 'over9')
          .choose('d_exercise', 'never')
          .build();

      expect(
        _confidenceOf(
          AssessmentEngine.evaluate(r),
          RootCause.pelvicFloorWeakness,
        ),
        greaterThanOrEqualTo(70),
      );
    });

    test('causes are sorted by descending confidence', () {
      final List<CauseConfidence> causes = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      ).causes;
      for (int i = 1; i < causes.length; i++) {
        expect(
          causes[i - 1].confidence,
          greaterThanOrEqualTo(causes[i].confidence),
        );
      }
    });

    test('a healthy profile has no cause above the relevance floor', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder.healthy(),
      );
      expect(r.relevantCauses, isEmpty);
      expect(r.isMultifactorial, isFalse);
    });

    test('a severe profile is classified as multifactorial', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      );
      expect(r.isMultifactorial, isTrue);
      expect(r.classification, 'Multiple contributing causes');
    });

    test('confidences never leave 0..100', () {
      for (final CauseConfidence c in AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      ).causes) {
        expect(c.confidence, inInclusiveRange(0, 100));
      }
    });
  });

  group('body metrics', () {
    test('BMI and waist-to-height are computed correctly', () {
      final BodyMetrics m = AssessmentEngine.deriveMetrics(
        AnswerBuilder().body(heightCm: 180, weightKg: 81, waistCm: 90).build(),
      );
      expect(m.bmi, closeTo(25.0, 0.05));
      expect(m.waistToHeight, closeTo(0.5, 0.001));
      expect(m.bmiBand, 'Overweight');
    });

    test('signals rise monotonically with BMI and waist ratio', () {
      double previous = -1;
      for (double bmi = 20; bmi <= 45; bmi += 1) {
        final double s = AssessmentEngine.bmiSignal(bmi);
        expect(s, greaterThanOrEqualTo(previous));
        expect(s, inInclusiveRange(0, 1));
        previous = s;
      }
      previous = -1;
      for (double r = 0.40; r <= 0.75; r += 0.01) {
        final double s = AssessmentEngine.waistSignal(r);
        expect(s, greaterThanOrEqualTo(previous));
        expect(s, inInclusiveRange(0, 1));
        previous = s;
      }
    });
  });

  group('clinical flags', () {
    test('diagnosed heart disease raises a cardiovascular referral', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder().body().choose('e_heart', 'diagnosed').build(),
      );
      expect(r.flags, contains(ClinicalFlag.cardiovascularReview));
    });

    test('medication for mood raises mental health support', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder().body().choose('e_mood', 'medicated').build(),
      );
      expect(r.flags, contains(ClinicalFlag.mentalHealthSupport));
    });

    test('compulsive use raises behavioural support', () {
      final AssessmentResult r = AssessmentEngine.evaluate(
        AnswerBuilder().body().choose('f_porn', 'compulsive').build(),
      );
      expect(r.flags, contains(ClinicalFlag.compulsiveUse));
    });

    test('a healthy profile raises no flags', () {
      expect(AssessmentEngine.evaluate(AnswerBuilder.healthy()).flags, isEmpty);
    });

    test('the severe profile raises several, without duplicates', () {
      final List<ClinicalFlag> flags = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
      ).flags;
      expect(flags.length, greaterThanOrEqualTo(4));
      expect(flags.toSet().length, flags.length);
    });
  });

  group('serialisation', () {
    test('a result survives a JSON round trip', () {
      final AssessmentResult original = AssessmentEngine.evaluate(
        AnswerBuilder.severe(),
        now: DateTime.utc(2026, 5, 4, 12),
      );
      final AssessmentResult restored = AssessmentResult.fromJson(
        original.toJson(),
      );

      expect(restored.scores.toJson(), original.scores.toJson());
      expect(restored.completedAt, original.completedAt);
      expect(restored.flags, original.flags);
      expect(restored.topCause.cause, original.topCause.cause);
      expect(restored.metrics.bmi, closeTo(original.metrics.bmi, 0.001));
    });

    test('responses survive a JSON round trip', () {
      final AssessmentResponses original = AnswerBuilder.severe();
      final AssessmentResponses restored = AssessmentResponses.fromJson(
        original.toJson(),
      );
      expect(restored.answers.length, original.answers.length);
      expect(restored.choice('b_achieve'), 'never');
      expect(restored.number('a_age'), 55);
    });
  });
}

double _confidenceOf(AssessmentResult result, RootCause cause) => result.causes
    .firstWhere((CauseConfidence c) => c.cause == cause)
    .confidence;

/// Two intakes that differ in exactly one answer.
class AssessmentBuilderPair {
  AssessmentBuilderPair({required this.psychogenic, required this.organic});

  final AssessmentResponses psychogenic;
  final AssessmentResponses organic;
}
