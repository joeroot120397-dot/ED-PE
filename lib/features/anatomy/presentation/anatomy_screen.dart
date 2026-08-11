import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../domain/anatomy_topic.dart';

class AnatomyDetailScreen extends StatelessWidget {
  const AnatomyDetailScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final AnatomyTopic topic;
    try {
      topic = AnatomyLibrary.byId(topicId);
    } on StateError {
      return const VitalScaffold(
        title: 'Anatomy',
        body: EmptyState(
          icon: Icons.help_outline,
          title: 'Topic not found',
          message: 'It may have been renamed in a newer version.',
        ),
      );
    }

    return VitalScaffold(
      title: topic.title,
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          Text(
            topic.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.muted(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // The illustrations are drawn for a light background; on a dark
          // theme they sit on their own light card rather than being
          // recoloured, which would break the clinical colour coding.
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Semantics(
              label: topic.semanticLabel,
              image: true,
              child: SvgPicture.asset(
                topic.asset,
                fit: BoxFit.contain,
                // A blank box rather than a spinner: these files are
                // bundled, so they decode in a frame or two, and an
                // indeterminate spinner never settles for a test harness.
                placeholderBuilder: (BuildContext context) =>
                    const SizedBox(height: 200),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            topic.body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
          const SizedBox(height: AppSpacing.lg),

          SectionCard(
            title: 'What this means for you',
            leadingIcon: Icons.lightbulb_outline,
            child: BulletList(items: topic.takeaways),
          ),
        ],
      ),
    );
  }
}
