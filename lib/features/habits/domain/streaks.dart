import 'package:meta/meta.dart';

import 'habit_log.dart';

/// Streak state derived from a set of daily logs.
@immutable
class StreakSummary {
  const StreakSummary({
    required this.current,
    required this.longest,
    required this.totalDays,
    required this.completedToday,
  });

  final int current;
  final int longest;
  final int totalDays;
  final bool completedToday;

  /// True when yesterday counted but today has not been logged yet - the
  /// streak is alive but at risk, which is what we nudge on.
  bool get atRisk => current > 0 && !completedToday;
}

/// Streak and badge computation.
///
/// Deliberately forgiving in one specific way: the streak survives being
/// checked mid-day. A streak is "current" if the most recent qualifying day
/// is today *or* yesterday, so opening the app in the morning does not show
/// a man that he has lost 40 days of work before he has had a chance to
/// train.
abstract final class StreakCalculator {
  static StreakSummary summarise(Iterable<HabitLog> logs, {DayKey? today}) {
    final DayKey now = today ?? DayKey.today();

    final Set<DayKey> qualifying = <DayKey>{
      for (final HabitLog log in logs)
        if (log.countsForStreak) log.day,
    };

    if (qualifying.isEmpty) {
      return const StreakSummary(
        current: 0,
        longest: 0,
        totalDays: 0,
        completedToday: false,
      );
    }

    final bool completedToday = qualifying.contains(now);

    // Walk backwards from today (or yesterday, if today is not logged yet).
    int current = 0;
    DayKey cursor = completedToday ? now : now.addDays(-1);
    while (qualifying.contains(cursor)) {
      current++;
      cursor = cursor.addDays(-1);
    }

    final List<DayKey> sorted = qualifying.toList()..sort();
    int longest = 1;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].differenceInDays(sorted[i - 1]) == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    return StreakSummary(
      current: current,
      longest: longest > current ? longest : current,
      totalDays: qualifying.length,
      completedToday: completedToday,
    );
  }
}

/// An unlockable achievement.
@immutable
class Badge {
  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.threshold,
    required this.kind,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final int threshold;
  final BadgeKind kind;
}

enum BadgeKind { streak, totalDays, sessions, consistency }

/// A badge plus whether the user has earned it.
@immutable
class BadgeStatus {
  const BadgeStatus({
    required this.badge,
    required this.earned,
    required this.progress,
  });

  final Badge badge;
  final bool earned;

  /// 0..1 toward the threshold.
  final double progress;
}

abstract final class BadgeCatalog {
  static const List<Badge> all = <Badge>[
    Badge(
      id: 'first_rep',
      title: 'First contraction',
      description: 'You logged your first pelvic floor session.',
      emoji: '🌱',
      threshold: 1,
      kind: BadgeKind.totalDays,
    ),
    Badge(
      id: 'week_one',
      title: 'Seven straight',
      description: 'A full week without missing a day.',
      emoji: '🔥',
      threshold: 7,
      kind: BadgeKind.streak,
    ),
    Badge(
      id: 'fortnight',
      title: 'Two weeks in',
      description:
          'Fourteen consecutive days. This is where habits start '
          'to run on their own.',
      emoji: '⚡',
      threshold: 14,
      kind: BadgeKind.streak,
    ),
    Badge(
      id: 'month_streak',
      title: 'Thirty days',
      description:
          'A month unbroken. Most men who reach here finish the '
          'programme.',
      emoji: '🏆',
      threshold: 30,
      kind: BadgeKind.streak,
    ),
    Badge(
      id: 'phase_two',
      title: 'Foundation complete',
      description: '28 days of training logged. Phase one is behind you.',
      emoji: '🧱',
      threshold: 28,
      kind: BadgeKind.totalDays,
    ),
    Badge(
      id: 'century',
      title: 'One hundred sessions',
      description: 'A hundred pelvic floor sessions banked.',
      emoji: '💯',
      threshold: 100,
      kind: BadgeKind.sessions,
    ),
    Badge(
      id: 'programme_done',
      title: 'Twelve weeks',
      description: 'You completed the full programme.',
      emoji: '🎖️',
      threshold: 84,
      kind: BadgeKind.totalDays,
    ),
    Badge(
      id: 'consistent',
      title: 'Reliable',
      description: 'Trained on at least 80% of days over the last month.',
      emoji: '📈',
      threshold: 80,
      kind: BadgeKind.consistency,
    ),
  ];

  /// Evaluates every badge against the user's logs.
  static List<BadgeStatus> evaluate(Iterable<HabitLog> logs, {DayKey? today}) {
    final DayKey now = today ?? DayKey.today();
    final StreakSummary streak = StreakCalculator.summarise(logs, today: now);
    final int sessions = logs.fold<int>(
      0,
      (int sum, HabitLog l) => sum + l.kegelSessions,
    );

    final DayKey monthAgo = now.addDays(-29);
    final int recentDays = logs
        .where(
          (HabitLog l) =>
              l.countsForStreak &&
              l.day.compareTo(monthAgo) >= 0 &&
              l.day.compareTo(now) <= 0,
        )
        .length;
    final int consistencyPct = ((recentDays / 30) * 100).round();

    return <BadgeStatus>[
      for (final Badge badge in all)
        () {
          final int value = switch (badge.kind) {
            BadgeKind.streak => streak.longest,
            BadgeKind.totalDays => streak.totalDays,
            BadgeKind.sessions => sessions,
            BadgeKind.consistency => consistencyPct,
          };
          return BadgeStatus(
            badge: badge,
            earned: value >= badge.threshold,
            progress: (value / badge.threshold).clamp(0.0, 1.0),
          );
        }(),
    ];
  }
}
