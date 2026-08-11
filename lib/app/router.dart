import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/vitalrise_repository.dart';
import '../features/anatomy/presentation/anatomy_screen.dart';
import '../features/assessment/presentation/assessment_screen.dart';
import '../features/assessment/presentation/results_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/dashboard/presentation/home_shell.dart';
import '../features/dashboard/presentation/today_screen.dart';
import '../features/diet/presentation/nutrition_screen.dart';
import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/train_screen.dart';
import '../features/habits/presentation/badges_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'providers.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final VitalRiseRepository repo = ref.watch(repositoryProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/today',
    debugLogDiagnostics: false,

    // The only redirect rule: a first-time user must see onboarding. Beyond
    // that the app is deliberately navigable without an account, so there is
    // no auth gate here.
    redirect: (BuildContext context, GoRouterState state) {
      final bool onboarding = state.matchedLocation == '/onboarding';
      if (!repo.hasSeenOnboarding && !onboarding) return '/onboarding';
      if (repo.hasSeenOnboarding && onboarding) return '/today';
      return null;
    },

    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) =>
            const AuthScreen(),
      ),
      GoRoute(
        path: '/assessment',
        builder: (BuildContext context, GoRouterState state) =>
            const AssessmentScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (BuildContext context, GoRouterState state) =>
            const ResultsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        path: '/badges',
        builder: (BuildContext context, GoRouterState state) =>
            const BadgesScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (BuildContext context, GoRouterState state) =>
            const LibraryScreen(),
      ),
      GoRoute(
        path: '/article/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ArticleScreen(articleId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/anatomy/:id',
        builder: (BuildContext context, GoRouterState state) =>
            AnatomyDetailScreen(topicId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/exercise/:id',
        builder: (BuildContext context, GoRouterState state) =>
            ExerciseDetailScreen(exerciseId: state.pathParameters['id'] ?? ''),
      ),

      // The five bottom-nav destinations, each with its own navigator so
      // tab state survives switching away and back.
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) => HomeShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/today',
                builder: (BuildContext context, GoRouterState state) =>
                    const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/train',
                builder: (BuildContext context, GoRouterState state) =>
                    const TrainScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/eat',
                builder: (BuildContext context, GoRouterState state) =>
                    const NutritionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/progress',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/coach',
                builder: (BuildContext context, GoRouterState state) =>
                    const CoachScreen(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off, size: 40),
              const SizedBox(height: 16),
              const Text('That screen does not exist.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/today'),
                child: const Text('Back to Today'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
