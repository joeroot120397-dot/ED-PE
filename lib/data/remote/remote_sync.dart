import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/coach/domain/coach_service.dart';
import '../../features/coach/domain/knowledge_base.dart';

/// Everything the app pushes to or pulls from the backend.
///
/// An interface rather than a direct Supabase dependency so the whole app
/// runs against [NoopRemoteSync] in tests, in the offline demo build, and
/// before a user signs in.
abstract interface class RemoteSync {
  bool get isAvailable;
  String? get userId;

  Future<void> upsertProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> fetchProfile();

  Future<void> saveAssessment({
    required Map<String, dynamic> responses,
    required Map<String, dynamic> result,
  });
  Future<Map<String, dynamic>?> fetchLatestAssessment();

  Future<void> upsertHabitLogs(List<Map<String, dynamic>> logs);
  Future<List<Map<String, dynamic>>> fetchHabitLogs();

  Future<void> upsertProgressEntries(List<Map<String, dynamic>> entries);
  Future<List<Map<String, dynamic>>> fetchProgressEntries();

  /// Asks the server-side coach. Model credentials live only there.
  Future<String> askCoach({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  });

  Future<void> deleteAllData();
}

/// Used when Supabase is not configured or nobody is signed in.
///
/// Every write is a silent no-op and every read is empty, so the app is
/// fully functional on-device and simply has nothing to sync.
class NoopRemoteSync implements RemoteSync {
  const NoopRemoteSync();

  @override
  bool get isAvailable => false;

  @override
  String? get userId => null;

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async {}

  @override
  Future<Map<String, dynamic>?> fetchProfile() async => null;

  @override
  Future<void> saveAssessment({
    required Map<String, dynamic> responses,
    required Map<String, dynamic> result,
  }) async {}

  @override
  Future<Map<String, dynamic>?> fetchLatestAssessment() async => null;

  @override
  Future<void> upsertHabitLogs(List<Map<String, dynamic>> logs) async {}

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

/// Thrown when a remote call is attempted with no backend available. The
/// coach catches this and falls back to the on-device extractive answer.
class RemoteUnavailable implements Exception {
  const RemoteUnavailable();

  @override
  String toString() => 'RemoteUnavailable: no backend configured';
}

/// Supabase-backed implementation.
///
/// Every table is protected by row level security keyed on `auth.uid()`
/// (see `supabase/migrations/0002_rls.sql`), so these queries never need -
/// and never include - a user id filter of their own. The database refuses
/// to return another user's rows even if the client asks for them.
class SupabaseRemoteSync implements RemoteSync {
  SupabaseRemoteSync(this._client, {required this.coachFunction});

  final SupabaseClient _client;
  final String coachFunction;

  @override
  bool get isAvailable => _client.auth.currentUser != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  void _requireAuth() {
    if (!isAvailable) throw const RemoteUnavailable();
  }

  @override
  Future<void> upsertProfile(Map<String, dynamic> profile) async {
    _requireAuth();
    await _client.from('profiles').upsert(<String, dynamic>{
      ...profile,
      'id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile() async {
    _requireAuth();
    return _client.from('profiles').select().eq('id', userId!).maybeSingle();
  }

  @override
  Future<void> saveAssessment({
    required Map<String, dynamic> responses,
    required Map<String, dynamic> result,
  }) async {
    _requireAuth();
    await _client.from('assessments').insert(<String, dynamic>{
      'user_id': userId,
      'responses': responses,
      'result': result,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchLatestAssessment() async {
    _requireAuth();
    return _client
        .from('assessments')
        .select()
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  @override
  Future<void> upsertHabitLogs(List<Map<String, dynamic>> logs) async {
    _requireAuth();
    if (logs.isEmpty) return;
    await _client.from('habit_logs').upsert(<Map<String, dynamic>>[
      for (final Map<String, dynamic> log in logs)
        <String, dynamic>{...log, 'user_id': userId},
    ], onConflict: 'user_id,day');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHabitLogs() async {
    _requireAuth();
    final List<Map<String, dynamic>> rows = await _client
        .from('habit_logs')
        .select()
        .order('day', ascending: false)
        .limit(400);
    return rows;
  }

  @override
  Future<void> upsertProgressEntries(List<Map<String, dynamic>> entries) async {
    _requireAuth();
    if (entries.isEmpty) return;
    await _client.from('progress_entries').upsert(<Map<String, dynamic>>[
      for (final Map<String, dynamic> entry in entries)
        <String, dynamic>{...entry, 'user_id': userId},
    ], onConflict: 'user_id,week_start');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProgressEntries() async {
    _requireAuth();
    return _client
        .from('progress_entries')
        .select()
        .order('week_start', ascending: false)
        .limit(120);
  }

  @override
  Future<String> askCoach({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) async {
    _requireAuth();
    final FunctionResponse response = await _client.functions.invoke(
      coachFunction,
      body: <String, dynamic>{
        'question': question,
        'profile': profile.toJson(),
        'context': <Map<String, String>>[
          for (final ScoredChunk c in context)
            <String, String>{
              'source': c.chunk.source,
              'title': c.chunk.title,
              'body': c.chunk.body,
            },
        ],
        // Only the last few turns travel, and only their text - no ids, no
        // timestamps, nothing that could re-identify a session.
        'history': <Map<String, String>>[
          for (final ChatMessage m
              in history.reversed.take(6).toList().reversed)
            <String, String>{'role': m.role.name, 'text': m.text},
        ],
      },
    );

    if (response.status >= 400) {
      throw StateError('Coach function failed with ${response.status}');
    }
    final Object? data = response.data;
    final String? answer = data is Map<String, dynamic>
        ? data['answer'] as String?
        : data?.toString();
    if (answer == null || answer.isEmpty) {
      throw StateError('Coach function returned an empty answer');
    }
    return answer;
  }

  @override
  Future<void> deleteAllData() async {
    _requireAuth();
    // A single RPC so the delete is transactional server-side; deleting
    // table by table from the client can leave a partial state if the
    // connection drops halfway through.
    await _client.rpc<void>('delete_my_data');
  }
}
