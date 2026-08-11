# Architecture

## Layering

```
┌──────────────────────────────────────────────────────────┐
│ presentation/   Flutter widgets. Reads providers, calls  │
│                 controllers. No business logic.          │
├──────────────────────────────────────────────────────────┤
│ app/providers   Riverpod. Wires domain to presentation,  │
│                 owns transient UI state.                 │
├──────────────────────────────────────────────────────────┤
│ data/           VitalRiseRepository (offline-first),     │
│                 RemoteSync (Supabase | noop).            │
├──────────────────────────────────────────────────────────┤
│ domain/         Pure Dart. Models + engines. No Flutter, │
│                 no IO, no time except what's passed in.  │
└──────────────────────────────────────────────────────────┘
```

The rule that pays for itself: **`domain/` never imports Flutter.** The
scoring engine, programme builder and diet engine are static functions over
immutable inputs. That's why 100+ tests over them run in under a second and
why calibration questions can be answered by reading one file.

Anything that needs the clock takes it as a parameter (`now`, `startedOn`,
`today`). There is no `DateTime.now()` inside an engine, which is what makes
streaks, programme weeks and results reproducible in tests.

## Feature layout

```
lib/features/<feature>/
├── domain/          models, engines, libraries of content
└── presentation/    screens, and widgets/ where a screen needs helpers
```

Features own their content. `ExerciseLibrary`, `ArticleLibrary`,
`FoodDatabase`, `AnatomyLibrary` and `QuestionBank` are `const` data in Dart
rather than JSON assets, which means the analyzer type-checks the content
and a malformed entry is a compile error rather than a runtime surprise.

One deliberate cross-feature dependency: the coach's `KnowledgeBase` builds
its corpus from `ArticleLibrary` and `ExerciseLibrary`. That's the point —
the coach can only say what the library says, and the two cannot drift.

## State management

Riverpod 2, no code generation. Providers are declared explicitly so the
graph is readable without running a build step.

| Kind | Used for | Examples |
| --- | --- | --- |
| `Provider` | Derived synchronous state | `streakProvider`, `badgeProvider`, `trendProvider` |
| `FutureProvider` | Async reads that rebuild on dependency change | `assessmentResultProvider`, `programProvider`, `mealPlanProvider` |
| `NotifierProvider` | Synchronous mutable state | `assessmentDraftProvider`, `settingsProvider` |
| `AsyncNotifierProvider` | Persisted collections with optimistic writes | `habitControllerProvider`, `progressControllerProvider`, `coachControllerProvider` |

`repositoryProvider` throws by default and is overridden in `main()` once
the encrypted store is open. That's intentional: it makes "you forgot to
initialise storage" a loud failure at startup rather than a silent empty
state, and it gives every widget test a clean injection point.

Derivation chains are declarative all the way down:

```
assessmentResultProvider
   ├── programProvider ── todaySessionProvider ──┐
   │                                             ├── habitTargetsProvider
   └── nutritionTargetsProvider ─────────────────┘
                └── mealPlanProvider
```

Invalidate the assessment and everything downstream rebuilds. Nothing is
recomputed by hand.

## Offline-first data flow

**Reads** always come from the encrypted local store. Nothing in the UI
waits on a network round trip.

**Writes** go local first, then push to Supabase. A failed push is swallowed
deliberately (`VitalRiseRepository._push`) — losing signal must never stop a
man from logging a session, and the local write already succeeded. The next
`syncDown()` reconciles.

**Sign-in** runs `syncUp()` then `syncDown()`, so data recorded before
creating an account is preserved rather than overwritten.

The whole remote layer sits behind the `RemoteSync` interface, with
`NoopRemoteSync` as the default. That's what makes "no backend configured"
a fully supported mode rather than a broken one: `Env.isOfflineDemo` picks
the noop, every write becomes a no-op, and the app is completely functional
on-device.

## Navigation

`go_router` with `StatefulShellRoute.indexedStack` for the five bottom-nav
destinations, so each tab keeps its own navigator stack and scroll position.

There is exactly one redirect rule — first-time users go to onboarding —
and **no auth gate**. Requiring an email address before a man can find out
whether the app helps is the fastest way to lose him, and this subject
matter makes that worse. An account is offered, never demanded.

## The disclaimer guarantee

Regulatory copy has to be on every screen. Relying on developers to remember
would fail on the first new screen, so it's structural:

1. `VitalScaffold` wraps `Scaffold` and always renders `DisclaimerFooter`.
2. Screens may override the *text* with a more specific caveat (exercise
   safety, nutrition limits, coach limitations) but cannot remove it.
3. A test walks every reachable screen and asserts a disclaimer renders.
4. A second test greps `lib/features/**/*_screen.dart` for a bare `Scaffold`
   and fails if any screen bypasses `VitalScaffold`.

## Scaling to 100k+ users

**Client.** The app is fully functional offline, so backend availability
affects sync and the coach, not core usage. Content is bundled, so a cold
start makes no content requests.

**Database.** Every user-data index leads with `user_id`; query cost tracks
one person's history, not table size. Daily and weekly records use natural
composite keys, so retries upsert idempotently. See `supabase/README.md` for
the partitioning path when `habit_logs` outgrows one table.

**Coach.** Retrieval runs on-device over a bundled corpus — zero server cost
per question, and it works offline. Only generation is remote. When the
corpus outgrows BM25 on a phone (a few thousand chunks), move retrieval into
the Edge Function with pgvector; `CoachBackend` is the seam and no other
code changes.

**Content updates.** `content_items` overlays the bundled libraries, so copy
fixes and new exercises ship without an app store release.

## Extending to a full men's health platform

The seams that make new verticals cheap:

- **`RootCause`** is an enum with a stable `slug`, and exercises, articles
  and foods are tagged by cause. A fertility or testosterone-optimisation
  track means new causes plus new tagged content — the programme builder
  and results screen pick them up unchanged.
- **`QuestionBank`** is data. New sections are additive; `content_version`
  on `assessments` records which bank produced a stored result.
- **`ExerciseCategory`**, `DietGoal` and `ProgressMetric` are enums with
  attached copy, so adding one is a single edit plus content.
- **Engines take their inputs explicitly.** `ProgramBuilder.build` takes a
  result and a start date; a second programme type is a second builder, not
  a fork of the app.

## Deliberate omissions

- **No `build_runner`.** Freezed and riverpod_generator would save some
  boilerplate at the cost of a generation step in every checkout and CI run.
  For a codebase this size, explicit `copyWith` and explicit providers were
  the better trade.
- **No local SQL database.** Habit logs and check-ins are small bounded
  collections; an encrypted JSON blob per collection is simpler than a
  schema plus migrations, and the repository interface means swapping to
  Drift later touches one class.
- **No `flutter_local_notifications`.** Reminders are scheduled server-side
  so they can be skipped for men who already trained today, and so they
  survive aggressive battery optimisation.
