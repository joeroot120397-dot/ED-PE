import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../domain/streaks.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<BadgeStatus> badges = ref.watch(badgeProvider);
    final StreakSummary streak = ref.watch(streakProvider);
    final int earned = badges.where((BadgeStatus b) => b.earned).length;

    return VitalScaffold(
      title: 'Badges',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          SectionCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    value: '${streak.current}',
                    label: 'Current streak',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${streak.longest}',
                    label: 'Longest streak',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '${streak.totalDays}',
                    label: 'Days trained',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: '$earned/${badges.length}',
                    label: 'Badges',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final BadgeStatus status in badges)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Opacity(
                opacity: status.earned ? 1 : 0.62,
                child: SectionCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: status.earned
                              ? AppColors.warning.withValues(alpha: 0.16)
                              : theme.dividerColor,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Text(
                          status.earned ? status.badge.emoji : '🔒',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              status.badge.title,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.badge.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted(context),
                                height: 1.4,
                              ),
                            ),
                            if (!status.earned) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: status.progress,
                                  minHeight: 5,
                                  backgroundColor: theme.dividerColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(status.progress * 100).round()}% there',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      ],
    );
  }
}
