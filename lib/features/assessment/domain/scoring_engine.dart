import 'dart:math' as math;

import 'assessment_models.dart';
import 'assessment_result.dart';
import 'question_bank.dart';
import 'root_cause.dart';

/// A `(weight, signal)` contribution to a root-cause score.
typedef Signal = (double weight, double value);

/// Pure, deterministic scoring for the VitalRise intake.
///
/// The engine has no dependencies on Flutter, Supabase or time-of-day beyond
/// the `now` it is handed, which keeps it fully unit-testable - see
/// `test/assessment/scoring_engine_test.dart`.
///
/// ## How it works
/// Every answer is normalised to a *burden* in `0..1` (0 = no concern,
/// 1 = maximum concern) by the question bank. From there:
///
/// 1. Section burdens are weighted means of their questions. Unanswered
///    questions are dropped and the remaining weights renormalised, so a
///    partial intake is never silently scored as "all zeros".
/// 2. The four headline scores are affine functions of those burdens.
/// 3. Each root cause is a weighted sum of hand-picked signals plus a small
///    number of clinically-motivated modifiers (see [_psychogenicBonus]).
///
/// The weights are editorial, not derived from a trained model. They encode
/// the product's point of view about which levers matter, and every one of
/// them is documented in `docs/SCORING.md`.
abstract final class AssessmentEngine {
  // ------------------------------------------------------------------
  // Section weights
  // ------------------------------------------------------------------
  static const Map<String, double> _edWeights = <String, double>{
    'b_achieve': 0.20,
    'b_maintain': 0.22,
    'b_morning': 0.16,
    'b_hardness': 0.18,
    'b_loss_during': 0.14,
    'b_duration': 0.10,
  };

  static const Map<String, double> _peWeights = <String, double>{
    'c_latency': 0.35,
    'c_control': 0.30,
    'c_satisfaction': 0.15,
    'c_anticipatory_anxiety': 0.20,
  };

  static const Map<String, double> _lifestyleWeights = <String, double>{
    'd_smoking': 0.20,
    'd_alcohol': 0.14,
    'd_sleep': 0.22,
    'd_exercise': 0.22,
    'd_sitting': 0.12,
    'd_stress': 0.10,
  };

  static const Map<String, double> _medicalWeights = <String, double>{
    'e_diabetes': 0.22,
    'e_blood_pressure': 0.18,
    'e_weight_status': 0.14,
    'e_thyroid': 0.08,
    'e_heart': 0.20,
    'e_testosterone': 0.10,
    'e_mood': 0.08,
  };

  static const Map<String, double> _psychWeights = <String, double>{
    'f_performance_anxiety': 0.34,
    'f_relationship': 0.18,
    'f_porn': 0.18,
    'f_masturbation': 0.10,
    'f_work_stress': 0.20,
  };

  /// Composite weights for the headline sexual-health score. Sums to 1.
  static const double _wEd = 0.30;
  static const double _wPe = 0.22;
  static const double _wLifestyle = 0.20;
  static const double _wMedical = 0.16;
  static const double _wPsych = 0.12;

  // ------------------------------------------------------------------
  // Entry point
  // ------------------------------------------------------------------
  static AssessmentResult evaluate(
    AssessmentResponses responses, {
    DateTime? now,
  }) {
    final BodyMetrics metrics = deriveMetrics(responses);

    final double edBurden = _weighted(responses, _edWeights);
    final double peBurden = _weighted(responses, _peWeights);
    final double lifestyleBurden = _weighted(responses, _lifestyleWeights);
    final double medicalBurden = _weighted(responses, _medicalWeights);
    final double psychBurden = _weighted(responses, _psychWeights);

    final double adiposity = math.max(
      bmiSignal(metrics.bmi),
      waistSignal(metrics.waistToHeight),
    );

    // Age is a context modifier, never a penalty: it slightly softens the ED
    // risk of an older man and slightly sharpens it for a young one, because
    // the same symptoms mean different things at 25 and at 65.
    final double ageAdjust = _ageAdjust(metrics.age);
    final int edRisk = _pct(edBurden * ageAdjust);
    final int peRisk = _pct(peBurden);
    final int lifestyleScore = _pct(1 - lifestyleBurden);

    final double composite =
        _wEd * edBurden * ageAdjust +
        _wPe * peBurden +
        _wLifestyle * lifestyleBurden +
        _wMedical * medicalBurden +
        _wPsych * psychBurden;
    final int sexualHealth = _pct(1 - composite);

    final HealthScores scores = HealthScores(
      sexualHealthScore: sexualHealth,
      edRiskScore: edRisk,
      peRiskScore: peRisk,
      lifestyleScore: lifestyleScore,
    );

    final List<CauseConfidence> causes = _causes(
      responses,
      adiposity: adiposity,
      edBurden: edBurden,
      peBurden: peBurden,
    );

    final List<ClinicalFlag> flags = _flags(
      responses,
      edBurden: edBurden,
      adiposity: adiposity,
    );

    final AssessmentResult draft = AssessmentResult(
      completedAt: now ?? DateTime.now(),
      metrics: metrics,
      scores: scores,
      causes: causes,
      flags: flags,
      headline: '',
      summary: '',
    );

    return AssessmentResult(
      completedAt: draft.completedAt,
      metrics: metrics,
      scores: scores,
      causes: causes,
      flags: flags,
      headline: _headline(draft),
      summary: _summary(draft),
    );
  }

