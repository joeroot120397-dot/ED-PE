import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../assessment/domain/question_bank.dart';

@immutable
class _Slide {
  const _Slide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> points;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    icon: Icons.favorite_outline,
    eyebrow: 'Erections',
    title: 'An erection is a blood-flow event, not a character test',
    body:
        'Arousal releases nitric oxide, arteries widen, blood fills two '
        'spongy cylinders, and the swelling pinches the draining veins shut. '
        'Anything that harms your blood vessels, hormones or nervous system '
        'shows up here - often years before it shows up anywhere else.',
    points: <String>[
      'Around 1 in 5 men experience it; most never mention it to anyone',
      'The penile arteries are narrower than the coronary arteries, so they '
          'give warning first',
      'The majority of causes are things you can influence',
    ],
  ),
  _Slide(
    icon: Icons.timer_outlined,
    eyebrow: 'Ejaculation',
    title: 'Control is a trained skill, not a fixed trait',
    body:
        'Ejaculation is a two-stage spinal reflex. Once the first stage '
        'starts, nothing stops it - which means all control happens before '
        'that point. Learning to recognise where the line is, and having a '
        'trained muscle to slow things down, is what actually works.',
    points: <String>[
      'The median time across large studies is about 5 minutes - there is no '
          '"correct" number',
      'Anxiety about finishing early is itself one of the main causes',
      'Both strength and relaxation of the pelvic floor matter here',
    ],
  ),
  _Slide(
    icon: Icons.fitness_center_outlined,
    eyebrow: 'Pelvic floor',
    title: 'The muscles almost nobody trains',
    body:
        'The ischiocavernosus drives rigidity by squeezing the base of the '
        'penis. The bulbospongiosus gates ejaculation. Both are voluntary '
        'skeletal muscles, and both respond to training like any other '
        'muscle in your body.',
    points: <String>[
      'Trials of pelvic floor training report most men improving over 3 to 6 '
          'months',
      'Most men do Kegels wrong - we will walk you through finding the muscle',
      'The release is a separate skill from the squeeze, and it is the half '
          'that gets skipped',
    ],
  ),
  _Slide(
    icon: Icons.restaurant_outlined,
    eyebrow: 'Diet & lifestyle',
    title: 'Sleep, waist and movement set the ceiling',
    body:
        'Most testosterone is released while you sleep. Abdominal fat '
        'converts testosterone to oestrogen. Sitting all day weakens the '
        'pelvic floor through disuse. None of this is glamorous, and all of '
        'it moves the needle more than any supplement.',
    points: <String>[
      'A week of 5-hour nights measurably lowers testosterone',
      'Losing 5 to 10 percent of body weight improves erectile function',
      'Dietary nitrates and flavonoids support the same pathway an erection '
          'runs on',
    ],
  ),
  _Slide(
    icon: Icons.assignment_outlined,
    eyebrow: 'Your turn',
    title: 'A short assessment, then a plan built for your causes',
    body:
        '{questionCount} questions about your body, symptoms, lifestyle, '
        'health history and state of mind. It takes about five minutes. '
        'Nothing is shared with anyone, and every answer stays encrypted on '
        'your device.',
    points: <String>[
      'You get a root-cause breakdown with confidence percentages',
      'A 12-week training programme built from those causes',
      'A nutrition plan calculated from your own numbers',
    ],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    await ref.read(repositoryProvider).markOnboardingSeen();
    if (mounted) context.go('/assessment');
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return VitalScaffold(
      padBody: false,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'VitalRise',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                if (!_isLast)
                  TextButton(onPressed: _finish, child: const Text('Skip')),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int i) =>
                  _SlideView(slide: _slides[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: i == _index ? 22 : 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_isLast)
                  const DisclaimerBannerCompact(
                    text: Disclaimers.assessmentIntro,
                  ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Start the assessment' : 'Continue'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(slide.icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            slide.eyebrow.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            // Substituted rather than hard-coded: the intake grew from 28
            // to 33 questions during development and this copy silently
            // kept claiming the old number.
            slide.body.replaceAll('{questionCount}', '${QuestionBank.count}'),
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color: AppColors.muted(context),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BulletList(items: slide.points),
        ],
      ),
    );
  }
}

/// Compact variant of the disclaimer used inside flows where the standing
/// footer is present but a specific framing helps.
class DisclaimerBannerCompact extends StatelessWidget {
  const DisclaimerBannerCompact({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, height: 1.4),
      ),
    );
  }
}
