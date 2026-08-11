import 'package:meta/meta.dart';

import '../../core/storage/health_store.dart';
import '../../features/assessment/domain/assessment_models.dart';
import '../../features/assessment/domain/assessment_result.dart';
import '../../features/coach/domain/coach_service.dart';
import '../../features/diet/domain/diet_engine.dart';
import '../../features/diet/domain/food.dart';
import '../../features/habits/domain/habit_log.dart';
import '../../features/progress/domain/progress_entry.dart';
import '../remote/remote_sync.dart';

/// The user's nutrition preferences.
@immutable
class DietPreferences {
  const DietPreferences({
    required this.pattern,
    required this.goal,
    required this.activity,
  });

  static const DietPreferences fallback = DietPreferences(
    pattern: DietPattern.nonVegetarian,
    goal: DietGoal.maintain,
    activity: ActivityLevel.sedentary,
  );

  final DietPattern pattern;
  final DietGoal goal;
  final ActivityLevel activity;

  DietPreferences copyWith({
    DietPattern? pattern,
    DietGoal? goal,
    ActivityLevel? activity,
  }) => DietPreferences(
    pattern: pattern ?? this.pattern,
    goal: goal ?? this.goal,
    activity: activity ?? this.activity,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pattern': pattern.name,
    'goal': goal.name,
    'activity': activity.name,
  };

  static DietPreferences fromJson(Map<String, dynamic> json) => DietPreferences(
    pattern: _enumByName(
      DietPattern.values,
      json['pattern'],
      DietPattern.nonVegetarian,
    ),
    goal: _enumByName(DietGoal.values, json['goal'], DietGoal.maintain),
    activity: _enumByName(
      ActivityLevel.values,
      json['activity'],
      ActivityLevel.sedentary,
    ),
  );
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final T v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Offline-first persistence for everything the user owns.
///
/// Reads always come from the encrypted local store, so the app is instant
/// and works on a train. Writes go local first and are then pushed to
/// Supabase; a failed push is swallowed rather than surfaced, because
/// losing connectivity should never block a man from logging a Kegel. The
/// next successful [syncDown] reconciles.
class VitalRiseRepository {
  VitalRiseRepository({
    required this.store,
    this.remote = const NoopRemoteSync(),
  });

  final HealthStore store;
  final RemoteSync remote;

  // ---- Onboarding flags ---------------------------------------------

  bool get hasSeenOnboarding => store.getFlag('onboarding_complete');

  Future<void> markOnboardingSeen() =>
      store.setFlag('onboarding_complete', value: true);

  bool get hasAcceptedDisclaimer => store.getFlag('disclaimer_accepted');

  Future<void> acceptDisclaimer() =>
      store.setFlag('disclaimer_accepted', value: true);

  // ---- Assessment -----------------------------------------------------

  Future<AssessmentResponses?> loadResponses() async {
    final Map<String, dynamic>? json = await store.readJson(
      HealthStore.kResponses,
    );
    return json == null ? null : AssessmentResponses.fromJson(json);
  }

  Future<AssessmentResult?> loadResult() async {
    final Map<String, dynamic>? json = await store.readJson(
      HealthStore.kResult,
    );
    return json == null ? null : AssessmentResult.fromJson(json);
  }

  Future<void> saveAssessment(
    AssessmentResponses responses,
    AssessmentResult result,
  ) async {
    await store.writeJson(HealthStore.kResponses, responses.toJson());
    await store.writeJson(HealthStore.kResult, result.toJson());
    await _push(
      () => remote.saveAssessment(
        responses: responses.toJson(),
        result: result.toJson(),
      ),
    );
  }

  /// Saves partial answers so a half-finished intake survives a force quit.
  Future<void> saveDraftResponses(AssessmentResponses responses) =>
      store.writeJson(HealthStore.kResponses, responses.toJson());

  // ---- Programme ------------------------------------------------------

