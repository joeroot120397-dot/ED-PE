import 'package:meta/meta.dart';

import '../../../core/constants/disclaimers.dart';
import '../../assessment/domain/assessment_result.dart';
import '../../assessment/domain/root_cause.dart';
import 'coach_safety.dart';
import 'knowledge_base.dart';

enum ChatRole { user, coach }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.sentAt,
    this.sources = const <String>[],
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime sentAt;

  /// Article/exercise titles the answer was grounded in.
  final List<String> sources;

  final bool isError;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': role.name,
    'text': text,
    'sent_at': sentAt.toIso8601String(),
    'sources': sources,
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    role: json['role'] == 'user' ? ChatRole.user : ChatRole.coach,
    text: json['text'] as String? ?? '',
    sentAt:
        DateTime.tryParse(json['sent_at'] as String? ?? '') ?? DateTime.now(),
    sources: <String>[
      ...(json['sources'] as List<dynamic>? ?? const <dynamic>[]).map(
        (Object? e) => e.toString(),
      ),
    ],
  );
}

/// What the coach knows about the user when answering. Deliberately a small,
/// explicit struct: nothing else from the profile is ever sent off-device.
@immutable
class CoachContext {
  const CoachContext({
    this.topCauses = const <String>[],
    this.sexualHealthScore,
    this.edRisk,
    this.peRisk,
    this.programWeek,
  });

  factory CoachContext.fromAssessment(
    AssessmentResult result, {
    int? programWeek,
  }) => CoachContext(
    topCauses: result.relevantCauses
        .take(3)
        .map((CauseConfidence c) => c.cause.title)
        .toList(),
    sexualHealthScore: result.scores.sexualHealthScore,
    edRisk: result.scores.edRiskScore,
    peRisk: result.scores.peRiskScore,
    programWeek: programWeek,
  );

  final List<String> topCauses;
  final int? sexualHealthScore;
  final int? edRisk;
  final int? peRisk;
  final int? programWeek;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (topCauses.isNotEmpty) 'top_causes': topCauses,
    if (sexualHealthScore != null) 'sexual_health_score': sexualHealthScore,
    if (edRisk != null) 'ed_risk': edRisk,
    if (peRisk != null) 'pe_risk': peRisk,
    if (programWeek != null) 'program_week': programWeek,
  };

  String get summaryLine {
    if (topCauses.isEmpty) return 'No assessment on file yet.';
    return 'Main drivers: ${topCauses.join(', ')}.'
        '${programWeek != null ? ' Currently in week $programWeek.' : ''}';
  }
}

/// A backend that can turn a grounded prompt into an answer.
abstract interface class CoachBackend {
  Future<String> complete({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  });
}

/// The instruction block sent with every request.
///
/// Kept in Dart *and* mirrored in the Edge Function so the guardrails
/// survive even if a caller forgets to send them; the function treats its
/// own copy as authoritative.
abstract final class CoachPrompt {
  static const String system = '''
You are the VitalRise coach, an educational assistant inside a men's sexual
wellness app. You are not a doctor and you never behave like one.

Rules, in priority order:
1. Never diagnose. Never name a condition as something the user "has".
2. Never recommend, dose, compare or source prescription medication or
   hormones. Redirect those questions to a prescriber.
3. Never claim the app or any exercise cures anything. Talk about what
   improves, for whom, and over what timeframe.
4. Ground every factual claim in the CONTEXT passages provided. If the
   context does not cover the question, say so plainly rather than
   inventing a mechanism or a statistic.
5. Point to a healthcare professional whenever the question involves
   symptoms, medication, sudden changes, pain, or anything the app cannot
   assess.
6. Be direct, warm and concrete. The user is often embarrassed and has
   usually been told to "just relax" by someone unhelpful. Do not moralise
   about pornography, masturbation or relationships.
7. Keep answers under 200 words unless the user asks for detail. Lead with
   the answer, then the mechanism, then the action.
8. Close with the standard disclaimer only when the question touches on
   symptoms or health decisions - not on every message.
''';

  /// Assembles the grounded user turn.
  static String buildUserPrompt({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
  }) {
    final StringBuffer sb = StringBuffer()
      ..writeln('USER PROFILE: ${profile.summaryLine}')
      ..writeln()
      ..writeln('CONTEXT PASSAGES:');

    if (context.isEmpty) {
      sb.writeln('(none matched - say so rather than guessing)');
    } else {
      for (int i = 0; i < context.length; i++) {
        final KnowledgeChunk c = context[i].chunk;
        sb
          ..writeln('[${i + 1}] ${c.source} - ${c.title}')
          ..writeln(c.body)
          ..writeln();
      }
    }

    sb
      ..writeln('QUESTION: $question')
      ..writeln()
      ..writeln('Answer using only the context above.');
    return sb.toString();
  }
}

