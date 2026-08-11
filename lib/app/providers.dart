import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/analytics_service.dart';
import '../core/config/env.dart';
import '../data/remote/remote_sync.dart';
import '../data/repositories/vitalrise_repository.dart';
import '../features/assessment/domain/assessment_models.dart';
import '../features/assessment/domain/assessment_result.dart';
import '../features/assessment/domain/scoring_engine.dart';
import '../features/coach/domain/coach_service.dart';
import '../features/coach/domain/knowledge_base.dart';
import '../features/diet/domain/diet_engine.dart';
import '../features/diet/domain/food.dart';
import '../features/exercises/domain/exercise.dart';
import '../features/exercises/domain/program_builder.dart';
import '../features/exercises/domain/training_program.dart';
import '../features/habits/domain/habit_log.dart';
import '../features/habits/domain/streaks.dart';
import '../features/progress/domain/progress_entry.dart';

/// Overridden in `main()` once the encrypted store has been opened.
final Provider<VitalRiseRepository> repositoryProvider =
    Provider<VitalRiseRepository>(
      (Ref ref) => throw UnimplementedError(
        'repositoryProvider must be overridden in main() with an opened store',
      ),
    );

/// Emits on every sign-in / sign-out so the router can redirect.
final StreamProvider<AuthState?> authStateProvider = StreamProvider<AuthState?>(
  (Ref ref) {
    if (Env.isOfflineDemo) return const Stream<AuthState?>.empty();
    return Supabase.instance.client.auth.onAuthStateChange;
  },
);

final Provider<bool> isSignedInProvider = Provider<bool>((Ref ref) {
  ref.watch(authStateProvider);
  if (Env.isOfflineDemo) return false;
  return Supabase.instance.client.auth.currentUser != null;
});

// ---------------------------------------------------------------------
// Assessment
// ---------------------------------------------------------------------

/// The in-progress intake. Persisted on every answer so a force quit or a
/// phone call never costs the user their place.
class AssessmentDraft extends Notifier<AssessmentResponses> {
  @override
  AssessmentResponses build() => const AssessmentResponses.empty();

  void answer(String questionId, Answer answer) {
    state = state.put(questionId, answer);
    unawaited(ref.read(repositoryProvider).saveDraftResponses(state));
  }

  void restore(AssessmentResponses responses) => state = responses;

  void clear() => state = const AssessmentResponses.empty();

  /// Scores the intake, persists it, and starts the programme clock.
  Future<AssessmentResult> submit() async {
    final AssessmentResult result = AssessmentEngine.evaluate(state);
    final VitalRiseRepository repo = ref.read(repositoryProvider);
    await repo.saveAssessment(state, result);
    if (repo.programStartedOn == null) {
      await repo.setProgramStart(DateTime.now());
    }
    ref.invalidate(assessmentResultProvider);
    unawaited(
      AnalyticsService.instance.log(AnalyticsEvent.assessmentCompleted),
    );
    return result;
  }
}

final NotifierProvider<AssessmentDraft, AssessmentResponses>
assessmentDraftProvider =
    NotifierProvider<AssessmentDraft, AssessmentResponses>(AssessmentDraft.new);

/// The most recent completed assessment, or null if there is none.
final FutureProvider<AssessmentResult?> assessmentResultProvider =
    FutureProvider<AssessmentResult?>(
      (Ref ref) => ref.watch(repositoryProvider).loadResult(),
    );

// ---------------------------------------------------------------------
// Training programme
// ---------------------------------------------------------------------

final FutureProvider<TrainingProgram?> programProvider =
    FutureProvider<TrainingProgram?>((Ref ref) async {
      final AssessmentResult? result = await ref.watch(
        assessmentResultProvider.future,
      );
      if (result == null) return null;
      final VitalRiseRepository repo = ref.watch(repositoryProvider);
      return ProgramBuilder.build(
        result,
        startedOn: repo.programStartedOn ?? result.completedAt,
      );
    });

