import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/config/env.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/vital_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = ref.watch(settingsProvider);
    final bool signedIn = ref.watch(isSignedInProvider);

    return VitalScaffold(
      title: 'Settings',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          // ---- Appearance --------------------------------------------
          SectionCard(
            title: 'Appearance',
            leadingIcon: Icons.palette_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: <ThemeMode>{settings.themeMode},
                  onSelectionChanged: (Set<ThemeMode> s) =>
                      ref.read(settingsProvider.notifier).setThemeMode(s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Accessibility -----------------------------------------
          SectionCard(
            title: 'Accessibility',
            leadingIcon: Icons.accessibility_new,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SwitchListTile(
                  value: settings.highContrast,
                  onChanged: (bool v) => ref
                      .read(settingsProvider.notifier)
                      .setHighContrast(value: v),
                  title: const Text('High contrast'),
                  subtitle: const Text(
                    'Stronger borders and outlines throughout the app',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Text size', style: theme.textTheme.titleSmall),
                Text(
                  'Applies on top of your system font size setting.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted(context),
                  ),
                ),
                Slider(
                  value: settings.textScale,
                  min: 0.9,
                  max: 1.6,
                  divisions: 7,
                  label: '${(settings.textScale * 100).round()}%',
                  onChanged: (double v) =>
                      ref.read(settingsProvider.notifier).setTextScale(v),
                ),
                Text(
                  'The quick brown fox jumps over the lazy dog.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Account -----------------------------------------------
          SectionCard(
            title: 'Account',
            subtitle: signedIn
                ? 'Signed in - your data syncs across devices'
                : Env.isOfflineDemo
                ? 'Running on-device only'
                : 'Not signed in - data stays on this device',
            leadingIcon: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (signedIn)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Signed out. Your data stays on this device.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  )
                else if (!Env.isOfflineDemo)
                  FilledButton.icon(
                    onPressed: () => context.push('/auth'),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in to back up your data'),
                  )
                else
                  Text(
                    'This build has no backend configured, so everything is '
                    'stored encrypted on this device and nothing leaves it.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Privacy -----------------------------------------------
          SectionCard(
            title: 'Privacy & data',
            leadingIcon: Icons.lock_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const BulletList(
                  items: <String>[
                    'Every health answer is encrypted with AES-256-GCM before '
                        'it touches disk, using a key held in the device '
                        'keystore',
                    'Coach conversations never leave your device',
                    'Row level security means the server can only ever return '
                        'your own rows',
                    'We never sell data, and there is no advertising SDK in '
                        'this app',
                  ],
                  icon: Icons.check,
                  iconSize: 14,
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.policy_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showLink(context, Env.privacyPolicyUrl),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Terms of use'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showLink(context, Env.termsUrl),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_forever,
                    color: AppColors.danger,
                  ),
                  title: const Text('Delete all my data'),
                  subtitle: const Text('Cannot be undone'),
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ---- Assessment --------------------------------------------
          SectionCard(
            title: 'Assessment',
            leadingIcon: Icons.assignment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => context.go('/results'),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('View my results'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.go('/assessment'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake the assessment'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const DisclaimerBanner(
            text: Disclaimers.urgentCare,
            icon: Icons.emergency_outlined,
            tone: BannerTone.urgent,
          ),
          const SizedBox(height: AppSpacing.md),

          Center(
            child: Text(
              'VitalRise - educational wellness app\n'
              'Support: ${Env.supportEmail}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLink(BuildContext context, String url) {
    // Deliberately not launching a browser from here: the store-review build
    // must not depend on a live domain. The URL is shown so it can be copied.
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Open in your browser'),
        content: SelectableText(url),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete everything?'),
        content: const Text(
          'This erases your assessment, programme, habit logs, progress '
          'check-ins and coach history from this device, and asks the server '
          'to delete its copy.\n\n'
          'The encryption key is destroyed too, so nothing left behind on '
          'disk can be recovered. There is no undo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await ref.read(repositoryProvider).deleteEverything();
    ref
      ..invalidate(assessmentResultProvider)
      ..invalidate(habitControllerProvider)
      ..invalidate(progressControllerProvider)
      ..invalidate(coachControllerProvider)
      ..invalidate(dietPreferencesProvider);
    ref.read(assessmentDraftProvider.notifier).clear();

    if (!context.mounted) return;
    context.go('/onboarding');
  }
}
