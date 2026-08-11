import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../assessment/domain/assessment_result.dart';
import 'food.dart';
import 'food_database.dart';

/// How active the user is, used for the TDEE multiplier.
enum ActivityLevel {
  sedentary('Sedentary', 1.2, 'Desk job, little deliberate exercise'),
  light('Lightly active', 1.375, 'Exercise 1-2 days a week'),
  moderate('Moderately active', 1.55, 'Exercise 3-4 days a week'),
  high('Very active', 1.725, 'Exercise 5+ days a week');

  const ActivityLevel(this.label, this.factor, this.description);

  final String label;
  final double factor;
  final String description;

  /// Maps the lifestyle answer `d_exercise` onto an activity level.
  static ActivityLevel fromExerciseAnswer(String? answer) => switch (answer) {
    '5plus' => ActivityLevel.high,
    '3to4' => ActivityLevel.moderate,
    '1to2' => ActivityLevel.light,
    _ => ActivityLevel.sedentary,
  };
}

/// Daily energy and macronutrient targets.
@immutable
class NutritionTargets {
  const NutritionTargets({
    required this.goal,
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
    required this.rationale,
  });

  final DietGoal goal;
  final double bmr;
  final double tdee;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;
  final String rationale;

  double get proteinKcal => proteinG * 4;
  double get carbsKcal => carbsG * 4;
  double get fatKcal => fatG * 9;
}

/// One day of eating.
@immutable
class DailyMealPlan {
  const DailyMealPlan({
    required this.dayIndex,
    required this.meals,
    required this.targets,
  });

  /// 0-based day within the rotating week.
  final int dayIndex;
  final List<Meal> meals;
  final NutritionTargets targets;

  double get kcal => meals.fold(0, (double s, Meal m) => s + m.kcal);
  double get proteinG => meals.fold(0, (double s, Meal m) => s + m.proteinG);
  double get carbsG => meals.fold(0, (double s, Meal m) => s + m.carbsG);
  double get fatG => meals.fold(0, (double s, Meal m) => s + m.fatG);

  Meal mealFor(MealSlot slot) => meals.firstWhere((Meal m) => m.slot == slot);

  /// Signed percentage difference from the calorie target.
  double get calorieVariancePct => targets.calories == 0
      ? 0
      : (kcal - targets.calories) / targets.calories * 100;
}

/// Builds nutrition targets and meal plans.
///
/// Pure and deterministic: the same inputs always give the same week, which
/// is what `test/diet/diet_engine_test.dart` relies on.
abstract final class DietEngine {
  /// Calorie split across the four meals, taken from [MealSlot.calorieShare].
  static const double _anchorProteinShare = 0.7;
  static const double _minServing = 0.5;
  static const double _maxServing = 3.0;

  // ------------------------------------------------------------------
  // Targets
  // ------------------------------------------------------------------
  static NutritionTargets targetsFor({
    required BodyMetrics metrics,
    required DietGoal goal,
    required ActivityLevel activity,
  }) {
    // Mifflin-St Jeor, male. The most accurate of the simple predictive
    // equations for this population.
    final double bmr =
        10 * metrics.weightKg + 6.25 * metrics.heightCm - 5 * metrics.age + 5;
    final double tdee = bmr * activity.factor;

    final int calories = switch (goal) {
      // A 500 kcal deficit targets roughly 0.5 kg a week. Floored so the
      // plan never drops below a level that would cost muscle and hormones.
      DietGoal.weightLoss =>
        math.max(tdee - 500, math.max(bmr * 1.15, 1500)).round(),
      DietGoal.weightGain => (tdee + 350).round(),
      _ => tdee.round(),
    };

    // For men well above a healthy weight, dosing protein on total body
    // weight overshoots badly. Adjusted body weight is the standard fix.
    final double referenceWeight = _referenceWeight(metrics);

    final double proteinPerKg = switch (goal) {
      DietGoal.weightLoss => 2.0,
      DietGoal.weightGain => 1.8,
      DietGoal.testosteroneSupport => 1.8,
      _ => 1.6,
    };
    final int proteinG = (referenceWeight * proteinPerKg).round();

    // Fat is set as a share of calories with a hard floor: chronically low
    // fat intake measurably suppresses testosterone.
    final double fatShare = switch (goal) {
      DietGoal.testosteroneSupport => 0.32,
      DietGoal.weightLoss => 0.27,
      _ => 0.30,
    };
    final int fatG = math.max(
      (calories * fatShare / 9).round(),
      (referenceWeight * 0.6).round(),
    );

    final int carbsG = math.max(
      0,
      ((calories - proteinG * 4 - fatG * 9) / 4).round(),
    );

    return NutritionTargets(
      goal: goal,
      bmr: bmr,
      tdee: tdee,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      waterMl: (metrics.weightKg * 35).round(),
      rationale: _targetRationale(goal, calories, tdee, proteinG, fatG),
    );
  }

