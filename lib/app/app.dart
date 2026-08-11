import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class VitalRiseApp extends ConsumerWidget {
  const VitalRiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsProvider);
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'VitalRise',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: AppTheme.light(highContrast: settings.highContrast),
      darkTheme: AppTheme.dark(highContrast: settings.highContrast),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        // The in-app text scale multiplies the system setting rather than
        // replacing it, so a user who has already enlarged type system-wide
        // is not silently reset to 100%.
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: settings.textScale,
              maxScaleFactor: settings.textScale * 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
