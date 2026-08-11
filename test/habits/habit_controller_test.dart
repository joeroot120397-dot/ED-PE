import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalrise/app/providers.dart';
import 'package:vitalrise/core/security/crypto_box.dart';
import 'package:vitalrise/core/storage/health_store.dart';
import 'package:vitalrise/data/repositories/vitalrise_repository.dart';
import 'package:vitalrise/features/exercises/domain/exercise_library.dart';
import 'package:vitalrise/features/habits/domain/habit_log.dart';
import 'package:vitalrise/features/habits/domain/streaks.dart';
import 'package:vitalrise/features/progress/domain/progress_entry.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final CryptoBox crypto = await CryptoBox.open(InMemoryKeyStore());
  final VitalRiseRepository repo = VitalRiseRepository(
    store: HealthStore(prefs, crypto),
  );

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[repositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('habit logging', () {
    test('a pelvic floor exercise counts toward the streak', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      await container
          .read(habitControllerProvider.notifier)
          .logExercise(DayKey.today(), ExerciseLibrary.byId('kegel_basic'));

      final HabitLog log = container
          .read(habitControllerProvider.notifier)
          .logFor(DayKey.today());
      expect(log.kegelSessions, 1);
      expect(log.countsForStreak, isTrue);
      expect(log.exerciseMinutes, greaterThan(0));
    });

    test(
      'cardio is logged as time but does not count toward the streak',
      () async {
        // The regression this guards: if a bike ride incremented the Kegel
        // counter, a man could hold a 30-day "streak" without ever doing the
        // training the streak exists to reinforce.
        final ProviderContainer container = await _container();
        await container.read(habitControllerProvider.future);

        await container
            .read(habitControllerProvider.notifier)
            .logExercise(DayKey.today(), ExerciseLibrary.byId('cycling'));

        final HabitLog log = container
            .read(habitControllerProvider.notifier)
            .logFor(DayKey.today());
        expect(log.kegelSessions, 0);
        expect(log.countsForStreak, isFalse);
        expect(log.exerciseMinutes, greaterThan(0));
        expect(container.read(streakProvider).current, 0);
      },
    );

    test('a reverse Kegel also counts - it is pelvic floor work', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      await container
          .read(habitControllerProvider.notifier)
          .logExercise(DayKey.today(), ExerciseLibrary.byId('reverse_kegel'));

      expect(container.read(streakProvider).current, 1);
    });

    test('completing a session logs both a session and its time', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      await container
          .read(habitControllerProvider.notifier)
          .completeSession(DayKey.today(), minutes: 25);

      final HabitLog log = container
          .read(habitControllerProvider.notifier)
          .logFor(DayKey.today());
      expect(log.kegelSessions, 1);
      expect(log.exerciseMinutes, 25);
      expect(container.read(streakProvider).completedToday, isTrue);
    });

    test('water accumulates and is clamped to a sane ceiling', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      final HabitController habits = container.read(
        habitControllerProvider.notifier,
      );
      for (int i = 0; i < 4; i++) {
        await habits.addWater(DayKey.today(), 250);
      }
      expect(habits.logFor(DayKey.today()).waterMl, 1000);

      await habits.addWater(DayKey.today(), 999999);
      expect(habits.logFor(DayKey.today()).waterMl, 10000);
    });

    test('logs survive a round trip through the repository', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      await container
          .read(habitControllerProvider.notifier)
          .completeSession(DayKey.today(), minutes: 12);

      // Re-read from storage rather than from the in-memory state.
      final List<HabitLog> reloaded = await container
          .read(repositoryProvider)
          .loadHabitLogs();
      expect(reloaded, hasLength(1));
      expect(reloaded.first.kegelSessions, 1);
      expect(reloaded.first.exerciseMinutes, 12);
    });

    test('badges react to logged sessions', () async {
      final ProviderContainer container = await _container();
      await container.read(habitControllerProvider.future);

      expect(
        container.read(badgeProvider).every((BadgeStatus b) => !b.earned),
        isTrue,
      );

      await container
          .read(habitControllerProvider.notifier)
          .completeSession(DayKey.today());

      expect(
        container
            .read(badgeProvider)
            .firstWhere((BadgeStatus b) => b.badge.id == 'first_rep')
            .earned,
        isTrue,
      );
    });
  });

  group('progress controller', () {
    test('a check-in is persisted and shows up in the trends', () async {
      final ProviderContainer container = await _container();
      await container.read(progressControllerProvider.future);

      final DayKey week = ProgressAnalytics.weekStartOf(DateTime.now());
      await container
          .read(progressControllerProvider.notifier)
          .submit(
            ProgressEntry(
              weekStart: week,
              ratings: <ProgressMetric, int>{
                for (final ProgressMetric m in ProgressMetric.values) m: 6,
              },
            ),
          );

      expect(
        container.read(progressControllerProvider).valueOrNull,
        hasLength(1),
      );
      expect(
        container
            .read(progressControllerProvider.notifier)
            .entryFor(week)
            ?.isComplete,
        isTrue,
      );
    });

    test(
      're-submitting the same week updates rather than duplicating',
      () async {
        final ProviderContainer container = await _container();
        await container.read(progressControllerProvider.future);

        final DayKey week = ProgressAnalytics.weekStartOf(DateTime.now());
        final ProgressController progress = container.read(
          progressControllerProvider.notifier,
        );

        await progress.submit(
          ProgressEntry(
            weekStart: week,
            ratings: const <ProgressMetric, int>{ProgressMetric.confidence: 3},
          ),
        );
        await progress.submit(
          ProgressEntry(
            weekStart: week,
            ratings: const <ProgressMetric, int>{ProgressMetric.confidence: 8},
          ),
        );

        expect(
          container.read(progressControllerProvider).valueOrNull,
          hasLength(1),
        );
        expect(
          progress.entryFor(week)?.ratingFor(ProgressMetric.confidence),
          8,
        );
      },
    );
  });
}
