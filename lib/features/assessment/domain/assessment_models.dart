import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The six sections of the VitalRise intake.
enum AssessmentSection {
  basics('Basic information', 'A few numbers that anchor every calculation.'),
  erectile('Erection quality', 'Adapted from validated self-report screeners.'),
  ejaculation('Ejaculation control', 'How much say you have over timing.'),
  lifestyle(
    'Lifestyle',
    'The daily inputs that drive blood flow and hormones.',
  ),
  medical(
    'Health history',
    'Conditions that commonly sit underneath symptoms.',
  ),
  psychological(
    'Mind & relationship',
    'Stress, anxiety and habits of arousal.',
  );

  const AssessmentSection(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

/// How a question is answered in the UI.
enum AnswerKind { single, numeric, scale }

/// A single selectable option.
///
/// [burden] is the normalised severity contribution of the option, where
/// `0.0` is "no concern" and `1.0` is "maximum concern". Keeping every
/// option on the same 0-1 scale is what lets the scoring engine combine
/// wildly different questions with simple weights.
@immutable
class AnswerOption {
  const AnswerOption(this.value, this.label, this.burden, {this.detail})
    : assert(burden >= 0 && burden <= 1, 'burden must be within 0..1');

  final String value;
  final String label;
  final double burden;
  final String? detail;
}

/// Bounds for numeric / scale questions.
@immutable
class NumericSpec {
  const NumericSpec({
    required this.min,
    required this.max,
    required this.unit,
    this.step = 1,
    this.initial,
    this.lowLabel,
    this.highLabel,
  });

  final double min;
  final double max;
  final double step;
  final String unit;
  final double? initial;
  final String? lowLabel;
  final String? highLabel;

  double clamp(double v) => v.clamp(min, max);
}

/// One question in the intake.
@immutable
class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.section,
    required this.prompt,
    required this.kind,
    this.helper,
    this.options = const <AnswerOption>[],
    this.numeric,
    this.burdenFromNumber,
  }) : assert(
         kind == AnswerKind.single || numeric != null,
         'numeric and scale questions need a NumericSpec',
       );

  final String id;
  final AssessmentSection section;
  final String prompt;
  final String? helper;
  final AnswerKind kind;
  final List<AnswerOption> options;
  final NumericSpec? numeric;

  /// Maps a numeric answer onto the shared 0-1 burden scale. Questions that
  /// only collect data (age, height, weight) leave this null and contribute
  /// through derived metrics such as BMI instead.
  final double Function(double value)? burdenFromNumber;

  AnswerOption? optionFor(String value) =>
      options.firstWhereOrNull((AnswerOption o) => o.value == value);
}

/// A user's answer to one question.
@immutable
sealed class Answer {
  const Answer();

  Object toJson();

  static Answer? fromJson(Object? json) => switch (json) {
    final String v => ChoiceAnswer(v),
    final num v => NumericAnswer(v.toDouble()),
    _ => null,
  };
}

@immutable
class ChoiceAnswer extends Answer {
  const ChoiceAnswer(this.value);
  final String value;

  @override
  Object toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is ChoiceAnswer && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

@immutable
class NumericAnswer extends Answer {
  const NumericAnswer(this.value);
  final double value;

  @override
  Object toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is NumericAnswer && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// The full set of answers, keyed by question id.
@immutable
class AssessmentResponses {
  const AssessmentResponses(this.answers);

  const AssessmentResponses.empty() : answers = const <String, Answer>{};

  final Map<String, Answer> answers;

  bool get isEmpty => answers.isEmpty;

  AssessmentResponses put(String questionId, Answer answer) =>
      AssessmentResponses(<String, Answer>{...answers, questionId: answer});

  AssessmentResponses remove(String questionId) =>
      AssessmentResponses(<String, Answer>{...answers}..remove(questionId));

  Answer? operator [](String questionId) => answers[questionId];

  String? choice(String questionId) {
    final Answer? a = answers[questionId];
    return a is ChoiceAnswer ? a.value : null;
  }

  double? number(String questionId) {
    final Answer? a = answers[questionId];
    return a is NumericAnswer ? a.value : null;
  }

  Map<String, Object> toJson() => answers.map(
    (String k, Answer v) => MapEntry<String, Object>(k, v.toJson()),
  );

  static AssessmentResponses fromJson(Map<String, dynamic> json) {
    final Map<String, Answer> parsed = <String, Answer>{};
    for (final MapEntry<String, dynamic> e in json.entries) {
      final Answer? a = Answer.fromJson(e.value as Object?);
      if (a != null) parsed[e.key] = a;
    }
    return AssessmentResponses(parsed);
  }
}
