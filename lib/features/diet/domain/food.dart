import 'package:meta/meta.dart';

/// Dietary patterns, ordered from most to least restrictive.
///
/// The ordering is load-bearing: a food is edible by a pattern when the
/// food's own [Food.pattern] index is less than or equal to the user's.
enum DietPattern {
  vegan('Vegan', 'No animal products at all'),
  vegetarian('Vegetarian', 'Includes dairy, no eggs or meat'),
  eggetarian('Eggetarian', 'Vegetarian plus eggs'),
  nonVegetarian('Non-vegetarian', 'Includes fish and meat');

  const DietPattern(this.label, this.description);

  final String label;
  final String description;

  bool canEat(Food food) => food.pattern.index <= index;
}

/// Nutrition goals the plan can be tuned for.
enum DietGoal {
  weightLoss(
    'Weight loss',
    'A moderate deficit, protein kept high to protect '
        'muscle. Losing abdominal fat is the single most effective nutrition '
        'lever for erection quality.',
  ),
  weightGain(
    'Weight gain',
    'A modest surplus with enough protein to make the '
        'gain lean rather than fat.',
  ),
  maintain(
    'Maintain weight',
    'Calories at maintenance, with the composition '
        'shifted toward blood-flow and hormone support.',
  ),
  testosteroneSupport(
    'Testosterone support',
    'Adequate fat intake, zinc, '
        'magnesium and vitamin D. Very low fat diets suppress testosterone.',
  ),
  edSupport(
    'Erection support',
    'Emphasises dietary nitrates and flavonoids '
        'that support nitric oxide production and vessel function.',
  ),
  peSupport(
    'Ejaculation control',
    'Steadier blood sugar and magnesium '
        'intake, which support nervous system regulation.',
  );

  const DietGoal(this.label, this.rationale);

  final String label;
  final String rationale;
}

/// Nutrient properties used to bias food selection toward a goal.
enum FoodBenefit {
  protein('High protein'),
  nitrate('Nitrates for blood flow'),
  citrulline('Citrulline'),
  flavonoid('Flavonoids'),
  zinc('Zinc'),
  magnesium('Magnesium'),
  vitaminD('Vitamin D'),
  omega3('Omega-3'),
  fibre('Fibre'),
  lowGi('Slow-release carbohydrate'),
  healthyFat('Healthy fats');

  const FoodBenefit(this.label);
  final String label;
}

enum FoodRole {
  proteinAnchor,
  complexCarb,
  vegetable,
  fruit,
  healthyFat,
  beverage,
}

enum MealSlot {
  breakfast('Breakfast', 0.27),
  lunch('Lunch', 0.33),
  dinner('Dinner', 0.28),
  snack('Snacks', 0.12);

  const MealSlot(this.label, this.calorieShare);

  final String label;

  /// Fraction of the daily calorie target allocated to this meal.
  /// The four shares sum to 1.0.
  final double calorieShare;
}

@immutable
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.pattern,
    required this.role,
    required this.slots,
    required this.servingLabel,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.benefits = const <FoodBenefit>[],
    this.note,
  });

  final String id;
  final String name;

  /// The *least* permissive pattern that can eat this food.
  final DietPattern pattern;

  final FoodRole role;
  final List<MealSlot> slots;

  /// Describes one serving, e.g. "2 large eggs" or "150 g cooked".
  final String servingLabel;

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final List<FoodBenefit> benefits;
  final String? note;

  bool suits(MealSlot slot) => slots.contains(slot);

  bool hasBenefit(FoodBenefit b) => benefits.contains(b);
}

/// A food scaled to a number of servings.
@immutable
class MealComponent {
  const MealComponent({required this.food, required this.servings});

  final Food food;
  final double servings;

  double get kcal => food.kcal * servings;
  double get proteinG => food.proteinG * servings;
  double get carbsG => food.carbsG * servings;
  double get fatG => food.fatG * servings;

  /// e.g. "1.5 x 150 g cooked".
  String get portionLabel {
    final String s = servings == servings.roundToDouble()
        ? servings.toStringAsFixed(0)
        : servings.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return s == '1' ? food.servingLabel : '$s x ${food.servingLabel}';
  }
}

@immutable
class Meal {
  const Meal({required this.slot, required this.components});

  final MealSlot slot;
  final List<MealComponent> components;

  double get kcal =>
      components.fold(0, (double s, MealComponent c) => s + c.kcal);
  double get proteinG =>
      components.fold(0, (double s, MealComponent c) => s + c.proteinG);
  double get carbsG =>
      components.fold(0, (double s, MealComponent c) => s + c.carbsG);
  double get fatG =>
      components.fold(0, (double s, MealComponent c) => s + c.fatG);
}
