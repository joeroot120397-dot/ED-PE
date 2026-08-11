import 'package:meta/meta.dart';

import 'exercise.dart';

/// One prescribed exercise inside a session.
@immutable
class ProgramItem {
  const ProgramItem({required this.exercise, required this.dosage, this.note});

  final Exercise exercise;
  final ExerciseDosage dosage;
  final String? note;
}

/// One day of the weekly template. An empty [items] list means a rest day.
@immutable
class DailySession {
  const DailySession({
    required this.dayOfWeek,
    required this.title,
    required this.items,
    this.restNote,
  });

  /// 1 = Monday ... 7 = Sunday, matching `DateTime.weekday`.
  final int dayOfWeek;
  final String title;
  final List<ProgramItem> items;
  final String? restNote;

  bool get isRest => items.isEmpty;

  int get estimatedMinutes => items.fold<int>(
    0,
    (int sum, ProgramItem i) => sum + i.dosage.estimatedMinutes,
  );

  static const List<String> dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get dayName => dayNames[dayOfWeek - 1];
}

/// A block of weeks sharing one weekly template.
@immutable
class ProgramPhase {
  const ProgramPhase({
    required this.index,
    required this.name,
    required this.focus,
    required this.startWeek,
    required this.endWeek,
    required this.week,
  });

  final int index;
  final String name;
  final String focus;
  final int startWeek;
  final int endWeek;

  /// Always 7 entries, Monday first.
  final List<DailySession> week;

  bool covers(int weekNumber) =>
      weekNumber >= startWeek && weekNumber <= endWeek;

  int get weeklyMinutes =>
      week.fold<int>(0, (int s, DailySession d) => s + d.estimatedMinutes);

  int get trainingDays => week.where((DailySession d) => !d.isRest).length;
}

/// A complete personalised programme.
@immutable
class TrainingProgram {
  const TrainingProgram({
    required this.phases,
    required this.rationale,
    required this.startedOn,
  });

  final List<ProgramPhase> phases;

  /// Plain-language explanation of *why* this programme looks like it does,
  /// shown at the top of the plan screen. Users follow plans they understand.
  final String rationale;

  final DateTime startedOn;

  int get totalWeeks => phases.isEmpty ? 0 : phases.last.endWeek;

  /// 1-based week number for [date], clamped to the programme length.
  int weekNumberOn(DateTime date) {
    final int days = date.difference(startedOn).inDays;
    final int week = (days ~/ 7) + 1;
    return week.clamp(1, totalWeeks == 0 ? 1 : totalWeeks);
  }

  ProgramPhase phaseForWeek(int weekNumber) => phases.firstWhere(
    (ProgramPhase p) => p.covers(weekNumber),
    orElse: () => phases.last,
  );

  DailySession sessionOn(DateTime date) {
    final ProgramPhase phase = phaseForWeek(weekNumberOn(date));
    return phase.week[date.weekday - 1];
  }
}
