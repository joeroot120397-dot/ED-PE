import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/score_ring.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../assessment/domain/assessment_result.dart';
import '../../exercises/domain/training_program.dart';
import '../../habits/domain/habit_log.dart';
import '../../habits/domain/streaks.dart';

/// The home screen: today's session, the habit tracker and the streak.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<AssessmentResult?> result = ref.watch(
      assessmentResultProvider,
    );

    return VitalScaffold(
      padBody: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_greeting(), style: theme.textTheme.titleLarge),
            Text(
              DateFormat('EEEE d MMMM').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Learn',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/library'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: 'Pull down to try again.',
        ),
        data: (AssessmentResult? r) =>
            r == null ? _NoAssessment() : _TodayContent(result: r),
      ),
    );
  }

  static String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _NoAssessment extends StatelessWidget {
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.assignment_outlined,
    title: 'Start with the assessment',
    message:
        'Five minutes of questions gives you a root-cause '
        'breakdown and a 12-week plan built around it.',
    action: FilledButton(
      onPressed: () => context.go('/assessment'),
      child: const Text('Begin assessment'),
    ),
  );
}

class _TodayContent extends ConsumerWidget {
  const _TodayContent({required this.result});

  final AssessmentResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DayKey today = DayKey.today();
    final StreakSummary streak = ref.watch(streakProvider);
    final HabitTargets targets = ref.watch(habitTargetsProvider);
    final AsyncValue<DailySession?> session = ref.watch(todaySessionProvider);
    final AsyncValue<TrainingProgram?> program = ref.watch(programProvider);
    final List<HabitLog> logs =
        ref.watch(habitControllerProvider).valueOrNull ?? const <HabitLog>[];
    final HabitLog log = logs.firstWhere(
      (HabitLog l) => l.day == today,
      orElse: () => HabitLog(day: today),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(habitControllerProvider)
          ..invalidate(assessmentResultProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          // ---- Streak -------------------------------------------------
          SectionCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        (streak.current > 0
                                ? AppColors.warning
                                : AppColors.slate400)
                            .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    streak.current > 0 ? '🔥' : '🌱',
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        streak.current == 0
                            ? 'No streak yet'
                            : '${streak.current} day '
                                  '${streak.current == 1 ? 'streak' : 'streak'}',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        streak.atRisk
                            ? 'Log a session today to keep it alive'
                            : streak.completedToday
                            ? 'Today is done. Best run: '
                                  '${streak.longest} days'
                            : 'Complete a pelvic floor session to start',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Badges',
                  icon: const Icon(Icons.military_tech_outlined),
                  onPressed: () => context.push('/badges'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Today's session ---------------------------------------
          session.when(
            loading: () => const SectionCard(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object e, StackTrace s) => const SizedBox.shrink(),
            data: (DailySession? s) {
              if (s == null) return const SizedBox.shrink();
              final int week =
                  program.valueOrNull?.weekNumberOn(DateTime.now()) ?? 1;
              final ProgramPhase? phase = program.valueOrNull?.phaseForWeek(
                week,
              );

              return SectionCard(
                title: s.title,
                subtitle: phase == null
                    ? null
                    : 'Week $week - ${phase.name} phase',
                leadingIcon: Icons.play_circle_outline,
                trailing: s.isRest
                    ? const VitalChip(label: 'Rest', icon: Icons.bedtime)
                    : VitalChip(
                        label: '${s.estimatedMinutes} min',
                        icon: Icons.schedule,
                      ),
                onTap: s.isRest ? null : () => context.go('/train'),
                child: s.isRest
                    ? Text(
                        s.restNote ?? 'Rest day.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final ProgramItem item in s.items.take(4))
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      item.exercise.name,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    item.dosage.label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (s.items.length > 4)
                            Text(
                              '+ ${s.items.length - 4} more',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted(context),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: () => context.go('/train'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text("Start today's session"),
                          ),
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Habit tracker -----------------------------------------
          SectionCard(
            title: 'Daily habits',
            leadingIcon: Icons.checklist_rtl,
            child: Column(
              children: <Widget>[
                _HabitRow(
                  icon: Icons.self_improvement,
                  label: 'Pelvic floor sessions',
                  value: '${log.kegelSessions} / ${targets.kegelSessions}',
                  progress: targets.kegelSessions == 0
                      ? 0
                      : log.kegelSessions / targets.kegelSessions,
                  action: IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: 'Log a session',
                    onPressed: () => ref
                        .read(habitControllerProvider.notifier)
                        .completeSession(today),
                  ),
                ),
                _HabitRow(
                  icon: Icons.water_drop_outlined,
                  label: 'Water',
                  value:
                      '${(log.waterMl / 1000).toStringAsFixed(1)} / '
                      '${(targets.waterMl / 1000).toStringAsFixed(1)} L',
                  progress: targets.waterMl == 0
                      ? 0
                      : log.waterMl / targets.waterMl,
                  action: IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add 250 ml',
                    onPressed: () => ref
                        .read(habitControllerProvider.notifier)
                        .addWater(today, 250),
                  ),
                ),
                _HabitRow(
                  icon: Icons.bedtime_outlined,
                  label: 'Sleep last night',
                  value: log.sleepHours == null
                      ? 'Not logged'
                      : '${log.sleepHours!.toStringAsFixed(1)} h',
                  progress: (log.sleepHours ?? 0) / targets.sleepHours,
                  action: IconButton.filledTonal(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Log sleep',
                    onPressed: () => _logSleep(context, ref, log),
                  ),
                ),
                _HabitRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight & waist',
                  value: log.weightKg == null
                      ? 'Not logged'
                      : '${log.weightKg!.toStringAsFixed(1)} kg'
                            '${log.waistCm == null ? '' : ' / ${log.waistCm!.round()} cm'}',
                  progress: log.weightKg == null ? 0 : 1,
                  action: IconButton.filledTonal(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Log measurements',
                    onPressed: () => _logBody(context, ref, log, result),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Score snapshot ----------------------------------------
          SectionCard(
            title: 'Where you started',
            subtitle: DateFormat('d MMM yyyy').format(result.completedAt),
            leadingIcon: Icons.flag_outlined,
            onTap: () => context.push('/results'),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                ScoreRing(
                  value: result.scores.sexualHealthScore,
                  label: 'Sexual health',
                  higherIsBetter: true,
                  size: 88,
                  strokeWidth: 8,
                  animate: false,
                ),
                ScoreRing(
                  value: result.scores.edRiskScore,
                  label: 'ED risk',
                  higherIsBetter: false,
                  size: 88,
                  strokeWidth: 8,
                  animate: false,
                ),
                ScoreRing(
                  value: result.scores.peRiskScore,
                  label: 'PE risk',
                  higherIsBetter: false,
                  size: 88,
                  strokeWidth: 8,
                  animate: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logSleep(
    BuildContext context,
    WidgetRef ref,
    HabitLog log,
  ) async {
    final double? hours = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _SliderSheet(
        title: 'How long did you sleep?',
        subtitle:
            'Most testosterone is released during sleep. Under 6 hours '
            'measurably lowers it within a week.',
        initial: log.sleepHours ?? 7,
        min: 3,
        max: 12,
        unit: 'hours',
        decimals: 1,
      ),
    );
    if (hours == null) return;
    await ref
        .read(habitControllerProvider.notifier)
        .saveLog(log.copyWith(sleepHours: hours));
  }

  Future<void> _logBody(
    BuildContext context,
    WidgetRef ref,
    HabitLog log,
    AssessmentResult result,
  ) async {
    final double? weight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _SliderSheet(
        title: 'Your weight today',
        subtitle: 'Weigh yourself at the same time of day for a usable trend.',
        initial: log.weightKg ?? result.metrics.weightKg,
        min: 40,
        max: 200,
        unit: 'kg',
        decimals: 1,
      ),
    );
    if (weight == null || !context.mounted) return;

    final double? waist = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _SliderSheet(
        title: 'Your waist today',
        subtitle:
            'Measured at the navel, relaxed. This tracks the fat that '
            'actually affects erections.',
        initial: log.waistCm ?? result.metrics.waistCm,
        min: 55,
        max: 170,
        unit: 'cm',
        decimals: 0,
      ),
    );

    await ref
        .read(habitControllerProvider.notifier)
        .saveLog(log.copyWith(weightKg: weight, waistCm: waist));
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool done = progress >= 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 22,
            color: done ? AppColors.success : AppColors.slate400,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: done ? AppColors.success : AppColors.slate400,
                        fontWeight: done ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.dividerColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          action,
        ],
      ),
    );
  }
}

/// Bottom sheet with a single slider, used for the quick-log actions.
class _SliderSheet extends StatefulWidget {
  const _SliderSheet({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.min,
    required this.max,
    required this.unit,
    required this.decimals,
  });

  final String title;
  final String subtitle;
  final double initial;
  final double min;
  final double max;
  final String unit;
  final int decimals;

  @override
  State<_SliderSheet> createState() => _SliderSheetState();
}

class _SliderSheetState extends State<_SliderSheet> {
  late double _value = widget.initial.clamp(widget.min, widget.max);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              '${_value.toStringAsFixed(widget.decimals)} ${widget.unit}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Slider(
            value: _value,
            min: widget.min,
            max: widget.max,
            divisions:
                ((widget.max - widget.min) * (widget.decimals > 0 ? 10 : 1))
                    .round(),
            onChanged: (double v) => setState(() => _value = v),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_value),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
