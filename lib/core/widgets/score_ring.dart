import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A circular score gauge.
///
/// [value] is always 0-100. [higherIsBetter] flips only the *colour* ramp,
/// never the sweep - a risk score of 80 draws a large red arc, and a health
/// score of 80 draws a large green one. Getting this wrong would show a
/// reassuring green ring for a high ED risk, so it is a required argument
/// with no default.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    required this.value,
    required this.label,
    required this.higherIsBetter,
    super.key,
    this.caption,
    this.size = 132,
    this.strokeWidth = 12,
    this.animate = true,
  });

  final int value;
  final String label;
  final bool higherIsBetter;
  final String? caption;
  final double size;
  final double strokeWidth;
  final bool animate;

  Color get _color => higherIsBetter
      ? AppColors.forScore(value.toDouble())
      : AppColors.forRisk(value.toDouble());

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label:
          '$label: $value out of 100'
          '${caption == null ? '' : '. $caption'}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value / 100),
          duration: Duration(milliseconds: animate ? 900 : 0),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double progress, _) => CustomPaint(
            painter: _RingPainter(
              progress: progress,
              color: _color,
              track: theme.dividerColor,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${(progress * 100).round()}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _color,
                      fontSize: size * 0.26,
                    ),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: size * 0.083,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// A horizontal confidence bar, used for root-cause percentages.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    required this.value,
    required this.label,
    super.key,
    this.trailing,
    this.higherIsBetter = false,
  });

  final double value;
  final String label;
  final String? trailing;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = higherIsBetter
        ? AppColors.forScore(value)
        : AppColors.forRisk(value);

    return Semantics(
      label:
          '$label: ${value.round()} percent'
          '${trailing == null ? '' : '. $trailing'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              Text(
                '${value.round()}%',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: theme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              trailing!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
