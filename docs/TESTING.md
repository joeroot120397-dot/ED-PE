# Testing

```bash
flutter test                     # 197 tests, ~10 seconds
flutter test test/assessment     # one suite
flutter test --coverage
```

## Layout

| Suite | Tests | Covers |
| --- | --- | --- |
| `test/assessment/` | 28 | Question bank integrity, score bounds and direction, root-cause analysis, clinical flags, serialisation |
| `test/diet/` | 27 | Food database integrity, Mifflin-St Jeor, macro maths, meal generation for every pattern × goal |
| `test/exercises/` | 23 | Exercise library integrity, animation metadata, 12-week programme structure |
| `test/coach/` | 24 | Safety triage, BM25 retrieval, service orchestration, offline fallback |
| `test/habits/` | 34 | DayKey arithmetic, streaks, badges, progress trends, and the Riverpod controllers against a real encrypted store |
| `test/widget/` | 29 | Screen rendering, the real router and navigation, disclaimer coverage, accessibility guidelines |
| `test/core/` | 20 | AES-GCM crypto, asset existence and validity |
| `test/data/` | 12 | Offline-first writes, sync-failure handling, persistence, deletion |

`test/support/answer_builder.dart` provides the shared fixtures: a `healthy()`
profile with no concerns anywhere and a `severe()` profile with the worst
answer in every section. Those two pin both ends of every scale.

## What the tests are actually for

Not coverage percentage. Each suite exists to catch a specific class of
mistake that would otherwise reach a user.

**Calibration drift.** The engines are editorial weights. `healthy()` must
score ≥ 90 and `severe()` must score ≤ 12; a change that quietly moves those
fails immediately. Directional tests (preserved morning erections must
increase anxiety confidence *and* decrease cardiovascular confidence) pin
the clinical reasoning rather than a magic number.

**Silent data loss.** The renormalisation test answers exactly one ED
question with the worst option and asserts risk ≥ 90. If unanswered
questions ever default to zero burden again, that test drops to ~20.

**Dietary restrictions.** Every pattern × goal × day combination is
generated and every component checked against the user's pattern. A vegan
being served eggs is a trust-destroying bug, and the combinatorics are too
large to catch by hand.

**Safety regressions.** The coach tests assert that emergency and
medication messages *never reach the backend* — using a recording fake that
counts calls, so the assertion is about behaviour rather than output text.

**Crypto correctness.** Round-trips, nonce freshness, MAC verification on
tampered payloads, key rotation on corruption. Two real bugs were caught
here: an off-by-one that made empty plaintexts undecryptable, and an
unguarded `base64Decode` that crashed the app on a corrupt keystore entry.

**Regulatory compliance.** One test walks every reachable screen and asserts
a disclaimer renders. A second greps the source for screens that build a
bare `Scaffold` instead of `VitalScaffold`, which is what makes the
guarantee structural rather than a convention.

**Asset integrity.** Every animation path is checked to exist, to parse as
valid Lottie, to contain animated properties, and to stay under 200 KB. A
missing animation degrades gracefully at runtime — and therefore silently,
which is exactly why it needs a test.

**Accessibility.** Tap target sizes, semantic labels and text contrast run
against Flutter's built-in guidelines. The contrast check caught a real
failure: the mandated disclaimer footer was rendering at 2.56:1, well under
WCAG AA, fixed by introducing a theme-aware muted colour. Driving the app at
a 1.4x text scale caught a second: `EmptyState` overflowed vertically, so
the accessibility setting was breaking the layouts it exists to help.

**Router integrity.** `flutter analyze` type-checks `router.dart`, but a
duplicate path, a malformed `StatefulShellRoute` or a redirect loop only
fails when the router is constructed and driven. `test/widget/navigation_test.dart`
builds the real `VitalRiseApp`, walks every tab, follows every deep link,
and checks the onboarding redirect in both directions.

**The offline-first promise.** `test/data/` runs the repository against a
backend that fails every single call, and asserts that local writes still
succeed, local reads still work, and deletion still clears the device. That
promise is load-bearing for the whole product and is easy to break with a
stray `rethrow`.

## Widget test harness

`_pumpScreen` sets a 360×780 viewport (a mid-range Android) rather than the
default 800×600 test window, which is both wider and shorter than any real
phone. That change alone surfaced four genuine layout overflows that would
have shipped as yellow-and-black stripes.

It pumps a fixed number of frames instead of `pumpAndSettle`, because
several screens run a looping animation — the Lottie player, progress
indicators — that never reaches a steady state.

`_expectVisible` scrolls to find content below the fold, trying each
scrollable on screen from innermost outwards. A lazy list never builds what
has not been reached, so asserting directly on off-screen content produces
confusing "found 0 widgets" failures.

## Writing a new test

Prefer the domain layer. Engines are pure functions over immutable inputs,
so a test is three lines and runs in microseconds:

```dart
test('sedentary profile surfaces sedentary lifestyle as a driver', () {
  final AssessmentResponses r = AnswerBuilder()
      .body(weightKg: 95, waistCm: 105)
      .choose('d_exercise', 'never')
      .choose('d_sitting', 'over9')
      .build();

  expect(
    _confidenceOf(AssessmentEngine.evaluate(r), RootCause.sedentaryLifestyle),
    greaterThanOrEqualTo(85),
  );
});
```

`AnswerBuilder.choose` asserts the option id exists, so a renamed option
fails loudly at the call site rather than silently scoring as unanswered.

## Not covered

Stated so nobody assumes otherwise:

- **Supabase integration.** `RemoteSync` is exercised through fakes only -
  `NoopRemoteSync`, a failing double and a recording double. The real
  Supabase client is never called. Testing it needs a live project; RLS
  behaviour should be verified with the SQL snippets in
  `supabase/README.md` after any policy change.
- **Edge Functions.** No Deno test suite. The safety triage inside them
  duplicates logic that *is* tested in Dart, but the duplication itself is
  untested — a divergence would not be caught automatically.
- **The assessment UI end to end.** Navigation and screens are covered, but
  no test taps through all 28 questions; the flow tests seed a completed
  assessment instead. An `integration_test` driver walking the real intake
  would be the next addition.
- **Golden/screenshot tests.** No pixel regression coverage. Worth adding
  for the results screen and exercise detail, which are the most
  visually complex.
- **Platform channels.** `flutter_secure_storage` is substituted with
  `InMemoryKeyStore` in tests, so real keystore behaviour is only verified
  on device.