  /// Actual weight in the healthy range; adjusted body weight above it.
  static double _referenceWeight(BodyMetrics metrics) {
    final double heightM = metrics.heightCm / 100;
    final double weightAtBmi25 = 25 * heightM * heightM;
    if (metrics.weightKg <= weightAtBmi25) return metrics.weightKg;
    return weightAtBmi25 + 0.25 * (metrics.weightKg - weightAtBmi25);
  }

  static String _targetRationale(
    DietGoal goal,
    int calories,
    double tdee,
    int proteinG,
    int fatG,
  ) {
    final int delta = calories - tdee.round();
    final StringBuffer sb = StringBuffer();
    if (delta < -50) {
      sb.write(
        'Your target sits ${delta.abs()} kcal below the energy you '
        'burn on an average day - about 0.5 kg of fat loss a week. Faster '
        'than that costs muscle and testosterone, which defeats the point. ',
      );
    } else if (delta > 50) {
      sb.write(
        'Your target sits $delta kcal above maintenance, a surplus '
        'small enough to build tissue rather than fat. ',
      );
    } else {
      sb.write('Your target matches your estimated daily burn. ');
    }
    sb.write(
      'Protein is set at ${proteinG}g to protect muscle, and fat at '
      '${fatG}g because testosterone is synthesised from cholesterol - very '
      'low fat diets measurably reduce it. ',
    );
    sb.write(goal.rationale);
    return sb.toString();
  }

  /// Picks a sensible default goal from an assessment.
  static DietGoal suggestGoal(AssessmentResult result) {
    if (result.metrics.bmi >= 27 || result.metrics.waistToHeight >= 0.55) {
      return DietGoal.weightLoss;
    }
    if (result.metrics.bmi < 18.5) return DietGoal.weightGain;
    if (result.scores.peRiskScore >= 55 &&
        result.scores.peRiskScore > result.scores.edRiskScore) {
      return DietGoal.peSupport;
    }
    if (result.scores.edRiskScore >= 45) return DietGoal.edSupport;
    return DietGoal.maintain;
  }

  // ------------------------------------------------------------------
  // Meal plan
  // ------------------------------------------------------------------

  /// Builds one day. [dayIndex] rotates the picks so a week has variety.
  static DailyMealPlan buildDay({
    required NutritionTargets targets,
    required DietPattern pattern,
    int dayIndex = 0,
  }) {
    final List<Meal> meals = <Meal>[
      for (final MealSlot slot in MealSlot.values)
        _buildMeal(
          slot: slot,
          pattern: pattern,
          targets: targets,
          dayIndex: dayIndex,
        ),
    ];
    return DailyMealPlan(dayIndex: dayIndex, meals: meals, targets: targets);
  }

  static List<DailyMealPlan> buildWeek({
    required NutritionTargets targets,
    required DietPattern pattern,
  }) => <DailyMealPlan>[
    for (int d = 0; d < 7; d++)
      buildDay(targets: targets, pattern: pattern, dayIndex: d),
  ];

  static Meal _buildMeal({
    required MealSlot slot,
    required DietPattern pattern,
    required NutritionTargets targets,
    required int dayIndex,
  }) {
    final List<FoodRole> composition = switch (slot) {
      MealSlot.breakfast => <FoodRole>[
        FoodRole.proteinAnchor,
        FoodRole.complexCarb,
        FoodRole.fruit,
        FoodRole.healthyFat,
      ],
      MealSlot.lunch => <FoodRole>[
        FoodRole.proteinAnchor,
        FoodRole.complexCarb,
        FoodRole.vegetable,
        FoodRole.healthyFat,
      ],
      MealSlot.dinner => <FoodRole>[
        FoodRole.proteinAnchor,
        FoodRole.complexCarb,
        FoodRole.vegetable,
      ],
      MealSlot.snack => <FoodRole>[
        FoodRole.proteinAnchor,
        FoodRole.fruit,
        FoodRole.healthyFat,
      ],
    };

    final List<Food> picked = <Food>[];
    for (int i = 0; i < composition.length; i++) {
      final Food? food = _pick(
        role: composition[i],
        slot: slot,
        pattern: pattern,
        goal: targets.goal,
        // Offsetting by the position keeps two roles from rotating in
        // lockstep and repeating the same pairing every week.
        rotation: dayIndex + i * 2,
        exclude: picked,
      );
      if (food != null) picked.add(food);
    }

    return Meal(
      slot: slot,
      components: _portion(
        foods: picked,
        targetKcal: targets.calories * slot.calorieShare,
        targetProtein: targets.proteinG * slot.calorieShare,
      ),
    );
  }

