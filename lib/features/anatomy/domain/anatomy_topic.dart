import 'package:meta/meta.dart';

/// One illustrated anatomy lesson.
@immutable
class AnatomyTopic {
  const AnatomyTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.semanticLabel,
    required this.body,
    required this.takeaways,
  });

  final String id;
  final String title;
  final String subtitle;

  /// SVG asset path.
  final String asset;

  /// Read aloud in place of the illustration by a screen reader.
  final String semanticLabel;

  final String body;

  /// Short bullets under the illustration.
  final List<String> takeaways;
}

abstract final class AnatomyLibrary {
  static const List<AnatomyTopic> all = <AnatomyTopic>[
    AnatomyTopic(
      id: 'reproductive_system',
      title: 'Male reproductive system',
      subtitle: 'The parts, and what each one does',
      asset: 'assets/illustrations/reproductive_system.svg',
      semanticLabel:
          'Side-view diagram showing the bladder, prostate, '
          'seminal vesicle, vas deferens, epididymis, testis, urethra and '
          'the paired corpora cavernosa of the penis.',
      body:
          'Two systems share the same exit. Urine leaves the bladder '
          'through the urethra; semen joins the same tube at the prostate. A '
          'valve at the bladder neck keeps them separate, which is why you '
          'cannot urinate with a full erection.\n\n'
          'The testes make sperm and around 95 percent of your testosterone. '
          'Sperm mature in the epididymis, travel up the vas deferens, and '
          'mix with fluid from the seminal vesicles and prostate - that '
          'fluid is most of the volume.\n\n'
          'The shaft is three cylinders. The paired corpora cavernosa on top '
          'do the work of an erection. The corpus spongiosum underneath '
          'carries the urethra and keeps it open.',
      takeaways: <String>[
        'The prostate sits directly above the pelvic floor - which is why '
            'pelvic floor training affects both urinary and sexual function',
        'Testosterone is made in the testes, not the penis; desire and '
            'erection are separate systems',
        'The corpora cavernosa are the erectile tissue that all training '
            'ultimately targets',
      ],
    ),
    AnatomyTopic(
      id: 'pelvic_floor',
      title: 'Pelvic floor muscles',
      subtitle: 'The muscles you are about to train',
      asset: 'assets/illustrations/pelvic_floor.svg',
      semanticLabel:
          'View from below of the male pelvic floor, showing the '
          'levator ani sling spanning the pelvic outlet, the paired '
          'ischiocavernosus muscles at the base of the penis, and the '
          'bulbospongiosus running along the midline.',
      body:
          'A hammock of muscle slung between the pubic bone at the front '
          'and the tailbone at the back. It holds up the organs above it, '
          'controls both sphincters, and does two specific jobs during sex.\n\n'
          'The ischiocavernosus squeezes the base of the penis during an '
          'erection. That squeeze drives internal pressure well above your '
          'blood pressure, which is the difference between "full" and '
          '"rigid".\n\n'
          'The bulbospongiosus contracts rhythmically during ejaculation and '
          'helps hold the venous seal. It is the muscle a trained man uses to '
          'delay ejaculation.\n\n'
          'The levator ani supports everything else and is what you feel when '
          'you lift during a Kegel.',
      takeaways: <String>[
        'These are voluntary skeletal muscles - they respond to training like '
            'any other muscle',
        'Strength is only half of it: they must also learn to release, which '
            'is what reverse Kegels train',
        'Sitting for long hours weakens them through simple disuse',
      ],
    ),
    AnatomyTopic(
      id: 'blood_flow',
      title: 'Blood flow and nitric oxide',
      subtitle: 'The chemistry an erection runs on',
      asset: 'assets/illustrations/blood_flow.svg',
      semanticLabel:
          'Flow diagram: arousal produces a nerve signal, which '
          'releases nitric oxide from the vessel lining, which relaxes '
          'smooth muscle, which widens arteries and compresses veins, '
          'producing a rigid erection. A panel lists smoking, high blood '
          'pressure, high blood sugar, visceral fat, inactivity and '
          'adrenaline as the factors that break the chain.',
      body:
          'Nitric oxide is the signalling molecule at the centre of the '
          'whole process. It is released by the endothelium, the single layer '
          'of cells lining every blood vessel you have.\n\n'
          'When it reaches the smooth muscle in the arterial walls, that '
          'muscle relaxes. Relaxed arteries widen, blood floods the corpora, '
          'and the swelling pinches the draining veins shut against the outer '
          'sheath. Blood is trapped, pressure rises, and you get rigidity.\n\n'
          'Every risk factor for erectile difficulty damages this one '
          'pathway. Smoking poisons the endothelium. High blood sugar '
          'glycates it. Visceral fat inflames it. Inactivity lets it '
          'stiffen. Adrenaline overrides it outright.\n\n'
          'The good news is that the endothelium is highly responsive to '
          'training - aerobic exercise measurably improves its function '
          'within weeks.',
      takeaways: <String>[
        'The endothelium is trainable tissue, and cardio is how you train it',
        'Erectile arteries are narrower than coronary arteries, so problems '
            'show up here first - often years earlier',
        'Adrenaline works directly against nitric oxide, which is the '
            'mechanism behind performance anxiety',
      ],
    ),
    AnatomyTopic(
      id: 'erection_physiology',
      title: 'Erection physiology',
      subtitle: 'What actually changes between flaccid and erect',
      asset: 'assets/illustrations/erection_physiology.svg',
      semanticLabel:
          'Two cross-sections side by side. Flaccid: small '
          'corpora, constricted arteries, open veins. Erect: expanded '
          'corpora, dilated arteries, and veins flattened shut against the '
          'outer sheath.',
      body:
          'At rest, the smooth muscle inside the corpora is contracted, '
          'arteries are narrow, and the veins drain freely. Blood passes '
          'through and leaves.\n\n'
          'On arousal the smooth muscle relaxes. Inflow can rise many times '
          'over. The corpora expand until they press the draining veins '
          'against the tunica albuginea, the tough fibrous sheath around '
          'them. That compression is the venous seal, and it is what turns '
          'inflow into pressure.\n\n'
          'Two distinct failures follow from this. If the arteries cannot '
          'widen, you never get hard - a vascular problem. If they widen but '
          'the seal leaks, you get hard and then lose it - a venous problem, '
          'and the one pelvic floor training most directly helps.',
      takeaways: <String>[
        'Losing firmness partway through usually points at the seal, not at '
            'inflow',
        'The ischiocavernosus muscle actively reinforces that seal - which '
            'is why it is trainable',
        'Rigidity requires pressure inside the corpora to exceed arterial '
            'pressure, which muscle contraction is what achieves',
      ],
    ),
    AnatomyTopic(
      id: 'ejaculation_process',
      title: 'The ejaculation reflex',
      subtitle: 'Two phases, and where control lives',
      asset: 'assets/illustrations/ejaculation_process.svg',
      semanticLabel:
          'An arousal curve rising to a red dashed line marked '
          '"point of no return". Before it, phase one, emission, driven by '
          'sympathetic nerves. After it, phase two, expulsion, driven by '
          'rhythmic bulbospongiosus contractions about every 0.8 seconds.',
      body:
          'Ejaculation is a spinal reflex with two stages.\n\n'
          'Emission comes first: sympathetic nerves trigger the vas deferens, '
          'seminal vesicles and prostate to load the urethra. Once emission '
          'starts you have crossed the point of no return, and the rest '
          'completes whether you want it to or not.\n\n'
          'Expulsion follows: the bulbospongiosus contracts rhythmically, '
          'roughly every 0.8 seconds, propelling semen out.\n\n'
          'Control therefore lives entirely *before* the red line. This is '
          'why stop-start training works - it is not about fighting the '
          'reflex, it is about learning to recognise where the line is and '
          'staying on the right side of it for longer. A trained pelvic floor '
          'gives you a physical brake to use while you are still there.',
      takeaways: <String>[
        'Once emission begins, nothing stops it - all control happens earlier',
        'Arousal awareness is the trainable skill; the reflex itself is not',
        'A pelvic floor that can contract on demand gives you a brake, and '
            'one that can relax keeps the reflex further away',
      ],
    ),
  ];

  static AnatomyTopic byId(String id) =>
      all.firstWhere((AnatomyTopic t) => t.id == id);
}
