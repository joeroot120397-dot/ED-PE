import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../habits/domain/habit_log.dart';
import '../domain/progress_entry.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<ProgressEntry> entries =
        ref.watch(progressControllerProvider).valueOrNull ??
        const <ProgressEntry>[];
    final List<HabitLog> logs =
        ref.watch(habitControllerProvider).valueOrNull ?? const <HabitLog>[];
    final List<MetricTrend> trends = ref.watch(trendProvider);

    final DayKey thisWeek = ProgressAnalytics.weekStartOf(DateTime.now());
    final bool checkedIn = entries.any(
      (ProgressEntry e) => e.weekStart == thisWeek,
    );

    return VitalScaffold(
      padBody: false,
      disclaimer: Disclaimers.scoreExplainer,
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          // ---- Weekly check-in ----------------------------------------
          SectionCard(
            title: checkedIn ? 'This week is logged' : 'Weekly check-in',
            subtitle: 'Week of ${DateFormat('d MMM').format(thisWeek.date)}',
            leadingIcon: Icons.event_note_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  checkedIn
                      ? 'You can update this week\'s ratings any time before '
                            'Sunday.'
                      : 'Five quick ratings. Consistency matters more than '
                            'precision - rate how the week felt overall.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => _checkIn(context, ref, entries, thisWeek),
                  icon: Icon(checkedIn ? Icons.edit : Icons.add),
                  label: Text(checkedIn ? 'Update ratings' : 'Check in'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.show_chart,
              title: 'No trends yet',
              message:
                  'Charts appear after your second weekly check-in. Two '
                  'points is the minimum a trend can be drawn from.',
            )
          else ...<Widget>[
            // ---- Trend summary ---------------------------------------
            SectionCard(
              title: 'Since you started',
              leadingIcon: Icons.trending_up,
              child: Column(
                children: <Widget>[
                  for (final MetricTrend t in trends)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            t.samples < 2
                                ? Icons.remove
                                : t.isImproving
                                ? Icons.arrow_upward
                                : t.isFlat
                                ? Icons.remove
                                : Icons.arrow_downward,
                            size: 18,
                            color: t.samples < 2 || t.isFlat
                                ? AppColors.slate400
                                : t.isImproving
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              t.metric.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            t.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ---- Metric charts ---------------------------------------
            for (final ProgressMetric metric in ProgressMetric.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _MetricChart(
                  metric: metric,
                  series: ProgressAnalytics.series(entries, metric),
                ),
              ),
          ],

          // ---- Body charts -------------------------------------------
          _BodyChart(
            title: 'Weight',
            unit: 'kg',
            series: ProgressAnalytics.bodySeries(logs, waist: false),
          ),
          const SizedBox(height: AppSpacing.md),
          _BodyChart(
            title: 'Waist',
            unit: 'cm',
            series: ProgressAnalytics.bodySeries(logs, waist: true),
          ),
        ],
      ),
    );
  }

  Future<void> _checkIn(
    BuildContext context,
    WidgetRef ref,
    List<ProgressEntry> entries,
    DayKey weekStart,
  ) async {
    ProgressEntry? existing;
    for (final ProgressEntry e in entries) {
      if (e.weekStart == weekStart) existing = e;
    }

    final ProgressEntry? entry = await showModalBottomSheet<ProgressEntry>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          _CheckInSheet(weekStart: weekStart, existing: existing),
    );
    if (entry == null) return;
    await ref.read(progressControllerProvider.notifier).submit(entry);
  }
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({required this.metric, required this.series});

  final ProgressMetric metric;
  final List<(DayKey, int)> series;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (series.length < 2) {
      return SectionCard(
        title: metric.label,
        child: Text(
          'One more check-in and this chart appears.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      );
    }

    final Color line = metric.higherIsBetter
        ? theme.colorScheme.primary
        : AppColors.info;

    return SectionCard(
      title: metric.label,
      subtitle: metric.higherIsBetter ? 'Higher is better' : 'Lower is better',
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 10,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (double v) =>
                  FlLine(color: theme.dividerColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  reservedSize: 26,
                  getTitlesWidget: (double v, TitleMeta meta) => Text(
                    v.round().toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: (series.length / 4).ceilToDouble(),
                  getTitlesWidget: (double v, TitleMeta meta) {
                    final int i = v.round();
                    if (i < 0 || i >= series.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      DateFormat('d/M').format(series[i].$1.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                isCurved: true,
                curveSmoothness: 0.25,
                color: line,
                barWidth: 3,
                dotData: const FlDotData(),
                belowBarData: BarAreaData(
                  show: true,
                  color: line.withValues(alpha: 0.12),
                ),
                spots: <FlSpot>[
                  for (int i = 0; i < series.length; i++)
                    FlSpot(i.toDouble(), series[i].$2.toDouble()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyChart extends StatelessWidget {
  const _BodyChart({
    required this.title,
    required this.unit,
    required this.series,
  });

  final String title;
  final String unit;
  final List<(DayKey, double)> series;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (series.length < 2) {
      return SectionCard(
        title: title,
        child: Text(
          'Log your $title at least twice from the Today screen and the trend '
          'appears here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted(context),
          ),
        ),
      );
    }

    final double min = series
        .map(((DayKey, double) e) => e.$2)
        .reduce((double a, double b) => a < b ? a : b);
    final double max = series
        .map(((DayKey, double) e) => e.$2)
        .reduce((double a, double b) => a > b ? a : b);
    final double pad = ((max - min) * 0.2).clamp(1.0, 10.0);
    final double change = series.last.$2 - series.first.$2;

    return SectionCard(
      title: title,
      subtitle:
          '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} $unit '
          'since your first entry',
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minY: min - pad,
            maxY: max + pad,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (double v) =>
                  FlLine(color: theme.dividerColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (double v, TitleMeta meta) => Text(
                    v.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: (series.length / 4).ceilToDouble(),
                  getTitlesWidget: (double v, TitleMeta meta) {
                    final int i = v.round();
                    if (i < 0 || i >= series.length) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      DateFormat('d/M').format(series[i].$1.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                isCurved: true,
                curveSmoothness: 0.25,
                color: AppColors.warning,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.warning.withValues(alpha: 0.12),
                ),
                spots: <FlSpot>[
                  for (int i = 0; i < series.length; i++)
                    FlSpot(i.toDouble(), series[i].$2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.weekStart, this.existing});

  final DayKey weekStart;
  final ProgressEntry? existing;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  late final Map<ProgressMetric, int> _ratings = <ProgressMetric, int>{
    for (final ProgressMetric m in ProgressMetric.values)
      m: widget.existing?.ratingFor(m) ?? 5,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Weekly check-in', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rate the week overall, not your best or worst day.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final ProgressMetric m in ProgressMetric.values) ...<Widget>[
              Text(m.prompt, style: theme.textTheme.titleSmall),
              Slider(
                value: _ratings[m]!.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '${_ratings[m]}',
                onChanged: (double v) =>
                    setState(() => _ratings[m] = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    m.lowLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                  Text(
                    m.highLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                ProgressEntry(
                  weekStart: widget.weekStart,
                  ratings: _ratings,
                  weightKg: widget.existing?.weightKg,
                  waistCm: widget.existing?.waistCm,
                ),
              ),
              child: const Text('Save check-in'),
            ),
          ],
        ),
      ),
    );
  }
}
