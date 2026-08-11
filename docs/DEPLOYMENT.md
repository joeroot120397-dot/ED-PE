# Deployment

## Prerequisites

- Flutter 3.44+ (Dart 3.12+)
- Xcode 16+ for iOS, Android SDK 35+ for Android
- Supabase CLI, if you are deploying the backend

## Build configuration

Nothing project-specific is committed. Configuration arrives at build time
through `--dart-define-from-file`.

`env/dev.json` (git-ignored — copy from `env/example.json`):

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "eyJhbGciOi...",
  "AUTH_REDIRECT_URL": "io.vitalrise.app://login-callback",
  "COACH_FUNCTION": "ai-coach",
  "FIREBASE_ENABLED": false,
  "SUPPORT_EMAIL": "support@vitalrise.app",
  "PRIVACY_POLICY_URL": "https://vitalrise.app/privacy",
  "TERMS_URL": "https://vitalrise.app/terms"
}
```

Omit `SUPABASE_URL` entirely to build the fully offline variant — useful for
demos and for a store-review build that needs no live backend.

The publishable key is *public by design*. Row-level security protects the
data, not the key. The keys that do matter — `ANTHROPIC_API_KEY`,
`FCM_SERVER_KEY`, the service-role key — exist only in Edge Function
environments and never in a binary.

## Local development

```bash
flutter pub get
flutter run                                        # offline mode
flutter run --dart-define-from-file=env/dev.json   # with backend
```

## Android release

**Signing** — create `android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Generate the keystore once and back it up somewhere you will still have it
in three years. Losing it means you cannot ship an update to the same
listing.

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Wire it into `android/app/build.gradle.kts` in the standard way (load the
properties file, define a `release` signing config, reference it from the
release build type).

**Build:**

```bash
flutter build appbundle --release \
  --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols/android
```

Keep `build/symbols/` — without it, release crash reports are unreadable.

Minimum SDK 23 (Android 6.0), required by `flutter_secure_storage` for
hardware-backed keys.

## iOS release

1. Set the bundle identifier to `io.vitalrise.app` in Xcode.
2. Add the URL scheme `io.vitalrise.app` under **Info → URL Types** so the
   OAuth redirect returns to the app.
3. Enable **Sign in with Apple** in Signing & Capabilities. This is
   mandatory for App Store review if you offer Google sign-in.
4. Enable **Push Notifications** and **Background Modes → Remote
   notifications** if reminders are on.

```bash
flutter build ipa --release \
  --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols/ios
```

### Required Info.plist entries

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We never track you across apps. This permission is not used.</string>

<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

`ITSAppUsesNonExemptEncryption=false` is correct here: the app uses only
standard platform cryptography for local data protection, which is exempt.
Confirm against current Apple guidance before each submission.

The app requests no camera, microphone, location, contacts or photo access.
Do not add a permission without a feature that genuinely needs it — in this
category, every extra permission costs trust and invites review questions.

## Backend

See [`supabase/README.md`](../supabase/README.md). Order matters:

1. `supabase db push` (migrations 0001 and 0002)
2. `supabase secrets set ...`
3. `supabase functions deploy ai-coach send-reminders`
4. Set `app.settings.project_url` and `app.settings.cron_secret`
5. Apply 0003 — the cron schedule fires as soon as it exists

## Release checklist

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Version bumped in `pubspec.yaml` (`version: 1.0.0+1` — the `+N` build
      number must increase on every upload)
- [ ] Release build tested on a physical device, not just a simulator
- [ ] Offline mode verified with the network off
- [ ] Sign-in tested end to end including the OAuth redirect
- [ ] Coach tested with the Edge Function reachable *and* unreachable, so
      the offline fallback path is exercised
- [ ] "Delete all my data" verified against the database
- [ ] Debug symbols archived
- [ ] `docs/STORE_READINESS.md` walked

## CI

`.github/workflows/ci.yml` runs format, analyze and test on every push, and
verifies the animation generator is reproducible — a hand-edited asset that
the generator would not produce is a drift bug waiting to happen.

Release builds are not automated on purpose. A health app should have a
human decide when it ships.

## Rollback

- **Backend:** Edge Functions keep previous versions; redeploy the prior
  revision. Migrations are forward-only, so write a compensating migration
  rather than rewinding.
- **Android:** halt the staged rollout in Play Console. You cannot un-ship
  a fully rolled-out release — always stage to 10% first.
- **iOS:** remove from sale, or expedite a fix. There is no rollback.

Because content lives in `content_items`, a bad copy change can be fixed by
unpublishing a row rather than shipping a build.