/// Today's session, or null before an assessment exists.
final FutureProvider<DailySession?> todaySessionProvider =
    FutureProvider<DailySession?>((Ref ref) async {
      final TrainingProgram? program = await ref.watch(programProvider.future);
      return program?.sessionOn(DateTime.now());
    });

// ---------------------------------------------------------------------
// Habits
// ---------------------------------------------------------------------

class HabitController extends AsyncNotifier<List<HabitLog>> {
  @override
  Future<List<HabitLog>> build() =>
      ref.watch(repositoryProvider).loadHabitLogs();

  HabitLog logFor(DayKey day) =>
      state.valueOrNull?.firstWhere(
        (HabitLog l) => l.day == day,
        orElse: () => HabitLog(day: day),
      ) ??
      HabitLog(day: day);

  /// Named [saveLog] rather than `update` because `AsyncNotifier` already
  /// defines an `update` with a different signature.
  Future<void> saveLog(HabitLog log) async {
    final VitalRiseRepository repo = ref.read(repositoryProvider);
    // Optimistic: the UI updates immediately, then persistence catches up.
    final List<HabitLog> current = <HabitLog>[...?state.valueOrNull];
    final int index = current.indexWhere((HabitLog l) => l.day == log.day);
    if (index >= 0) {
      current[index] = log;
    } else {
      current.add(log);
    }
    current.sort((HabitLog a, HabitLog b) => b.day.compareTo(a.day));
    state = AsyncData<List<HabitLog>>(current);
    state = AsyncData<List<HabitLog>>(await repo.upsertHabitLog(log));
  }

  /// Logs one completed exercise.
  ///
  /// Only pelvic floor work increments [HabitLog.kegelSessions], because
  /// that counter is what drives the streak. Counting a bike ride as a
  /// Kegel session would let a man keep a streak alive for weeks without
  /// ever doing the training the streak is meant to reinforce.
  Future<void> logExercise(DayKey day, Exercise exercise) async {
    final HabitLog log = logFor(day);
    final bool isPelvicFloor =
        exercise.category == ExerciseCategory.kegel ||
        exercise.category == ExerciseCategory.reverseKegel;

    await saveLog(
      log.copyWith(
        kegelSessions: log.kegelSessions + (isPelvicFloor ? 1 : 0),
        exerciseMinutes: log.exerciseMinutes + exercise.dosage.estimatedMinutes,
      ),
    );
    unawaited(AnalyticsService.instance.log(AnalyticsEvent.sessionLogged));
  }

  /// Logs a whole prescribed session: one pelvic floor entry plus the
  /// session's total time.
  Future<void> completeSession(DayKey day, {int minutes = 0}) async {
    final HabitLog log = logFor(day);
    await saveLog(
      log.copyWith(
        kegelSessions: log.kegelSessions + 1,
        exerciseMinutes: log.exerciseMinutes + minutes,
      ),
    );
    unawaited(AnalyticsService.instance.log(AnalyticsEvent.sessionLogged));
  }

  Future<void> addWater(DayKey day, int ml) async {
    final HabitLog log = logFor(day);
    await saveLog(log.copyWith(waterMl: (log.waterMl + ml).clamp(0, 10000)));
  }
}

final AsyncNotifierProvider<HabitController, List<HabitLog>>
habitControllerProvider =
    AsyncNotifierProvider<HabitController, List<HabitLog>>(HabitController.new);

final Provider<StreakSummary> streakProvider = Provider<StreakSummary>((
  Ref ref,
) {
  final List<HabitLog> logs =
      ref.watch(habitControllerProvider).valueOrNull ?? const <HabitLog>[];
  return StreakCalculator.summarise(logs);
});

final Provider<List<BadgeStatus>> badgeProvider = Provider<List<BadgeStatus>>((
  Ref ref,
) {
  final List<HabitLog> logs =
      ref.watch(habitControllerProvider).valueOrNull ?? const <HabitLog>[];
  return BadgeCatalog.evaluate(logs);
});

