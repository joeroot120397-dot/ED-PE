import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/disclaimers.dart';
import '../../../core/widgets/disclaimer.dart';
import '../../../core/widgets/vital_scaffold.dart';
import '../domain/assessment_models.dart';
import '../domain/question_bank.dart';

/// The intake, one question per screen.
///
/// One question at a time rather than a long form: the subject matter is
/// uncomfortable, and a wall of questions about erections is where people
/// abandon. Every answer is persisted immediately, so quitting halfway and
/// coming back tomorrow costs nothing.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _submitting = false;

  static const List<AssessmentQuestion> _questions = QuestionBank.all;

  @override
  void initState() {
    super.initState();
    // Restore a half-finished intake and drop the user back where they were.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AssessmentResponses? saved = await ref
          .read(repositoryProvider)
          .loadResponses();
      if (saved == null || saved.isEmpty || !mounted) return;
      ref.read(assessmentDraftProvider.notifier).restore(saved);

      final int resume = _questions.indexWhere(
        (AssessmentQuestion q) => saved[q.id] == null,
      );
      if (resume > 0) {
        setState(() => _index = resume);
        _controller.jumpToPage(resume);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AssessmentQuestion get _question => _questions[_index];

  /// Whether the user can move on from the current question.
  ///
  /// Numeric questions (age, height, weight, waist) render a sensible
  /// default on their slider, so the value on screen *is* an answer as far
  /// as the user is concerned. Requiring them to nudge the slider to
  /// confirm a number they can already see reads as a broken button - and
  /// a 32-year-old on the default of 32 would have no way forward at all.
  /// Scale questions are different: a 1-10 firmness rating has no
  /// defensible default, so those still need a deliberate tap.
  bool get _isAnswered {
    if (ref.read(assessmentDraftProvider)[_question.id] != null) return true;
    return _question.kind == AnswerKind.numeric &&
        _question.numeric?.initial != null;
  }

  /// Writes the displayed default for a numeric question the user chose not
  /// to adjust, so what was on screen is what gets scored.
  void _commitShownDefault() {
    final AssessmentQuestion q = _question;
    if (q.kind != AnswerKind.numeric) return;
    if (ref.read(assessmentDraftProvider)[q.id] != null) return;
    final double? initial = q.numeric?.initial;
    if (initial == null) return;
    ref
        .read(assessmentDraftProvider.notifier)
        .answer(q.id, NumericAnswer(initial));
  }

  void _goTo(int index) {
    if (index < 0 || index >= _questions.length) return;
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _advance() {
    _commitShownDefault();
    if (_index == _questions.length - 1) {
      _submit();
    } else {
      _goTo(_index + 1);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(assessmentDraftProvider.notifier).submit();
      if (mounted) context.go('/results');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AssessmentResponses responses = ref.watch(assessmentDraftProvider);
    final int answered = _questions
        .where((AssessmentQuestion q) => responses[q.id] != null)
        .length;

    return VitalScaffold(
      padBody: false,
      disclaimer: Disclaimers.standard,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _index == 0
              ? () => context.canPop() ? context.pop() : context.go('/')
              : () => _goTo(_index - 1),
        ),
        title: Text(_question.section.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: answered / _questions.length,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      'Question ${_index + 1} of ${_questions.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted(context),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$answered answered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _questions.length,
              onPageChanged: (int i) => setState(() => _index = i),
              itemBuilder: (BuildContext context, int i) => _QuestionView(
                question: _questions[i],
                isFirstOfSection:
                    i == 0 ||
                    _questions[i - 1].section != _questions[i].section,
                onAnswered: _advance,
              ),
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
              children: <Widget>[
                if (_index > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goTo(_index - 1),
                      child: const Text('Back'),
                    ),
                  ),
                if (_index > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : _isAnswered
                        ? _advance
                        : null,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _index == _questions.length - 1
                                ? 'See my results'
                                : 'Next',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({
    required this.question,
    required this.isFirstOfSection,
    required this.onAnswered,
  });

  final AssessmentQuestion question;
  final bool isFirstOfSection;
  final VoidCallback onAnswered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AssessmentResponses responses = ref.watch(assessmentDraftProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isFirstOfSection) ...<Widget>[
            DisclaimerBanner(
              text: question.section.subtitle,
              icon: Icons.segment,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            question.prompt,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (question.helper != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              question.helper!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted(context),
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          switch (question.kind) {
            AnswerKind.single => _ChoiceInput(
              question: question,
              selected: responses.choice(question.id),
              onSelected: (String value) {
                ref
                    .read(assessmentDraftProvider.notifier)
                    .answer(question.id, ChoiceAnswer(value));
                Future<void>.delayed(
                  const Duration(milliseconds: 180),
                  onAnswered,
                );
              },
            ),
            AnswerKind.numeric => _NumberInput(question: question),
            AnswerKind.scale => _ScaleInput(question: question),
          },
        ],
      ),
    );
  }
}

class _ChoiceInput extends StatelessWidget {
  const _ChoiceInput({
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final AssessmentQuestion question;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        for (final AnswerOption option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Semantics(
              button: true,
              selected: option.value == selected,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => onSelected(option.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: option.value == selected
                        ? theme.colorScheme.primary.withValues(alpha: 0.10)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: option.value == selected
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: option.value == selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        option.value == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: option.value == selected
                            ? theme.colorScheme.primary
                            : AppColors.slate400,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              option.label,
                              style: theme.textTheme.bodyLarge,
                            ),
                            if (option.detail != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  option.detail!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted(context),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NumberInput extends ConsumerWidget {
  const _NumberInput({required this.question});

  final AssessmentQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NumericSpec spec = question.numeric!;
    final double value =
        ref.watch(assessmentDraftProvider).number(question.id) ??
        spec.initial ??
        ((spec.min + spec.max) / 2);

    void set(double v) => ref
        .read(assessmentDraftProvider.notifier)
        .answer(question.id, NumericAnswer(spec.clamp(v.roundToDouble())));

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              value.round().toString(),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(spec.unit, style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Slider(
          value: spec.clamp(value),
          min: spec.min,
          max: spec.max,
          divisions: ((spec.max - spec.min) / spec.step).round(),
          label: '${value.round()} ${spec.unit}',
          onChanged: set,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton.outlined(
              onPressed: () => set(value - spec.step),
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease',
            ),
            Text(
              '${spec.min.round()} - ${spec.max.round()} ${spec.unit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            IconButton.outlined(
              onPressed: () => set(value + spec.step),
              icon: const Icon(Icons.add),
              tooltip: 'Increase',
            ),
          ],
        ),
      ],
    );
  }
}

class _ScaleInput extends ConsumerWidget {
  const _ScaleInput({required this.question});

  final AssessmentQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NumericSpec spec = question.numeric!;
    final double? current = ref
        .watch(assessmentDraftProvider)
        .number(question.id);
    final double value = current ?? spec.initial ?? spec.min;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int i = spec.min.round(); i <= spec.max.round(); i++)
              _ScaleDot(
                number: i,
                selected: current != null && value.round() == i,
                onTap: () => ref
                    .read(assessmentDraftProvider.notifier)
                    .answer(question.id, NumericAnswer(i.toDouble())),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              spec.lowLabel ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            Text(
              spec.highLabel ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScaleDot extends StatelessWidget {
  const _ScaleDot({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$number out of 10',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '$number',
            style: theme.textTheme.titleMedium?.copyWith(
              color: selected ? Colors.white : null,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
