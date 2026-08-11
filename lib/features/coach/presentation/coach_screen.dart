import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../domain/coach_service.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await ref.read(coachControllerProvider.notifier).send(text);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ChatMessage> messages =
        ref.watch(coachControllerProvider).valueOrNull ?? const <ChatMessage>[];

    return VitalScaffold(
      padBody: false,
      disclaimer: Disclaimers.coachDisclaimer,
      appBar: AppBar(
        title: const Text('Coach'),
        actions: <Widget>[
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear conversation',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Clear this conversation?'),
                    content: const Text(
                      'Your chat history is stored only on this device and '
                      'cannot be recovered once deleted.',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await ref.read(coachControllerProvider.notifier).clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messages.isEmpty
                ? _EmptyCoach(onAsk: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length + (_sending ? 1 : 0),
                    itemBuilder: (BuildContext context, int i) {
                      if (i >= messages.length) return const _TypingBubble();
                      return _MessageBubble(message: messages[i]);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about training, food, sleep, anxiety...',
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(_input.text),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'The coach cannot diagnose, prescribe or handle emergencies.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted(context),
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _EmptyCoach extends StatelessWidget {
  const _EmptyCoach({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Icon(Icons.forum_outlined, size: 44, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ask me anything',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'I answer from the VitalRise library - the same articles and '
          'exercise notes you can read yourself - and I know your assessment '
          'results, so answers are tailored to your causes.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.muted(context),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const DisclaimerBanner(
          text: Disclaimers.coachDisclaimer,
          icon: Icons.smart_toy_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Try one of these', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final String q in CoachService.suggestedQuestions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: OutlinedButton(
              onPressed: () => onAsk(q),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(q, textAlign: TextAlign.left),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.85,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadii.lg),
                  topRight: const Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(isUser ? AppRadii.lg : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadii.lg),
                ),
                border: isUser ? null : Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser ? Colors.white : null,
                      height: 1.5,
                    ),
                  ),
                  if (message.sources.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: theme.dividerColor, height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Based on: ${message.sources.join('; ')}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.muted(context),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (message.isError) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.cloud_off,
                          size: 12,
                          color: AppColors.muted(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Answered offline from the library',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.muted(context),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Thinking', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