/// Composes an answer directly from retrieved passages, with no model call.
///
/// This is not a degraded stub - it is the offline and first-launch path,
/// and it is what runs when the network is unavailable. Because it only
/// ever quotes reviewed content, it cannot hallucinate.
class ExtractiveCoach implements CoachBackend {
  const ExtractiveCoach();

  @override
  Future<String> complete({
    required String question,
    required List<ScoredChunk> context,
    required CoachContext profile,
    required List<ChatMessage> history,
  }) async {
    if (context.isEmpty) {
      return 'I could not find anything in the VitalRise library that answers '
          'that directly, and I would rather say so than guess.\n\n'
          'Try rephrasing it, or browse the Learn tab - the articles on '
          'erections, ejaculation control, pelvic floor training, '
          'testosterone, sleep, weight and anxiety cover most ground.\n\n'
          '${Disclaimers.standard}';
    }

    final StringBuffer sb = StringBuffer();
    final KnowledgeChunk top = context.first.chunk;
    sb
      ..writeln('Here is what the VitalRise library says about that.')
      ..writeln()
      ..writeln('**${top.title}**')
      ..writeln(_trim(top.body, 900));

    if (context.length > 1) {
      sb
        ..writeln()
        ..writeln('**${context[1].chunk.title}**')
        ..writeln(_trim(context[1].chunk.body, 500));
    }

    sb
      ..writeln()
      ..writeln(Disclaimers.standard);
    return sb.toString();
  }

  static String _trim(String body, int max) {
    if (body.length <= max) return body;
    final int cut = body.lastIndexOf('. ', max);
    return '${body.substring(0, cut > 0 ? cut + 1 : max)}...';
  }
}

/// Orchestrates safety triage, retrieval and generation.
class CoachService {
  CoachService({
    required this.backend,
    BM25Retriever? retriever,
    CoachBackend? fallback,
  }) : _retriever = retriever ?? BM25Retriever.standard(),
       _fallback = fallback ?? const ExtractiveCoach();

  final CoachBackend backend;
  final BM25Retriever _retriever;
  final CoachBackend _fallback;

  /// Answers [question], returning the coach's message.
  ///
  /// Order of operations matters: triage runs first and can short-circuit
  /// without any network call; retrieval runs next so both the model and
  /// the offline fallback see the same grounding.
  Future<ChatMessage> ask({
    required String question,
    required CoachContext profile,
    List<ChatMessage> history = const <ChatMessage>[],
    DateTime? now,
  }) async {
    final DateTime timestamp = now ?? DateTime.now();
    final String id = 'coach-${timestamp.microsecondsSinceEpoch}';

    final SafetyDecision decision = CoachSafety.assess(question);
    if (decision.blocksModel) {
      return ChatMessage(
        id: id,
        role: ChatRole.coach,
        text: decision.response!,
        sentAt: timestamp,
      );
    }

    final List<ScoredChunk> context = _retriever.search(question);

    String answer;
    bool errored = false;
    try {
      answer = await backend.complete(
        question: question,
        context: context,
        profile: profile,
        history: history,
      );
    } on Object {
      // Any backend failure falls back to quoting the library rather than
      // showing the user an error they cannot act on.
      answer = await _fallback.complete(
        question: question,
        context: context,
        profile: profile,
        history: history,
      );
      errored = true;
    }

    if (decision.verdict == SafetyVerdict.referClinician) {
      answer = '${Disclaimers.referralPrompt}\n\n$answer';
    }

    return ChatMessage(
      id: id,
      role: ChatRole.coach,
      text: answer,
      sentAt: timestamp,
      sources: context
          .map((ScoredChunk c) => c.chunk.source)
          .toSet()
          .toList(growable: false),
      isError: errored,
    );
  }

  /// Starter questions offered on an empty coach screen.
  static const List<String> suggestedQuestions = <String>[
    'How do I do Kegels correctly?',
    'Why do I lose my erection during sex?',
    'How does anxiety affect erections?',
    'What are the best foods for blood flow?',
    'How long before I see improvements?',
    'What is a reverse Kegel and why does it matter?',
    'Does sleep really affect testosterone?',
  ];
}
