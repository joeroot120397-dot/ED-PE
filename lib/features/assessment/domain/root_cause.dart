import 'package:meta/meta.dart';

/// The root-cause categories VitalRise can talk about.
///
/// These are *lifestyle and training* categories, deliberately chosen so
/// every one of them has an app-deliverable intervention. Anything that
/// needs a clinician (hormonal, neurological, medication side effects,
/// structural) is surfaced as a [ClinicalFlag] referral instead of a
/// category we claim to address.
enum RootCause {
  pelvicFloorWeakness(
    'Pelvic floor weakness',
    'The muscles that trap blood in an erection and gate ejaculation are '
        'under-trained. This is the most directly trainable factor there is.',
    'pelvic_floor',
  ),
  obesityRelated(
    'Weight and metabolic load',
    'Excess abdominal fat converts testosterone to oestrogen and inflames '
        'the lining of blood vessels, which blunts the erection response.',
    'obesity',
  ),
  anxietyRelated(
    'Anxiety and arousal',
    'Adrenaline is chemically opposed to an erection. Performance worry '
        'creates the exact physiology that prevents the outcome you want.',
    'anxiety',
  ),
  cardiovascular(
    'Circulation and vascular health',
    'An erection is a blood-flow event. Smoking, blood pressure, cholesterol '
        'and vessel stiffness show up here before they show up anywhere else.',
    'cardiovascular',
  ),
  sedentaryLifestyle(
    'Sedentary lifestyle',
    'Long sitting hours compress the perineum, reduce pelvic circulation and '
        'let the supporting muscles waste through simple disuse.',
    'sedentary',
  ),
  sleepDeficiency(
    'Sleep deficiency',
    'The bulk of daily testosterone is released during deep sleep, and most '
        'spontaneous erections happen in REM. Short sleep costs you both.',
    'sleep',
  ),
  diabetesRelated(
    'Blood sugar regulation',
    'Sustained high blood glucose damages the small nerves and vessels that '
        'erections depend on. Glycaemic control is the lever here.',
    'diabetes',
  );

  const RootCause(this.title, this.explanation, this.slug);

  final String title;
  final String explanation;

  /// Stable identifier persisted to Postgres and used to look up programme
  /// templates. Never rename.
  final String slug;

  static RootCause? fromSlug(String slug) {
    for (final RootCause c in RootCause.values) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

/// A cause with its confidence, 0-100.
@immutable
class CauseConfidence implements Comparable<CauseConfidence> {
  const CauseConfidence(this.cause, this.confidence);

  final RootCause cause;
  final double confidence;

  /// Bands used for copy and colour. Anything under 35 is not shown as a
  /// driver at all.
  bool get isPrimary => confidence >= 65;
  bool get isContributing => confidence >= 40 && confidence < 65;
  bool get isRelevant => confidence >= 35;

  String get band {
    if (confidence >= 80) return 'Strong signal';
    if (confidence >= 65) return 'Likely driver';
    if (confidence >= 40) return 'Contributing';
    return 'Minor';
  }

  @override
  int compareTo(CauseConfidence other) =>
      other.confidence.compareTo(confidence);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cause': cause.slug,
    'confidence': confidence,
  };

  static CauseConfidence? fromJson(Map<String, dynamic> json) {
    final RootCause? c = RootCause.fromSlug(json['cause'] as String? ?? '');
    if (c == null) return null;
    return CauseConfidence(c, (json['confidence'] as num?)?.toDouble() ?? 0);
  }
}

/// Things the app must hand to a human clinician rather than coach.
enum ClinicalFlag {
  cardiovascularReview(
    'Circulation check-up',
    'Erection changes can be the earliest sign of narrowing arteries, often '
        'years before heart symptoms. A blood pressure, lipid and glucose '
        'panel is a reasonable, low-cost thing to ask for.',
  ),
  glycaemicReview(
    'Blood sugar review',
    'Diabetes that is not tightly controlled damages the nerves and vessels '
        'this app cannot train around. Ask about an HbA1c test.',
  ),
  hormonalReview(
    'Hormone panel',
    'Your answers describe a pattern that sometimes accompanies low '
        'testosterone or a thyroid issue. Only a morning blood test can '
        'establish that - no app can.',
  ),
  mentalHealthSupport(
    'Mental health support',
    'Low mood and anxiety both suppress desire and erections, and several '
        'common antidepressants affect them further. A prescriber can weigh '
        'the options with you. Never adjust medication on your own.',
  ),
  suddenOnset(
    'Sudden onset review',
    'Erection changes that began abruptly in an otherwise healthy man are '
        'worth a conversation with a doctor to rule out treatable causes.',
  ),
  compulsiveUse(
    'Compulsive behaviour support',
    'When sexual behaviour feels out of your control, structured support '
        'from a therapist works far better than willpower alone.',
  );

  const ClinicalFlag(this.title, this.guidance);

  final String title;
  final String guidance;

  String get slug => name;
}
