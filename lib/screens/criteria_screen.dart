import 'package:flutter/material.dart';
import '../models/assessment.dart';
import '../models/rubric.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/status_pill.dart';
import '../widgets/tiny_tag.dart';

class CriteriaPage extends StatelessWidget {
  const CriteriaPage({super.key, required this.assessment});

  final Assessment? assessment;

  @override
  Widget build(BuildContext context) {
    final a = assessment;

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeaderWithAction(
            title: a != null
                ? '${a.courseCode} — ${a.assessmentTitle}'
                : 'Criteria Matrix',
            subtitle: a != null
                ? 'Rubric for ${a.assessmentTitle}. '
                    '${a.totalRawScore.toInt()} raw marks → /${a.totalConvertedScore % 1 == 0 ? a.totalConvertedScore.toInt() : a.totalConvertedScore} converted. '
                    '${a.questions.isEmpty ? 'Text-only (no structured rubric).' : '${a.questions.length} question(s).'}'
                : 'No assessment loaded. Go to Assessment Setup to load or create one.',
            badge: a != null
                ? 'Total ${a.totalRawScore.toInt()} raw → /${a.totalConvertedScore % 1 == 0 ? a.totalConvertedScore.toInt() : a.totalConvertedScore}'
                : 'No Assessment',
            button: 'Assessment Setup',
          ),
          const SizedBox(height: 26),
          Expanded(child: a == null ? _buildEmpty() : _buildGrid(a)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rule_folder_rounded,
            size: 64,
            color: AppColors.muted.withAlpha(120),
          ),
          const SizedBox(height: 20),
          const Text(
            'No assessment rubric loaded.',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please create or load an assessment first.\nGo to Assessment Setup in the left navigation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(Assessment a) {
    if (a.questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 64,
              color: AppColors.muted.withAlpha(120),
            ),
            const SizedBox(height: 20),
            const Text(
              'Assessment loaded (text only).',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No structured rubric items were detected in the grading guide.\n'
              'Try importing a grading guide .txt with lines like:\n'
              '  Q1 - Project Charter: 20 marks\n'
              '  Q2 - Risk Register: 30 marks',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.6),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      itemCount: a.questions.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 390,
        mainAxisExtent: 320,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemBuilder: (context, index) {
        final q = a.questions[index];
        final weightFraction = q.rawMaxScore / a.totalRawScore;
        final weightPct = (weightFraction * 100).round();

        return _RubricCard(
          question: q,
          weightFraction: weightFraction,
          weightPct: weightPct,
          courseCode: a.courseCode,
        );
      },
    );
  }
}

class _RubricCard extends StatelessWidget {
  const _RubricCard({
    required this.question,
    required this.weightFraction,
    required this.weightPct,
    required this.courseCode,
  });

  final QuestionRubric question;
  final double weightFraction;
  final int weightPct;
  final String courseCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            minHeight: 4,
            value: weightFraction,
            backgroundColor: AppColors.surfaceHighest,
            color: AppColors.primary,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconForQuestion(question.questionId),
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          question.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(
                        text: '$weightPct%',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ScoreBadge(
                        label: 'Raw',
                        value: '${question.rawMaxScore.toInt()} pts',
                      ),
                      _ScoreBadge(
                        label: 'Conv',
                        value: '/${question.convertedMaxScore % 1 == 0 ? question.convertedMaxScore.toInt() : question.convertedMaxScore.toStringAsFixed(2)}',
                      ),
                      if (question.subCriteria.isNotEmpty)
                        _ScoreBadge(
                          label: 'Sub',
                          value: '${question.subCriteria.length} criteria',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Text(
                      question.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.45,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TinyTag(text: question.questionId.toUpperCase()),
                      const SizedBox(width: 8),
                      TinyTag(text: courseCode),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForQuestion(String qId) {
    switch (qId) {
      case 'q1':
        return Icons.assignment_rounded;
      case 'q2':
        return Icons.payments_rounded;
      case 'q3':
        return Icons.warning_amber_rounded;
      case 'q4':
        return Icons.group_rounded;
      default:
        return Icons.quiz_rounded;
    }
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(color: AppColors.muted),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
