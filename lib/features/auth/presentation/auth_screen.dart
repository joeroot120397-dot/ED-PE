import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/config/env.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';

/// Sign-in is optional by design.
///
/// The product works entirely on-device; an account exists only to sync
/// across devices and survive a reinstall. Forcing a man to hand over an
/// email address before he can find out whether the app is any use is the
/// fastest way to lose him, and this subject matter makes that worse.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;
  bool _linkSent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(
        () => _error =
            'Could not reach the server. You can keep using the app without '
            'an account.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendMagicLink() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _email.text.trim(),
        emailRedirectTo: Env.authRedirectUrl,
      );
      if (mounted) setState(() => _linkSent = true);
    });
  }

  Future<void> _oauth(OAuthProvider provider) => _run(() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      provider,
      redirectTo: Env.authRedirectUrl,
    );
  });

  Future<void> _continueWithoutAccount() async {
    await ref.read(repositoryProvider).markOnboardingSeen();
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return VitalScaffold(
      padBody: false,
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          Text(
            'Back up your progress',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'An account is optional. It exists so your programme and history '
            'survive a new phone - nothing more. Your coach conversations '
            'stay on this device either way.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.muted(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (Env.isOfflineDemo)
            const SectionCard(
              title: 'No backend configured',
              leadingIcon: Icons.cloud_off,
              child: Text(
                'This build has no Supabase project attached, so sign-in is '
                'unavailable. Everything still works - your data is stored '
                'encrypted on this device.',
              ),
            )
          else ...<Widget>[
            if (_linkSent)
              SectionCard(
                title: 'Check your email',
                leadingIcon: Icons.mark_email_read_outlined,
                child: Text(
                  'We sent a sign-in link to ${_email.text.trim()}. Open it '
                  'on this device and you will be signed in.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              )
            else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (String? v) {
                        final String value = (v ?? '').trim();
                        if (value.isEmpty) return 'Enter your email address';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value)) {
                          return 'That does not look like an email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _sendMagicLink,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Email me a sign-in link'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'or',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _oauth(OAuthProvider.google),
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _oauth(OAuthProvider.apple),
              icon: const Icon(Icons.apple, size: 22),
              label: const Text('Continue with Apple'),
            ),
          ],

          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: _busy ? null : _continueWithoutAccount,
            child: const Text('Continue without an account'),
          ),
        ],
      ),
    );
  }
}