  /// Ranks candidates by how well they serve [goal], keeps the top handful,
  /// then rotates within that shortlist so the week varies without ever
  /// dropping to an irrelevant food.
  static Food? _pick({
    required FoodRole role,
    required MealSlot slot,
    required DietPattern pattern,
    required DietGoal goal,
    required int rotation,
    required List<Food> exclude,
  }) {
    final List<Food> candidates = FoodDatabase.all
        .where(
          (Food f) =>
              f.role == role &&
              f.suits(slot) &&
              pattern.canEat(f) &&
              !exclude.contains(f),
        )
        .toList();

    if (candidates.isEmpty) {
      // Beverages stand in as a protein source for patterns with few
      // anchors in a given slot (a vegan breakfast, for instance).
      if (role == FoodRole.proteinAnchor) {
        return _pick(
          role: FoodRole.beverage,
          slot: slot,
          pattern: pattern,
          goal: goal,
          rotation: rotation,
          exclude: exclude,
        );
      }
      return null;
    }

    candidates.sort((Food a, Food b) {
      final int byScore = _goalScore(b, goal).compareTo(_goalScore(a, goal));
      // Sorting by id on ties keeps the whole engine deterministic.
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });

    final int shortlist = math.min(4, candidates.length);
    return candidates[rotation % shortlist];
  }

  static int _goalScore(Food food, DietGoal goal) {
    int score = 0;
    for (final FoodBenefit b in food.benefits) {
      score += switch (goal) {
        DietGoal.weightLoss => switch (b) {
          FoodBenefit.protein => 3,
          FoodBenefit.fibre => 3,
          FoodBenefit.lowGi => 2,
          _ => 0,
        },
        DietGoal.weightGain => switch (b) {
          FoodBenefit.protein => 3,
          FoodBenefit.healthyFat => 2,
          _ => 0,
        },
        DietGoal.testosteroneSupport => switch (b) {
          FoodBenefit.zinc => 3,
          FoodBenefit.vitaminD => 3,
          FoodBenefit.magnesium => 2,
          FoodBenefit.healthyFat => 2,
          FoodBenefit.protein => 1,
          _ => 0,
        },
        DietGoal.edSupport => switch (b) {
          FoodBenefit.nitrate => 3,
          FoodBenefit.citrulline => 3,
          FoodBenefit.flavonoid => 2,
          FoodBenefit.omega3 => 2,
          _ => 0,
        },
        DietGoal.peSupport => switch (b) {
          FoodBenefit.magnesium => 3,
          FoodBenefit.lowGi => 3,
          FoodBenefit.fibre => 1,
          _ => 0,
        },
        DietGoal.maintain => switch (b) {
          FoodBenefit.nitrate => 1,
          FoodBenefit.protein => 1,
          FoodBenefit.fibre => 1,
          _ => 0,
        },
      };
    }
    return score;
  }

  /// Scales the chosen foods to hit the slot's calorie and protein targets.
  ///
  /// The protein anchor is sized first (it carries most of the slot's
  /// protein), then everything else absorbs the remaining calories.
  static List<MealComponent> _portion({
    required List<Food> foods,
    required double targetKcal,
    required double targetProtein,
  }) {
    if (foods.isEmpty) return const <MealComponent>[];

    final Map<Food, double> servings = <Food, double>{
      for (final Food f in foods) f: 1.0,
    };

    final Food? anchor = foods
        .where(
          (Food f) =>
              f.role == FoodRole.proteinAnchor || f.role == FoodRole.beverage,
        )
        .firstOrNull;

    double anchorKcal = 0;
    if (anchor != null && anchor.proteinG > 0) {
      final double want = targetProtein * _anchorProteinShare / anchor.proteinG;
      servings[anchor] = _roundServing(want);
      anchorKcal = anchor.kcal * servings[anchor]!;
    }

    final List<Food> rest = foods.where((Food f) => f != anchor).toList();
    if (rest.isNotEmpty) {
      final double baseKcal = rest.fold(0, (double s, Food f) => s + f.kcal);
      final double remaining = targetKcal - anchorKcal;
      final double factor = baseKcal <= 0 ? 1 : remaining / baseKcal;
      for (final Food f in rest) {
        servings[f] = _roundServing(factor);
      }
    }

    return <MealComponent>[
      for (final Food f in foods)
        MealComponent(food: f, servings: servings[f] ?? 1.0),
    ];
  }

  /// Rounds to the nearest quarter serving inside sane bounds - nobody
  /// weighs out 1.37 of an avocado.
  static double _roundServing(double raw) {
    if (raw.isNaN || raw.isInfinite) return 1.0;
    final double clamped = raw.clamp(_minServing, _maxServing);
    return (clamped * 4).round() / 4;
  }
}
