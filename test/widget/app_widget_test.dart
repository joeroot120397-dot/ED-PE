import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalrise/app/providers.dart';
import 'package:vitalrise/app/theme/app_theme.dart';
import 'package:vitalrise/core/constants/disclaimers.dart';
import 'package:vitalrise/core/security/crypto_box.dart';
import 'package:vitalrise/core/storage/health_store.dart';
import 'package:vitalrise/data/repositories/vitalrise_repository.dart';
import 'package:vitalrise/features/anatomy/presentation/anatomy_screen.dart';
import 'package:vitalrise/features/assessment/domain/scoring_engine.dart';
import 'package:vitalrise/features/assessment/presentation/results_screen.dart';
import 'package:vitalrise/features/dashboard/presentation/today_screen.dart';
import 'package:vitalrise/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:vitalrise/features/habits/presentation/badges_screen.dart';
import 'package:vitalrise/features/library/presentation/library_screen.dart';
import 'package:vitalrise/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vitalrise/features/progress/presentation/progress_screen.dart';

import '../support/answer_builder.dart';

Future<VitalRiseRepository> _repository() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final CryptoBox crypto = await CryptoBox.open(InMemoryKeyStore());
  return VitalRiseRepository(store: HealthStore(prefs, crypto));
}

/// Pumps a screen on a realistic phone viewport.
///
/// The default 800x600 test window is both wider and shorter than any real
/// device: too short for lazy list content below the fold to be built at
/// all, and too wide to catch the horizontal overflows that a 360dp phone
/// hits. 360x780 is a mid-range Android.
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child,
  VitalRiseRepository repo,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(child, repo));
  // Not pumpAndSettle: several screens run a looping animation (the Lottie
  // exercise player, progress indicators) that never reaches a steady state.
  // A few explicit frames is enough to resolve the async providers and lay
  // the screen out.
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Asserts [finder] is present, scrolling the screen if the content sits
/// below the fold - a lazy list never builds what has not been reached.
Future<void> _expectVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    expect(finder, findsWidgets);
    return;
  }

  // A screen can hold several scrollables (a tab view, a horizontal filter
  // strip, the content list). Try each from the innermost outwards rather
  // than guessing which one owns the target.
  final int scrollables = find.byType(Scrollable).evaluate().length;
  for (int i = scrollables - 1; i >= 0; i--) {
    try {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).at(i),
        maxScrolls: 30,
      );
      expect(finder, findsWidgets);
      return;
    } on Object {
      // Wrong scrollable - try the next one out.
    }
  }
  fail('could not bring $finder into view in any of $scrollables scrollables');
}

