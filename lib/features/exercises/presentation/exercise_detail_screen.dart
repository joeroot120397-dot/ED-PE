import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../assessment/domain/root_cause.dart';
import '../../habits/domain/habit_log.dart';
import '../domain/exercise.dart';
import '../domain/exercise_library.dart';
import 'widgets/exercise_animation_player.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    final Exercise exercise;
    try {
      exercise = ExerciseLibrary.byId(exerciseId);
    } on StateError {
      return const VitalScaffold(
        title: 'Exercise',
        body: EmptyState(
          icon: Icons.help_outline,
          title: 'Exercise not found',
          message: 'This exercise may have been renamed in a newer version.',
        ),
      );
    }

    return VitalScaffold(
      title: exercise.name,
      padBody: false,
      disclaimer: Disclaimers.exerciseSafety,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              VitalChip(label: exercise.category.label),
              VitalChip(
                label: exercise.difficulty.label,
                color: AppColors.info,
              ),
              VitalChip(label: exercise.dosage.label, color: AppColors.warning),
              VitalChip(
                label: '~${exercise.dosage.estimatedMinutes} min',
                color: AppColors.muted(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            exercise.summary,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),

          ExerciseAnimationPlayer(animation: exercise.animation),
          const SizedBox(height: AppSpacing.lg),

          SectionCard(
            title: 'How to do it',
            leadingIcon: Icons.list_alt,
            child: NumberedSteps(steps: exercise.instructions),
          ),
          const SizedBox(height: AppSpacing.md),

          SectionCard(
            title: 'Why it works',
            leadingIcon: Icons.biotech_outlined,
            child: BulletList(items: exercise.benefits),
          ),
          const SizedBox(height: AppSpacing.md),

          SectionCard(
            title: 'Common mistakes',
            subtitle: 'The reasons men get no result from this',
            leadingIcon: Icons.warning_amber_outlined,
            child: BulletList(
              items: exercise.commonMistakes,
              icon: Icons.close,
              iconColor: AppColors.danger,
              iconSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          SectionCard(
            title: 'Safety',
            leadingIcon: Icons.health_and_safety_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                BulletList(
                  items: exercise.safetyTips,
                  icon: Icons.shield_outlined,
                  iconColor: AppColors.warning,
                  iconSize: 14,
                ),
                if (exercise.contraindications.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  DisclaimerBanner(
                    text:
                        'Do not do this exercise if: '
                        '${exercise.contraindications.join('; ')}.',
                    icon: Icons.block,
                    tone: BannerTone.urgent,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: AppColors.muted(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Equipment: ${exercise.equipment}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          SectionCard(
            title: 'What this targets',
            leadingIcon: Icons.my_location,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final RootCause cause in exercise.targets)
                  VitalChip(label: cause.title, icon: Icons.check),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(habitControllerProvider.notifier)
                  .logExercise(DayKey.today(), exercise);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${exercise.name} logged.')),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Log this exercise'),
          ),
        ],
      ),
    );
  }
}
