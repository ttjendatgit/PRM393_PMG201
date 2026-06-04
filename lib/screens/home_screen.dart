import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../models/grading_result.dart';
import '../models/grading_status.dart';
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
    required this.statuses,
    required this.message,
    required this.isGrading,
    required this.aiMode,
    required this.onPickFiles,
    required this.onGradeAll,
    required this.onSelectSubmission,
  });

  final List<Submission> submissions;
  final List<GradingResult> results;
  final Map<String, GradingStatus> statuses;
  final String message;
  final bool isGrading;
  final AiMode aiMode;
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
                'Upload student submissions (.txt), load an assessment rubric, and run AI-assisted grading.',
          ),
          const SizedBox(height: 10),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.primary),
          ),
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
                    statuses: statuses,
                    onTap: onSelectSubmission,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 7,
                  child: _UploadZone(
                    isGrading: isGrading,
                    aiMode: aiMode,
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
    required this.statuses,
    required this.onTap,
  });

  final List<Submission> submissions;
  final List<GradingResult> results;
  final Map<String, GradingStatus> statuses;
  final ValueChanged<int> onTap;

  GradingResult? _findResult(String fileName) {
    for (final r in results) {
      if (r.fileName == fileName) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Imported Submissions',
          action: submissions.isEmpty ? '' : '${submissions.length} files',
        ),
        const SizedBox(height: 14),
        if (submissions.isEmpty)
          const EmptyCard(
            text: 'No .txt files imported yet. Click Select .txt Files to begin.',
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final item = submissions[index];
                final status = statuses[item.fileName] ?? GradingStatus.pending;
                final result = _findResult(item.fileName);

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
                              const SizedBox(width: 8),
                              StatusPill(
                                text: status.label,
                                color: status.color,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (result != null) ...[
                            Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.badge_outlined,
                                  label: result.studentId,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoChip(
                                    icon: Icons.person_outline_rounded,
                                    label: result.studentName,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              '${item.sizeInBytes} bytes',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _UploadZone extends StatelessWidget {
  const _UploadZone({
    required this.isGrading,
    required this.aiMode,
    required this.onPickFiles,
    required this.onGradeAll,
  });

  final bool isGrading;
  final AiMode aiMode;
  final VoidCallback onPickFiles;
  final VoidCallback onGradeAll;

  String get _gradeButtonLabel {
    if (isGrading) return 'Grading...';
    return switch (aiMode) {
      AiMode.mock => 'Grade with Mock AI',
      AiMode.openRouter => 'Grade with OpenRouter AI',
      AiMode.gemini => 'Grade with Gemini AI',
    };
  }

  IconData get _gradeButtonIcon => switch (aiMode) {
    AiMode.mock => Icons.science_rounded,
    AiMode.openRouter => Icons.hub_rounded,
    AiMode.gemini => Icons.auto_awesome_rounded,
  };

  String get _providerFooter => switch (aiMode) {
    AiMode.mock => 'SUPPORTED FORMAT: .TXT  |  MOCK AI MODE',
    AiMode.openRouter => 'SUPPORTED FORMAT: .TXT  |  OPENROUTER AI',
    AiMode.gemini => 'SUPPORTED FORMAT: .TXT  |  GEMINI AI',
  };

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    'Upload Student Submissions',
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
                      'Select plain text (.txt) submission files. Load an assessment rubric in Assessment Setup, then grade with Mock AI, OpenRouter AI, or Gemini AI.',
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
                          foregroundColor:
                              isGrading ? AppColors.muted : AppColors.text,
                          side: BorderSide(
                            color: isGrading
                                ? AppColors.outlineVariant
                                : AppColors.outline,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isGrading ? null : onGradeAll,
                        icon: isGrading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.muted,
                                ),
                              )
                            : Icon(_gradeButtonIcon),
                        label: Text(
                          _gradeButtonLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _providerFooter,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
        if (action.isNotEmpty)
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
