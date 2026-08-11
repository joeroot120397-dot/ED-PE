import 'package:meta/meta.dart';

import 'root_cause.dart';

/// Body metrics derived from Section A.
@immutable
class BodyMetrics {
  const BodyMetrics({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.waistCm,
  });

  final int age;
  final double heightCm;
  final double weightKg;
  final double waistCm;

  double get bmi {
    final double m = heightCm / 100;
    if (m <= 0) return 0;
    return weightKg / (m * m);
  }

  /// Waist-to-height ratio. Above 0.5 is the widely used "keep your waist to
  /// less than half your height" threshold.
  double get waistToHeight => heightCm <= 0 ? 0 : waistCm / heightCm;

  String get bmiBand {
    final double b = bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25) return 'Healthy range';
    if (b < 30) return 'Overweight';
    if (b < 35) return 'Obese (class I)';
    return 'Obese (class II+)';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'age': age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'waist_cm': waistCm,
  };

  static BodyMetrics fromJson(Map<String, dynamic> json) => BodyMetrics(
    age: (json['age'] as num?)?.toInt() ?? 30,
    heightCm: (json['height_cm'] as num?)?.toDouble() ?? 175,
    weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 75,
    waistCm: (json['waist_cm'] as num?)?.toDouble() ?? 85,
  );
}

/// The four headline scores.
///
/// **Direction matters and is not uniform** - it is the single easiest thing
/// to get wrong when reading this class:
/// * [sexualHealthScore] and [lifestyleScore] are *higher is better*.
/// * [edRiskScore] and [peRiskScore] are *higher is worse*.
@immutable
class HealthScores {
  const HealthScores({
    required this.sexualHealthScore,
    required this.edRiskScore,
    required this.peRiskScore,
    required this.lifestyleScore,
  });

  final int sexualHealthScore;
  final int edRiskScore;
  final int peRiskScore;
  final int lifestyleScore;

  String get sexualHealthBand => switch (sexualHealthScore) {
    >= 80 => 'Strong',
    >= 65 => 'Good',
    >= 50 => 'Fair',
    >= 35 => 'Needs work',
    _ => 'Priority',
  };

  static String riskBand(int risk) => switch (risk) {
    >= 75 => 'High',
    >= 50 => 'Moderate',
    >= 25 => 'Mild',
    _ => 'Low',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sexual_health': sexualHealthScore,
    'ed_risk': edRiskScore,
    'pe_risk': peRiskScore,
    'lifestyle': lifestyleScore,
  };

  static HealthScores fromJson(Map<String, dynamic> json) => HealthScores(
    sexualHealthScore: (json['sexual_health'] as num?)?.toInt() ?? 0,
    edRiskScore: (json['ed_risk'] as num?)?.toInt() ?? 0,
    peRiskScore: (json['pe_risk'] as num?)?.toInt() ?? 0,
    lifestyleScore: (json['lifestyle'] as num?)?.toInt() ?? 0,
  );
}

/// Everything the engine produces from one completed intake.
@immutable
class AssessmentResult {
  const AssessmentResult({
    required this.completedAt,
    required this.metrics,
    required this.scores,
    required this.causes,
    required this.flags,
    required this.headline,
    required this.summary,
  });

  final DateTime completedAt;
  final BodyMetrics metrics;
  final HealthScores scores;

  /// Sorted descending by confidence. Always contains every [RootCause] so
  /// the UI can show the full picture; use [primaryCauses] for the drivers.
  final List<CauseConfidence> causes;

  final List<ClinicalFlag> flags;

  /// One-line plain-language framing shown at the top of the results screen.
  final String headline;

  /// Two or three sentences explaining the result.
  final String summary;

  List<CauseConfidence> get primaryCauses =>
      causes.where((CauseConfidence c) => c.isPrimary).toList();

  List<CauseConfidence> get relevantCauses =>
      causes.where((CauseConfidence c) => c.isRelevant).toList();

  /// True when three or more categories clear the "likely driver" bar. This
  /// is the "Multiple Causes" classification from the product brief.
  bool get isMultifactorial => primaryCauses.length >= 3;

  CauseConfidence get topCause => causes.first;

  String get classification =>
      isMultifactorial ? 'Multiple contributing causes' : topCause.cause.title;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'completed_at': completedAt.toIso8601String(),
    'metrics': metrics.toJson(),
    'scores': scores.toJson(),
    'causes': causes.map((CauseConfidence c) => c.toJson()).toList(),
    'flags': flags.map((ClinicalFlag f) => f.slug).toList(),
    'headline': headline,
    'summary': summary,
  };

  static AssessmentResult fromJson(Map<String, dynamic> json) {
    final List<CauseConfidence> causes = <CauseConfidence>[];
    for (final Object? raw
        in (json['causes'] as List<dynamic>? ?? const <dynamic>[])) {
      final CauseConfidence? c = CauseConfidence.fromJson(
        raw! as Map<String, dynamic>,
      );
      if (c != null) causes.add(c);
    }
    causes.sort();

    final List<ClinicalFlag> flags = <ClinicalFlag>[];
    for (final Object? raw
        in (json['flags'] as List<dynamic>? ?? const <dynamic>[])) {
      for (final ClinicalFlag f in ClinicalFlag.values) {
        if (f.slug == raw) flags.add(f);
      }
    }

    return AssessmentResult(
      completedAt:
          DateTime.tryParse(json['completed_at'] as String? ?? '') ??
          DateTime.now(),
      metrics: BodyMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      scores: HealthScores.fromJson(
        json['scores'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      causes: causes,
      flags: flags,
      headline: json['headline'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }
}
