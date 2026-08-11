import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../../anatomy/domain/anatomy_topic.dart';
import '../domain/article.dart';
import '../domain/article_library.dart';

/// Two tabs: written articles, and the illustrated anatomy section.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _query = '';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Article> articles = ArticleLibrary.search(_query);

    return VitalScaffold(
      padBody: false,
      appBar: AppBar(
        title: const Text('Learn'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Articles'),
            Tab(text: 'Anatomy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search the library',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (String v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: articles.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Nothing matched',
                        message: 'Try a different word.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        itemCount: articles.length,
                        separatorBuilder: (BuildContext _, int _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final Article a = articles[i];
                          return SectionCard(
                            onTap: () => context.push('/article/${a.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.xs,
                                  children: <Widget>[
                                    VitalChip(
                                      label: a.topic.label,
                                      dense: true,
                                    ),
                                    VitalChip(
                                      label: '${a.readMinutes} min read',
                                      dense: true,
                                      color: AppColors.muted(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  a.title,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.summary,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted(context),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: AnatomyLibrary.all.length,
            separatorBuilder: (BuildContext _, int _) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              final AnatomyTopic t = AnatomyLibrary.all[i];
              return SectionCard(
                onTap: () => context.push('/anatomy/${t.id}'),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Icon(
                        Icons.biotech_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(t.title, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            t.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Article article;
    try {
      article = ArticleLibrary.byId(articleId);
    } on StateError {
      return const VitalScaffold(
        title: 'Article',
        body: EmptyState(
          icon: Icons.help_outline,
          title: 'Article not found',
          message: 'It may have been renamed in a newer version.',
        ),
      );
    }

    return VitalScaffold(
      title: article.topic.label,
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
            article.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              VitalChip(
                label: '${article.readMinutes} min read',
                dense: true,
                color: AppColors.muted(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            article.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.muted(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final ArticleSection section in article.sections) ...<Widget>[
            Text(
              section.heading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              section.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
