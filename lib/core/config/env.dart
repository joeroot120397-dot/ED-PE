/// Compile-time configuration.
///
/// Nothing secret lives in the binary. The Supabase anon key is a *public*
/// key whose blast radius is bounded by row level security (see
/// `supabase/migrations`). Model provider keys live only in Supabase Edge
/// Functions, never on device.
///
/// Supply values at build time:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
/// or with a JSON file: `--dart-define-from-file=env/dev.json`.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase calls this the *publishable* key (formerly "anon key"). It is
  /// public by design - row level security, not secrecy, is what protects
  /// the data behind it.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  /// Deep link used to return from Google / Apple OAuth.
  /// Must match the redirect URLs configured in the Supabase dashboard.
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.vitalrise.app://login-callback',
  );

  /// Name of the Edge Function backing the AI coach.
  static const String coachFunction = String.fromEnvironment(
    'COACH_FUNCTION',
    defaultValue: 'ai-coach',
  );

  static const bool firebaseEnabled = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: false,
  );

  /// When true the app runs entirely on-device with seeded content and an
  /// offline coach. Used for tests, demos and store review builds.
  static bool get isOfflineDemo =>
      supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@vitalrise.app',
  );

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://vitalrise.app/privacy',
  );

  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://vitalrise.app/terms',
  );
}
