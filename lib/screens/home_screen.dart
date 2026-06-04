import 'package:flutter/material.dart';
import '../models/grading_result.dart';
import '../models/submission.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_card.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/status_pill.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.submissions,
    required this.results,
    required this.message,
    required this.isGrading,
    required this.onPickFiles,
    required this.onGradeAll,
    required this.onSelectSubmission,
  });

  final List<Submission> submissions;
  final List<GradingResult> results;
  final String message;
  final bool isGrading;
  final VoidCallback onPickFiles;
  final VoidCallback onGradeAll;
  final ValueChanged<int> onSelectSubmission;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            title: 'Workspace',
            subtitle:
                'Upload PMG201c submissions, prepare rubric criteria, and start the AI-assisted grading pipeline.',
          ),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: AppColors.primary)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _SubmissionsPanel(
                    submissions: submissions,
                    results: results,
                    onTap: onSelectSubmission,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 7,
                  child: _UploadZone(
                    isGrading: isGrading,
                    onPickFiles: onPickFiles,
                    onGradeAll: onGradeAll,
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

class _SubmissionsPanel extends StatelessWidget {
  const _SubmissionsPanel({
    required this.submissions,
    required this.results,
    required this.onTap,
  });

  final List<Submission> submissions;
  final List<GradingResult> results;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Imported Submissions', action: 'View All'),
        const SizedBox(height: 14),
        if (submissions.isEmpty)
          EmptyCard(
            text:
                'No .txt files imported yet. Click Select .txt Files to begin.',
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final item = submissions[index];
                final graded = results.any((r) => r.fileName == item.fileName);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onTap(index),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.fileName,
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              StatusPill(
                                text: graded ? 'Graded' : 'Not Graded',
                                color: graded
                                    ? AppColors.primary
                                    : AppColors.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${item.sizeInBytes} bytes',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _UploadZone extends StatelessWidget {
  const _UploadZone({
    required this.isGrading,
    required this.onPickFiles,
    required this.onGradeAll,
  });

  final bool isGrading;
  final VoidCallback onPickFiles;
  final VoidCallback onGradeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 420),
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant, width: 1.6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 86,
            width: 86,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: AppColors.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload PMG201c Submissions',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            width: 520,
            child: Text(
              'Select plain text assignment files to begin translation, rubric matching, AI scoring, and Excel-ready result generation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF00297A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPickFiles,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text(
                  'Select .txt Files',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.outline),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isGrading ? null : onGradeAll,
                icon: const Icon(Icons.translate_rounded),
                label: Text(isGrading ? 'Grading...' : 'Translate + Grade'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'SUPPORTED FORMAT: .TXT | PHASE 1 MOCK AI',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
