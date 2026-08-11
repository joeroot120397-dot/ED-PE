import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalrise/core/security/crypto_box.dart';
import 'package:vitalrise/core/storage/health_store.dart';
import 'package:vitalrise/data/remote/remote_sync.dart';
import 'package:vitalrise/data/repositories/vitalrise_repository.dart';
import 'package:vitalrise/features/assessment/domain/assessment_models.dart';
import 'package:vitalrise/features/assessment/domain/assessment_result.dart';
import 'package:vitalrise/features/assessment/domain/scoring_engine.dart';
import 'package:vitalrise/features/coach/domain/coach_service.dart';
import 'package:vitalrise/features/coach/domain/knowledge_base.dart';
import 'package:vitalrise/features/diet/domain/diet_engine.dart';
import 'package:vitalrise/features/diet/domain/food.dart';
import 'package:vitalrise/features/habits/domain/habit_log.dart';
import 'package:vitalrise/features/progress/domain/progress_entry.dart';

import '../support/answer_builder.dart';

/// A backend that is reachable but fails every call - the realistic
/// failure, and the one that must never cost a user their data.
class _FailingRemote implements RemoteSync {
  int attempts = 0;

  @override
  bool get isAvailable => true;

  @override
  String? get userId => 'user-1';

  Never _fail() {
    attempts++;
    throw StateError('backend down');
  }

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async => _fail();

  @override
  Future<Map<String, dynamic>?> fetchProfile() async => _fail();

  @override
  Future<void> saveAssessment({
    required Map<String, dynamic> responses,
    required Map<String, dynamic> result,
  }) async => _fail();

  @override
  Future<Map<String, dynamic>?> fetchLatestAssessment() async => _fail();

  @override
  Future<void> upsertHabitLogs(List<Map<String, dynamic>> logs) async =>
      _fail();

  @override
  Future<List<Map<String, dynamic>>> fetchHabitLogs() async => _fail();

  @override
  Future<void> upsertProgressEntries(
    List<Map<String, dynamic>> entries,
  ) async => _fail();

  @override
  Future<List<Map<String, dynamic>>> fetchProgressEntries() async => _fail();

  @override
  Future<String> askCoach({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) async => _fail();

  @override
  Future<void> deleteAllData() async => _fail();
}

/// Records what was pushed, so sync behaviour can be asserted.
class _RecordingRemote implements NoopRemoteSync {
  final List<Map<String, dynamic>> habitPushes = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> assessmentPushes = <Map<String, dynamic>>[];
  Map<String, dynamic>? profilePush;

  @override
  bool get isAvailable => true;

  @override
  String? get userId => 'user-1';

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async =>
      profilePush = profile;

  @override
  Future<Map<String, dynamic>?> fetchProfile() async => null;

  @override
  Future<void> saveAssessment({
    required Map<String, dynamic> responses,
    required Map<String, dynamic> result,
  }) async => assessmentPushes.add(result);

  @override
  Future<Map<String, dynamic>?> fetchLatestAssessment() async => null;

  @override
  Future<void> upsertHabitLogs(List<Map<String, dynamic>> logs) async =>
      habitPushes.addAll(logs);

  @override
  Future<List<Map<String, dynamic>>> fetchHabitLogs() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<void> upsertProgressEntries(
    List<Map<String, dynamic>> entries,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchProgressEntries() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<String> askCoach({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) => throw const RemoteUnavailable();

  @override
  Future<void> deleteAllData() async {}
}

Future<HealthStore> _store() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return HealthStore(prefs, await CryptoBox.open(InMemoryKeyStore()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('offline-first writes', () {
    test('a local write succeeds even when every remote call fails', () async {
      // The central design promise: losing signal must never stop a man
      // logging a session.
      final _FailingRemote remote = _FailingRemote();
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
        remote: remote,
      );

      final AssessmentResponses responses = AnswerBuilder.severe();
      final AssessmentResult result = AssessmentEngine.evaluate(responses);

      await expectLater(repo.saveAssessment(responses, result), completes);
      await expectLater(
        repo.upsertHabitLog(HabitLog(day: DayKey.today(), kegelSessions: 1)),
        completes,
      );

      // The data is readable locally despite the backend being down.
      expect(
        (await repo.loadResult())?.scores.edRiskScore,
        result.scores.edRiskScore,
      );
      expect(await repo.loadHabitLogs(), hasLength(1));
      expect(remote.attempts, greaterThan(0), reason: 'it did try');
    });

    test('a failed sync leaves local data untouched', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
        remote: _FailingRemote(),
      );

      await repo.upsertHabitLog(
        HabitLog(day: DayKey.today(), kegelSessions: 3),
      );

      await expectLater(repo.syncDown(), completes);
      await expectLater(repo.syncUp(), completes);

      final List<HabitLog> logs = await repo.loadHabitLogs();
      expect(logs, hasLength(1));
      expect(logs.first.kegelSessions, 3);
    });

    test('nothing is pushed when no backend is configured', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
      );

      expect(repo.remote.isAvailable, isFalse);
      await expectLater(repo.syncUp(), completes);
      await expectLater(repo.syncDown(), completes);
      await repo.upsertHabitLog(
        HabitLog(day: DayKey.today(), kegelSessions: 1),
      );
      expect(await repo.loadHabitLogs(), hasLength(1));
    });

