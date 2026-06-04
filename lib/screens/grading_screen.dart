import 'package:flutter/material.dart';
import '../models/grading_result.dart';
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
  });

  final Submission? submission;
  final GradingResult? result;
  final VoidCallback onGradeAll;

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
        AiPanel(result: result, onGradeAll: onGradeAll),
      ],
    );
  }
}

class AiPanel extends StatelessWidget {
  const AiPanel({
    super.key,
    required this.result,
    required this.onGradeAll,
  });

  final GradingResult? result;
  final VoidCallback onGradeAll;

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
                const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
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
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const EmptyCard(
                          text:
                              'This submission has not been graded yet. Click the button below to run mock AI grading.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onGradeAll,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Run Mock AI Grading'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      ScoreCard(result: result!),
                      const SizedBox(height: 18),
                      CriteriaMiniGrid(result: result!),
                      const SizedBox(height: 22),
                      FeedbackBox(feedback: result!.feedback),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.result});

  final GradingResult result;

  @override
  Widget build(BuildContext context) {
    final progress = result.finalScore / 10;

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
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.finalScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  '/ 10',
                  style: TextStyle(color: AppColors.muted, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: AppColors.surfaceHigh,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Text(
                'Threshold: 6.0',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Spacer(),
              Text(
                'Excellent',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
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
                'Mock AI scoring breakdown',
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
          'DETAILED FEEDBACK',
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
