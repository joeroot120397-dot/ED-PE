import 'package:meta/meta.dart';

/// A calendar day with no time component, used as the key for daily logs.
@immutable
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  DayKey.fromDate(DateTime date)
    : year = date.year,
      month = date.month,
      day = date.day;

  static DayKey today() => DayKey.fromDate(DateTime.now());

  final int year;
  final int month;
  final int day;

  DateTime get date => DateTime(year, month, day);

  DayKey addDays(int days) => DayKey.fromDate(date.add(Duration(days: days)));

  int differenceInDays(DayKey other) => date.difference(other.date).inDays;

  /// ISO-8601 date, e.g. `2026-03-09`. This is the Postgres `date` format
  /// and the storage key, so it must stay stable.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  static DayKey? parse(String value) {
    final DateTime? d = DateTime.tryParse(value);
    return d == null ? null : DayKey.fromDate(d);
  }

  @override
  int compareTo(DayKey other) => date.compareTo(other.date);

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}

/// One day of habit tracking.
@immutable
class HabitLog {
  const HabitLog({
    required this.day,
    this.kegelSessions = 0,
    this.waterMl = 0,
    this.sleepHours,
    this.exerciseMinutes = 0,
    this.weightKg,
    this.waistCm,
    this.note,
  });

  final DayKey day;
  final int kegelSessions;
  final int waterMl;
  final double? sleepHours;
  final int exerciseMinutes;
  final double? weightKg;
  final double? waistCm;
  final String? note;

  /// A day counts toward a streak once the pelvic floor work is done. That
  /// is the non-negotiable habit; everything else is supporting cast.
  bool get countsForStreak => kegelSessions > 0;

  bool get isEmpty =>
      kegelSessions == 0 &&
      waterMl == 0 &&
      sleepHours == null &&
      exerciseMinutes == 0 &&
      weightKg == null &&
      waistCm == null &&
      (note == null || note!.isEmpty);

  HabitLog copyWith({
    int? kegelSessions,
    int? waterMl,
    double? sleepHours,
    int? exerciseMinutes,
    double? weightKg,
    double? waistCm,
    String? note,
  }) => HabitLog(
    day: day,
    kegelSessions: kegelSessions ?? this.kegelSessions,
    waterMl: waterMl ?? this.waterMl,
    sleepHours: sleepHours ?? this.sleepHours,
    exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
    weightKg: weightKg ?? this.weightKg,
    waistCm: waistCm ?? this.waistCm,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day.iso,
    'kegel_sessions': kegelSessions,
    'water_ml': waterMl,
    'sleep_hours': sleepHours,
    'exercise_minutes': exerciseMinutes,
    'weight_kg': weightKg,
    'waist_cm': waistCm,
    'note': note,
  };

  static HabitLog fromJson(Map<String, dynamic> json) => HabitLog(
    day: DayKey.parse(json['day'] as String? ?? '') ?? DayKey.today(),
    kegelSessions: (json['kegel_sessions'] as num?)?.toInt() ?? 0,
    waterMl: (json['water_ml'] as num?)?.toInt() ?? 0,
    sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
    exerciseMinutes: (json['exercise_minutes'] as num?)?.toInt() ?? 0,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    waistCm: (json['waist_cm'] as num?)?.toDouble(),
    note: json['note'] as String?,
  );
}

/// Daily targets the tracker measures against.
@immutable
class HabitTargets {
  const HabitTargets({
    required this.kegelSessions,
    required this.waterMl,
    required this.sleepHours,
    required this.exerciseMinutes,
  });

  static const HabitTargets fallback = HabitTargets(
    kegelSessions: 1,
    waterMl: 2600,
    sleepHours: 7.5,
    exerciseMinutes: 30,
  );

  final int kegelSessions;
  final int waterMl;
  final double sleepHours;
  final int exerciseMinutes;
}
