import 'package:vitalrise/features/assessment/domain/assessment_models.dart';
import 'package:vitalrise/features/assessment/domain/question_bank.dart';

/// Test helper for assembling intake responses without repeating the
/// `ChoiceAnswer`/`NumericAnswer` ceremony at every call site.
class AnswerBuilder {
  AnswerBuilder();

  final Map<String, Answer> _answers = <String, Answer>{};

  AnswerBuilder choose(String questionId, String value) {
    final AssessmentQuestion q = QuestionBank.byId(questionId);
    assert(
      q.optionFor(value) != null,
      'Question "$questionId" has no option "$value". '
      'Available: ${q.options.map((AnswerOption o) => o.value).join(', ')}',
    );
    _answers[questionId] = ChoiceAnswer(value);
    return this;
  }

  AnswerBuilder number(String questionId, double value) {
    _answers[questionId] = NumericAnswer(value);
    return this;
  }

  AnswerBuilder body({
    double age = 35,
    double heightCm = 175,
    double weightKg = 75,
    double waistCm = 85,
  }) => number('a_age', age)
      .number('a_height_cm', heightCm)
      .number('a_weight_kg', weightKg)
      .number('a_waist_cm', waistCm);

  AssessmentResponses build() => AssessmentResponses(_answers);

  /// A man with no meaningful concerns in any section - the "floor" case.
  static AssessmentResponses healthy() => AnswerBuilder()
      .body(age: 30, heightCm: 178, weightKg: 72, waistCm: 80)
      .choose('a_relationship', 'married')
      .choose('b_achieve', 'always')
      .choose('b_maintain', 'always')
      .choose('b_morning', 'daily')
      .number('b_hardness', 10)
      .choose('b_loss_during', 'never')
      .choose('b_duration', 'none')
      .choose('c_latency', 'over5')
      .choose('c_control', 'none')
      .choose('c_satisfaction', 'very')
      .choose('c_anticipatory_anxiety', 'none')
      .choose('d_smoking', 'never')
      .choose('d_alcohol', 'none')
      .choose('d_sleep', '8plus')
      .choose('d_exercise', '5plus')
      .choose('d_sitting', 'under4')
      .choose('d_stress', 'low')
      .choose('e_diabetes', 'no')
      .choose('e_blood_pressure', 'no')
      .choose('e_weight_status', 'no')
      .choose('e_thyroid', 'no')
      .choose('e_heart', 'no')
      .choose('e_testosterone', 'no')
      .choose('e_mood', 'no')
      .choose('f_performance_anxiety', 'none')
      .choose('f_relationship', 'good')
      .choose('f_porn', 'never')
      .choose('f_masturbation', 'rare')
      .choose('f_work_stress', 'low')
      .build();

  /// The worst case in every section - the "ceiling".
  static AssessmentResponses severe() => AnswerBuilder()
      .body(age: 55, heightCm: 172, weightKg: 118, waistCm: 128)
      .choose('a_relationship', 'separated')
      .choose('b_achieve', 'never')
      .choose('b_maintain', 'never')
      .choose('b_morning', 'never')
      .number('b_hardness', 1)
      .choose('b_loss_during', 'always')
      .choose('b_duration', 'years')
      .choose('c_latency', 'under30')
      .choose('c_control', 'unable')
      .choose('c_satisfaction', 'very_dissatisfied')
      .choose('c_anticipatory_anxiety', 'severe')
      .choose('d_smoking', 'heavy')
      .choose('d_alcohol', 'daily_heavy')
      .choose('d_sleep', 'under5')
      .choose('d_exercise', 'never')
      .choose('d_sitting', 'over9')
      .choose('d_stress', 'severe')
      .choose('e_diabetes', 't2_uncontrolled')
      .choose('e_blood_pressure', 'uncontrolled')
      .choose('e_weight_status', 'obese')
      .choose('e_thyroid', 'hypo')
      .choose('e_heart', 'diagnosed')
      .choose('e_testosterone', 'diagnosed')
      .choose('e_mood', 'medicated')
      .choose('f_performance_anxiety', 'severe')
      .choose('f_relationship', 'distant')
      .choose('f_porn', 'compulsive')
      .choose('f_masturbation', 'multiple')
      .choose('f_work_stress', 'burnout')
      .build();
}
