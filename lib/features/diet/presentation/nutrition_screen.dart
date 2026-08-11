import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../../data/repositories/vitalrise_repository.dart';
import '../domain/diet_engine.dart';
import '../domain/food.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<NutritionTargets?> targets = ref.watch(
      nutritionTargetsProvider,
    );
    final AsyncValue<List<DailyMealPlan>> plan = ref.watch(mealPlanProvider);
    final AsyncValue<DietPreferences> prefs = ref.watch(
      dietPreferencesProvider,
    );

    return VitalScaffold(
      padBody: false,
      disclaimer: Disclaimers.dietSafety,
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(Icons.tune),
            onPressed: () => _editPreferences(prefs.valueOrNull),
          ),
        ],
      ),
      body: targets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not build your plan',
          message: 'Try reopening this tab.',
        ),
        data: (NutritionTargets? t) {
          if (t == null) {
            return EmptyState(
              icon: Icons.restaurant_outlined,
              title: 'No nutrition plan yet',
              message:
                  'Your targets are calculated from the height, weight, '
                  'age and activity you gave in the assessment.',
              action: FilledButton(
                onPressed: () => context.go('/assessment'),
                child: const Text('Start assessment'),
              ),
            );
          }

          final List<DailyMealPlan> week =
              plan.valueOrNull ?? const <DailyMealPlan>[];
          final DailyMealPlan? today = week.isEmpty
              ? null
              : week[_day % week.length];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _TargetsCard(targets: t, preferences: prefs.valueOrNull),
              const SizedBox(height: AppSpacing.md),

              Text('Your week', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: week.length,
                  itemBuilder: (BuildContext context, int i) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text('Day ${i + 1}'),
                      selected: _day == i,
                      onSelected: (_) => setState(() => _day = i),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (today != null) ...<Widget>[
                for (final MealSlot slot in MealSlot.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _MealCard(meal: today.mealFor(slot)),
                  ),
                SectionCard(
                  title: 'Day total',
                  leadingIcon: Icons.summarize_outlined,
                  child: Column(
                    children: <Widget>[
                      _MacroRow(
                        label: 'Calories',
                        value: today.kcal,
                        target: t.calories.toDouble(),
                        unit: 'kcal',
                      ),
                      _MacroRow(
                        label: 'Protein',
                        value: today.proteinG,
                        target: t.proteinG.toDouble(),
                        unit: 'g',
                      ),
                      _MacroRow(
                        label: 'Carbohydrate',
                        value: today.carbsG,
                        target: t.carbsG.toDouble(),
                        unit: 'g',
                      ),
                      _MacroRow(
                        label: 'Fat',
                        value: today.fatG,
                        target: t.fatG.toDouble(),
                        unit: 'g',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              const DisclaimerBanner(
                text: Disclaimers.dietSafety,
                icon: Icons.restaurant_menu,
                tone: BannerTone.caution,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editPreferences(DietPreferences? current) async {
    final DietPreferences start = current ?? DietPreferences.fallback;
    final DietPreferences? updated =
        await showModalBottomSheet<DietPreferences>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => _PreferencesSheet(initial: start),
        );
    if (updated == null) return;
    await ref.read(dietPreferencesProvider.notifier).save(updated);
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.targets, required this.preferences});

  final NutritionTargets targets;
  final DietPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: 'Daily targets',
      subtitle: preferences == null
          ? targets.goal.label
          : '${preferences!.pattern.label} - ${targets.goal.label}',
      leadingIcon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  value: '${targets.calories}',
                  label: 'kcal',
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _Stat(value: '${targets.proteinG}g', label: 'protein'),
              ),
              Expanded(
                child: _Stat(value: '${targets.carbsG}g', label: 'carbs'),
              ),
              Expanded(
                child: _Stat(value: '${targets.fatG}g', label: 'fat'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              VitalChip(
                label: 'BMR ${targets.bmr.round()} kcal',
                dense: true,
                color: AppColors.muted(context),
              ),
              VitalChip(
                label: 'Burn ${targets.tdee.round()} kcal',
                dense: true,
                color: AppColors.muted(context),
              ),
              VitalChip(
                label: '${(targets.waterMl / 1000).toStringAsFixed(1)} L water',
                dense: true,
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            targets.rationale,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SectionCard(
      title: meal.slot.label,
      subtitle: '${meal.kcal.round()} kcal - ${meal.proteinG.round()}g protein',
      leadingIcon: switch (meal.slot) {
        MealSlot.breakfast => Icons.wb_sunny_outlined,
        MealSlot.lunch => Icons.lunch_dining_outlined,
        MealSlot.dinner => Icons.dinner_dining_outlined,
        MealSlot.snack => Icons.cookie_outlined,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final MealComponent c in meal.components)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          c.food.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        c.portionLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                  if (c.food.benefits.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 2,
                        children: <Widget>[
                          for (final FoodBenefit b in c.food.benefits.take(3))
                            VitalChip(
                              label: b.label,
                              dense: true,
                              color: AppColors.muted(context),
                            ),
                        ],
                      ),
                    ),
                  if (c.food.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        c.food.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted(context),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
  });

  final String label;
  final double value;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = target == 0 ? 0 : value / target;
    // Within 10% of target is on plan; the bar turns amber outside that.
    final bool onTarget = (ratio - 1).abs() <= 0.1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                '${value.round()} / ${target.round()} $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onTarget ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                onTarget ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleLarge?.copyWith(color: color)),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      ],
    );
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial});

  final DietPreferences initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late DietPreferences _prefs = widget.initial;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Nutrition preferences', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),

            Text('What do you eat?', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<DietPattern>(
              groupValue: _prefs.pattern,
              onChanged: (DietPattern? v) =>
                  setState(() => _prefs = _prefs.copyWith(pattern: v)),
              child: Column(
                children: <Widget>[
                  for (final DietPattern p in DietPattern.values)
                    RadioListTile<DietPattern>(
                      value: p,
                      title: Text(p.label),
                      subtitle: Text(p.description),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Your goal', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<DietGoal>(
              groupValue: _prefs.goal,
              onChanged: (DietGoal? v) =>
                  setState(() => _prefs = _prefs.copyWith(goal: v)),
              child: Column(
                children: <Widget>[
                  for (final DietGoal g in DietGoal.values)
                    RadioListTile<DietGoal>(
                      value: g,
                      title: Text(g.label),
                      subtitle: Text(
                        g.rationale,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      isThreeLine: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text('Activity level', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ActivityLevel>(
              groupValue: _prefs.activity,
              onChanged: (ActivityLevel? v) =>
                  setState(() => _prefs = _prefs.copyWith(activity: v)),
              child: Column(
                children: <Widget>[
                  for (final ActivityLevel a in ActivityLevel.values)
                    RadioListTile<ActivityLevel>(
                      value: a,
                      title: Text(a.label),
                      subtitle: Text(a.description),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            FilledButton(
              onPressed: () => Navigator.of(context).pop(_prefs),
              child: const Text('Rebuild my plan'),
            ),
          ],
        ),
      ),
    );
  }
}
