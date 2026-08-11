import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../constants/disclaimers.dart';

/// The regulatory footer that must appear on every screen.
///
/// Rendered automatically by [VitalScaffold], so screens do not have to
/// remember - and `test/core/disclaimer_coverage_test.dart` fails the build
/// if a screen bypasses the scaffold.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key, this.text = Disclaimers.standard});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      liveRegion: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, size: 15, color: AppColors.muted(context)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A prominent in-content notice, used where a specific caveat matters more
/// than the standing footer - exercise safety, nutrition limits, coach
/// limitations.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({
    required this.text,
    super.key,
    this.icon = Icons.shield_outlined,
    this.tone = BannerTone.neutral,
  });

  final String text;
  final IconData icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = switch (tone) {
      BannerTone.neutral => AppColors.info,
      BannerTone.caution => AppColors.warning,
      BannerTone.urgent => AppColors.danger,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { neutral, caution, urgent }