    test('writes reach the backend when it is healthy', () async {
      final _RecordingRemote remote = _RecordingRemote();
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
        remote: remote,
      );

      await repo.saveAssessment(
        AnswerBuilder.healthy(),
        AssessmentEngine.evaluate(AnswerBuilder.healthy()),
      );
      await repo.upsertHabitLog(
        HabitLog(day: DayKey.today(), kegelSessions: 2),
      );

      expect(remote.assessmentPushes, hasLength(1));
      expect(remote.habitPushes, hasLength(1));
      expect(remote.habitPushes.first['kegel_sessions'], 2);
    });

    test('reminder registration only fires with a real token', () async {
      final _RecordingRemote remote = _RecordingRemote();
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
        remote: remote,
      );

      await repo.registerForReminders(pushToken: null);
      expect(remote.profilePush, isNull);

      await repo.registerForReminders(pushToken: '', reminderHour: 8);
      expect(remote.profilePush, isNull);

      await repo.registerForReminders(pushToken: 'tok-123', reminderHour: 8);
      expect(remote.profilePush?['push_token'], 'tok-123');
      expect(remote.profilePush?['reminder_hour'], 8);
      expect(remote.profilePush?['reminders_on'], isTrue);
    });
  });

  group('persistence', () {
    test('everything round-trips through the encrypted store', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
      );

      await repo.saveAssessment(
        AnswerBuilder.severe(),
        AssessmentEngine.evaluate(AnswerBuilder.severe()),
      );
      await repo.saveDietPreferences(
        const DietPreferences(
          pattern: DietPattern.vegan,
          goal: DietGoal.edSupport,
          activity: ActivityLevel.high,
        ),
      );
      await repo.upsertProgressEntry(
        ProgressEntry(
          weekStart: ProgressAnalytics.weekStartOf(DateTime.now()),
          ratings: const <ProgressMetric, int>{ProgressMetric.confidence: 7},
        ),
      );
      await repo.saveChatHistory(<ChatMessage>[
        ChatMessage(
          id: 'a',
          role: ChatRole.user,
          text: 'how do I do kegels',
          sentAt: DateTime.utc(2026, 5, 1),
        ),
      ]);

      expect((await repo.loadResponses())?.choice('b_achieve'), 'never');
      expect((await repo.loadDietPreferences()).pattern, DietPattern.vegan);
      expect((await repo.loadDietPreferences()).goal, DietGoal.edSupport);
      expect(await repo.loadProgressEntries(), hasLength(1));
      expect((await repo.loadChatHistory()).first.text, 'how do I do kegels');
    });

    test('chat history is capped so it cannot grow without bound', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
      );

      await repo.saveChatHistory(<ChatMessage>[
        for (int i = 0; i < 250; i++)
          ChatMessage(
            id: '$i',
            role: i.isEven ? ChatRole.user : ChatRole.coach,
            text: 'message $i',
            sentAt: DateTime.utc(2026, 5, 1),
          ),
      ]);

      final List<ChatMessage> stored = await repo.loadChatHistory();
      expect(stored, hasLength(100));
      // The most recent turns are what survive, not the oldest.
      expect(stored.last.text, 'message 249');
    });

    test('an unfinished intake is preserved as a draft', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
      );

      await repo.saveDraftResponses(
        AnswerBuilder().choose('b_achieve', 'few').build(),
      );

      expect((await repo.loadResponses())?.choice('b_achieve'), 'few');
      // A draft is not a completed assessment.
      expect(await repo.loadResult(), isNull);
    });

    test('deleting erases everything locally', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
      );

      await repo.markOnboardingSeen();
      await repo.saveAssessment(
        AnswerBuilder.severe(),
        AssessmentEngine.evaluate(AnswerBuilder.severe()),
      );
      await repo.upsertHabitLog(
        HabitLog(day: DayKey.today(), kegelSessions: 5),
      );

      await repo.deleteEverything();

      expect(await repo.loadResult(), isNull);
      expect(await repo.loadResponses(), isNull);
      expect(await repo.loadHabitLogs(), isEmpty);
      expect(await repo.loadProgressEntries(), isEmpty);
      expect(await repo.loadChatHistory(), isEmpty);
      expect(repo.hasSeenOnboarding, isFalse);
      expect(repo.programStartedOn, isNull);
    });

    test('deletion still clears locally when the backend refuses', () async {
      final VitalRiseRepository repo = VitalRiseRepository(
        store: await _store(),
        remote: _FailingRemote(),
      );
      await repo.upsertHabitLog(
        HabitLog(day: DayKey.today(), kegelSessions: 1),
      );

      await expectLater(repo.deleteEverything(), completes);
      expect(await repo.loadHabitLogs(), isEmpty);
    });

    test('settings persist and survive a reload', () async {
      final HealthStore store = await _store();
      final VitalRiseRepository repo = VitalRiseRepository(store: store);

      expect(repo.themePreference, 'system');
      expect(repo.highContrastPreference, isFalse);
      expect(repo.textScalePreference, 1.0);

      await repo.setThemePreference('dark');
      await repo.setHighContrastPreference(value: true);
      await repo.setTextScalePreference(1.35);

      final VitalRiseRepository reloaded = VitalRiseRepository(store: store);
      expect(reloaded.themePreference, 'dark');
      expect(reloaded.highContrastPreference, isTrue);
      expect(reloaded.textScalePreference, closeTo(1.35, 0.001));
    });

    test('an out-of-range stored text scale is clamped on read', () async {
      final HealthStore store = await _store();
      final VitalRiseRepository repo = VitalRiseRepository(store: store);

      await repo.setTextScalePreference(99);
      expect(repo.textScalePreference, lessThanOrEqualTo(2.0));
    });
  });
}
