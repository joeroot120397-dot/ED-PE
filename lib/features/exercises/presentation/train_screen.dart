import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../habits/domain/habit_log.dart';
import '../domain/exercise.dart';
import '../domain/exercise_library.dart';
import '../domain/training_program.dart';

/// Two tabs: the personalised programme, and the full exercise library.
class TrainScreen extends ConsumerStatefulWidget {
  const TrainScreen({super.key});

  @override
  ConsumerState<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends ConsumerState<TrainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VitalScaffold(
      padBody: false,
      disclaimer: Disclaimers.exerciseSafety,
      appBar: AppBar(
        title: const Text('Train'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'My programme'),
            Tab(text: 'All exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const <Widget>[_ProgramTab(), _LibraryTab()],
      ),
    );
  }
}

class _ProgramTab extends ConsumerWidget {
  const _ProgramTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<TrainingProgram?> async = ref.watch(programProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace s) => const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not build your programme',
        message: 'Try reopening this tab.',
      ),
      data: (TrainingProgram? program) {
        if (program == null) {
          return EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No programme yet',
            message:
                'Complete the assessment and we will build a 12-week '
                'plan around your root causes.',
            action: FilledButton(
              onPressed: () => context.go('/assessment'),
              child: const Text('Start assessment'),
            ),
          );
        }

        final int week = program.weekNumberOn(DateTime.now());
        final ProgramPhase phase = program.phaseForWeek(week);
        final int todayIndex = DateTime.now().weekday;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: <Widget>[
            // Phase progress
            SectionCard(
              title: 'Week $week of ${program.totalWeeks}',
              subtitle:
                  '${phase.name} phase - weeks ${phase.startWeek} to '
                  '${phase.endWeek}',
              leadingIcon: Icons.timeline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: week / program.totalWeeks,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    phase.focus,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      VitalChip(
                        label: '${phase.trainingDays} training days',
                        icon: Icons.event_available,
                      ),
                      VitalChip(
                        label: '${phase.weeklyMinutes} min / week',
                        icon: Icons.schedule,
                        color: AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            SectionCard(
              title: 'Why this plan',
              leadingIcon: Icons.psychology_outlined,
              child: Text(
                program.rationale,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text('This week', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final DailySession session in phase.week)
              _DayCard(
                session: session,
                isToday: session.dayOfWeek == todayIndex,
              ),
          ],
        );
      },
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.session, required this.isToday});

  final DailySession session;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(
            color: isToday ? theme.colorScheme.primary : theme.dividerColor,
            width: isToday ? 2 : 1,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: isToday,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            backgroundColor: session.isRest
                ? theme.dividerColor
                : theme.colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              session.dayName.substring(0, 2),
              style: theme.textTheme.labelMedium?.copyWith(
                color: session.isRest ? AppColors.slate400 : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Row(
            children: <Widget>[
              Expanded(child: Text(session.title)),
              if (isToday) const VitalChip(label: 'Today', dense: true),
            ],
          ),
          subtitle: Text(
            session.isRest
                ? 'Recovery'
                : '${session.items.length} exercises - '
                      '${session.estimatedMinutes} min',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted(context),
            ),
          ),
          children: <Widget>[
            if (session.isRest)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Text(
                  session.restNote ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              )
            else ...<Widget>[
              for (final ProgramItem item in session.items)
                ListTile(
                  onTap: () => context.push('/exercise/${item.exercise.id}'),
                  leading: Icon(
                    _iconFor(item.exercise.category),
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(item.exercise.name),
                  subtitle: Text(
                    <String>[
                      item.dosage.label,
                      if (item.note != null) item.note!,
                    ].join(' - '),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  isThreeLine: item.note != null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(habitControllerProvider.notifier)
                        .completeSession(
                          DayKey.today(),
                          minutes: session.estimatedMinutes,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session logged. Streak updated.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Mark session complete'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibraryTab extends StatefulWidget {
  const _LibraryTab();

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  String _query = '';
  ExerciseCategory? _category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Exercise> results = ExerciseLibrary.search(_query)
        .where((Exercise e) => _category == null || e.category == _category)
        .toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search exercises',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
              ),
              for (final ExerciseCategory c in ExerciseCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) =>
                        setState(() => _category = _category == c ? null : c),
                  ),
                ),
            ],
          ),
        ),
        if (_category != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Text(
              _category!.rationale,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
                height: 1.4,
              ),
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'Nothing matched',
                  message: 'Try a different word or clear the filter.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: results.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int i) {
                    final Exercise e = results[i];
                    return SectionCard(
                      onTap: () => context.push('/exercise/${e.id}'),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Icon(
                              _iconFor(e.category),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(e.name, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  e.summary,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted(context),
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.xs,
                                  children: <Widget>[
                                    VitalChip(
                                      label: e.difficulty.label,
                                      dense: true,
                                    ),
                                    VitalChip(
                                      label: e.dosage.label,
                                      dense: true,
                                      color: AppColors.info,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

IconData _iconFor(ExerciseCategory category) => switch (category) {
  ExerciseCategory.kegel => Icons.self_improvement,
  ExerciseCategory.reverseKegel => Icons.spa_outlined,
  ExerciseCategory.strength => Icons.fitness_center,
  ExerciseCategory.core => Icons.accessibility_new,
  ExerciseCategory.cardio => Icons.directions_run,
  ExerciseCategory.mobility => Icons.airline_seat_flat_angled,
  ExerciseCategory.breathing => Icons.air,
};
