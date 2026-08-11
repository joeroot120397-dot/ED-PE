import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/exercise.dart';

/// Plays an exercise animation with the controls the brief calls for:
/// play/pause, speed control, a scrubbable progress bar, the starting
/// position, the motion path and the muscles being worked.
///
/// If the Lottie asset is missing or malformed the widget degrades to a
/// described placeholder rather than throwing - a broken animation must
/// never cost the user the instructions.
class ExerciseAnimationPlayer extends StatefulWidget {
  const ExerciseAnimationPlayer({
    required this.animation,
    super.key,
    this.height = 260,
  });

  final ExerciseAnimation animation;
  final double height;

  @override
  State<ExerciseAnimationPlayer> createState() =>
      _ExerciseAnimationPlayerState();
}

class _ExerciseAnimationPlayerState extends State<ExerciseAnimationPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  bool _playing = true;
  bool _failed = false;
  bool _showMuscles = true;
  double _speed = 1;

  static const List<double> _speeds = <double>[0.5, 0.75, 1.0, 1.5];

  @override
  void initState() {
    super.initState();
    _speed = widget.animation.defaultSpeed;
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    if (_playing) {
      _controller.repeat();
    }
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  void _cycleSpeed() {
    final int next = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    setState(() => _speed = _speeds[next]);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.navySoft.withValues(alpha: 0.35)
                : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: widget.animation.semanticLabel,
            image: true,
            child: _failed
                ? _AnimationFallback(animation: widget.animation)
                : Lottie.asset(
                    widget.animation.asset,
                    controller: _controller,
                    onLoaded: _onLoaded,
                    fit: BoxFit.contain,
                    frameRate: FrameRate.max,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stack,
                        ) {
                          // Flip the flag after this frame so the rebuild is
                          // legal; returning the fallback keeps this frame valid.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_failed) {
                              setState(() => _failed = true);
                            }
                          });
                          return _AnimationFallback(
                            animation: widget.animation,
                          );
                        },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ---- Transport controls ----
        Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: _failed ? null : _togglePlay,
              icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              tooltip: _playing ? 'Pause' : 'Play',
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Slider(
                value: _controller.value.clamp(0.0, 1.0),
                onChanged: _failed
                    ? null
                    : (double v) {
                        setState(() {
                          _playing = false;
                          _controller
                            ..stop()
                            ..value = v;
                        });
                      },
                label: '${(_controller.value * 100).round()}%',
              ),
            ),
            TextButton(
              onPressed: _failed ? null : _cycleSpeed,
              child: Text('${_speed}x'),
            ),
          ],
        ),

        // ---- Description ----
        _DetailRow(
          icon: Icons.my_location_outlined,
          label: 'Starting position',
          value: widget.animation.startingPosition,
        ),
        _DetailRow(
          icon: Icons.route_outlined,
          label: 'Movement',
          value: widget.animation.motionPath,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Muscle activation',
                style: theme.textTheme.labelLarge,
              ),
            ),
            Switch(
              value: _showMuscles,
              onChanged: (bool v) => setState(() => _showMuscles = v),
            ),
          ],
        ),
        if (_showMuscles)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String muscle in widget.animation.activatedMuscles)
                Chip(
                  label: Text(muscle),
                  avatar: const Icon(Icons.bolt, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.muted(context)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                children: <InlineSpan>[
                  TextSpan(
                    text: '$label: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimationFallback extends StatelessWidget {
  const _AnimationFallback({required this.animation});

  final ExerciseAnimation animation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.accessibility_new,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            animation.motionPath,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
