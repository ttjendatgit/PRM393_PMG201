import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../models/grading_result.dart';
import '../models/question_result.dart';
import '../models/submission.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_card.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/status_pill.dart';
import '../widgets/tiny_tag.dart';

class GradingPage extends StatelessWidget {
  const GradingPage({
    super.key,
    required this.submission,
    required this.result,
    required this.onGradeAll,
    required this.aiMode,
    required this.assessment,
  });

  final Submission? submission;
  final GradingResult? result;
  final VoidCallback onGradeAll;
  final AiMode aiMode;
  final Assessment? assessment;

  @override
  Widget build(BuildContext context) {
    if (submission == null) {
      return PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageTitle(
              title: 'AI Grading Detail',
              subtitle:
                  'Select a submission from Home to preview content and AI analysis.',
            ),
            const SizedBox(height: 24),
            const EmptyCard(
              text:
                  'No submission selected. Go to Home, import .txt files, then click a submission.',
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF060E20),
            child: Column(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    border: Border(
                      bottom: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_rounded,
                        color: AppColors.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        submission!.fileName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(36),
                    child: Container(
                      width: 760,
                      padding: const EdgeInsets.all(44),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        border: Border.all(color: AppColors.outlineVariant),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 18,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Text(
                        submission!.content,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.65,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AiPanel(
          result: result,
          onGradeAll: onGradeAll,
          aiMode: aiMode,
          assessment: assessment,
        ),
      ],
    );
  }
}

class AiPanel extends StatelessWidget {
  const AiPanel({
    super.key,
    required this.result,
    required this.onGradeAll,
    required this.aiMode,
    required this.assessment,
  });

  final GradingResult? result;
  final VoidCallback onGradeAll;
  final AiMode aiMode;
  final Assessment? assessment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  aiMode == AiMode.openRouter
                      ? Icons.hub_rounded
                      : Icons.science_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Analysis Panel',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                StatusPill(
                  text: result == null ? 'Pending' : 'Complete',
                  color: result == null ? AppColors.muted : AppColors.primary,
                ),
              ],
            ),
          ),
          Expanded(
            child: result == null
                ? _buildPendingState()
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      ScoreCard(
                        result: result!,
                        maxRawScore: assessment?.totalRawScore ?? 100,
                        maxConvertedScore: assessment?.totalConvertedScore ?? 10,
                      ),
                      const SizedBox(height: 18),
                      result!.questionResults != null
                          ? QuestionResultList(
                              questionResults: result!.questionResults!,
                            )
                          : CriteriaMiniGrid(result: result!),
                      const SizedBox(height: 22),
                      FeedbackBox(feedback: result!.feedback),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          EmptyCard(
            text: aiMode == AiMode.openRouter
                ? 'This submission has not been graded yet. Make sure an assessment is loaded and a valid API key is saved, then click Grade with OpenRouter AI.'
                : 'This submission has not been graded yet. Click Grade with AI to run mock grading.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.text,
            ),
            onPressed: onGradeAll,
            icon: Icon(
              aiMode == AiMode.openRouter
                  ? Icons.hub_rounded
                  : Icons.auto_awesome_rounded,
            ),
            label: Text(
              aiMode == AiMode.openRouter ? 'Grade with OpenRouter AI' : 'Grade with AI',
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.result,
    required this.maxRawScore,
    required this.maxConvertedScore,
  });

  final GradingResult result;
  final double maxRawScore;
  final double maxConvertedScore;

  String _fmt(double v, {bool integer = false}) {
    if (integer) return v.toInt().toString();
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final rawProgress =
        maxRawScore > 0 ? (result.totalRawScore / maxRawScore).clamp(0.0, 1.0) : 0.0;
    final convProgress =
        maxConvertedScore > 0 ? (result.finalScore / maxConvertedScore).clamp(0.0, 1.0) : 0.0;
    final threshold = maxConvertedScore * 0.6;
    final passed = result.finalScore >= threshold;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECOMMENDED SCORE',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          // Raw Score row
          Row(
            children: [
              const Text(
                'Raw Score',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_fmt(result.totalRawScore, integer: true)} / ${_fmt(maxRawScore, integer: true)}',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            minHeight: 4,
            value: rawProgress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: 16),
          // Converted Score row
          Row(
            children: [
              const Text(
                'Converted Score',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    result.finalScore.toStringAsFixed(1),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '/ ${_fmt(maxConvertedScore)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 8,
            value: convProgress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Threshold: ${threshold.toStringAsFixed(1)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Spacer(),
              Text(
                passed ? 'Pass' : 'Below Threshold',
                style: TextStyle(
                  color: passed ? AppColors.primary : AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuestionResultList extends StatelessWidget {
  const QuestionResultList({super.key, required this.questionResults});

  final List<QuestionResult> questionResults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUESTION BREAKDOWN',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ...questionResults.map(
          (qr) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuestionResultCard(qr: qr),
          ),
        ),
      ],
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  const _QuestionResultCard({required this.qr});

  final QuestionResult qr;

  String _fmtMax(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final progress = qr.maxRawScore > 0
        ? (qr.rawScore / qr.maxRawScore).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  qr.questionTitle,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TinyTag(
                    text: 'Raw  ${qr.rawScore.toInt()} / ${_fmtMax(qr.maxRawScore)}',
                  ),
                  const SizedBox(height: 4),
                  TinyTag(
                    text: 'Conv  ${qr.convertedScore.toStringAsFixed(1)} / ${_fmtMax(qr.maxConvertedScore)}',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 4,
            value: progress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.primary,
          ),
          if (qr.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              qr.comment,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CriteriaMiniGrid extends StatelessWidget {
  const CriteriaMiniGrid({super.key, required this.result});

  final GradingResult result;

  @override
  Widget build(BuildContext context) {
    final entries = result.criteriaScores.entries.toList();

    return GridView.builder(
      itemCount: entries.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 118,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final item = entries[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TinyTag(text: item.value.toStringAsFixed(1)),
              const SizedBox(height: 10),
              Text(
                item.key,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Mock AI scoring',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FeedbackBox extends StatelessWidget {
  const FeedbackBox({super.key, required this.feedback});

  final String feedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FINAL COMMENT',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            feedback,
            style: const TextStyle(color: AppColors.text, height: 1.55),
          ),
        ),
      ],
    );
  }
}