Widget _wrap(Widget child, VitalRiseRepository repo) => ProviderScope(
  overrides: <Override>[repositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screens render', () {
    testWidgets('onboarding shows the first slide and can advance', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const OnboardingScreen(), repo);

      expect(find.text('VitalRise'), findsOneWidget);
      expect(find.textContaining('blood-flow event'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('trained skill'), findsOneWidget);
    });

    testWidgets('results screen renders scores and causes', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await repo.saveAssessment(
        AnswerBuilder.severe(),
        AssessmentEngine.evaluate(AnswerBuilder.severe()),
      );

      await _pumpScreen(tester, const ResultsScreen(showContinue: false), repo);

      expect(find.text('Your results'), findsOneWidget);
      await _expectVisible(tester, find.text('Your scores'));
      await _expectVisible(tester, find.text('Sexual health'));
      await _expectVisible(tester, find.text('What is driving it'));
      await _expectVisible(
        tester,
        find.textContaining('Pelvic floor weakness'),
      );
    });

    testWidgets('today screen prompts for the assessment when there is none', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const TodayScreen(), repo);

      expect(find.text('Start with the assessment'), findsOneWidget);
    });

    testWidgets('exercise detail renders instructions, mistakes and safety', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(
        tester,
        const ExerciseDetailScreen(exerciseId: 'kegel_basic'),
        repo,
      );

      expect(find.text('Basic Kegel contraction'), findsOneWidget);
      await _expectVisible(tester, find.text('How to do it'));
      await _expectVisible(tester, find.text('Common mistakes'));
      await _expectVisible(tester, find.text('Safety'));
    });

    testWidgets('an unknown exercise id shows a not-found state, not a crash', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(
        tester,
        const ExerciseDetailScreen(exerciseId: 'does_not_exist'),
        repo,
      );
      expect(find.text('Exercise not found'), findsOneWidget);
    });

    testWidgets('library lists the articles', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const LibraryScreen(), repo);

      expect(find.text('Learn'), findsOneWidget);
      expect(find.text('Understanding erectile difficulty'), findsOneWidget);
      await _expectVisible(
        tester,
        find.text('Pelvic floor training, properly'),
      );
    });

    testWidgets('an article renders its sections', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(
        tester,
        const ArticleScreen(articleId: 'understanding_pe'),
        repo,
      );

      expect(find.text('Understanding early ejaculation'), findsOneWidget);
      await _expectVisible(tester, find.text('What counts as early'));
    });

    testWidgets('anatomy detail renders its illustration and takeaways', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(
        tester,
        const AnatomyDetailScreen(topicId: 'pelvic_floor'),
        repo,
      );

      expect(find.text('Pelvic floor muscles'), findsOneWidget);
      await _expectVisible(tester, find.text('What this means for you'));
    });

    testWidgets('badges screen renders every badge as locked initially', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const BadgesScreen(), repo);

      expect(find.text('Badges'), findsWidgets);
      await _expectVisible(tester, find.text('First contraction'));
      expect(find.text('🔒'), findsWidgets);
    });

    testWidgets('progress screen invites a first check-in', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const ProgressScreen(), repo);

      expect(find.text('Weekly check-in'), findsOneWidget);
      await _expectVisible(tester, find.text('No trends yet'));
    });
  });

  group('regulatory disclaimer', () {
    testWidgets('appears on every screen that a user can reach', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();

      final Map<String, Widget> screens = <String, Widget>{
        'onboarding': const OnboardingScreen(),
        'today': const TodayScreen(),
        'results': const ResultsScreen(showContinue: false),
        'library': const LibraryScreen(),
        'article': const ArticleScreen(articleId: 'understanding_ed'),
        'anatomy': const AnatomyDetailScreen(topicId: 'blood_flow'),
        'exercise': const ExerciseDetailScreen(exerciseId: 'plank'),
        'badges': const BadgesScreen(),
        'progress': const ProgressScreen(),
      };

      for (final MapEntry<String, Widget> entry in screens.entries) {
        await _pumpScreen(tester, entry.value, repo);

        // Screens may override the footer with a more specific caveat, so
        // accept the standard text or any of the approved variants.
        final bool hasDisclaimer = <String>[
          Disclaimers.standard,
          Disclaimers.scoreExplainer,
          Disclaimers.exerciseSafety,
          Disclaimers.dietSafety,
          Disclaimers.coachDisclaimer,
        ].any((String text) => find.text(text).evaluate().isNotEmpty);

        expect(
          hasDisclaimer,
          isTrue,
          reason: 'the ${entry.key} screen renders no disclaimer footer',
        );
      }
    });

    testWidgets('the footer text matches the wording the brief mandates', (
      WidgetTester tester,
    ) async {
      expect(
        Disclaimers.standard,
        'This application provides educational guidance only and is not a '
        'substitute for medical advice. Consult a qualified healthcare '
        'professional for diagnosis and treatment.',
      );
    });

    test('no screen builds a bare Scaffold instead of VitalScaffold', () {
      // VitalScaffold is what guarantees the footer. A screen reaching past
      // it would silently drop the disclaimer, so this is enforced
      // structurally rather than by convention.
      final List<String> offenders = <String>[];

      for (final FileSystemEntity entity in Directory(
        'lib/features',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('_screen.dart')) continue;
        final String source = entity.readAsStringSync();
        if (source.contains('VitalScaffold')) continue;
        if (RegExp(r'\breturn (const )?Scaffold\(').hasMatch(source)) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these screens bypass VitalScaffold and lose the disclaimer',
      );
    });
  });

  group('accessibility', () {
    testWidgets('score rings expose their value to screen readers', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await repo.saveAssessment(
        AnswerBuilder.healthy(),
        AssessmentEngine.evaluate(AnswerBuilder.healthy()),
      );

      await _pumpScreen(tester, const ResultsScreen(showContinue: false), repo);

      await _expectVisible(
        tester,
        find.bySemanticsLabel(RegExp(r'Sexual health: \d+ out of 100')),
      );
    });

    testWidgets('tap targets on the onboarding flow meet the minimum size', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const OnboardingScreen(), repo);

      final SemanticsHandle handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text contrast passes on the light theme', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      await _pumpScreen(tester, const BadgesScreen(), repo);

      final SemanticsHandle handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
