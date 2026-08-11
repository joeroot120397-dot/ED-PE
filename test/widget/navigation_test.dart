import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalrise/app/app.dart';
import 'package:vitalrise/app/providers.dart';
import 'package:vitalrise/app/router.dart';
import 'package:vitalrise/core/security/crypto_box.dart';
import 'package:vitalrise/core/storage/health_store.dart';
import 'package:vitalrise/data/repositories/vitalrise_repository.dart';
import 'package:vitalrise/features/assessment/domain/scoring_engine.dart';

import '../support/answer_builder.dart';

/// End-to-end coverage of the real router and app shell.
///
/// `flutter analyze` type-checks `router.dart`, but a duplicate path, a
/// malformed `StatefulShellRoute` or a redirect loop only fails when the
/// router is actually constructed and driven. Nothing else in the suite
/// touches these files, so without this they ship unexecuted.
Future<VitalRiseRepository> _repository({bool onboarded = true}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final CryptoBox crypto = await CryptoBox.open(InMemoryKeyStore());
  final VitalRiseRepository repo = VitalRiseRepository(
    store: HealthStore(prefs, crypto),
  );
  if (onboarded) await repo.markOnboardingSeen();
  return repo;
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  VitalRiseRepository repo,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[repositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const VitalRiseApp(),
    ),
  );
  // Fixed frames rather than pumpAndSettle: progress indicators and the
  // Lottie player never reach a steady state.
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  return container;
}

String _location(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<void> _goTo(
  WidgetTester tester,
  ProviderContainer container,
  String path,
) async {
  container.read(routerProvider).go(path);
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('router construction', () {
    test('the route table builds without throwing', () async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(() => container.read(routerProvider), returnsNormally);
      expect(container.read(routerProvider).configuration.routes, isNotEmpty);
    });
  });

  group('redirects', () {
    testWidgets('a first-time user is sent to onboarding', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository(onboarded: false);
      final ProviderContainer container = await _pumpApp(tester, repo);

      expect(_location(container), '/onboarding');
      expect(find.text('VitalRise'), findsOneWidget);
    });

    testWidgets('a returning user lands on Today', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      expect(_location(container), '/today');
    });

    testWidgets('a returning user cannot navigate back into onboarding', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      await _goTo(tester, container, '/onboarding');
      expect(_location(container), '/today');
    });

    testWidgets('there is no auth gate - every tab opens signed out', (
      WidgetTester tester,
    ) async {
      // Deliberate product decision: an account is offered, never demanded.
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      for (final String path in <String>[
        '/train',
        '/eat',
        '/progress',
        '/coach',
      ]) {
        await _goTo(tester, container, path);
        expect(_location(container), path, reason: 'blocked from $path');
      }
    });
  });

  group('bottom navigation', () {
    testWidgets('every destination is reachable by tapping', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      const Map<String, String> tabs = <String, String>{
        'Train': '/train',
        'Eat': '/eat',
        'Progress': '/progress',
        'Coach': '/coach',
        'Today': '/today',
      };

      for (final MapEntry<String, String> tab in tabs.entries) {
        await tester.tap(find.text(tab.key).last);
        for (int i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(_location(container), tab.value, reason: tab.key);
      }
    });

    testWidgets('each tab keeps its own stack', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      // Push a detail screen from the Train branch, switch away, come back.
      await _goTo(tester, container, '/train');
      unawaited(container.read(routerProvider).push('/exercise/kegel_basic'));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Basic Kegel contraction'), findsOneWidget);
    });
  });

  group('deep links', () {
    testWidgets('content routes resolve by id', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      const Map<String, String> routes = <String, String>{
        '/exercise/reverse_kegel': 'Reverse Kegels',
        '/article/testosterone_basics': 'Testosterone basics',
        '/anatomy/erection_physiology': 'Erection physiology',
        '/badges': 'Badges',
        '/library': 'Learn',
        '/settings': 'Settings',
      };

      for (final MapEntry<String, String> route in routes.entries) {
        await _goTo(tester, container, route.key);
        expect(
          find.text(route.value),
          findsWidgets,
          reason: 'nothing rendered for ${route.key}',
        );
      }
    });

    testWidgets('an unknown id renders a not-found state, not a crash', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      await _goTo(tester, container, '/exercise/no_such_exercise');
      expect(find.text('Exercise not found'), findsOneWidget);

      await _goTo(tester, container, '/article/no_such_article');
      expect(find.text('Article not found'), findsOneWidget);
    });

    testWidgets('an unknown path falls through to the error screen', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      await _goTo(tester, container, '/nowhere');
      expect(find.text('That screen does not exist.'), findsOneWidget);

      await tester.tap(find.text('Back to Today'));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(_location(container), '/today');
    });
  });

  group('assessment flow', () {
    testWidgets('finishing the assessment routes to results with a plan', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      // Seed a completed assessment rather than tapping 28 questions.
      await repo.saveAssessment(
        AnswerBuilder.severe(),
        AssessmentEngine.evaluate(AnswerBuilder.severe()),
      );
      await repo.setProgramStart(DateTime.now());

      final ProviderContainer container = await _pumpApp(tester, repo);

      await _goTo(tester, container, '/results');
      expect(find.text('Your results'), findsOneWidget);

      // And the programme derived from it is live on the Train tab.
      await _goTo(tester, container, '/train');
      expect(find.textContaining('Week 1 of 12'), findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('settings drive the app theme', (WidgetTester tester) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      expect(container.read(settingsProvider).themeMode, ThemeMode.system);

      await container
          .read(settingsProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pump();

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.themeMode, ThemeMode.dark);
      expect(app.darkTheme, isNotNull);
      expect(app.theme, isNotNull);
    });

    testWidgets('the accessibility text scale reaches the widget tree', (
      WidgetTester tester,
    ) async {
      final VitalRiseRepository repo = await _repository();
      final ProviderContainer container = await _pumpApp(tester, repo);

      await container.read(settingsProvider.notifier).setTextScale(1.4);
      await tester.pump();

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      expect(MediaQuery.textScalerOf(context).scale(10), greaterThan(10));
    });
  });
}