/// Daily targets, derived from the user's own nutrition plan where it
/// exists rather than a hard-coded number.
final Provider<HabitTargets> habitTargetsProvider = Provider<HabitTargets>((
  Ref ref,
) {
  final NutritionTargets? nutrition = ref
      .watch(nutritionTargetsProvider)
      .valueOrNull;
  final DailySession? session = ref.watch(todaySessionProvider).valueOrNull;
  return HabitTargets(
    kegelSessions: 1,
    waterMl: nutrition?.waterMl ?? HabitTargets.fallback.waterMl,
    sleepHours: 7.5,
    exerciseMinutes:
        session?.estimatedMinutes ?? HabitTargets.fallback.exerciseMinutes,
  );
});

// ---------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------

class ProgressController extends AsyncNotifier<List<ProgressEntry>> {
  @override
  Future<List<ProgressEntry>> build() =>
      ref.watch(repositoryProvider).loadProgressEntries();

  Future<void> submit(ProgressEntry entry) async {
    state = AsyncData<List<ProgressEntry>>(
      await ref.read(repositoryProvider).upsertProgressEntry(entry),
    );
    unawaited(
      AnalyticsService.instance.log(AnalyticsEvent.progressCheckInSubmitted),
    );
  }

  ProgressEntry? entryFor(DayKey weekStart) {
    for (final ProgressEntry e
        in state.valueOrNull ?? const <ProgressEntry>[]) {
      if (e.weekStart == weekStart) return e;
    }
    return null;
  }
}

final AsyncNotifierProvider<ProgressController, List<ProgressEntry>>
progressControllerProvider =
    AsyncNotifierProvider<ProgressController, List<ProgressEntry>>(
      ProgressController.new,
    );

final Provider<List<MetricTrend>> trendProvider = Provider<List<MetricTrend>>((
  Ref ref,
) {
  final List<ProgressEntry> entries =
      ref.watch(progressControllerProvider).valueOrNull ??
      const <ProgressEntry>[];
  return ProgressAnalytics.trends(entries);
});

// ---------------------------------------------------------------------
// Diet
// ---------------------------------------------------------------------

class DietPreferencesController extends AsyncNotifier<DietPreferences> {
  @override
  Future<DietPreferences> build() async {
    final VitalRiseRepository repo = ref.watch(repositoryProvider);
    final DietPreferences stored = await repo.loadDietPreferences();

    // Seed sensible defaults from the assessment the first time through, so
    // the user is not asked for information the intake already captured.
    final AssessmentResult? result = await ref.watch(
      assessmentResultProvider.future,
    );
    if (result != null && stored.goal == DietGoal.maintain) {
      return stored.copyWith(goal: DietEngine.suggestGoal(result));
    }
    return stored;
  }

  Future<void> save(DietPreferences prefs) async {
    state = AsyncData<DietPreferences>(prefs);
    await ref.read(repositoryProvider).saveDietPreferences(prefs);
    unawaited(
      AnalyticsService.instance.log(AnalyticsEvent.nutritionPreferencesChanged),
    );
  }
}

final AsyncNotifierProvider<DietPreferencesController, DietPreferences>
dietPreferencesProvider =
    AsyncNotifierProvider<DietPreferencesController, DietPreferences>(
      DietPreferencesController.new,
    );

final FutureProvider<NutritionTargets?> nutritionTargetsProvider =
    FutureProvider<NutritionTargets?>((Ref ref) async {
      final AssessmentResult? result = await ref.watch(
        assessmentResultProvider.future,
      );
      if (result == null) return null;
      final DietPreferences prefs = await ref.watch(
        dietPreferencesProvider.future,
      );
      return DietEngine.targetsFor(
        metrics: result.metrics,
        goal: prefs.goal,
        activity: prefs.activity,
      );
    });