  // ------------------------------------------------------------------
  // Burden helpers
  // ------------------------------------------------------------------

  /// Burden for one question, or null when unanswered / not scored.
  static double? burdenOf(AssessmentResponses responses, String questionId) {
    final Answer? answer = responses[questionId];
    if (answer == null) return null;

    final AssessmentQuestion question = QuestionBank.byId(questionId);
    return switch (answer) {
      ChoiceAnswer(:final String value) => question.optionFor(value)?.burden,
      NumericAnswer(:final double value) => question.burdenFromNumber?.call(
        value,
      ),
    };
  }

  /// Weighted mean of the answered questions, renormalised over the weights
  /// actually present. Returns 0 when nothing in the group was answered.
  static double _weighted(
    AssessmentResponses responses,
    Map<String, double> weights,
  ) {
    double total = 0;
    double used = 0;
    for (final MapEntry<String, double> e in weights.entries) {
      final double? b = burdenOf(responses, e.key);
      if (b == null) continue;
      total += b * e.value;
      used += e.value;
    }
    if (used <= 0) return 0;
    return (total / used).clamp(0.0, 1.0);
  }

  static BodyMetrics deriveMetrics(AssessmentResponses responses) =>
      BodyMetrics(
        age: (responses.number('a_age') ?? 32).round(),
        heightCm: responses.number('a_height_cm') ?? 175,
        weightKg: responses.number('a_weight_kg') ?? 78,
        waistCm: responses.number('a_waist_cm') ?? 90,
      );

  /// BMI mapped onto the shared 0-1 burden scale.
  static double bmiSignal(double bmi) => _bands(bmi, const <List<double>>[
    <double>[24, 0.0],
    <double>[27, 0.30],
    <double>[30, 0.55],
    <double>[35, 0.85],
    <double>[40, 1.0],
  ]);

  /// Waist-to-height ratio mapped onto the shared 0-1 burden scale.
  static double waistSignal(double ratio) => _bands(ratio, const <List<double>>[
    <double>[0.45, 0.0],
    <double>[0.50, 0.25],
    <double>[0.55, 0.55],
    <double>[0.60, 0.80],
    <double>[0.65, 1.0],
  ]);

  /// Piecewise-linear interpolation through `[breakpoint, value]` pairs.
  /// Clamps flat below the first and above the last breakpoint.
  static double _bands(double x, List<List<double>> points) {
    if (x <= points.first[0]) return points.first[1];
    for (int i = 1; i < points.length; i++) {
      final double x0 = points[i - 1][0];
      final double x1 = points[i][0];
      if (x <= x1) {
        final double t = (x - x0) / (x1 - x0);
        return points[i - 1][1] + t * (points[i][1] - points[i - 1][1]);
      }
    }
    return points.last[1];
  }

  /// Multiplier applied to ED burden. 1.0 at 45, gently lower with age,
  /// gently higher when young. Bounded to +-12% so it can never dominate.
  static double _ageAdjust(int age) =>
      (1.0 + (45 - age) * 0.004).clamp(0.88, 1.12);

  static int _pct(double v) => (v.clamp(0.0, 1.0) * 100).round();