  DateTime? get programStartedOn {
    final String? raw = store.getString(HealthStore.kProgramStart);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setProgramStart(DateTime date) => store.setString(
    HealthStore.kProgramStart,
    DateTime(date.year, date.month, date.day).toIso8601String(),
  );

  // ---- Habits ---------------------------------------------------------

  Future<List<HabitLog>> loadHabitLogs() async {
    final List<Map<String, dynamic>> raw = await store.readJsonList(
      HealthStore.kHabitLogs,
    );
    return raw.map(HabitLog.fromJson).toList();
  }

  Future<void> saveHabitLogs(List<HabitLog> logs) async {
    final List<Map<String, dynamic>> json = logs
        .map((HabitLog l) => l.toJson())
        .toList();
    await store.writeJsonList(HealthStore.kHabitLogs, json);
    await _push(() => remote.upsertHabitLogs(json));
  }

  /// Inserts or replaces the log for one day and returns the new list.
  Future<List<HabitLog>> upsertHabitLog(HabitLog log) async {
    final List<HabitLog> logs = await loadHabitLogs();
    final int index = logs.indexWhere((HabitLog l) => l.day == log.day);
    if (index >= 0) {
      logs[index] = log;
    } else {
      logs.add(log);
    }
    logs.sort((HabitLog a, HabitLog b) => b.day.compareTo(a.day));
    await saveHabitLogs(logs);
    return logs;
  }

  // ---- Progress -------------------------------------------------------

  Future<List<ProgressEntry>> loadProgressEntries() async {
    final List<Map<String, dynamic>> raw = await store.readJsonList(
      HealthStore.kProgressEntries,
    );
    return raw.map(ProgressEntry.fromJson).toList();
  }

  Future<List<ProgressEntry>> upsertProgressEntry(ProgressEntry entry) async {
    final List<ProgressEntry> entries = await loadProgressEntries();
    final int index = entries.indexWhere(
      (ProgressEntry e) => e.weekStart == entry.weekStart,
    );
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
    entries.sort(
      (ProgressEntry a, ProgressEntry b) => b.weekStart.compareTo(a.weekStart),
    );

    final List<Map<String, dynamic>> json = entries
        .map((ProgressEntry e) => e.toJson())
        .toList();
    await store.writeJsonList(HealthStore.kProgressEntries, json);
    await _push(() => remote.upsertProgressEntries(json));
    return entries;
  }

  // ---- Diet -----------------------------------------------------------

  Future<DietPreferences> loadDietPreferences() async {
    final Map<String, dynamic>? json = await store.readJson(
      HealthStore.kDietPreferences,
    );
    return json == null
        ? DietPreferences.fallback
        : DietPreferences.fromJson(json);
  }

  Future<void> saveDietPreferences(DietPreferences prefs) =>
      store.writeJson(HealthStore.kDietPreferences, prefs.toJson());

  // ---- Coach ----------------------------------------------------------

  Future<List<ChatMessage>> loadChatHistory() async {
    final List<Map<String, dynamic>> raw = await store.readJsonList(
      HealthStore.kChatHistory,
    );
    return raw.map(ChatMessage.fromJson).toList();
  }

  /// Chat stays on device. It is the most sensitive text in the product and
  /// it has no feature that needs it server-side.
  Future<void> saveChatHistory(List<ChatMessage> messages) {
    const int keep = 100;
    final List<ChatMessage> trimmed = messages.length <= keep
        ? messages
        : messages.sublist(messages.length - keep);
    return store.writeJsonList(
      HealthStore.kChatHistory,
      trimmed.map((ChatMessage m) => m.toJson()).toList(),
    );
  }

  // ---- Settings -------------------------------------------------------
  //
  // Stored unencrypted on purpose: they are not health data, and the first
  // frame needs them before the keystore is available.

  String get themePreference => store.getString('theme_mode') ?? 'system';

  Future<void> setThemePreference(String mode) =>
      store.setString('theme_mode', mode);

  bool get highContrastPreference => store.getFlag('high_contrast');

  Future<void> setHighContrastPreference({required bool value}) =>
      store.setFlag('high_contrast', value: value);

  double get textScalePreference =>
      double.tryParse(store.getString('text_scale') ?? '')?.clamp(0.8, 2.0) ??
      1.0;

  Future<void> setTextScalePreference(double scale) =>
      store.setString('text_scale', scale.toStringAsFixed(2));

  /// Registers this device for reminder notifications.
  ///
  /// The token goes to `profiles`, which deliberately holds no health data,
  /// so the reminder job can read it without touching anything sensitive.
  Future<void> registerForReminders({
    required String? pushToken,
    int reminderHour = 19,
  }) async {
    if (pushToken == null || pushToken.isEmpty) return;
    await _push(
      () => remote.upsertProfile(<String, dynamic>{
        'push_token': pushToken,
        'reminder_hour': reminderHour,
        'reminders_on': true,
      }),
    );
  }

  // ---- Sync & deletion ------------------------------------------------

  /// Pulls server state into the local store. Called after sign-in so a
  /// user who reinstalls gets their history back.
  Future<void> syncDown() async {
    if (!remote.isAvailable) return;
    try {
      final Map<String, dynamic>? assessment = await remote
          .fetchLatestAssessment();
      if (assessment != null) {
        final Object? responses = assessment['responses'];
        final Object? result = assessment['result'];
        if (responses is Map<String, dynamic>) {
          await store.writeJson(HealthStore.kResponses, responses);
        }
        if (result is Map<String, dynamic>) {
          await store.writeJson(HealthStore.kResult, result);
        }
      }

      final List<Map<String, dynamic>> habits = await remote.fetchHabitLogs();
      if (habits.isNotEmpty) {
        await store.writeJsonList(HealthStore.kHabitLogs, habits);
      }

      final List<Map<String, dynamic>> progress = await remote
          .fetchProgressEntries();
      if (progress.isNotEmpty) {
        await store.writeJsonList(HealthStore.kProgressEntries, progress);
      }
    } on Object {
      // A failed sync leaves local data untouched, which is the safe
      // outcome. The next launch tries again.
    }
  }

  /// Pushes everything held locally. Used after sign-in on a device that
  /// already has data, so nothing recorded while signed out is lost.
  Future<void> syncUp() async {
    if (!remote.isAvailable) return;
    try {
      final AssessmentResponses? responses = await loadResponses();
      final AssessmentResult? result = await loadResult();
      if (responses != null && result != null) {
        await remote.saveAssessment(
          responses: responses.toJson(),
          result: result.toJson(),
        );
      }
      await remote.upsertHabitLogs(
        (await loadHabitLogs()).map((HabitLog l) => l.toJson()).toList(),
      );
      await remote.upsertProgressEntries(
        (await loadProgressEntries())
            .map((ProgressEntry e) => e.toJson())
            .toList(),
      );
    } on Object {
      // Same reasoning as syncDown.
    }
  }

  /// Erases local data and asks the server to erase its copy.
  Future<void> deleteEverything() async {
    await _push(remote.deleteAllData);
    await store.clearAll();
  }

  Future<void> _push(Future<void> Function() action) async {
    if (!remote.isAvailable) return;
    try {
      await action();
    } on Object {
      // Deliberately swallowed - see the class doc. Local write already
      // succeeded, so the user's data is safe and sync will retry.
    }
  }
}
