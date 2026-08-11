import 'article.dart';

/// The VitalRise education library.
///
/// This is also the AI coach's knowledge base (see
/// `lib/features/coach/domain/knowledge_base.dart`), so the two can never
/// drift apart: what the coach says is what the article says.
///
/// Editorial rules for anything added here:
/// * Explain mechanisms, never diagnose.
/// * Never name a prescription medication as a recommendation.
/// * Always point to a clinician where a clinician is the right answer.
abstract final class ArticleLibrary {
  static const List<Article> all = <Article>[
    // ================================================================
    Article(
      id: 'understanding_ed',
      title: 'Understanding erectile difficulty',
      topic: ArticleTopic.erectile,
      summary:
          'What actually happens during an erection, why it fails, and '
          'what the pattern of failure tells you about the cause.',
      readMinutes: 7,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'An erection is a blood-flow event',
          body:
              'An erection is not a muscle flexing. It is hydraulics.\n\n'
              'When you become aroused, nerves release nitric oxide into the '
              'two spongy cylinders that run along the top of the penis, the '
              'corpora cavernosa. Nitric oxide relaxes the smooth muscle in '
              'the walls of the arteries feeding them. Relaxed arteries widen, '
              'blood rushes in, and the cylinders swell.\n\n'
              'That swelling presses the veins that would normally drain the '
              'penis against the tough outer sheath, the tunica albuginea. The '
              'exit is squeezed shut. Blood goes in faster than it comes out, '
              'pressure rises, and you get rigidity.\n\n'
              'So an erection needs four things working at once: a nervous '
              'system that is relaxed enough to send the signal, arteries '
              'healthy enough to widen, enough testosterone for desire to '
              'start the process, and a functioning venous seal to keep the '
              'blood in.',
          keywords: <String>[
            'how erections work',
            'nitric oxide',
            'blood flow',
            'corpora cavernosa',
            'physiology',
          ],
        ),
        ArticleSection(
          heading: 'Where it breaks, and what that tells you',
          body:
              'Different causes produce different patterns, which is why '
              'the assessment asks about the shape of the problem rather than '
              'just its presence.\n\n'
              'Trouble getting hard at all, gradually worsening over years, '
              'with morning erections also fading, usually points at the '
              'arteries. This is the same disease process as heart disease, '
              'showing up earlier because penile arteries are much narrower '
              'than coronary arteries.\n\n'
              'Getting hard fine but losing it partway through often points '
              'at the venous seal or the pelvic floor muscles that support '
              'it, or at anxiety cutting in once performance becomes the '
              'focus.\n\n'
              'Working perfectly alone or on waking, but failing with a '
              'partner, is almost always psychological rather than vascular. '
              'The plumbing is demonstrably intact.\n\n'
              'Sudden onset in a healthy young man, especially tied to a new '
              'partner, new stress or a new medication, is rarely a vascular '
              'problem.',
          keywords: <String>[
            'why do I lose my erection',
            'lose erection during sex',
            'morning wood',
            'sudden',
            'pattern',
          ],
        ),
        ArticleSection(
          heading: 'Why anxiety is so effective at preventing erections',
          body:
              'Erections are parasympathetic - the "rest and digest" branch '
              'of the nervous system. Anxiety is sympathetic: "fight or '
              'flight".\n\n'
              'These two systems are directly opposed. Adrenaline constricts '
              'the exact smooth muscle that nitric oxide needs to relax. '
              'Physiologically, being anxious about getting an erection is '
              'close to the most efficient way to prevent one.\n\n'
              'That produces a self-sustaining loop. One difficult episode '
              'creates worry. The worry raises adrenaline the next time. The '
              'adrenaline causes another difficult episode. Within a few '
              'cycles, the original trigger no longer matters - the fear of '
              'recurrence is now the whole cause.\n\n'
              'Breaking the loop is a skill, not willpower. The breathing '
              'work in your programme and the pre-intimacy reset routine are '
              'the tools for it.',
          keywords: <String>[
            'anxiety',
            'performance anxiety',
            'stress',
            'adrenaline',
            'nervous',
          ],
        ),
        ArticleSection(
          heading: 'How long until things change',
          body:
              'Honest timelines, assuming you actually do the work:\n\n'
              'Pelvic floor training: most men notice a change in firmness '
              'and control somewhere between weeks 4 and 6. Controlled trials '
              'of pelvic floor training for erectile difficulty have run for '
              'three to six months, with a substantial share of men returning '
              'to normal function and most of the rest improving.\n\n'
              'Cardiovascular exercise: vessel-lining function starts '
              'improving within 2 to 4 weeks of regular aerobic work, though '
              'the change you can feel usually takes 8 to 12 weeks.\n\n'
              'Weight loss: meaningful improvement typically follows a loss '
              'of around 5 to 10 percent of body weight.\n\n'
              'Quitting smoking: measurable vascular improvement within weeks, '
              'with continued gains over the following year.\n\n'
              'Sleep: this one is fast. Testosterone responds to a week of '
              'proper sleep.\n\n'
              'Anxiety work: highly variable. Some men see a change in days '
              'once the pressure comes off; entrenched patterns take months '
              'and often benefit from a therapist.',
          keywords: <String>[
            'how long',
            'timeline',
            'results',
            'when will I improve',
            'weeks',
          ],
        ),
        ArticleSection(
          heading: 'When to see a doctor rather than an app',
          body:
              'Book an appointment if any of these apply.\n\n'
              'Erection difficulty that came on suddenly and has persisted, '
              'particularly after starting a new medication.\n\n'
              'You have diabetes, high blood pressure, high cholesterol or a '
              'family history of early heart disease. Erectile difficulty is '
              'an early cardiovascular warning sign and deserves a proper '
              'workup, not an app.\n\n'
              'Loss of morning erections together with fatigue, low mood and '
              'loss of muscle - that combination warrants a morning '
              'testosterone blood test.\n\n'
              'Pain with erection, a curve that has developed or worsened, or '
              'any injury to the area.\n\n'
              'You are taking antidepressants, blood pressure medication or '
              'finasteride and noticed the change after starting them. Do not '
              'stop anything on your own - a prescriber can often switch you '
              'to an alternative.\n\n'
              'Seek urgent care for an erection lasting more than four hours, '
              'or for chest pain during exertion or sex.',
          keywords: <String>[
            'see a doctor',
            'when to worry',
            'medication',
            'antidepressants',
            'urgent',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'understanding_pe',
      title: 'Understanding early ejaculation',
      topic: ArticleTopic.ejaculation,
      summary:
          'What is normal, what drives early ejaculation, and the '
          'techniques with actual evidence behind them.',
      readMinutes: 6,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'What counts as early',
          body:
              'The median time from penetration to ejaculation across large '
              'international studies is roughly 5 to 6 minutes. The spread is '
              'enormous and completely normal.\n\n'
              'Clinically, "premature ejaculation" is usually defined as '
              'ejaculation within about a minute of penetration, that you '
              'cannot delay, and that causes you distress. All three parts '
              'matter, and the third is the one men skip.\n\n'
              'If you last four minutes and are unhappy about it, the useful '
              'target is not a stopwatch number - it is control and '
              'confidence. Plenty of men chasing an arbitrary benchmark from '
              'pornography have entirely normal function.',
          keywords: <String>[
            'how long should sex last',
            'average time',
            'normal',
            'premature ejaculation definition',
          ],
        ),
        ArticleSection(
          heading: 'Lifelong versus acquired',
          body:
              'Lifelong early ejaculation has been present since your first '
              'sexual experiences. It is largely neurobiological, tied to '
              'serotonin signalling and receptor sensitivity, and it responds '
              'best to a combination of behavioural training and, where '
              'appropriate, medical treatment a doctor can discuss with you.\n\n'
              'Acquired early ejaculation appeared after a period of normal '
              'control. This is the more hopeful version, because there is '
              'usually something identifiable behind it: anxiety, relationship '
              'stress, thyroid problems, prostatitis, or - very commonly - '
              'erectile difficulty.\n\n'
              'That last link is worth spelling out. Men who are worried '
              'about losing an erection often unconsciously rush to finish '
              'before it fails. Treating the erection problem resolves the '
              'ejaculation problem, and treating them separately gets nowhere.',
          keywords: <String>[
            'lifelong',
            'acquired',
            'always been this way',
            'started recently',
            'causes',
          ],
        ),
        ArticleSection(
          heading: 'The pelvic floor connection',
          body:
              'Ejaculation is a reflex with two stages: emission, then '
              'expulsion. The expulsion stage is driven by rhythmic '
              'contraction of the bulbospongiosus muscle - part of the pelvic '
              'floor.\n\n'
              'A pelvic floor you can consciously control gives you a brake '
              'on that reflex. Trials of pelvic floor training for lifelong '
              'early ejaculation have reported that a majority of men achieve '
              'clinically meaningful increases in latency after around 12 '
              'weeks of consistent work.\n\n'
              'Both directions matter. Strength training gives you the '
              'ability to clamp down. Relaxation training - the reverse Kegel '
              '- matters just as much, because a chronically tight pelvic '
              'floor sits closer to its firing threshold and goes off sooner.',
          keywords: <String>[
            'kegels for premature ejaculation',
            'pelvic floor',
            'bulbospongiosus',
            'last longer',
          ],
        ),
        ArticleSection(
          heading: 'Techniques that work',
          body:
              'Stop-start. During masturbation or sex, build arousal to '
              'roughly 7 or 8 out of 10, then stop completely until it falls '
              'back to about 4. Repeat three times, then finish. Practised '
              'two or three times a week, this teaches you to recognise the '
              'point of no return before you cross it.\n\n'
              'The squeeze technique. At high arousal, firmly squeeze just '
              'below the head of the penis for several seconds until the urge '
              'passes. Older and less popular than stop-start, but effective '
              'for some men.\n\n'
              'Arousal mapping. Most men have no vocabulary for their own '
              'arousal beyond "fine" and "too late". Deliberately rating it 1 '
              'to 10 during practice builds the awareness that control '
              'depends on.\n\n'
              'Breathing. Slow diaphragmatic breathing at high arousal '
              'directly counteracts the sympathetic surge that triggers the '
              'reflex.\n\n'
              'Reduce the arousal gap. If you masturbate with a much firmer '
              'grip or far more speed than partnered sex provides, you have '
              'trained yourself to a stimulus that sex cannot match. Closing '
              'that gap for a few weeks helps a surprising number of men.',
          keywords: <String>[
            'stop start',
            'squeeze technique',
            'how to last longer',
            'exercises',
            'edging',
          ],
        ),
        ArticleSection(
          heading: 'What not to do',
          body:
              'Do not rely on numbing sprays and creams as a strategy. They '
              'can help short term, but they reduce your sensation - and '
              'often your partner\'s - and they teach you nothing, so the '
              'problem is unchanged the day you run out.\n\n'
              'Do not distract yourself with unpleasant mental images. It '
              'works occasionally and it makes sex worse, while training you '
              'to disconnect from your own body during intimacy.\n\n'
              'Do not treat it as a solo problem in a relationship. Partners '
              'almost always know something is wrong, and in the absence of '
              'information they usually assume it is about attraction. A '
              'direct conversation removes more pressure than any technique.\n\n'
              'Do not chase a number. The goal is control and mutual '
              'satisfaction, not a stopwatch.',
          keywords: <String>[
            'numbing spray',
            'delay spray',
            'distraction',
            'partner',
            'mistakes',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'pelvic_floor_training',
      title: 'Pelvic floor training, properly',
      topic: ArticleTopic.pelvicFloor,
      summary:
          'How to find the muscle, how to train both halves of its '
          'function, and the mistakes that waste months.',
      readMinutes: 6,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'What the pelvic floor does for erections',
          body:
              'The pelvic floor is a hammock of muscle slung between the '
              'pubic bone and tailbone. Three parts of it matter here.\n\n'
              'The ischiocavernosus compresses the base of the penis during '
              'an erection, driving internal pressure well above your blood '
              'pressure. That is what produces genuine rigidity rather than '
              'partial fullness.\n\n'
              'The bulbospongiosus contracts rhythmically during ejaculation '
              'and helps maintain the venous seal.\n\n'
              'The levator ani supports the whole pelvic organ system.\n\n'
              'Weak versions of these muscles produce a recognisable pattern: '
              'you get hard, but not fully rigid, and you lose it partway '
              'through. If that is your pattern, this is your highest-yield '
              'training.',
          keywords: <String>[
            'pelvic floor anatomy',
            'ischiocavernosus',
            'what muscles',
            'rigidity',
          ],
        ),
        ArticleSection(
          heading: 'Finding the muscle',
          body:
              'Three reliable methods.\n\n'
              'The wind method: contract as though stopping yourself passing '
              'wind. This isolates the back portion.\n\n'
              'The mirror method: with an erection, try to make the penis lift '
              'without using any other muscle. That movement is the pelvic '
              'floor.\n\n'
              'The urine method, used once only as a test: briefly slow your '
              'urine stream to identify the sensation. Do not train this way '
              'repeatedly - it interferes with normal bladder emptying.\n\n'
              'The check that matters: place one hand on your abdomen and one '
              'on your glutes. If either moves during a contraction, you are '
              'recruiting the wrong muscles. Your breathing should stay '
              'completely normal.',
          keywords: <String>[
            'how to do kegels',
            'find the muscle',
            'which muscle',
            'am I doing it right',
          ],
        ),
        ArticleSection(
          heading: 'Train both directions',
          body:
              'This is the part almost every guide gets wrong.\n\n'
              'A muscle is only strong through a full range. Training '
              'contraction alone, thousands of reps deep, produces a pelvic '
              'floor that is short, tight and permanently half-contracted - '
              'which is weak, not strong.\n\n'
              'An over-tight pelvic floor causes its own problems: pelvic '
              'pain, urinary urgency, and early ejaculation, because a muscle '
              'already near its firing threshold triggers sooner.\n\n'
              'That is why reverse Kegels are in your programme from day one. '
              'They train the lengthening half - letting go, widening, '
              'dropping - and for a lot of men with early ejaculation they '
              'matter more than the squeeze.\n\n'
              'A simple diagnostic: if Kegels feel like effort but you cannot '
              'clearly feel a release afterwards, you are probably already '
              'tight. Spend two weeks on reverse Kegels and breathing before '
              'adding strength work.',
          keywords: <String>[
            'reverse kegels',
            'too tight',
            'hypertonic',
            'relaxation',
            'pelvic pain',
          ],
        ),
        ArticleSection(
          heading: 'Programming that actually progresses',
          body:
              'Weeks 1 to 4, foundation: 3 sets of 8 to 10 contractions, 3 '
              'second holds, most days. Add reverse Kegels. The goal is a '
              'clean, isolated contraction, not volume.\n\n'
              'Weeks 5 to 8, build: introduce long holds, working toward 10 '
              'seconds, and quick pulses for the fast-twitch fibres. Add '
              'glute bridges and squats.\n\n'
              'Weeks 9 to 12, transfer: functional Kegels standing, in a '
              'squat, and during movement. Strength that only exists lying '
              'down does not help you during sex.\n\n'
              'More is not better. The pelvic floor is a small muscle group '
              'and it fatigues. Training it hard twice a day will make it '
              'sore and tight, not strong. Six days a week at the prescribed '
              'volume beats a heroic daily grind.',
          keywords: <String>[
            'how many kegels',
            'sets and reps',
            'programme',
            'progression',
            'how often',
          ],
        ),
        ArticleSection(
          heading: 'Common mistakes',
          body:
              'Holding your breath. If you cannot talk through a '
              'contraction, you are bracing, not contracting.\n\n'
              'Bearing down instead of lifting up. This is the opposite '
              'movement and it makes things worse over time.\n\n'
              'Recruiting glutes, thighs and abs. Check with your hands.\n\n'
              'Skipping the release. The relaxation is a separate trained '
              'skill.\n\n'
              'Doing them only when you remember. Anchor the session to '
              'something you already do every day.\n\n'
              'Quitting at week three. Muscle adaptation is not fast. Most '
              'men who report no benefit stopped before the point where the '
              'benefit shows up.',
          keywords: <String>[
            'mistakes',
            'doing it wrong',
            'not working',
            'no results',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'testosterone_basics',
      title: 'Testosterone basics',
      topic: ArticleTopic.hormones,
      summary:
          'What testosterone does and does not control, what genuinely '
          'moves it, and why most supplements do not.',
      readMinutes: 6,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'What testosterone actually controls',
          body:
              'Testosterone drives sexual desire, muscle protein synthesis, '
              'bone density, red blood cell production, mood and energy.\n\n'
              'What it does not do is directly produce an erection. That is a '
              'blood-flow event. A man with low testosterone and healthy '
              'arteries can often get an erection but has little interest in '
              'doing so; a man with normal testosterone and damaged arteries '
              'wants sex and cannot perform.\n\n'
              'This distinction matters because it changes what to fix. Low '
              'desire with functioning erections points at hormones, sleep, '
              'mood or relationship factors. Strong desire with failing '
              'erections points at blood flow, the pelvic floor or anxiety.',
          keywords: <String>[
            'what does testosterone do',
            'low libido',
            'sex drive',
            'desire',
          ],
        ),
        ArticleSection(
          heading: 'Signs worth testing for',
          body:
              'Low testosterone is diagnosed on a blood test, not on '
              'symptoms and never on an app.\n\n'
              'The pattern that justifies asking for a test: persistently low '
              'desire, fatigue that sleep does not fix, loss of muscle despite '
              'training, increasing abdominal fat, low mood, reduced body '
              'hair, and loss of morning erections - several of these '
              'together, not one alone.\n\n'
              'If you are tested, the sample should be taken in the morning, '
              'ideally before 10am, because levels swing substantially across '
              'the day. A single borderline afternoon result means very '
              'little. Ask about free testosterone and SHBG as well as total, '
              'since total alone can be misleading.',
          keywords: <String>[
            'low testosterone symptoms',
            'blood test',
            'how to test',
            'trt',
          ],
        ),
        ArticleSection(
          heading: 'What genuinely raises it',
          body:
              'Sleep. This is the biggest lever most men have. The majority '
              'of daily testosterone release happens during sleep. One week '
              'of restricting healthy young men to five hours a night dropped '
              'daytime testosterone by 10 to 15 percent - equivalent to '
              'ageing them a decade.\n\n'
              'Losing abdominal fat. Fat tissue contains aromatase, an enzyme '
              'that converts testosterone into oestrogen. More abdominal fat '
              'means more conversion and less testosterone, which drives more '
              'fat storage. Losing weight breaks the loop.\n\n'
              'Resistance training. Compound movements using large muscle '
              'groups produce an acute post-exercise rise and, more '
              'importantly, improve body composition and insulin sensitivity '
              'over time.\n\n'
              'Correcting real deficiencies. Vitamin D, zinc and magnesium '
              'support production - but only supplementation of an actual '
              'deficiency helps. Topping up a man who is already replete does '
              'nothing.\n\n'
              'Reducing alcohol. Heavy drinking suppresses testicular '
              'function directly.\n\n'
              'Managing stress. Cortisol and testosterone are functionally '
              'opposed; chronically elevated cortisol suppresses production.',
          keywords: <String>[
            'how to increase testosterone',
            'boost testosterone',
            'naturally',
            'sleep',
            'zinc',
          ],
        ),
        ArticleSection(
          heading: 'What does not work',
          body:
              'Most "testosterone booster" supplements. The category is '
              'largely built on studies in deficient or infertile men, '
              'extrapolated to everyone else. Tribulus in particular has '
              'repeatedly failed to raise testosterone in controlled trials.\n\n'
              'Very low fat diets. Cholesterol is the raw material '
              'testosterone is built from. Cutting fat below roughly 20 '
              'percent of calories tends to lower it - which is why your '
              'nutrition targets keep fat intake up.\n\n'
              'Excessive endurance training. Very high volume with '
              'insufficient fuel can suppress the whole hormonal axis. This '
              'is not a risk for most men, but it is real for the ones '
              'training for endurance events.\n\n'
              'Testosterone therapy bought without supervision. Beyond the '
              'cardiovascular and clotting risks, external testosterone '
              'shuts down your own production and shrinks fertility, '
              'sometimes permanently. If therapy is genuinely indicated, it '
              'is a decision for you and a doctor with monitoring, not an '
              'online purchase.',
          keywords: <String>[
            'testosterone supplements',
            'boosters',
            'tribulus',
            'do supplements work',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'sleep_and_sexual_health',
      title: 'Sleep and sexual health',
      topic: ArticleTopic.sleep,
      summary:
          'The most underrated lever in the whole programme, and the '
          'fastest to respond.',
      readMinutes: 5,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'Why sleep sits underneath everything else',
          body:
              'Three things happen during sleep that bear directly on '
              'sexual function.\n\n'
              'Testosterone is released in pulses, overwhelmingly during '
              'sleep, with the largest surge tied to your first REM period. '
              'Cut sleep short and you cut the release.\n\n'
              'Nocturnal erections occur during REM - typically three to five '
              'per night, totalling an hour or more. These are not '
              'incidental. They oxygenate the erectile tissue. Without them, '
              'the smooth muscle gradually gets replaced with collagen, and '
              'the tissue loses elasticity permanently.\n\n'
              'The autonomic nervous system rebalances. Short sleep leaves '
              'you sympathetically dominant the next day - more adrenaline, '
              'more constriction, less of the parasympathetic state an '
              'erection requires.',
          keywords: <String>[
            'sleep and testosterone',
            'nocturnal erections',
            'REM',
            'why sleep matters',
          ],
        ),
        ArticleSection(
          heading: 'Sleep apnoea deserves its own paragraph',
          body:
              'Obstructive sleep apnoea is strongly associated with erectile '
              'difficulty, and it is badly underdiagnosed in men.\n\n'
              'It fragments sleep so you never reach sustained REM, it drops '
              'blood oxygen repeatedly through the night, it raises blood '
              'pressure, and it lowers testosterone.\n\n'
              'Suspect it if you snore loudly, wake unrefreshed after eight '
              'hours, have been told you stop breathing in your sleep, wake '
              'with headaches or a dry mouth, or fall asleep easily during '
              'the day.\n\n'
              'This is a medical issue with an effective medical treatment. '
              'Men who treat their apnoea frequently report improvements in '
              'erectile function as a side effect. If this sounds like you, '
              'raise it with a doctor - no amount of pelvic floor training '
              'substitutes for it.',
          keywords: <String>[
            'sleep apnoea',
            'apnea',
            'snoring',
            'tired',
            'cpap',
          ],
        ),
        ArticleSection(
          heading: 'What to change tonight',
          body:
              'Keep a fixed wake time, including weekends. Consistency of '
              'wake time regulates the whole rhythm more powerfully than '
              'bedtime does.\n\n'
              'Get daylight into your eyes within an hour of waking, for 10 '
              'minutes or more. This is the strongest signal your body clock '
              'receives.\n\n'
              'No caffeine within 8 to 10 hours of bed. Its half-life is '
              'about 5 to 6 hours, so a 4pm coffee still has a quarter of its '
              'dose circulating at midnight.\n\n'
              'Alcohol is not a sleep aid. It shortens the time to fall '
              'asleep and then suppresses REM and fragments the second half '
              'of the night - taking out exactly the sleep stage that '
              'produces testosterone and nocturnal erections.\n\n'
              'Cool and dark. Core temperature has to fall for sleep to '
              'consolidate; around 18°C suits most people.\n\n'
              'Screens matter less than what is on them. A stressful email at '
              '11pm costs you more than the light does.',
          keywords: <String>[
            'sleep hygiene',
            'how to sleep better',
            'caffeine',
            'alcohol sleep',
            'insomnia',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'weight_and_erections',
      title: 'Weight loss and erections',
      topic: ArticleTopic.weight,
      summary:
          'Why abdominal fat specifically, and how much you actually '
          'need to lose before things change.',
      readMinutes: 5,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'Four mechanisms, all pointing the same way',
          body:
              'Abdominal fat is not inert storage. It is metabolically '
              'active tissue that works against you in four distinct ways.\n\n'
              'Aromatase conversion. Fat tissue converts testosterone into '
              'oestrogen. More fat, less testosterone, and lower testosterone '
              'promotes further fat storage.\n\n'
              'Endothelial dysfunction. Visceral fat drives chronic '
              'low-grade inflammation that damages the lining of blood '
              'vessels - the tissue responsible for releasing nitric oxide. '
              'Less nitric oxide means arteries that will not widen.\n\n'
              'Insulin resistance. Abdominal fat drives it, and it damages '
              'both the small vessels and the nerves that erections need.\n\n'
              'Sleep apnoea. Neck and abdominal fat increase airway collapse, '
              'which brings all the sleep consequences with it.\n\n'
              'This is why waist measurement appears in the assessment. Waist '
              'circumference predicts sexual function better than weight or '
              'BMI, because it measures the fat that is doing the damage.',
          keywords: <String>[
            'belly fat',
            'visceral fat',
            'waist',
            'obesity',
            'aromatase',
          ],
        ),
        ArticleSection(
          heading: 'How much needs to go',
          body:
              'Less than most men assume.\n\n'
              'Studies of lifestyle intervention in men with obesity and '
              'erectile difficulty have found meaningful improvement in '
              'function after roughly a 5 to 10 percent reduction in body '
              'weight - for a 100 kg man, 5 to 10 kg.\n\n'
              'A useful target for waist is to keep it under half your '
              'height. At 175 cm, that means a waist under 87 cm.\n\n'
              'Speed is counterproductive. Aggressive deficits cost you '
              'muscle and suppress testosterone, which works against the '
              'thing you are trying to fix. Around 0.5 kg a week, with '
              'protein kept high and resistance training in place, keeps the '
              'loss coming from fat.',
          keywords: <String>[
            'how much weight',
            'how much to lose',
            'waist target',
            'bmi',
          ],
        ),
        ArticleSection(
          heading: 'Eat for blood vessels, not just for calories',
          body:
              'Two men can lose the same weight and get different results, '
              'because what you eat also affects the vessels directly.\n\n'
              'Dietary nitrates - beetroot, spinach, rocket, other leafy '
              'greens - convert to nitric oxide, the same molecule that '
              'drives an erection.\n\n'
              'Flavonoids - berries, citrus, dark chocolate, red grapes - are '
              'associated with lower rates of erectile difficulty in '
              'long-running cohort studies, with the strongest signal in '
              'younger men.\n\n'
              'Omega-3 fats from oily fish, walnuts and flaxseed improve '
              'vessel wall flexibility.\n\n'
              'The overall pattern beats any single food. Mediterranean-style '
              'eating - vegetables, whole grains, legumes, fish, olive oil, '
              'nuts - has the best evidence for improving erectile function, '
              'and it is roughly what your generated plan looks like.',
          keywords: <String>[
            'best foods for ED',
            'diet for erections',
            'beetroot',
            'mediterranean diet',
            'what to eat',
          ],
        ),
      ],
    ),

    // ================================================================
    Article(
      id: 'anxiety_management',
      title: 'Managing performance anxiety',
      topic: ArticleTopic.mind,
      summary:
          'The spectator loop, why willpower fails against it, and the '
          'techniques that break it.',
      readMinutes: 6,
      sections: <ArticleSection>[
        ArticleSection(
          heading: 'The spectator loop',
          body:
              'Researchers named this decades ago: spectatoring. Instead of '
              'being inside the experience, you are watching yourself from '
              'the outside, monitoring for signs of failure.\n\n'
              'The monitoring is the problem. Arousal is generated by '
              'attention to sensation. Attention spent on self-assessment is '
              'attention not spent on sensation, so arousal drops - which '
              'produces exactly the evidence you were watching for, which '
              'intensifies the monitoring.\n\n'
              'This is why willpower does not work. Trying harder means '
              'monitoring harder. The instruction "just relax" is worse than '
              'useless, because it adds a second thing to fail at.\n\n'
              'The exit is not to try harder. It is to move attention out of '
              'evaluation and back into physical sensation.',
          keywords: <String>[
            'performance anxiety',
            'spectatoring',
            'in my head',
            'overthinking',
            'anxious about sex',
          ],
        ),
        ArticleSection(
          heading: 'Techniques that break it',
          body:
              'Sensate focus. The best-evidenced approach there is. With a '
              'partner, agree to a period - typically a couple of weeks - '
              'where intercourse is off the table entirely. You touch, '
              'explore and receive pleasure with no expectation of an '
              'erection or an outcome. Removing the possibility of failure '
              'removes the anxiety, and function frequently returns on its '
              'own. Then reintroduce intercourse gradually.\n\n'
              'Sensory anchoring. When you notice yourself monitoring, '
              'deliberately move attention to something physical and specific: '
              'temperature, texture, pressure, your partner\'s breathing. Not '
              'a distraction from sex - a redirection deeper into it.\n\n'
              'Breathing before, not during. The pre-intimacy reset in your '
              'programme lowers baseline adrenaline before anything starts. '
              'Trying to calm down mid-episode rarely works.\n\n'
              'Talk to your partner. This is the single highest-yield action '
              'for most men and the one most avoided. In the absence of an '
              'explanation, partners overwhelmingly assume the problem is '
              'attraction. Saying "this is something I am working on, it is '
              'not about you" removes an enormous amount of pressure - and '
              'the pressure is the mechanism.',
          keywords: <String>[
            'sensate focus',
            'how to stop overthinking',
            'talk to partner',
            'relax during sex',
          ],
        ),
        ArticleSection(
          heading: 'Reframing what sex is for',
          body:
              'Performance anxiety needs a performance. Remove the '
              'performance frame and the anxiety loses its object.\n\n'
              'The frame most men carry is that sex is a test with a pass '
              'condition: erection achieved, intercourse completed, partner '
              'satisfied by that specific route. Under that frame every '
              'encounter is an exam.\n\n'
              'The alternative frame is that sex is shared pleasure, and '
              'intercourse is one of many ways to get there. That is not a '
              'consolation prize - it is how sex works for most couples most '
              'of the time, and it takes the load-bearing weight off a single '
              'physiological response.\n\n'
              'Practically: agree with your partner that a given encounter '
              'does not need to include intercourse. The paradox is well '
              'documented - when the requirement is removed, erections often '
              'turn up.',
          keywords: <String>['reframe', 'pressure', 'expectations', 'mindset'],
        ),
        ArticleSection(
          heading: 'When to bring in a professional',
          body:
              'Consider a psychologist or a sex therapist if anxiety about '
              'sex has led you to avoid intimacy altogether, if it is '
              'affecting your relationship or your mood more broadly, if '
              'there is sexual trauma in your history, or if you have worked '
              'consistently for three months without change.\n\n'
              'Sex therapy is talking therapy with a specific focus. It has a '
              'solid evidence base, it is usually short-term, and combining '
              'it with the physical work in this app outperforms either alone.\n\n'
              'If you have thoughts of harming yourself, contact a crisis '
              'line or emergency services now. That is not a coaching '
              'conversation.',
          keywords: <String>[
            'therapist',
            'sex therapy',
            'counselling',
            'professional help',
          ],
        ),
      ],
    ),
  ];

  static Article byId(String id) => all.firstWhere((Article a) => a.id == id);

  static List<Article> byTopic(ArticleTopic topic) =>
      all.where((Article a) => a.topic == topic).toList();

  static List<Article> search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (Article a) =>
              a.title.toLowerCase().contains(q) ||
              a.summary.toLowerCase().contains(q) ||
              a.plainText.toLowerCase().contains(q),
        )
        .toList();
  }
}
