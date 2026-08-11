import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/features/habits/domain/habit_log.dart';
import 'package:vitalrise/features/habits/domain/streaks.dart';
import 'package:vitalrise/features/progress/domain/progress_entry.dart';

const DayKey _today = DayKey(2026, 6, 15); // a Monday

List<HabitLog> _run(int days, {int endingDaysAgo = 0, int sessions = 1}) =>
    <HabitLog>[
      for (int i = 0; i < days; i++)
        HabitLog(
          day: _today.addDays(-(endingDaysAgo + i)),
          kegelSessions: sessions,
        ),
    ];

void main() {
  group('DayKey', () {
    test('formats and parses ISO dates', () {
      expect(const DayKey(2026, 1, 5).iso, '2026-01-05');
      expect(DayKey.parse('2026-01-05'), const DayKey(2026, 1, 5));
      expect(DayKey.parse('nonsense'), isNull);
    });

    test('arithmetic crosses month and year boundaries', () {
      expect(const DayKey(2026, 1, 31).addDays(1), const DayKey(2026, 2, 1));
      expect(const DayKey(2026, 12, 31).addDays(1), const DayKey(2027, 1, 1));
      expect(const DayKey(2026, 3, 1).addDays(-1), const DayKey(2026, 2, 28));
      expect(
        const DayKey(2026, 3, 10).differenceInDays(const DayKey(2026, 3, 1)),
        9,
      );
    });

    test('equality and ordering behave as value types', () {
      expect(const DayKey(2026, 5, 5), const DayKey(2026, 5, 5));
      expect(
        const DayKey(2026, 5, 5).hashCode,
        const DayKey(2026, 5, 5).hashCode,
      );
      expect(
        const DayKey(2026, 5, 4).compareTo(const DayKey(2026, 5, 5)),
        lessThan(0),
      );
    });
  });

  group('streaks', () {
    test('no logs means no streak', () {
      final StreakSummary s = StreakCalculator.summarise(
        const <HabitLog>[],
        today: _today,
      );
      expect(s.current, 0);
      expect(s.longest, 0);
      expect(s.totalDays, 0);
      expect(s.completedToday, isFalse);
      expect(s.atRisk, isFalse);
    });

    test('counts an unbroken run ending today', () {
      final StreakSummary s = StreakCalculator.summarise(
        _run(5),
        today: _today,
      );
      expect(s.current, 5);
      expect(s.longest, 5);
      expect(s.completedToday, isTrue);
      expect(s.atRisk, isFalse);
    });

    test('a run ending yesterday still counts, and is flagged at risk', () {
      // The forgiveness rule: opening the app in the morning must not show a
      // man that he has already lost his streak.
      final StreakSummary s = StreakCalculator.summarise(
        _run(4, endingDaysAgo: 1),
        today: _today,
      );
      expect(s.current, 4);
      expect(s.completedToday, isFalse);
      expect(s.atRisk, isTrue);
    });

    test('a gap of two days breaks the current streak', () {
      final StreakSummary s = StreakCalculator.summarise(
        _run(4, endingDaysAgo: 2),
        today: _today,
      );
      expect(s.current, 0);
      expect(s.longest, 4);
      expect(s.atRisk, isFalse);
    });

    test('the longest run is remembered across gaps', () {
      final List<HabitLog> logs = <HabitLog>[
        ..._run(2), // today and yesterday
        ..._run(9, endingDaysAgo: 10), // an older, longer run
      ];
      final StreakSummary s = StreakCalculator.summarise(logs, today: _today);
      expect(s.current, 2);
      expect(s.longest, 9);
      expect(s.totalDays, 11);
    });

    test('days with no Kegel session do not count toward a streak', () {
      final List<HabitLog> logs = <HabitLog>[
        const HabitLog(day: _today, waterMl: 2000),
        HabitLog(day: _today.addDays(-1), sleepHours: 8),
      ];
      final StreakSummary s = StreakCalculator.summarise(logs, today: _today);
      expect(s.current, 0);
      expect(s.totalDays, 0);
    });

    test('duplicate days are not double counted', () {
      final List<HabitLog> logs = <HabitLog>[
        const HabitLog(day: _today, kegelSessions: 1),
        const HabitLog(day: _today, kegelSessions: 3),
      ];
      expect(StreakCalculator.summarise(logs, today: _today).totalDays, 1);
    });
  });

  group('badges', () {
    test('nothing is earned with no history', () {
      final List<BadgeStatus> badges = BadgeCatalog.evaluate(
        const <HabitLog>[],
        today: _today,
      );
      expect(badges, hasLength(BadgeCatalog.all.length));
      expect(badges.every((BadgeStatus b) => !b.earned), isTrue);
      expect(badges.every((BadgeStatus b) => b.progress == 0), isTrue);
    });

    test('the first session unlocks the first badge only', () {
      final List<BadgeStatus> badges = BadgeCatalog.evaluate(
        _run(1),
        today: _today,
      );
      final Iterable<String> earned = badges
          .where((BadgeStatus b) => b.earned)
          .map((BadgeStatus b) => b.badge.id);
      expect(earned, <String>['first_rep']);
    });

    test('a seven day run unlocks the week badge', () {
      final List<BadgeStatus> badges = BadgeCatalog.evaluate(
        _run(7),
        today: _today,
      );
      expect(
        badges.firstWhere((BadgeStatus b) => b.badge.id == 'week_one').earned,
        isTrue,
      );
      expect(
        badges
            .firstWhere((BadgeStatus b) => b.badge.id == 'month_streak')
            .earned,
        isFalse,
      );
    });

    test('progress toward an unearned badge is proportional', () {
      final BadgeStatus month = BadgeCatalog.evaluate(
        _run(15),
        today: _today,
      ).firstWhere((BadgeStatus b) => b.badge.id == 'month_streak');
      expect(month.earned, isFalse);
      expect(month.progress, closeTo(0.5, 0.01));
    });

    test('the session badge counts sessions, not days', () {
      final BadgeStatus century = BadgeCatalog.evaluate(
        _run(30, sessions: 4),
        today: _today,
      ).firstWhere((BadgeStatus b) => b.badge.id == 'century');
      expect(century.earned, isTrue);
    });

    test('consistency uses the last 30 days only', () {
      // 25 of the last 30 days is above the 80% threshold.
      final BadgeStatus recent = BadgeCatalog.evaluate(
        _run(25),
        today: _today,
      ).firstWhere((BadgeStatus b) => b.badge.id == 'consistent');
      expect(recent.earned, isTrue);

      // The same 25 days, but a year ago, must not count.
      final BadgeStatus stale = BadgeCatalog.evaluate(
        _run(25, endingDaysAgo: 365),
        today: _today,
      ).firstWhere((BadgeStatus b) => b.badge.id == 'consistent');
      expect(stale.earned, isFalse);
    });

    test('badge ids are unique', () {
      final Set<String> ids = BadgeCatalog.all.map((Badge b) => b.id).toSet();
      expect(ids.length, BadgeCatalog.all.length);
    });
  });

  group('progress analytics', () {
    ProgressEntry entry(DayKey week, Map<ProgressMetric, int> ratings) =>
        ProgressEntry(weekStart: week, ratings: ratings);

    test('week start is always the Monday', () {
      // 17 June 2026 is a Wednesday.
      expect(
        ProgressAnalytics.weekStartOf(DateTime(2026, 6, 17)),
        const DayKey(2026, 6, 15),
      );
      expect(
        ProgressAnalytics.weekStartOf(DateTime(2026, 6, 21)), // Sunday
        const DayKey(2026, 6, 15),
      );
    });

    test('improvement is measured in the right direction per metric', () {
      final List<ProgressEntry> entries = <ProgressEntry>[
        entry(const DayKey(2026, 6, 1), <ProgressMetric, int>{
          ProgressMetric.erectionQuality: 4,
          ProgressMetric.stressLevel: 8,
        }),
        entry(const DayKey(2026, 6, 8), <ProgressMetric, int>{
          ProgressMetric.erectionQuality: 7,
          ProgressMetric.stressLevel: 3,
        }),
      ];

      final List<MetricTrend> trends = ProgressAnalytics.trends(entries);
      final MetricTrend erection = trends.firstWhere(
        (MetricTrend t) => t.metric == ProgressMetric.erectionQuality,
      );
      final MetricTrend stress = trends.firstWhere(
        (MetricTrend t) => t.metric == ProgressMetric.stressLevel,
      );

      expect(erection.rawDelta, 3);
      expect(erection.improvement, 3);
      expect(erection.isImproving, isTrue);

      // Stress fell by 5, which is an improvement of 5 - not -5.
      expect(stress.rawDelta, -5);
      expect(stress.improvement, 5);
      expect(stress.isImproving, isTrue);
      expect(stress.label, contains('better'));
    });

    test('entries are sorted before trends are computed', () {
      final List<ProgressEntry> outOfOrder = <ProgressEntry>[
        entry(const DayKey(2026, 6, 8), <ProgressMetric, int>{
          ProgressMetric.energyLevel: 8,
        }),
        entry(const DayKey(2026, 6, 1), <ProgressMetric, int>{
          ProgressMetric.energyLevel: 3,
        }),
      ];
      final MetricTrend t = ProgressAnalytics.trends(
        outOfOrder,
      ).firstWhere((MetricTrend t) => t.metric == ProgressMetric.energyLevel);
      expect(t.first, 3);
      expect(t.latest, 8);
    });

    test('a single check-in reports as not enough data', () {
      final MetricTrend t = ProgressAnalytics.trends(<ProgressEntry>[
        entry(const DayKey(2026, 6, 1), <ProgressMetric, int>{
          ProgressMetric.confidence: 5,
        }),
      ]).firstWhere((MetricTrend t) => t.metric == ProgressMetric.confidence);
      expect(t.samples, 1);
      expect(t.label, 'Not enough check-ins yet');
    });

    test('series skips missing weeks rather than zero-filling them', () {
      final List<(DayKey, int)> series = ProgressAnalytics.series(
        <ProgressEntry>[
          entry(const DayKey(2026, 6, 1), <ProgressMetric, int>{
            ProgressMetric.confidence: 5,
          }),
          entry(const DayKey(2026, 6, 8), <ProgressMetric, int>{}),
          entry(const DayKey(2026, 6, 15), <ProgressMetric, int>{
            ProgressMetric.confidence: 7,
          }),
        ],
        ProgressMetric.confidence,
      );
      expect(series, hasLength(2));
      expect(series.map(((DayKey, int) e) => e.$2), <int>[5, 7]);
    });

    test('body series filters out days with no measurement', () {
      final List<HabitLog> logs = <HabitLog>[
        const HabitLog(day: DayKey(2026, 6, 1), weightKg: 90),
        const HabitLog(day: DayKey(2026, 6, 2), kegelSessions: 1),
        const HabitLog(day: DayKey(2026, 6, 3), weightKg: 89),
      ];
      expect(ProgressAnalytics.bodySeries(logs, waist: false), hasLength(2));
      expect(ProgressAnalytics.bodySeries(logs, waist: true), isEmpty);
    });

    test('a progress entry survives a JSON round trip', () {
      final ProgressEntry original = ProgressEntry(
        weekStart: const DayKey(2026, 6, 15),
        ratings: <ProgressMetric, int>{
          for (final ProgressMetric m in ProgressMetric.values) m: 6,
        },
        weightKg: 84.5,
        note: 'better week',
      );
      final ProgressEntry restored = ProgressEntry.fromJson(original.toJson());
      expect(restored.weekStart, original.weekStart);
      expect(restored.isComplete, isTrue);
      expect(restored.weightKg, 84.5);
      expect(restored.note, 'better week');
    });

    test('a habit log survives a JSON round trip', () {
      const HabitLog original = HabitLog(
        day: DayKey(2026, 6, 15),
        kegelSessions: 2,
        waterMl: 2500,
        sleepHours: 7.5,
        exerciseMinutes: 30,
        weightKg: 82.4,
        waistCm: 91,
      );
      final HabitLog restored = HabitLog.fromJson(original.toJson());
      expect(restored.day, original.day);
      expect(restored.kegelSessions, 2);
      expect(restored.waterMl, 2500);
      expect(restored.sleepHours, 7.5);
      expect(restored.weightKg, 82.4);
      expect(restored.countsForStreak, isTrue);
    });
  });
}
