import 'package:meta/meta.dart';

import '../../habits/domain/habit_log.dart';

/// The weekly self-rated metrics.
///
/// Kept separate from [HabitLog] on purpose: habits are objective daily
/// facts, these are subjective weekly impressions. Mixing them would make
/// the trend charts meaningless.
enum ProgressMetric {
  erectionQuality(
    'Erection quality',
    'How firm and reliable were your erections this week?',
    'Soft / unreliable',
    'Firm and reliable',
    higherIsBetter: true,
  ),
  ejaculationControl(
    'Ejaculation control',
    'How much say did you have over timing this week?',
    'No control',
    'Full control',
    higherIsBetter: true,
  ),
  energyLevel(
    'Energy',
    'How were your energy levels day to day?',
    'Exhausted',
    'Energised',
    higherIsBetter: true,
  ),
  stressLevel(
    'Stress',
    'How stressed did you feel overall?',
    'Calm',
    'Overwhelmed',
    higherIsBetter: false,
  ),
  confidence(
    'Sexual confidence',
    'How confident did you feel about sex this week?',
    'Anxious',
    'Confident',
    higherIsBetter: true,
  );

  const ProgressMetric(
    this.label,
    this.prompt,
    this.lowLabel,
    this.highLabel, {
    required this.higherIsBetter,
  });

  final String label;
  final String prompt;
  final String lowLabel;
  final String highLabel;

  /// Stress is the one metric where a lower number is the good outcome.
  /// Charts and deltas must respect this or they will celebrate the wrong
  /// direction.
  final bool higherIsBetter;

  String get key => name;
}

/// One weekly check-in.
@immutable
class ProgressEntry {
  const ProgressEntry({
    required this.weekStart,
    required this.ratings,
    this.weightKg,
    this.waistCm,
    this.note,
  });

  /// Monday of the week this entry covers.
  final DayKey weekStart;

  /// Metric -> rating on a 1-10 scale.
  final Map<ProgressMetric, int> ratings;

  final double? weightKg;
  final double? waistCm;
  final String? note;

  int? ratingFor(ProgressMetric m) => ratings[m];

  bool get isComplete => ProgressMetric.values.every(ratings.containsKey);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'week_start': weekStart.iso,
    'ratings': <String, int>{
      for (final MapEntry<ProgressMetric, int> e in ratings.entries)
        e.key.key: e.value,
    },
    'weight_kg': weightKg,
    'waist_cm': waistCm,
    'note': note,
  };

  static ProgressEntry fromJson(Map<String, dynamic> json) {
    final Map<ProgressMetric, int> ratings = <ProgressMetric, int>{};
    final Map<String, dynamic> raw =
        (json['ratings'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    for (final ProgressMetric m in ProgressMetric.values) {
      final Object? v = raw[m.key];
      if (v is num) ratings[m] = v.toInt();
    }
    return ProgressEntry(
      weekStart:
          DayKey.parse(json['week_start'] as String? ?? '') ?? DayKey.today(),
      ratings: ratings,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      waistCm: (json['waist_cm'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }
}

/// The direction and size of a change between two check-ins.
@immutable
class MetricTrend {
  const MetricTrend({
    required this.metric,
    required this.first,
    required this.latest,
    required this.samples,
  });

  final ProgressMetric metric;
  final int first;
  final int latest;
  final int samples;

  int get rawDelta => latest - first;

  /// Positive means "better", regardless of which direction the underlying
  /// number moved. Use this for copy and colour; use [rawDelta] for charts.
  int get improvement => metric.higherIsBetter ? rawDelta : -rawDelta;

  bool get isImproving => improvement > 0;
  bool get isFlat => improvement == 0;

  String get label {
    if (samples < 2) return 'Not enough check-ins yet';
    if (isFlat) return 'Holding steady';
    final String direction = isImproving ? 'better' : 'worse';
    return '${improvement.abs()} ${improvement.abs() == 1 ? 'point' : 'points'} '
        '$direction since you started';
  }
}

abstract final class ProgressAnalytics {
  static int _byWeek(ProgressEntry a, ProgressEntry b) =>
      a.weekStart.compareTo(b.weekStart);

  /// Monday of the week containing [date].
  static DayKey weekStartOf(DateTime date) {
    final DateTime monday = date.subtract(Duration(days: date.weekday - 1));
    return DayKey.fromDate(monday);
  }

  /// Trend per metric across the supplied entries, oldest to newest.
  static List<MetricTrend> trends(List<ProgressEntry> entries) {
    final List<ProgressEntry> sorted = <ProgressEntry>[...entries]
      ..sort(_byWeek);

    return <MetricTrend>[
      for (final ProgressMetric metric in ProgressMetric.values)
        () {
          final List<int> values = <int>[
            for (final ProgressEntry e in sorted)
              if (e.ratingFor(metric) != null) e.ratingFor(metric)!,
          ];
          return MetricTrend(
            metric: metric,
            first: values.isEmpty ? 0 : values.first,
            latest: values.isEmpty ? 0 : values.last,
            samples: values.length,
          );
        }(),
    ];
  }

  /// Series for charting, oldest first. Missing weeks are skipped rather
  /// than zero-filled, which would draw a cliff that never happened.
  static List<(DayKey, int)> series(
    List<ProgressEntry> entries,
    ProgressMetric metric,
  ) {
    final List<ProgressEntry> sorted = <ProgressEntry>[...entries]
      ..sort(_byWeek);
    return <(DayKey, int)>[
      for (final ProgressEntry e in sorted)
        if (e.ratingFor(metric) != null) (e.weekStart, e.ratingFor(metric)!),
    ];
  }

  /// Body-measurement series, useful for the weight and waist charts.
  static List<(DayKey, double)> bodySeries(
    List<HabitLog> logs, {
    required bool waist,
  }) {
    final List<HabitLog> sorted = <HabitLog>[...logs]
      ..sort((HabitLog a, HabitLog b) => a.day.compareTo(b.day));
    return <(DayKey, double)>[
      for (final HabitLog l in sorted)
        if ((waist ? l.waistCm : l.weightKg) != null)
          (l.day, (waist ? l.waistCm : l.weightKg)!),
    ];
  }
}
