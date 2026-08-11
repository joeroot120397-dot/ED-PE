import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/analytics/analytics_service.dart';
import 'core/config/env.dart';
import 'core/storage/health_store.dart';
import 'data/remote/remote_sync.dart';
import 'data/repositories/vitalrise_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Opening the encrypted store is the one thing that must succeed before
  // the first frame: every screen reads through it.
  final HealthStore store = await HealthStore.open();

  RemoteSync remote = const NoopRemoteSync();
  if (!Env.isOfflineDemo) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      remote = SupabaseRemoteSync(
        Supabase.instance.client,
        coachFunction: Env.coachFunction,
      );
    } on Object catch (error, stack) {
      // A backend that will not start must not stop the app: everything
      // except cross-device sync works on-device.
      debugPrint('Supabase init failed, continuing offline: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stack);
    }
  }

  final VitalRiseRepository repository = VitalRiseRepository(
    store: store,
    remote: remote,
  );

  await AnalyticsService.instance.initialise();

  // Pull anything the server has for a user who is already signed in, so a
  // reinstall lands on their real programme rather than an empty state.
  if (remote.isAvailable) {
    unawaited(repository.syncDown());
    unawaited(
      AnalyticsService.instance.pushToken().then(
        (String? token) => repository.registerForReminders(pushToken: token),
      ),
    );
  }

  runApp(
    ProviderScope(
      overrides: <Override>[repositoryProvider.overrideWithValue(repository)],
      child: const VitalRiseApp(),
    ),
  );
}
