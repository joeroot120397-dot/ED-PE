import 'assessment_models.dart';

/// The canonical VitalRise intake.
///
/// Every option carries a `burden` on a shared 0-1 scale so the scoring
/// engine can combine sections with plain weights. Wording is deliberately
/// non-diagnostic: we ask about *experience and frequency*, never "do you
/// have erectile dysfunction".
///
/// Question ids are a stable API - they are persisted in Postgres and used
/// by the scoring engine, so they must never be renamed or reused.
abstract final class QuestionBank {
  static const List<AssessmentQuestion> all = <AssessmentQuestion>[
    ..._basics,
    ..._erectile,
    ..._ejaculation,
    ..._lifestyle,
    ..._medical,
    ..._psychological,
  ];

  static List<AssessmentQuestion> forSection(AssessmentSection section) =>
      all.where((AssessmentQuestion q) => q.section == section).toList();

  static AssessmentQuestion byId(String id) =>
      all.firstWhere((AssessmentQuestion q) => q.id == id);

  static int get count => all.length;

  // ------------------------------------------------------------------
  // Section A - Basic information
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _basics = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'a_age',
      section: AssessmentSection.basics,
      prompt: 'How old are you?',
      helper:
          'Erection physiology changes with age; we adjust expectations '
          'rather than judging you against a 20-year-old.',
      kind: AnswerKind.numeric,
      numeric: NumericSpec(min: 18, max: 90, unit: 'years', initial: 32),
    ),
    AssessmentQuestion(
      id: 'a_height_cm',
      section: AssessmentSection.basics,
      prompt: 'How tall are you?',
      kind: AnswerKind.numeric,
      numeric: NumericSpec(min: 130, max: 220, unit: 'cm', initial: 175),
    ),
    AssessmentQuestion(
      id: 'a_weight_kg',
      section: AssessmentSection.basics,
      prompt: 'What do you weigh?',
      kind: AnswerKind.numeric,
      numeric: NumericSpec(min: 35, max: 200, unit: 'kg', initial: 78),
    ),
    AssessmentQuestion(
      id: 'a_waist_cm',
      section: AssessmentSection.basics,
      prompt: 'What is your waist measurement?',
      helper:
          'Measure at the navel, relaxed. Waist predicts blood-vessel and '
          'hormone health better than weight alone.',
      kind: AnswerKind.numeric,
      numeric: NumericSpec(min: 55, max: 170, unit: 'cm', initial: 90),
    ),
    AssessmentQuestion(
      id: 'a_relationship',
      section: AssessmentSection.basics,
      prompt: 'What best describes your relationship situation?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('single', 'Single', 0.15),
        AnswerOption('dating', 'Dating / new partner', 0.25),
        AnswerOption('committed', 'Long-term relationship', 0.0),
        AnswerOption('married', 'Married', 0.0),
        AnswerOption('separated', 'Separated or divorced', 0.35),
      ],
    ),
  ];

  // ------------------------------------------------------------------
  // Section B - Erection quality
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _erectile = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'b_achieve',
      section: AssessmentSection.erectile,
      prompt:
          'Over the last 4 weeks, how often were you able to get an '
          'erection during sexual activity?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('always', 'Almost always or always', 0.0),
        AnswerOption('most', 'Most times (more than half)', 0.25),
        AnswerOption('half', 'About half the time', 0.5),
        AnswerOption('few', 'A few times (less than half)', 0.75),
        AnswerOption('never', 'Almost never or never', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'b_maintain',
      section: AssessmentSection.erectile,
      prompt:
          'How often were you able to maintain your erection until the '
          'end of intercourse?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('always', 'Almost always or always', 0.0),
        AnswerOption('most', 'Most times', 0.25),
        AnswerOption('half', 'About half the time', 0.5),
        AnswerOption('few', 'A few times', 0.75),
        AnswerOption('never', 'Almost never or never', 1.0),
        AnswerOption(
          'na',
          'No intercourse in this period',
          0.4,
          detail: 'Scored neutrally - it tells us less either way.',
        ),
      ],
    ),
    AssessmentQuestion(
      id: 'b_morning',
      section: AssessmentSection.erectile,
      prompt: 'How often do you notice erections on waking?',
      helper:
          'A strong clue. Morning erections that continue while sex is '
          'difficult usually point away from a blood-flow cause.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('daily', 'Most mornings', 0.0),
        AnswerOption('often', '4-6 times a week', 0.2),
        AnswerOption('sometimes', '2-3 times a week', 0.45),
        AnswerOption('rare', 'Once a week or less', 0.8),
        AnswerOption('never', 'Never', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'b_hardness',
      section: AssessmentSection.erectile,
      prompt: 'At its best, how firm is your erection?',
      helper: '1 = enlarges but not hard, 10 = completely rigid.',
      kind: AnswerKind.scale,
      numeric: NumericSpec(
        min: 1,
        max: 10,
        unit: '/10',
        initial: 6,
        lowLabel: 'Soft',
        highLabel: 'Fully rigid',
      ),
      burdenFromNumber: _hardnessBurden,
    ),
    AssessmentQuestion(
      id: 'b_loss_during',
      section: AssessmentSection.erectile,
      prompt: 'Do you lose firmness partway through intercourse?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('never', 'Never', 0.0),
        AnswerOption('occasionally', 'Occasionally', 0.35),
        AnswerOption('often', 'Often', 0.7),
        AnswerOption('always', 'Almost every time', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'b_duration',
      section: AssessmentSection.erectile,
      prompt: 'How long have you noticed these erection changes?',
      helper:
          'Sudden onset in an otherwise healthy man often has a different '
          'driver than a slow change over years.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('none', 'I have not noticed changes', 0.0),
        AnswerOption('recent', 'Less than 3 months, fairly sudden', 0.45),
        AnswerOption('months', '3-12 months, gradual', 0.7),
        AnswerOption('years', 'More than a year, gradual', 1.0),
      ],
    ),
  ];

  static double _hardnessBurden(double v) => ((10 - v) / 9).clamp(0.0, 1.0);

  // ------------------------------------------------------------------
  // Section C - Ejaculation control
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _ejaculation = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'c_latency',
      section: AssessmentSection.ejaculation,
      prompt: 'Typically, how long from penetration to ejaculation?',
      helper:
          'For reference, the median across large studies is roughly 5 '
          'minutes. There is no "correct" number.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('over5', 'More than 5 minutes', 0.0),
        AnswerOption('2to5', '2 to 5 minutes', 0.3),
        AnswerOption('1to2', '1 to 2 minutes', 0.6),
        AnswerOption('30to60', '30 to 60 seconds', 0.85),
        AnswerOption('under30', 'Under 30 seconds, or before penetration', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'c_control',
      section: AssessmentSection.ejaculation,
      prompt: 'How difficult is it to delay ejaculation when you want to?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('none', 'Not difficult', 0.0),
        AnswerOption('slight', 'Slightly difficult', 0.3),
        AnswerOption('moderate', 'Moderately difficult', 0.6),
        AnswerOption('very', 'Very difficult', 0.85),
        AnswerOption('unable', 'I have no control at all', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'c_satisfaction',
      section: AssessmentSection.ejaculation,
      prompt: 'How satisfied are you with your sex life overall?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('very', 'Very satisfied', 0.0),
        AnswerOption('satisfied', 'Satisfied', 0.25),
        AnswerOption('mixed', 'Mixed', 0.5),
        AnswerOption('dissatisfied', 'Dissatisfied', 0.8),
        AnswerOption('very_dissatisfied', 'Very dissatisfied', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'c_anticipatory_anxiety',
      section: AssessmentSection.ejaculation,
      prompt: 'How much do you worry about finishing too quickly beforehand?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('none', 'Not at all', 0.0),
        AnswerOption('slight', 'A little', 0.3),
        AnswerOption('moderate', 'A moderate amount', 0.6),
        AnswerOption('high', 'A lot', 0.85),
        AnswerOption('severe', 'It dominates my thinking', 1.0),
      ],
    ),
  ];

  // ------------------------------------------------------------------
  // Section D - Lifestyle
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _lifestyle = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'd_smoking',
      section: AssessmentSection.lifestyle,
      prompt: 'Do you smoke or vape nicotine?',
      helper:
          'Nicotine constricts the small arteries that fill erectile '
          'tissue - one of the most reversible factors on this list.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('never', 'Never', 0.0),
        AnswerOption('former', 'I quit', 0.2),
        AnswerOption('light', 'Occasionally / under 10 a day', 0.6),
        AnswerOption('heavy', '10 or more a day', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'd_alcohol',
      section: AssessmentSection.lifestyle,
      prompt: 'How often do you drink alcohol?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('none', 'I do not drink', 0.0),
        AnswerOption('occasional', 'A few times a month', 0.2),
        AnswerOption('weekly', 'Weekly', 0.5),
        AnswerOption('most_days', 'Most days', 0.85),
        AnswerOption('daily_heavy', 'Daily, several drinks', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'd_sleep',
      section: AssessmentSection.lifestyle,
      prompt: 'On a typical night, how much do you sleep?',
      helper:
          'Most testosterone is released during sleep. Under 6 hours '
          'measurably lowers it within a week.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('8plus', '8 hours or more', 0.0),
        AnswerOption('7to8', '7 to 8 hours', 0.1),
        AnswerOption('6to7', '6 to 7 hours', 0.4),
        AnswerOption('5to6', '5 to 6 hours', 0.7),
        AnswerOption('under5', 'Under 5 hours', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'd_exercise',
      section: AssessmentSection.lifestyle,
      prompt: 'How many days a week do you exercise for 30 minutes or more?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('5plus', '5 or more', 0.0),
        AnswerOption('3to4', '3 to 4', 0.2),
        AnswerOption('1to2', '1 to 2', 0.5),
        AnswerOption('rare', 'Less than weekly', 0.8),
        AnswerOption('never', 'Never', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'd_sitting',
      section: AssessmentSection.lifestyle,
      prompt: 'How many hours a day do you spend sitting?',
      helper:
          'Prolonged sitting compresses the perineum and weakens the '
          'pelvic floor through disuse.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('under4', 'Under 4', 0.0),
        AnswerOption('4to6', '4 to 6', 0.3),
        AnswerOption('6to9', '6 to 9', 0.65),
        AnswerOption('over9', 'More than 9', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'd_stress',
      section: AssessmentSection.lifestyle,
      prompt: 'How would you rate your day-to-day stress?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('low', 'Low', 0.0),
        AnswerOption('mild', 'Mild', 0.3),
        AnswerOption('moderate', 'Moderate', 0.6),
        AnswerOption('high', 'High', 0.85),
        AnswerOption('severe', 'Overwhelming', 1.0),
      ],
    ),
  ];

  // ------------------------------------------------------------------
  // Section E - Health history
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _medical = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'e_diabetes',
      section: AssessmentSection.medical,
      prompt: 'Have you been told you have diabetes or prediabetes?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('prediabetes', 'Prediabetes / borderline', 0.5),
        AnswerOption('t2_controlled', 'Type 2, well controlled', 0.7),
        AnswerOption('t1', 'Type 1', 0.8),
        AnswerOption('t2_uncontrolled', 'Type 2, not well controlled', 1.0),
        AnswerOption('unsure', 'Not sure / never tested', 0.35),
      ],
    ),
    AssessmentQuestion(
      id: 'e_blood_pressure',
      section: AssessmentSection.medical,
      prompt: 'Do you have high blood pressure?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('borderline', 'Borderline', 0.4),
        AnswerOption('medicated', 'Yes, controlled with medication', 0.6),
        AnswerOption('uncontrolled', 'Yes, not well controlled', 1.0),
        AnswerOption('unsure', 'Not sure', 0.3),
      ],
    ),
    AssessmentQuestion(
      id: 'e_weight_status',
      section: AssessmentSection.medical,
      prompt: 'Has a clinician raised your weight as a health concern?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('overweight', 'Told I am overweight', 0.5),
        AnswerOption('obese', 'Told I am obese', 1.0),
        AnswerOption('underweight', 'Told I am underweight', 0.4),
      ],
    ),
    AssessmentQuestion(
      id: 'e_thyroid',
      section: AssessmentSection.medical,
      prompt: 'Any thyroid condition?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('treated', 'Yes, treated and stable', 0.3),
        AnswerOption('hyper', 'Overactive thyroid', 0.5),
        AnswerOption('hypo', 'Underactive thyroid', 0.6),
      ],
    ),
    AssessmentQuestion(
      id: 'e_heart',
      section: AssessmentSection.medical,
      prompt: 'Any heart or cholesterol issues?',
      helper:
          'Erectile arteries are narrower than coronary arteries, so '
          'erection changes can be an early circulation signal worth checking.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'None', 0.0),
        AnswerOption('family', 'Family history only', 0.35),
        AnswerOption('cholesterol', 'High cholesterol', 0.5),
        AnswerOption('diagnosed', 'Diagnosed heart disease', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'e_testosterone',
      section: AssessmentSection.medical,
      prompt: 'Low testosterone symptoms or diagnosis?',
      helper:
          'Symptoms include low drive, fatigue, low mood, loss of muscle '
          'and morning erections.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('symptoms', 'I have some of these symptoms', 0.6),
        AnswerOption('diagnosed', 'Diagnosed by blood test', 1.0),
        AnswerOption('treated', 'Diagnosed and on treatment', 0.5),
      ],
    ),
    AssessmentQuestion(
      id: 'e_mood',
      section: AssessmentSection.medical,
      prompt: 'Have you experienced depression or an anxiety disorder?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('no', 'No', 0.0),
        AnswerOption('past', 'In the past, not now', 0.35),
        AnswerOption('current', 'Currently, undiagnosed', 0.75),
        AnswerOption('diagnosed', 'Currently, diagnosed', 0.9),
        AnswerOption(
          'medicated',
          'Currently taking medication for it',
          1.0,
          detail:
              'Some antidepressants affect erections and ejaculation. '
              'Never stop or change a prescription on your own.',
        ),
      ],
    ),
  ];

  // ------------------------------------------------------------------
  // Section F - Mind & relationship
  // ------------------------------------------------------------------
  static const List<AssessmentQuestion> _psychological = <AssessmentQuestion>[
    AssessmentQuestion(
      id: 'f_performance_anxiety',
      section: AssessmentSection.psychological,
      prompt: 'Do you feel anxious about how you will perform during sex?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('none', 'Never', 0.0),
        AnswerOption('slight', 'Occasionally', 0.3),
        AnswerOption('moderate', 'Often', 0.6),
        AnswerOption('high', 'Almost every time', 0.85),
        AnswerOption('severe', 'I avoid sex because of it', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'f_relationship',
      section: AssessmentSection.psychological,
      prompt: 'How are things between you and your partner?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('na', 'No current partner', 0.2),
        AnswerOption('good', 'Close and communicative', 0.0),
        AnswerOption('tension', 'Some tension', 0.35),
        AnswerOption('conflict', 'Frequent conflict', 0.7),
        AnswerOption('distant', 'Emotionally distant', 0.85),
      ],
    ),
    AssessmentQuestion(
      id: 'f_porn',
      section: AssessmentSection.psychological,
      prompt: 'How often do you watch pornography?',
      helper:
          'Heavy, novelty-driven use can recalibrate what your brain '
          'treats as arousing. We ask without judgement.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('never', 'Never or rarely', 0.0),
        AnswerOption('weekly', 'A few times a week', 0.4),
        AnswerOption('daily', 'Daily', 0.75),
        AnswerOption('compulsive', 'Several times a day, hard to stop', 1.0),
      ],
    ),
    AssessmentQuestion(
      id: 'f_masturbation',
      section: AssessmentSection.psychological,
      prompt: 'How often do you masturbate?',
      helper:
          'Normal and healthy. It only matters here if the technique or '
          'frequency differs sharply from partnered sex.',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('rare', 'Rarely', 0.0),
        AnswerOption('weekly', '2-3 times a week', 0.15),
        AnswerOption('daily', 'Daily', 0.5),
        AnswerOption('multiple', 'Several times a day', 0.9),
      ],
    ),
    AssessmentQuestion(
      id: 'f_work_stress',
      section: AssessmentSection.psychological,
      prompt: 'How demanding is your work or study life right now?',
      kind: AnswerKind.single,
      options: <AnswerOption>[
        AnswerOption('low', 'Manageable', 0.0),
        AnswerOption('mild', 'Busy but fine', 0.3),
        AnswerOption('moderate', 'Frequently overloaded', 0.6),
        AnswerOption('high', 'Constant pressure', 0.85),
        AnswerOption('burnout', 'I feel burnt out', 1.0),
      ],
    ),
  ];
}