final FutureProvider<List<DailyMealPlan>> mealPlanProvider =
    FutureProvider<List<DailyMealPlan>>((Ref ref) async {
      final NutritionTargets? targets = await ref.watch(
        nutritionTargetsProvider.future,
      );
      if (targets == null) return const <DailyMealPlan>[];
      final DietPreferences prefs = await ref.watch(
        dietPreferencesProvider.future,
      );
      return DietEngine.buildWeek(targets: targets, pattern: prefs.pattern);
    });

// ---------------------------------------------------------------------
// Coach
// ---------------------------------------------------------------------

/// Routes coach questions through the Edge Function when signed in, and
/// through the on-device extractive answer otherwise.
class _RemoteCoachBackend implements CoachBackend {
  const _RemoteCoachBackend(this._remote);

  final RemoteSync _remote;

  @override
  Future<String> complete({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) => _remote.askCoach(
    question: question,
    context: context,
    profile: profile,
    history: history,
  );
}

final Provider<CoachService> coachServiceProvider = Provider<CoachService>((
  Ref ref,
) {
  final RemoteSync remote = ref.watch(repositoryProvider).remote;
  return CoachService(backend: _RemoteCoachBackend(remote));
});

class CoachController extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() =>
      ref.watch(repositoryProvider).loadChatHistory();

  bool _busy = false;
  bool get isResponding => _busy;

  Future<void> send(String text) async {
    final String question = text.trim();
    if (question.isEmpty || _busy) return;
    _busy = true;

    final List<ChatMessage> messages = <ChatMessage>[
      ...?state.valueOrNull,
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        text: question,
        sentAt: DateTime.now(),
      ),
    ];
    state = AsyncData<List<ChatMessage>>(messages);
    unawaited(AnalyticsService.instance.log(AnalyticsEvent.coachQuestionAsked));

    try {
      final AssessmentResult? result = await ref.read(
        assessmentResultProvider.future,
      );
      final TrainingProgram? program = await ref.read(programProvider.future);
      final CoachContext profile = result == null
          ? const CoachContext()
          : CoachContext.fromAssessment(
              result,
              programWeek: program?.weekNumberOn(DateTime.now()),
            );

      final ChatMessage reply = await ref
          .read(coachServiceProvider)
          .ask(question: question, profile: profile, history: messages);
      final List<ChatMessage> updated = <ChatMessage>[...messages, reply];
      state = AsyncData<List<ChatMessage>>(updated);
      await ref.read(repositoryProvider).saveChatHistory(updated);
      if (reply.isError) {
        unawaited(
          AnalyticsService.instance.log(AnalyticsEvent.coachAnsweredOffline),
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> clear() async {
    state = const AsyncData<List<ChatMessage>>(<ChatMessage>[]);
    await ref.read(repositoryProvider).saveChatHistory(const <ChatMessage>[]);
  }
}

final AsyncNotifierProvider<CoachController, List<ChatMessage>>
coachControllerProvider =
    AsyncNotifierProvider<CoachController, List<ChatMessage>>(
      CoachController.new,
    );

// ---------------------------------------------------------------------
// Settings & accessibility
// ---------------------------------------------------------------------

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.highContrast = false,
    this.textScale = 1.0,
  });

  final ThemeMode themeMode;
  final bool highContrast;
  final double textScale;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    double? textScale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    highContrast: highContrast ?? this.highContrast,
    textScale: textScale ?? this.textScale,
  );
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final VitalRiseRepository repo = ref.watch(repositoryProvider);
    return AppSettings(
      themeMode: switch (repo.themePreference) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      highContrast: repo.highContrastPreference,
      textScale: repo.textScalePreference,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(repositoryProvider).setThemePreference(mode.name);
  }

  Future<void> setHighContrast({required bool value}) async {
    state = state.copyWith(highContrast: value);
    await ref.read(repositoryProvider).setHighContrastPreference(value: value);
  }

  Future<void> setTextScale(double scale) async {
    state = state.copyWith(textScale: scale);
    await ref.read(repositoryProvider).setTextScalePreference(scale);
  }
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
