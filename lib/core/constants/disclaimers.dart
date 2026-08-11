/// Regulatory copy. VitalRise is a wellness/education product, **not** a
/// medical device: it must never diagnose, treat, cure or prescribe.
///
/// [Disclaimers.standard] is rendered on every screen via
/// `DisclaimerBanner` / `DisclaimerFooter`; see
/// `test/core/disclaimer_coverage_test.dart` which fails the build if a
/// screen forgets it.
abstract final class Disclaimers {
  static const String standard =
      'This application provides educational guidance only and is not a '
      'substitute for medical advice. Consult a qualified healthcare '
      'professional for diagnosis and treatment.';

  static const String assessmentIntro =
      'The questions ahead are a structured self-reflection tool, not a '
      'clinical diagnosis. Your answers produce educational guidance about '
      'habits that research links to sexual wellness.';

  static const String scoreExplainer =
      'Scores describe your self-reported answers on a 0-100 scale. They are '
      'not clinical measurements and cannot confirm or rule out any '
      'condition.';

  static const String exerciseSafety =
      'Stop any exercise that causes pain, numbness or dizziness. If you have '
      'a heart condition, recent surgery, hernia or chronic pelvic pain, get '
      'clearance from a clinician before starting.';

  static const String dietSafety =
      'Nutrition targets are general estimates from your height, weight, age '
      'and activity. They do not account for medication, allergies, kidney or '
      'liver conditions. Review any plan with a doctor or dietitian.';

  static const String coachDisclaimer =
      'The coach is an AI assistant trained on general wellness education. It '
      'cannot examine you, does not know your medical records, and must not '
      'be used for diagnosis, medication advice or emergencies.';

  static const String urgentCare =
      'Seek urgent medical care for chest pain, an erection lasting more than '
      '4 hours, blood in urine or semen, sudden loss of erections after '
      'injury, or thoughts of self-harm.';

  /// Shown when the assessment surfaces something that warrants a clinician.
  static const String referralPrompt =
      'Some of your answers are best reviewed by a healthcare professional. '
      'This is not a cause for alarm - it means a clinician can rule out '
      'treatable underlying causes that an app cannot assess.';
}
