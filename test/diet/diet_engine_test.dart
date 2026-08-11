import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/features/assessment/domain/assessment_result.dart';
import 'package:vitalrise/features/assessment/domain/root_cause.dart';
import 'package:vitalrise/features/diet/domain/diet_engine.dart';
import 'package:vitalrise/features/diet/domain/food.dart';
import 'package:vitalrise/features/diet/domain/food_database.dart';

const BodyMetrics _average = BodyMetrics(
  age: 35,
  heightCm: 178,
  weightKg: 82,
  waistCm: 92,
);

const BodyMetrics _obese = BodyMetrics(
  age: 48,
  heightCm: 172,
  weightKg: 118,
  waistCm: 124,
);

void main() {
  group('food database integrity', () {
    test('ids are unique', () {
      final Set<String> ids = FoodDatabase.all.map((Food f) => f.id).toSet();
      expect(ids.length, FoodDatabase.all.length);
    });

    test('macros are consistent with stated calories', () {
      // 4/4/9 kcal per gram. Allow 15% slack for fibre, alcohol-free
      // rounding and the imprecision of published composition tables.
      for (final Food f in FoodDatabase.all) {
        final double fromMacros = f.proteinG * 4 + f.carbsG * 4 + f.fatG * 9;
        expect(
          fromMacros,
          closeTo(f.kcal, f.kcal * 0.15 + 12),
          reason: '${f.id}: macros imply $fromMacros kcal, states ${f.kcal}',
        );
      }
    });

    test('every food declares at least one meal slot', () {
      for (final Food f in FoodDatabase.all) {
        expect(f.slots, isNotEmpty, reason: f.id);
      }
    });

    test('every pattern can fill every role it needs in every slot', () {
      // The regression this guards: a vegan breakfast with no protein
      // source, which the engine would silently render as a bowl of fruit.
      for (final DietPattern pattern in DietPattern.values) {
        for (final MealSlot slot in MealSlot.values) {
          final Iterable<Food> proteins = FoodDatabase.all.where(
            (Food f) =>
                (f.role == FoodRole.proteinAnchor ||
                    f.role == FoodRole.beverage) &&
                f.suits(slot) &&
                pattern.canEat(f),
          );
          expect(
            proteins,
            isNotEmpty,
            reason: 'no protein source for ${pattern.label} at ${slot.label}',
          );
        }
      }
    });

    test('meal slot calorie shares sum to one', () {
      final double total = MealSlot.values.fold(
        0,
        (double s, MealSlot m) => s + m.calorieShare,
      );
      expect(total, closeTo(1.0, 0.0001));
    });
  });

  group('nutrition targets', () {
    test('Mifflin-St Jeor is applied correctly', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.maintain,
        activity: ActivityLevel.moderate,
      );
      // 10*82 + 6.25*178 - 5*35 + 5 = 1762.5
      expect(t.bmr, closeTo(1762.5, 0.01));
      expect(t.tdee, closeTo(1762.5 * 1.55, 0.01));
      expect(t.calories, t.tdee.round());
    });

    test('weight loss applies a deficit with a safety floor', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.weightLoss,
        activity: ActivityLevel.moderate,
      );
      expect(t.calories, lessThan(t.tdee));
      expect(t.calories, greaterThanOrEqualTo(1500));
      expect(t.calories, greaterThanOrEqualTo((t.bmr * 1.15).round()));
    });

    test('the deficit floor holds for a small, sedentary man', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: const BodyMetrics(
          age: 60,
          heightCm: 160,
          weightKg: 58,
          waistCm: 82,
        ),
        goal: DietGoal.weightLoss,
        activity: ActivityLevel.sedentary,
      );
      expect(t.calories, greaterThanOrEqualTo(1500));
    });

    test('weight gain applies a surplus', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.weightGain,
        activity: ActivityLevel.light,
      );
      expect(t.calories, greaterThan(t.tdee));
    });

    test('macros add up to the calorie target', () {
      for (final DietGoal goal in DietGoal.values) {
        final NutritionTargets t = DietEngine.targetsFor(
          metrics: _average,
          goal: goal,
          activity: ActivityLevel.moderate,
        );
        final double fromMacros = t.proteinKcal + t.carbsKcal + t.fatKcal;
        expect(
          fromMacros,
          closeTo(t.calories.toDouble(), t.calories * 0.03 + 10),
          reason: goal.name,
        );
      }
    });

    test('protein is dosed on adjusted weight for a man with obesity', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: _obese,
        goal: DietGoal.weightLoss,
        activity: ActivityLevel.sedentary,
      );
      // Naive dosing would be 118 * 2.0 = 236 g, which is neither necessary
      // nor achievable. Adjusted body weight should land far below that.
      expect(t.proteinG, lessThan(200));
      expect(t.proteinG, greaterThan(120));
    });

    test('testosterone support never drops fat too low', () {
      final NutritionTargets t = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.testosteroneSupport,
        activity: ActivityLevel.moderate,
      );
      expect(t.fatG * 9 / t.calories, greaterThanOrEqualTo(0.25));
    });

    test('water target scales with body weight', () {
      expect(
        DietEngine.targetsFor(
          metrics: _average,
          goal: DietGoal.maintain,
          activity: ActivityLevel.moderate,
        ).waterMl,
        (82 * 35).round(),
      );
    });
  });

  group('meal plan generation', () {
    test('every pattern gets a plan that respects its restrictions', () {
      for (final DietPattern pattern in DietPattern.values) {
        final NutritionTargets targets = DietEngine.targetsFor(
          metrics: _average,
          goal: DietGoal.maintain,
          activity: ActivityLevel.moderate,
        );
        for (final DailyMealPlan day in DietEngine.buildWeek(
          targets: targets,
          pattern: pattern,
        )) {
          for (final Meal meal in day.meals) {
            expect(
              meal.components,
              isNotEmpty,
              reason: '${pattern.label} ${meal.slot.label} is empty',
            );
            for (final MealComponent c in meal.components) {
              expect(
                pattern.canEat(c.food),
                isTrue,
                reason: '${pattern.label} was served ${c.food.name}',
              );
            }
          }
        }
      }
    });

    test('daily calories land close to the target', () {
      for (final DietPattern pattern in DietPattern.values) {
        for (final DietGoal goal in DietGoal.values) {
          final NutritionTargets targets = DietEngine.targetsFor(
            metrics: _average,
            goal: goal,
            activity: ActivityLevel.moderate,
          );
          for (final DailyMealPlan day in DietEngine.buildWeek(
            targets: targets,
            pattern: pattern,
          )) {
            expect(
              day.calorieVariancePct.abs(),
              lessThanOrEqualTo(18),
              reason:
                  '${pattern.label} / ${goal.name} / day ${day.dayIndex} '
                  'came out at ${day.kcal.round()} kcal against a target of '
                  '${targets.calories}',
            );
          }
        }
      }
    });

    test('daily protein lands near the target', () {
      for (final DietPattern pattern in DietPattern.values) {
        final NutritionTargets targets = DietEngine.targetsFor(
          metrics: _average,
          goal: DietGoal.weightLoss,
          activity: ActivityLevel.moderate,
        );
        for (final DailyMealPlan day in DietEngine.buildWeek(
          targets: targets,
          pattern: pattern,
        )) {
          expect(
            day.proteinG,
            greaterThanOrEqualTo(targets.proteinG * 0.7),
            reason:
                '${pattern.label} day ${day.dayIndex}: '
                '${day.proteinG.round()}g vs ${targets.proteinG}g target',
          );
        }
      }
    });

    test('portions stay within sane serving bounds', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.maintain,
        activity: ActivityLevel.moderate,
      );
      for (final DailyMealPlan day in DietEngine.buildWeek(
        targets: targets,
        pattern: DietPattern.nonVegetarian,
      )) {
        for (final Meal m in day.meals) {
          for (final MealComponent c in m.components) {
            expect(c.servings, inInclusiveRange(0.5, 3.0));
            expect(
              (c.servings * 4) % 1,
              0,
              reason: '${c.food.id} servings must be a quarter step',
            );
          }
        }
      }
    });

    test('the week has variety rather than seven identical days', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.edSupport,
        activity: ActivityLevel.moderate,
      );
      final List<DailyMealPlan> week = DietEngine.buildWeek(
        targets: targets,
        pattern: DietPattern.nonVegetarian,
      );

      final Set<String> signatures = week
          .map(
            (DailyMealPlan d) => d.meals
                .expand(
                  (Meal m) => m.components.map((MealComponent c) => c.food.id),
                )
                .join('|'),
          )
          .toSet();
      expect(signatures.length, greaterThanOrEqualTo(3));
    });

    test('generation is deterministic', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.edSupport,
        activity: ActivityLevel.moderate,
      );
      String render(DailyMealPlan d) => d.meals
          .expand(
            (Meal m) => m.components.map(
              (MealComponent c) => '${c.food.id}:${c.servings}',
            ),
          )
          .join(',');

      expect(
        render(
          DietEngine.buildDay(
            targets: targets,
            pattern: DietPattern.vegan,
            dayIndex: 3,
          ),
        ),
        render(
          DietEngine.buildDay(
            targets: targets,
            pattern: DietPattern.vegan,
            dayIndex: 3,
          ),
        ),
      );
    });

    test('the ED goal pulls in blood-flow foods', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.edSupport,
        activity: ActivityLevel.moderate,
      );
      final Set<FoodBenefit> benefits =
          DietEngine.buildWeek(
                targets: targets,
                pattern: DietPattern.vegetarian,
              )
              .expand((DailyMealPlan d) => d.meals)
              .expand((Meal m) => m.components)
              .expand((MealComponent c) => c.food.benefits)
              .toSet();

      expect(
        benefits.intersection(<FoodBenefit>{
          FoodBenefit.nitrate,
          FoodBenefit.citrulline,
          FoodBenefit.flavonoid,
        }),
        isNotEmpty,
      );
    });

    test('the testosterone goal pulls in zinc and vitamin D foods', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.testosteroneSupport,
        activity: ActivityLevel.moderate,
      );
      final Set<FoodBenefit> benefits =
          DietEngine.buildWeek(
                targets: targets,
                pattern: DietPattern.nonVegetarian,
              )
              .expand((DailyMealPlan d) => d.meals)
              .expand((Meal m) => m.components)
              .expand((MealComponent c) => c.food.benefits)
              .toSet();

      expect(benefits, contains(FoodBenefit.zinc));
      expect(benefits, contains(FoodBenefit.vitaminD));
    });

    test('a meal never repeats the same food twice', () {
      final NutritionTargets targets = DietEngine.targetsFor(
        metrics: _average,
        goal: DietGoal.maintain,
        activity: ActivityLevel.moderate,
      );
      for (final DietPattern p in DietPattern.values) {
        for (final DailyMealPlan day in DietEngine.buildWeek(
          targets: targets,
          pattern: p,
        )) {
          for (final Meal m in day.meals) {
            final List<String> ids = m.components
                .map((MealComponent c) => c.food.id)
                .toList();
            expect(ids.toSet().length, ids.length, reason: m.slot.label);
          }
        }
      }
    });
  });

  group('goal suggestion', () {
    test('suggests weight loss for a high BMI', () {
      expect(
        DietEngine.suggestGoal(_resultWith(_obese, edRisk: 40, peRisk: 20)),
        DietGoal.weightLoss,
      );
    });

    test('suggests ED support when erection risk dominates', () {
      expect(
        DietEngine.suggestGoal(_resultWith(_average, edRisk: 60, peRisk: 20)),
        DietGoal.edSupport,
      );
    });

    test('suggests PE support when ejaculation risk dominates', () {
      expect(
        DietEngine.suggestGoal(_resultWith(_average, edRisk: 20, peRisk: 70)),
        DietGoal.peSupport,
      );
    });
  });

  group('portion labels', () {
    test('a single serving is rendered without a multiplier', () {
      final MealComponent c = MealComponent(
        food: FoodDatabase.byId('eggs'),
        servings: 1,
      );
      expect(c.portionLabel, '2 large eggs');
    });

    test('fractional servings are rendered readably', () {
      final MealComponent c = MealComponent(
        food: FoodDatabase.byId('oats'),
        servings: 1.5,
      );
      expect(c.portionLabel, '1.5 x 50 g dry');
    });
  });
}

AssessmentResult _resultWith(
  BodyMetrics metrics, {
  required int edRisk,
  required int peRisk,
}) => AssessmentResult(
  completedAt: DateTime(2026),
  metrics: metrics,
  scores: HealthScores(
    sexualHealthScore: 100 - edRisk,
    edRiskScore: edRisk,
    peRiskScore: peRisk,
    lifestyleScore: 60,
  ),
  causes: const <CauseConfidence>[],
  flags: const <ClinicalFlag>[],
  headline: '',
  summary: '',
);
