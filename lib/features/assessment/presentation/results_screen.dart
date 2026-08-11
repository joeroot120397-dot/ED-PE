import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../domain/assessment_result.dart';
import '../domain/root_cause.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, this.showContinue = true});

  final bool showContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AssessmentResult?> async = ref.watch(
      assessmentResultProvider,
    );

    return VitalScaffold(
      title: 'Your results',
      padBody: false,
      disclaimer: Disclaimers.scoreExplainer,
      actions: <Widget>[
        IconButton(
          tooltip: 'Retake assessment',
          icon: const Icon(Icons.refresh),
          onPressed: () => context.go('/assessment'),
        ),
      ],
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.error_outline,
          title: 'We could not load your results',
          message: 'Your answers are safe. Try reopening this screen.',
          action: FilledButton(
            onPressed: () => ref.invalidate(assessmentResultProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (AssessmentResult? result) {
          if (result == null) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No assessment yet',
              message:
                  'Complete the five-minute assessment to see your scores and '
                  'root-cause breakdown.',
              action: FilledButton(
                onPressed: () => context.go('/assessment'),
                child: const Text('Start assessment'),
              ),
            );
          }
          return _Results(result: result, showContinue: showContinue);
        },
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, required this.showContinue});

  final AssessmentResult result;
  final bool showContinue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: <Widget>[
        // ---- Headline -------------------------------------------------
        Text(
          result.headline,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.summary,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.55,
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---- Scores ---------------------------------------------------
        SectionCard(
          title: 'Your scores',
          subtitle: 'Self-reported, on a 0-100 scale',
          leadingIcon: Icons.insights_outlined,
          child: Column(
            children: <Widget>[
              Center(
                child: ScoreRing(
                  value: result.scores.sexualHealthScore,
                  label: 'Sexual health',
                  caption: result.scores.sexualHealthBand,
                  higherIsBetter: true,
                  size: 150,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  ScoreRing(
                    value: result.scores.edRiskScore,
                    label: 'ED risk',
                    caption: HealthScores.riskBand(result.scores.edRiskScore),
                    higherIsBetter: false,
                    size: 94,
                    strokeWidth: 9,
                  ),
                  ScoreRing(
                    value: result.scores.peRiskScore,
                    label: 'PE risk',
                    caption: HealthScores.riskBand(result.scores.peRiskScore),
                    higherIsBetter: false,
                    size: 94,
                    strokeWidth: 9,
                  ),
                  ScoreRing(
                    value: result.scores.lifestyleScore,
                    label: 'Lifestyle',
                    higherIsBetter: true,
                    size: 94,
                    strokeWidth: 9,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  'Sexual health and lifestyle are scored so higher is '
                  'better. ED risk and PE risk are the opposite - lower is '
                  'better there.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- Body metrics --------------------------------------------
        SectionCard(
          title: 'Your numbers',
          leadingIcon: Icons.straighten,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'BMI',
                  value: result.metrics.bmi.toStringAsFixed(1),
                  caption: result.metrics.bmiBand,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Waist / height',
                  value: result.metrics.waistToHeight.toStringAsFixed(2),
                  caption: result.metrics.waistToHeight < 0.5
                      ? 'Below 0.5 - good'
                      : 'Aim for under 0.5',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Waist',
                  value: '${result.metrics.waistCm.round()} cm',
                  caption: 'Target ${(result.metrics.heightCm / 2).round()} cm',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- Root causes ---------------------------------------------
        SectionCard(
          title: 'What is driving it',
          subtitle: result.isMultifactorial
              ? 'Several factors, which usually reinforce each other'
              : 'Ranked by confidence from your answers',
          leadingIcon: Icons.account_tree_outlined,
          child: Column(
            children: <Widget>[
              for (final CauseConfidence cause in result.causes) ...<Widget>[
                ConfidenceBar(
                  value: cause.confidence,
                  label: cause.cause.title,
                  trailing: cause.isRelevant ? cause.band : null,
                ),
                if (cause.isPrimary)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Text(
                      cause.cause.explanation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted(context),
                        height: 1.45,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- Clinical flags -------------------------------------------
        if (result.flags.isNotEmpty) ...<Widget>[
          SectionCard(
            title: 'Worth raising with a doctor',
            subtitle:
                '${result.flags.length} '
                '${result.flags.length == 1 ? 'topic' : 'topics'} an app '
                'cannot assess',
            leadingIcon: Icons.local_hospital_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const DisclaimerBanner(
                  text: Disclaimers.referralPrompt,
                  icon: Icons.medical_information_outlined,
                  tone: BannerTone.caution,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final ClinicalFlag flag in result.flags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.flag_outlined,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                flag.title,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            flag.guidance,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const DisclaimerBanner(
          text: Disclaimers.urgentCare,
          icon: Icons.emergency_outlined,
          tone: BannerTone.urgent,
        ),
        const SizedBox(height: AppSpacing.lg),

        if (showContinue)
          FilledButton.icon(
            onPressed: () => context.go('/today'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Build my 12-week plan'),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.muted(context),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
