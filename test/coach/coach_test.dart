import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/features/coach/domain/coach_safety.dart';
import 'package:vitalrise/features/coach/domain/coach_service.dart';
import 'package:vitalrise/features/coach/domain/knowledge_base.dart';

/// Records what it was asked and returns a canned answer.
class _RecordingBackend implements CoachBackend {
  int calls = 0;
  List<ScoredChunk> lastContext = const <ScoredChunk>[];
  String? lastQuestion;

  @override
  Future<String> complete({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) async {
    calls++;
    lastQuestion = question;
    lastContext = context;
    return 'MODEL ANSWER';
  }
}

class _FailingBackend implements CoachBackend {
  @override
  Future<String> complete({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) async => throw StateError('network down');
}

void main() {
  group('safety triage', () {
    test('self-harm is escalated to crisis resources without a model call', () {
      final SafetyDecision d = CoachSafety.assess(
        'honestly I want to kill myself',
      );
      expect(d.verdict, SafetyVerdict.emergency);
      expect(d.blocksModel, isTrue);
      expect(d.response, contains('988'));
      expect(d.reason, 'self_harm');
    });

    test('priapism and chest pain are treated as medical emergencies', () {
      for (final String message in <String>[
        'my erection lasting 6 hours what do I do',
        'I get chest pain during sex',
        'is this priapism',
      ]) {
        expect(
          CoachSafety.assess(message).verdict,
          SafetyVerdict.emergency,
          reason: message,
        );
      }
    });

    test('medication questions are refused and redirected', () {
      for (final String message in <String>[
        'should I take viagra',
        'what dose of cialis is safe',
        'how do I get tadalafil without a prescription',
        'thinking about starting TRT',
      ]) {
        final SafetyDecision d = CoachSafety.assess(message);
        expect(d.verdict, SafetyVerdict.refuse, reason: message);
        expect(d.response, contains('prescriber'));
      }
    });

    test(
      'the medication refusal warns against stopping a drug unilaterally',
      () {
        expect(
          CoachSafety.assess(
            'should I stop my sildenafil prescription',
          ).response,
          contains('do not stop it on your own'),
        );
      },
    );

    test('diagnosis requests still answer, but lead with a referral', () {
      final SafetyDecision d = CoachSafety.assess('do i have ED?');
      expect(d.verdict, SafetyVerdict.referClinician);
      expect(d.blocksModel, isFalse);
    });

    test('self-declared minors are turned away', () {
      for (final String message in <String>[
        'I am 15 and worried about this',
        "i'm 17, is this normal",
      ]) {
        final SafetyDecision d = CoachSafety.assess(message);
        expect(d.verdict, SafetyVerdict.refuse, reason: message);
        expect(d.response, contains('18'));
      }
    });

    test('ordinary questions are allowed through', () {
      for (final String message in <String>[
        'how do I do kegels',
        'what foods help blood flow',
        'why do I lose my erection',
        'how long until I see results',
      ]) {
        expect(
          CoachSafety.assess(message).verdict,
          SafetyVerdict.allow,
          reason: message,
        );
      }
    });

    test('triage is case-insensitive', () {
      expect(
        CoachSafety.assess('SHOULD I TAKE VIAGRA').verdict,
        SafetyVerdict.refuse,
      );
    });
  });

  group('knowledge base and retrieval', () {
    setUp(KnowledgeBase.resetCache);

    test('the corpus is built from articles and exercises', () {
      final List<KnowledgeChunk> chunks = KnowledgeBase.chunks;
      expect(chunks.length, greaterThan(30));
      expect(
        chunks.any((KnowledgeChunk c) => c.id.startsWith('exercise:')),
        isTrue,
      );
      expect(
        chunks.any((KnowledgeChunk c) => c.id.contains('understanding_ed')),
        isTrue,
      );
      for (final KnowledgeChunk c in chunks) {
        expect(c.body, isNotEmpty, reason: c.id);
        expect(c.source, isNotEmpty, reason: c.id);
      }
    });

    test('chunk ids are unique', () {
      final Set<String> ids = KnowledgeBase.chunks
          .map((KnowledgeChunk c) => c.id)
          .toSet();
      expect(ids.length, KnowledgeBase.chunks.length);
    });

    test('retrieval surfaces the right passage for the sample questions', () {
      final BM25Retriever retriever = BM25Retriever.standard();

      final Map<String, String> expectations = <String, String>{
        'How do I do Kegels correctly?': 'kegel',
        'Why do I lose my erection during sex?': 'erection',
        'How does anxiety affect erections?': 'anxi',
        'What are the best foods for blood flow?': 'flow',
        'Does sleep affect testosterone?': 'sleep',
      };

      for (final MapEntry<String, String> e in expectations.entries) {
        final List<ScoredChunk> hits = retriever.search(e.key);
        expect(hits, isNotEmpty, reason: e.key);
        final String joined = hits
            .map((ScoredChunk c) => '${c.chunk.title} ${c.chunk.source}')
            .join(' ')
            .toLowerCase();
        expect(joined, contains(e.value), reason: e.key);
      }
    });

    test('results are ordered by descending score', () {
      final List<ScoredChunk> hits = BM25Retriever.standard().search(
        'pelvic floor training',
        limit: 6,
      );
      for (int i = 1; i < hits.length; i++) {
        expect(hits[i - 1].score, greaterThanOrEqualTo(hits[i].score));
      }
    });

    test('nonsense queries return nothing rather than a random passage', () {
      expect(BM25Retriever.standard().search('qwertyuiop zxcvbnm'), isEmpty);
    });

    test('the limit is respected', () {
      expect(
        BM25Retriever.standard().search('erection', limit: 2),
        hasLength(2),
      );
    });

    test('tokenisation drops stopwords and short tokens', () {
      final List<String> tokens = BM25Retriever.tokenize(
        'How do the exercises work for me?',
      );
      expect(tokens, isNot(contains('the')));
      expect(tokens, isNot(contains('do')));
      expect(tokens, contains('exercise')); // stemmed from "exercises"
    });

    test('an empty corpus does not crash the retriever', () {
      expect(
        BM25Retriever(const <KnowledgeChunk>[]).search('anything'),
        isEmpty,
      );
    });
  });

  group('coach service', () {
    test('emergency messages never reach the backend', () async {
      final _RecordingBackend backend = _RecordingBackend();
      final ChatMessage reply = await CoachService(
        backend: backend,
      ).ask(question: 'I want to kill myself', profile: const CoachContext());

      expect(backend.calls, 0);
      expect(reply.text, contains('crisis line'));
      expect(reply.role, ChatRole.coach);
    });

    test('medication requests never reach the backend', () async {
      final _RecordingBackend backend = _RecordingBackend();
      await CoachService(
        backend: backend,
      ).ask(question: 'what dose of viagra', profile: const CoachContext());
      expect(backend.calls, 0);
    });

    test(
      'allowed questions reach the backend with retrieved context',
      () async {
        final _RecordingBackend backend = _RecordingBackend();
        final ChatMessage reply = await CoachService(backend: backend).ask(
          question: 'How do I do Kegels correctly?',
          profile: const CoachContext(),
        );

        expect(backend.calls, 1);
        expect(backend.lastContext, isNotEmpty);
        expect(reply.text, 'MODEL ANSWER');
        expect(reply.sources, isNotEmpty);
        expect(reply.isError, isFalse);
      },
    );

    test('a diagnosis request is answered with a referral prefix', () async {
      final ChatMessage reply = await CoachService(backend: _RecordingBackend())
          .ask(
            question: 'do i have erectile dysfunction',
            profile: const CoachContext(),
          );
      expect(reply.text, startsWith('Some of your answers'));
      expect(reply.text, contains('MODEL ANSWER'));
    });

    test('a backend failure falls back to the on-device library', () async {
      final ChatMessage reply = await CoachService(backend: _FailingBackend())
          .ask(
            question: 'How do I do Kegels correctly?',
            profile: const CoachContext(),
          );

      expect(reply.isError, isTrue);
      expect(reply.text, isNotEmpty);
      expect(reply.text, contains('VitalRise library'));
      // The fallback must still carry the standard disclaimer.
      expect(reply.text, contains('not a substitute for medical advice'));
    });

    test(
      'the offline coach admits when it has nothing rather than guessing',
      () async {
        final String answer = await const ExtractiveCoach().complete(
          question: 'unrelated',
          context: const <ScoredChunk>[],
          profile: const CoachContext(),
          history: const <ChatMessage>[],
        );
        expect(answer, contains('could not find'));
        expect(answer, contains('rather say so than guess'));
      },
    );

    test('the prompt contract carries the guardrails and the context', () {
      final List<ScoredChunk> context = BM25Retriever.standard().search(
        'kegel',
        limit: 2,
      );
      final String prompt = CoachPrompt.buildUserPrompt(
        question: 'how do I do kegels',
        context: context,
        profile: const CoachContext(
          topCauses: <String>['Pelvic floor weakness'],
          programWeek: 3,
        ),
      );

      expect(CoachPrompt.system, contains('Never diagnose'));
      expect(CoachPrompt.system, contains('prescription medication'));
      expect(prompt, contains('CONTEXT PASSAGES'));
      expect(prompt, contains('Pelvic floor weakness'));
      expect(prompt, contains('week 3'));
      expect(prompt, contains('how do I do kegels'));
    });

    test('a chat message survives a JSON round trip', () {
      final ChatMessage original = ChatMessage(
        id: 'x',
        role: ChatRole.coach,
        text: 'hello',
        sentAt: DateTime.utc(2026, 4, 1, 9),
        sources: const <String>['Understanding erectile difficulty'],
      );
      final ChatMessage restored = ChatMessage.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.role, original.role);
      expect(restored.text, original.text);
      expect(restored.sentAt, original.sentAt);
      expect(restored.sources, original.sources);
    });
  });
}