  // ------------------------------------------------------------------
  // Root cause analysis
  // ------------------------------------------------------------------
  static List<CauseConfidence> _causes(
    AssessmentResponses responses, {
    required double adiposity,
    required double edBurden,
    required double peBurden,
  }) {
    double b(String id) => burdenOf(responses, id) ?? 0;

    final double morning = b('b_morning');

    final Map<RootCause, double> raw = <RootCause, double>{
      // Pelvic floor: weak seal (losing firmness mid-act) and poor
      // ejaculatory gating are the two hallmark signals, plus disuse.
      RootCause.pelvicFloorWeakness: _sum(<Signal>[
        (0.24, b('b_loss_during')),
        (0.18, b('c_control')),
        (0.16, b('c_latency')),
        (0.14, b('b_maintain')),
        (0.14, b('d_sitting')),
        (0.14, b('d_exercise')),
      ]),
      RootCause.obesityRelated: _sum(<Signal>[
        (0.50, adiposity),
        (0.20, b('e_weight_status')),
        (0.15, b('d_exercise')),
        (0.15, b('e_diabetes')),
      ]),
      RootCause.anxietyRelated: _sum(<Signal>[
        (0.28, b('f_performance_anxiety')),
        (0.18, b('c_anticipatory_anxiety')),
        (0.14, b('d_stress')),
        (0.12, b('f_work_stress')),
        (0.14, b('e_mood')),
        (0.14, b('f_relationship')),
      ]),
      RootCause.cardiovascular: _sum(<Signal>[
        (0.24, b('e_heart')),
        (0.22, b('e_blood_pressure')),
        (0.22, b('d_smoking')),
        (0.16, morning),
        (0.16, adiposity),
      ]),
      RootCause.sedentaryLifestyle: _sum(<Signal>[
        (0.40, b('d_exercise')),
        (0.40, b('d_sitting')),
        (0.20, adiposity),
      ]),
      RootCause.sleepDeficiency: _sum(<Signal>[
        (0.70, b('d_sleep')),
        (0.15, b('d_stress')),
        (0.15, b('e_mood')),
      ]),
      RootCause.diabetesRelated: _sum(<Signal>[
        (0.62, b('e_diabetes')),
        (0.20, adiposity),
        (0.18, morning),
      ]),
    };

    // --- Clinically motivated modifiers -------------------------------
    // Preserved morning erections alongside difficulty during sex is the
    // classic pointer towards a psychogenic driver rather than a vascular
    // one. Absent morning erections points the other way.
    final double psychogenic = _psychogenicBonus(morning, edBurden);
    raw[RootCause.anxietyRelated] =
        raw[RootCause.anxietyRelated]! + psychogenic;
    raw[RootCause.cardiovascular] =
        raw[RootCause.cardiovascular]! + morning * edBurden * 0.12;

    // Abrupt onset in someone with few medical risks reads as situational.
    if (responses.choice('b_duration') == 'recent') {
      raw[RootCause.anxietyRelated] =
          raw[RootCause.anxietyRelated]! + 0.08 * edBurden;
    }

    // Fast, poorly controlled ejaculation with high anxiety loads both the
    // pelvic floor (no trained brake) and the anxiety channel.
    raw[RootCause.pelvicFloorWeakness] =
        raw[RootCause.pelvicFloorWeakness]! + peBurden * 0.10;

    final List<CauseConfidence> out =
        raw.entries
            .map(
              (MapEntry<RootCause, double> e) =>
                  CauseConfidence(e.key, (e.value * 100).clamp(0.0, 100.0)),
            )
            .toList()
          ..sort();
    return out;
  }

  static double _psychogenicBonus(double morningBurden, double edBurden) =>
      (1 - morningBurden) * edBurden * 0.22;

  /// Sum of `(weight, signal)` pairs. A list of records rather than a map,
  /// because two signals in the same table routinely share a weight and map
  /// literals would silently drop one of them.
  static double _sum(List<Signal> weighted) {
    double total = 0;
    for (final Signal s in weighted) {
      total += s.$1 * s.$2;
    }
    return total;
  }

