import 'package:meta/meta.dart';

enum ArticleTopic {
  erectile('Erections'),
  ejaculation('Ejaculation'),
  pelvicFloor('Pelvic floor'),
  hormones('Hormones'),
  sleep('Sleep'),
  weight('Weight'),
  mind('Mind');

  const ArticleTopic(this.label);
  final String label;
}

/// One heading + body within an article. Sections are also the unit of
/// retrieval for the AI coach, which is why they are individually titled
/// and kept to a few paragraphs.
@immutable
class ArticleSection {
  const ArticleSection({
    required this.heading,
    required this.body,
    this.keywords = const <String>[],
  });

  final String heading;
  final String body;

  /// Extra retrieval terms that do not appear verbatim in the body -
  /// synonyms and the words users actually type.
  final List<String> keywords;
}

@immutable
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.topic,
    required this.summary,
    required this.readMinutes,
    required this.sections,
  });

  final String id;
  final String title;
  final ArticleTopic topic;
  final String summary;
  final int readMinutes;
  final List<ArticleSection> sections;

  String get plainText => sections
      .map((ArticleSection s) => '${s.heading}\n${s.body}')
      .join('\n\n');
}
