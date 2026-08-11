import 'package:meta/meta.dart';

import '../../../core/constants/disclaimers.dart';

/// How a message should be handled before it ever reaches a model.
enum SafetyVerdict {
  /// Answer normally.
  allow,

  /// Answer, but lead with a referral to a clinician.
  referClinician,

  /// Do not call the model. Return the crisis response verbatim.
  emergency,

  /// Do not call the model. Explain what the coach will not do.
  refuse,
}

@immutable
class SafetyDecision {
  const SafetyDecision(this.verdict, {this.response, this.reason});

  final SafetyVerdict verdict;

  /// Set for [SafetyVerdict.emergency] and [SafetyVerdict.refuse] - the
  /// exact text to show instead of a model answer.
  final String? response;

  /// Short machine-readable tag for analytics. Never contains user text.
  final String? reason;

  bool get blocksModel =>
      verdict == SafetyVerdict.emergency || verdict == SafetyVerdict.refuse;
}

/// Deterministic pre-flight triage for coach messages.
///
/// This runs on-device, before any network call, for three reasons: an
/// emergency answer must not depend on connectivity, a model must never be
/// the last line of defence on a crisis message, and refusals must be
/// identical every time rather than sampled.
///
/// It is intentionally over-inclusive. A false positive costs a user one
/// unnecessary "see a doctor" line; a false negative can cost far more.
abstract final class CoachSafety {
  static SafetyDecision assess(String message) {
    final String text = message.toLowerCase();

    if (_containsAny(text, _selfHarm)) {
      return const SafetyDecision(
        SafetyVerdict.emergency,
        reason: 'self_harm',
        response:
            'I am not able to help with this, and I do not want to give '
            'you a coaching answer when something more important is going '
            'on.\n\n'
            'Please contact a crisis line or your local emergency number now. '
            'In the US you can call or text 988; in the UK, call 116 123 for '
            'Samaritans; elsewhere, findahelpline.com lists services by '
            'country.\n\n'
            'If you are in immediate danger, call emergency services.',
      );
    }

    if (_containsAny(text, _medicalEmergency)) {
      return const SafetyDecision(
        SafetyVerdict.emergency,
        reason: 'medical_emergency',
        response:
            'What you are describing needs urgent medical attention '
            'rather than an app.\n\n${Disclaimers.urgentCare}\n\n'
            'Please contact emergency services or an urgent care service now. '
            'An erection lasting more than four hours in particular can cause '
            'permanent damage and is treatable if seen quickly.',
      );
    }

    if (_containsAny(text, _prescriptionRequests)) {
      return const SafetyDecision(
        SafetyVerdict.refuse,
        reason: 'medication_request',
        response:
            'I cannot advise on prescription medication - not doses, '
            'not sourcing, and not whether to start or stop anything. That '
            'genuinely needs a prescriber who knows your history and your '
            'other medications.\n\n'
            'What I can do is help with the training, nutrition and sleep '
            'side, and help you work out what to raise at the appointment. '
            'Would that be useful?\n\n'
            'One thing worth saying plainly: if you noticed a change after '
            'starting a medication, do not stop it on your own. Tell the '
            'prescriber - there is often an alternative.',
      );
    }

    if (_containsAny(text, _diagnosisRequests)) {
      return const SafetyDecision(
        SafetyVerdict.referClinician,
        reason: 'diagnosis_request',
      );
    }

    if (_containsAny(text, _minorIndicators)) {
      return const SafetyDecision(
        SafetyVerdict.refuse,
        reason: 'age_restriction',
        response:
            'VitalRise is built for adults aged 18 and over, so I am '
            'not the right place for this.\n\n'
            'If you have questions about your body or sexual health and you '
            'are under 18, a doctor or a service aimed at young people will '
            'give you better and safer answers than I can.',
      );
    }

    return const SafetyDecision(SafetyVerdict.allow);
  }

  static bool _containsAny(String text, List<String> needles) =>
      needles.any(text.contains);

  static const List<String> _selfHarm = <String>[
    'kill myself',
    'killing myself',
    'end my life',
    'suicide',
    'suicidal',
    'want to die',
    'better off dead',
    'self harm',
    'self-harm',
    'hurt myself',
  ];

  static const List<String> _medicalEmergency = <String>[
    'chest pain',
    'erection for hours',
    'erection lasting',
    'priapism',
    'wont go down',
    "won't go down",
    'blood in my urine',
    'blood in urine',
    'blood in semen',
    'blood when i',
    'testicle pain',
    'testicular pain',
    'severe pain',
    'penis broke',
    'broke my penis',
    'penile fracture',
    'heard a pop',
    'cant urinate',
    "can't urinate",
    'unable to urinate',
  ];

  static const List<String> _prescriptionRequests = <String>[
    'viagra',
    'sildenafil',
    'cialis',
    'tadalafil',
    'levitra',
    'vardenafil',
    'stendra',
    'avanafil',
    'dapoxetine',
    'priligy',
    'trt',
    'testosterone injection',
    'testosterone shot',
    'anabolic',
    'steroid cycle',
    'clomid',
    'clomiphene',
    'hcg',
    'what dose',
    'what dosage',
    'how many mg',
    'prescription',
    'without a prescription',
    'buy online',
  ];

  static const List<String> _diagnosisRequests = <String>[
    'do i have',
    'am i diagnosed',
    'is this cancer',
    'do you think i have',
    'diagnose me',
    'what is wrong with me',
    'whats wrong with me',
    "what's wrong with me",
  ];

  static const List<String> _minorIndicators = <String>[
    'i am 13',
    'i am 14',
    'i am 15',
    'i am 16',
    'i am 17',
    "i'm 13",
    "i'm 14",
    "i'm 15",
    "i'm 16",
    "i'm 17",
    'im 13',
    'im 14',
    'im 15',
    'im 16',
    'im 17',
  ];
}