  // ------------------------------------------------------------------
  // Clinical flags
  // ------------------------------------------------------------------
  static List<ClinicalFlag> _flags(
    AssessmentResponses responses, {
    required double edBurden,
    required double adiposity,
  }) {
    final List<ClinicalFlag> flags = <ClinicalFlag>[];
    final String? heart = responses.choice('e_heart');
    final String? bp = responses.choice('e_blood_pressure');
    final String? diabetes = responses.choice('e_diabetes');
    final String? testosterone = responses.choice('e_testosterone');
    final String? mood = responses.choice('e_mood');

    if (heart == 'diagnosed' ||
        bp == 'uncontrolled' ||
        (edBurden >= 0.6 && (heart == 'cholesterol' || bp == 'medicated'))) {
      flags.add(ClinicalFlag.cardiovascularReview);
    }
    if (diabetes == 't2_uncontrolled' ||
        diabetes == 't1' ||
        diabetes == 'prediabetes' ||
        (diabetes == 'unsure' && adiposity >= 0.55)) {
      flags.add(ClinicalFlag.glycaemicReview);
    }
    if (testosterone == 'symptoms' ||
        testosterone == 'diagnosed' ||
        responses.choice('e_thyroid') == 'hypo' ||
        (responses.choice('b_morning') == 'never' && edBurden >= 0.5)) {
      flags.add(ClinicalFlag.hormonalReview);
    }
    if (mood == 'current' || mood == 'diagnosed' || mood == 'medicated') {
      flags.add(ClinicalFlag.mentalHealthSupport);
    }
    if (responses.choice('b_duration') == 'recent' && edBurden >= 0.5) {
      flags.add(ClinicalFlag.suddenOnset);
    }
    if (responses.choice('f_porn') == 'compulsive' ||
        responses.choice('f_masturbation') == 'multiple') {
      flags.add(ClinicalFlag.compulsiveUse);
    }
    return flags;
  }

  // ------------------------------------------------------------------
  // Narrative
  // ------------------------------------------------------------------
  static String _headline(AssessmentResult r) {
    if (r.isMultifactorial) {
      return 'Several factors are stacking up - and they overlap more than '
          'they compete';
    }
    final CauseConfidence top = r.topCause;
    if (top.confidence < 35) {
      return 'Nothing here stands out as a major driver';
    }
    return switch (top.cause) {
      RootCause.pelvicFloorWeakness =>
        'Your answers point at the pelvic floor - the most trainable factor '
            'there is',
      RootCause.obesityRelated =>
        'Metabolic load looks like your biggest lever right now',
      RootCause.anxietyRelated =>
        'This reads as an arousal and anxiety pattern, not a plumbing problem',
      RootCause.cardiovascular =>
        'Circulation is the thread running through your answers',
      RootCause.sedentaryLifestyle =>
        'Time spent sitting is doing more damage here than anything else',
      RootCause.sleepDeficiency =>
        'Sleep is quietly setting the ceiling on everything else',
      RootCause.diabetesRelated =>
        'Blood sugar control is the factor to get on top of first',
    };
  }

  static String _summary(AssessmentResult r) {
    final StringBuffer sb = StringBuffer();
    final List<CauseConfidence> drivers = r.relevantCauses.take(3).toList();

    sb.write(
      'Your sexual health score is ${r.scores.sexualHealthScore}/100 '
      '(${r.scores.sexualHealthBand}). ',
    );

    if (drivers.isEmpty) {
      sb.write(
        'None of the factors we screen for scored high enough to call '
        'a driver, so your programme focuses on maintaining what is already '
        'working. ',
      );
    } else {
      final String names = drivers
          .map((CauseConfidence c) => c.cause.title.toLowerCase())
          .join(', ');
      sb.write('The factors carrying the most weight are $names. ');
    }

    if (r.scores.edRiskScore >= 50 && r.scores.peRiskScore >= 50) {
      sb.write(
        'Erection quality and ejaculation control both scored in a '
        'range worth working on - they often share a root cause, so one '
        'programme addresses both. ',
      );
    } else if (r.scores.edRiskScore >= 50) {
      sb.write('Erection quality is the primary target of your programme. ');
    } else if (r.scores.peRiskScore >= 50) {
      sb.write('Ejaculation control is the primary target of your programme. ');
    }

    if (r.flags.isNotEmpty) {
      sb.write(
        'We have also flagged ${r.flags.length} '
        '${r.flags.length == 1 ? 'topic' : 'topics'} to raise with a '
        'healthcare professional - these are things an app cannot assess.',
      );
    } else {
      sb.write(
        'Nothing in your answers needs urgent medical attention, '
        'though a routine check-up is never wasted.',
      );
    }
    return sb.toString();
  }
}
