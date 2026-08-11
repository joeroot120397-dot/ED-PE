import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_library.dart';
import '../../library/domain/article.dart';
import '../../library/domain/article_library.dart';

/// One retrievable passage.
@immutable
class KnowledgeChunk {
  const KnowledgeChunk({
    required this.id,
    required this.title,
    required this.source,
    required this.body,
    required this.keywords,
  });

  final String id;
  final String title;

  /// Human-readable citation, shown to the user under the answer.
  final String source;

  final String body;
  final List<String> keywords;

  String get searchText => '$title ${keywords.join(' ')} $body';
}

/// A chunk with its retrieval score.
@immutable
class ScoredChunk {
  const ScoredChunk(this.chunk, this.score);
  final KnowledgeChunk chunk;
  final double score;
}

/// Builds the corpus from the bundled article and exercise content, so the
/// coach can only ever ground its answers in reviewed material.
abstract final class KnowledgeBase {
  static List<KnowledgeChunk>? _cache;

  static List<KnowledgeChunk> get chunks => _cache ??= _build();

  static List<KnowledgeChunk> _build() {
    final List<KnowledgeChunk> out = <KnowledgeChunk>[];

    for (final Article article in ArticleLibrary.all) {
      for (int i = 0; i < article.sections.length; i++) {
        final ArticleSection s = article.sections[i];
        out.add(
          KnowledgeChunk(
            id: '${article.id}#$i',
            title: s.heading,
            source: article.title,
            body: s.body,
            keywords: <String>[
              ...s.keywords,
              article.title,
              article.topic.label,
            ],
          ),
        );
      }
    }

    for (final Exercise e in ExerciseLibrary.all) {
      out.add(
        KnowledgeChunk(
          id: 'exercise:${e.id}',
          title: 'How to do: ${e.name}',
          source: 'Exercise library - ${e.name}',
          body: <String>[
            e.summary,
            'Steps: ${e.instructions.join(' ')}',
            'Prescription: ${e.dosage.label}.',
            'Benefits: ${e.benefits.join('. ')}.',
            'Common mistakes: ${e.commonMistakes.join(' ')}',
            'Safety: ${e.safetyTips.join(' ')}',
          ].join('\n'),
          keywords: <String>[
            e.name,
            e.category.label,
            e.difficulty.label,
            'exercise',
            'how to',
            'technique',
          ],
        ),
      );
    }

    return out;
  }

  /// Test seam - forces the corpus to rebuild.
  @visibleForTesting
  static void resetCache() => _cache = null;
}

/// A small BM25 retriever.
///
/// BM25 rather than embeddings because the corpus is a few hundred short
/// passages that ship inside the binary: it needs no model, no network and
/// no vector store, it runs in under a millisecond, and it works offline and
/// on the first launch. If the corpus grows past a few thousand chunks,
/// move retrieval server-side into the Edge Function and swap this for
/// pgvector - the [CoachRetriever] interface is the seam for that.
class BM25Retriever {
  BM25Retriever(this.corpus) {
    _index();
  }

  BM25Retriever.standard() : this(KnowledgeBase.chunks);

  final List<KnowledgeChunk> corpus;

  static const double _k1 = 1.5;
  static const double _b = 0.75;

  final Map<String, int> _documentFrequency = <String, int>{};
  final List<Map<String, int>> _termFrequencies = <Map<String, int>>[];
  final List<int> _lengths = <int>[];
  double _averageLength = 0;

  void _index() {
    for (final KnowledgeChunk chunk in corpus) {
      final List<String> tokens = tokenize(chunk.searchText);
      final Map<String, int> tf = <String, int>{};
      for (final String t in tokens) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      _termFrequencies.add(tf);
      _lengths.add(tokens.length);
      for (final String term in tf.keys) {
        _documentFrequency[term] = (_documentFrequency[term] ?? 0) + 1;
      }
    }
    _averageLength = _lengths.isEmpty
        ? 0
        : _lengths.reduce((int a, int b) => a + b) / _lengths.length;
  }

  List<ScoredChunk> search(String query, {int limit = 4}) {
    final List<String> terms = tokenize(query);
    if (terms.isEmpty || corpus.isEmpty) return const <ScoredChunk>[];

    final int n = corpus.length;
    final List<ScoredChunk> scored = <ScoredChunk>[];

    for (int i = 0; i < n; i++) {
      double score = 0;
      final Map<String, int> tf = _termFrequencies[i];
      for (final String term in terms) {
        final int f = tf[term] ?? 0;
        if (f == 0) continue;
        final int df = _documentFrequency[term] ?? 0;
        // BM25 IDF with the +1 smoothing that keeps common terms positive.
        final double idf = math.log(1 + (n - df + 0.5) / (df + 0.5));
        final double norm = _averageLength == 0
            ? 1
            : 1 - _b + _b * (_lengths[i] / _averageLength);
        score += idf * (f * (_k1 + 1)) / (f + _k1 * norm);
      }
      if (score > 0) scored.add(ScoredChunk(corpus[i], score));
    }

    scored.sort((ScoredChunk a, ScoredChunk b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  /// Lowercases, strips punctuation, drops stopwords and applies a very
  /// small suffix stemmer. Deliberately simple - aggressive stemming hurts
  /// more than it helps on a corpus this size.
  static List<String> tokenize(String input) {
    final Iterable<String> raw = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s'-]"), ' ')
        .split(RegExp(r'\s+'))
        .where((String t) => t.length > 2);

    return <String>[
      for (final String token in raw)
        if (!_stopwords.contains(token)) _stem(token),
    ];
  }

  static String _stem(String token) {
    for (final String suffix in const <String>['ing', 'ies', 'ed', 's']) {
      if (token.length > suffix.length + 3 && token.endsWith(suffix)) {
        final String stem = token.substring(0, token.length - suffix.length);
        return suffix == 'ies' ? '${stem}y' : stem;
      }
    }
    return token;
  }

  static const Set<String> _stopwords = <String>{
    'the',
    'and',
    'for',
    'are',
    'but',
    'not',
    'you',
    'all',
    'can',
    'her',
    'was',
    'one',
    'our',
    'out',
    'day',
    'get',
    'has',
    'him',
    'his',
    'how',
    'its',
    'may',
    'new',
    'now',
    'old',
    'see',
    'two',
    'who',
    'boy',
    'did',
    'that',
    'this',
    'with',
    'have',
    'from',
    'they',
    'will',
    'been',
    'were',
    'what',
    'when',
    'your',
    'would',
    'there',
    'their',
    'about',
    'which',
    'them',
    'then',
    'than',
    'some',
    'into',
    'more',
    'very',
    'just',
    'like',
    'does',
    'much',
    'over',
    'also',
    'because',
  };
}
