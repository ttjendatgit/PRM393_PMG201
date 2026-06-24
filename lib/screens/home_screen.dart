import 'package:flutter/material.dart';

import '../features/auth/models/user_profile.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../models/grading_result.dart';
import '../models/grading_status.dart';
import '../models/submission.dart';
import '../theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HomePage — Stitch desktop layout
// ═══════════════════════════════════════════════════════════════════════════════

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
    required this.onNavigate,
    this.currentAssessment,
    this.userProfile,
    this.backendOnline,
    this.questionUploaded = false,
    this.guideUploaded    = false,
  });

  final List<Submission>            submissions;
  final List<GradingResult>         results;
  final Map<String, GradingStatus>  statuses;
  final String                      message;
  final bool                        isGrading;
  final AiMode                      aiMode;
  final VoidCallback                onPickFiles;
  final VoidCallback                onGradeAll;
  final ValueChanged<int>           onSelectSubmission;
  final ValueChanged<int>           onNavigate;
  final Assessment?                 currentAssessment;
  final UserProfile?                userProfile;
  final bool?                       backendOnline;
  final bool                        questionUploaded;
  final bool                        guideUploaded;

  // ── Derived state ──────────────────────────────────────────────────────────

  bool get _isBackend => aiMode == AiMode.backend;

  GradingStatus _statusOf(Submission s) {
    final key = _isBackend ? s.id : s.fileName;
    return statuses[key] ?? GradingStatus.pending;
  }

  GradingResult? _resultFor(Submission s) {
    for (final r in results) {
      if (_isBackend ? r.submissionId == s.id : r.fileName == s.fileName) return r;
    }
    return null;
  }

  int get _aiGradedCount  => results.length;

  int get _reviewedCount  => statuses.values.where((s) =>
      s == GradingStatus.reviewed ||
      s == GradingStatus.finalized ||
      s == GradingStatus.exported).length;

  int get _finalizedCount => statuses.values.where((s) =>
      s == GradingStatus.finalized ||
      s == GradingStatus.exported).length;

  // Workflow step completion states
  bool get _wAssessment   => currentAssessment != null;
  // Use real backend metadata flags, not the Assessment text fields which
  // are not populated from the list/detail JSON responses.
  bool get _wFiles        => questionUploaded || guideUploaded;
  bool get _wRubric       => currentAssessment?.questions.isNotEmpty ?? false;
  bool get _wSubmissions  => submissions.isNotEmpty;
  bool get _wGraded       => _aiGradedCount > 0;
  bool get _wReviewed     => _reviewedCount > 0;
  bool get _wExported     => statuses.values.any((s) => s == GradingStatus.exported);

  // Next recommended action
  ({String title, String desc, IconData icon, VoidCallback? action}) get _nextAction {
    if (!_wAssessment) {
      return (
        title:  'Select Assessment',
        desc:   'Choose or create an assessment to begin the grading workflow.',
        icon:   Icons.assignment_rounded,
        action: () => onNavigate(1),
      );
    }
    if (!_wFiles) {
      return (
        title:  'Upload Question & Guide',
        desc:   'Upload the exam question and grading guide for this assessment.',
        icon:   Icons.upload_file_rounded,
        action: () => onNavigate(1),
      );
    }
    if (!_wRubric) {
      return (
        title:  'Parse Rubric',
        desc:   'The rubric has not been parsed yet. Go to Assessment Setup to parse it.',
        icon:   Icons.rule_rounded,
        action: () => onNavigate(1),
      );
    }
    if (!_wSubmissions) {
      return (
        title:  'Upload Submissions',
        desc:   'Upload student submission files to start grading.',
        icon:   Icons.folder_open_rounded,
        action: onPickFiles,
      );
    }
    if (!_wGraded) {
      return (
        title:  'Run AI Grading',
        desc:   'All submissions are ready. Start the AI grading process.',
        icon:   Icons.auto_awesome_rounded,
        action: onGradeAll,
      );
    }
    if (_reviewedCount < _aiGradedCount) {
      return (
        title:  'Review Submissions',
        desc:   '${_aiGradedCount - _reviewedCount} submission(s) are graded and awaiting your review.',
        icon:   Icons.rate_review_rounded,
        action: () => onNavigate(3),
      );
    }
    if (!_wExported) {
      return (
        title:  'Export Results',
        desc:   'All submissions reviewed. Export the grading results to Excel.',
        icon:   Icons.ios_share_rounded,
        action: () => onNavigate(4),
      );
    }
    return (
      title:  'Workflow Complete',
      desc:   'All steps are done. You can export again or start a new assessment.',
      icon:   Icons.verified_rounded,
      action: null,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomePage] assessment=${currentAssessment?.assessmentId}, '
        'q=$questionUploaded, guide=$guideUploaded, '
        'rubric=${currentAssessment?.questions.length ?? 0} items, '
        'submissions=${submissions.length}, results=${results.length}');
    final na = _nextAction;
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Hero header
            _HeroCard(
              userProfile:        userProfile,
              currentAssessment:  currentAssessment,
              submissions:        submissions,
              reviewedCount:      _reviewedCount,
              aiGradedCount:      _aiGradedCount,
            ),
            const SizedBox(height: 20),

            // B. Workflow progress
            _WorkflowCard(steps: [
              ('Assessment',   _wAssessment),
              ('Files',        _wFiles),
              ('Rubric',       _wRubric),
              ('Submissions',  _wSubmissions),
              ('AI Grading',   _wGraded),
              ('Review',       _wReviewed),
              ('Export',       _wExported),
            ]),
            const SizedBox(height: 20),

            // C + E / D side by side
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Next Action + Readiness
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      // C. Next Action
                      _NextActionCard(
                        title:    na.title,
                        desc:     na.desc,
                        icon:     na.icon,
                        action:   na.action,
                        isComplete: na.action == null,
                      ),
                      const SizedBox(height: 16),
                      // E. Assessment Readiness
                      _ReadinessCard(
                        assessment:       currentAssessment,
                        questionUploaded: questionUploaded,
                        guideUploaded:    guideUploaded,
                        backendOnline:    backendOnline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // D. Submission Intake
                Expanded(
                  flex: 6,
                  child: _SubmissionIntakeCard(
                    submissions:  submissions,
                    isGrading:    isGrading,
                    aiMode:       aiMode,
                    onPickFiles:  onPickFiles,
                    onGradeAll:   onGradeAll,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // F. Status cards (4)
            _StatusRow(
              totalSubmissions: submissions.length,
              aiGraded:         _aiGradedCount,
              reviewed:         _reviewedCount,
              finalized:        _finalizedCount,
            ),
            const SizedBox(height: 20),

            // G. Recent submissions table
            _RecentTable(
              submissions:       submissions,
              statusOf:          _statusOf,
              resultFor:         _resultFor,
              onSelectSubmission: onSelectSubmission,
              onNavigate:        onNavigate,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// A. Hero card
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.userProfile,
    required this.currentAssessment,
    required this.submissions,
    required this.reviewedCount,
    required this.aiGradedCount,
  });

  final UserProfile?  userProfile;
  final Assessment?   currentAssessment;
  final List<Submission> submissions;
  final int           reviewedCount;
  final int           aiGradedCount;

  @override
  Widget build(BuildContext context) {
    final name = userProfile?.displayName ?? 'Professor';
    final rubricParsed = currentAssessment?.questions.isNotEmpty ?? false;
    final pendingReview = aiGradedCount - reviewedCount;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $name',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          const Text(
            'Continue grading with PMG GradeAI',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Active assessment chip
              _HeroChip(
                icon:  Icons.assignment_rounded,
                label: currentAssessment != null
                    ? '${currentAssessment!.courseCode} — ${currentAssessment!.assessmentTitle}'
                    : 'No assessment selected',
                color: currentAssessment != null ? AppColors.primary : AppColors.muted,
              ),
              // Rubric chip
              _HeroChip(
                icon:  rubricParsed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                label: rubricParsed ? 'Rubric parsed' : 'No rubric',
                color: rubricParsed ? AppColors.success : AppColors.warning,
              ),
              // Submissions chip
              _HeroChip(
                icon:  Icons.upload_file_rounded,
                label: '${submissions.length} submission${submissions.length == 1 ? '' : 's'}',
                color: AppColors.secondary,
              ),
              // Pending review chip
              if (pendingReview > 0)
                _HeroChip(
                  icon:  Icons.rate_review_rounded,
                  label: '$pendingReview pending review',
                  color: AppColors.aiPurple,
                ),
            ],
          ),
          // Status message
          if (currentAssessment != null) ...[
            const SizedBox(height: 8),
            Text(
              currentAssessment!.assessmentTitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// B. Workflow progress card
// ═══════════════════════════════════════════════════════════════════════════════

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.steps});
  final List<(String, bool)> steps;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workflow Progress',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(steps.length * 2 - 1, (idx) {
              if (idx.isOdd) {
                // Connector line — offset from top to align with circle center (16px = 32/2)
                final prevDone = steps[idx ~/ 2].$2;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 15),
                    height: 2,
                    color: prevDone ? AppColors.success : AppColors.outlineVariant,
                  ),
                );
              }
              final si    = idx ~/ 2;
              final done  = steps[si].$2;
              final label = steps[si].$1;
              // Current step = first incomplete
              final isCurrent = !done &&
                  (si == 0 || steps[si - 1].$2);
              return SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.success
                            : isCurrent
                                ? AppColors.primary
                                : AppColors.surfaceHighest,
                        border: isCurrent
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Center(
                              child: Text(
                                '${si + 1}',
                                style: TextStyle(
                                  color:      isCurrent ? Colors.white : AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                  fontSize:   13,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize:   10,
                        color:      done ? AppColors.text : AppColors.muted,
                        fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// C. Next Action card
// ═══════════════════════════════════════════════════════════════════════════════

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.isComplete,
    this.action,
  });

  final String     title;
  final String     desc;
  final IconData   icon;
  final bool       isComplete;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    final accent = isComplete ? AppColors.success : AppColors.primary;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recommended Next Step',
                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: action,
                icon: Icon(icon, size: 16),
                label: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// D. Submission Intake card
// ═══════════════════════════════════════════════════════════════════════════════

class _SubmissionIntakeCard extends StatelessWidget {
  const _SubmissionIntakeCard({
    required this.submissions,
    required this.isGrading,
    required this.aiMode,
    required this.onPickFiles,
    required this.onGradeAll,
  });

  final List<Submission> submissions;
  final bool             isGrading;
  final AiMode           aiMode;
  final VoidCallback     onPickFiles;
  final VoidCallback     onGradeAll;

  String get _gradeLabel {
    if (isGrading) return 'Grading…';
    return switch (aiMode) {
      AiMode.mock       => 'Grade with Mock AI',
      AiMode.openRouter => 'Grade with OpenRouter',
      AiMode.gemini     => 'Grade with Gemini AI',
      AiMode.backend    => 'Grade via Backend',
    };
  }

  IconData get _gradeIcon => switch (aiMode) {
    AiMode.mock       => Icons.science_rounded,
    AiMode.openRouter => Icons.hub_rounded,
    AiMode.gemini     => Icons.auto_awesome_rounded,
    AiMode.backend    => Icons.cloud_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submission Intake',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  Text(
                    'Upload student work for AI grading',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Upload drop zone
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color:        AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(
                color: AppColors.outline,
                width: 1.5,
                // dashed effect via a decoration with stroke dash pattern is
                // not natively supported; we use a solid subtle border instead.
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Upload Student Submissions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supported formats: .txt, .md, .docx',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  submissions.isEmpty
                      ? 'No files uploaded yet'
                      : '${submissions.length} file${submissions.length == 1 ? '' : 's'} ready for grading',
                  style: TextStyle(
                    fontSize:   12,
                    color:      submissions.isEmpty ? AppColors.muted : AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: onPickFiles,
                  icon: const Icon(Icons.folder_open_rounded, size: 17),
                  label: const Text('Upload Files', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isGrading ? AppColors.muted : AppColors.primary,
                    side: BorderSide(
                      color: isGrading ? AppColors.outlineVariant : AppColors.primary,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: isGrading ? null : onGradeAll,
                  icon: isGrading
                      ? const SizedBox(
                          width: 15, height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
                        )
                      : Icon(_gradeIcon, size: 17),
                  label: Text(
                    _gradeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// E. Assessment Readiness card
// ═══════════════════════════════════════════════════════════════════════════════

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.assessment,
    required this.questionUploaded,
    required this.guideUploaded,
    required this.backendOnline,
  });

  final Assessment? assessment;
  final bool        questionUploaded;
  final bool        guideUploaded;
  final bool?       backendOnline;

  @override
  Widget build(BuildContext context) {
    // rubricParsed is derived from the Assessment model (populated by
    // AssessmentSetupScreen after parse-rubric succeeds).
    final rubricParsed = assessment?.questions.isNotEmpty ?? false;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assessment Readiness',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 14),
          _ReadinessRow(
            label:    'Question File',
            ok:       questionUploaded,
            okText:   'Uploaded',
            failText: 'Missing',
          ),
          _ReadinessRow(
            label:    'Guide File',
            ok:       guideUploaded,
            okText:   'Uploaded',
            failText: 'Missing',
          ),
          _ReadinessRow(
            label:    'Rubric',
            ok:       rubricParsed,
            okText:   'Parsed',
            failText: 'Not parsed',
          ),
          _ReadinessRow(
            label:    'Backend AI',
            ok:       backendOnline ?? false,
            okText:   'Connected',
            failText: backendOnline == null ? 'Checking…' : 'Disconnected',
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.ok,
    required this.okText,
    required this.failText,
  });

  final String label;
  final bool   ok;
  final String okText;
  final String failText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size:  16,
            color: ok ? AppColors.success : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ok
                  ? const Color(0xFFF0FDF4)
                  : AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ok ? okText : failText,
              style: TextStyle(
                fontSize:   11,
                color:      ok ? AppColors.success : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// F. Status cards row (4 cards)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.totalSubmissions,
    required this.aiGraded,
    required this.reviewed,
    required this.finalized,
  });

  final int totalSubmissions;
  final int aiGraded;
  final int reviewed;
  final int finalized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(
          label: 'Total Submissions',
          value: '$totalSubmissions',
          icon:  Icons.folder_open_rounded,
          color: AppColors.primary,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatTile(
          label: 'AI Graded',
          value: '$aiGraded',
          icon:  Icons.auto_awesome_rounded,
          color: AppColors.aiPurple,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatTile(
          label: 'Reviewed',
          value: '$reviewed',
          icon:  Icons.rate_review_rounded,
          color: AppColors.success,
        )),
        const SizedBox(width: 16),
        Expanded(child: _StatTile(
          label: 'Finalized',
          value: '$finalized',
          icon:  Icons.verified_rounded,
          color: AppColors.secondary,
        )),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        color.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// G. Recent Submissions table
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentTable extends StatelessWidget {
  const _RecentTable({
    required this.submissions,
    required this.statusOf,
    required this.resultFor,
    required this.onSelectSubmission,
    required this.onNavigate,
  });

  final List<Submission>                          submissions;
  final GradingStatus Function(Submission)        statusOf;
  final GradingResult? Function(Submission)       resultFor;
  final ValueChanged<int>                         onSelectSubmission;
  final ValueChanged<int>                         onNavigate;

  String _ext(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1).toUpperCase() : '—';
  }

  ({Color bg, Color fg}) _statusColors(GradingStatus s) => switch (s) {
    GradingStatus.pending   => (bg: AppColors.surfaceHighest, fg: AppColors.muted),
    GradingStatus.grading   => (bg: const Color(0xFFFFFBEB), fg: const Color(0xFFD97706)),
    GradingStatus.graded    => (bg: AppColors.primaryContainer, fg: AppColors.primary),
    GradingStatus.reviewed  => (bg: const Color(0xFFF0FDF4), fg: AppColors.success),
    GradingStatus.finalized => (bg: const Color(0xFFEFF6FF), fg: AppColors.secondary),
    GradingStatus.exported  => (bg: const Color(0xFFF5F3FF), fg: const Color(0xFF7C3AED)),
    GradingStatus.error     => (bg: const Color(0xFFFEF2F2), fg: AppColors.error),
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Recent Submissions',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const Spacer(),
                if (submissions.isNotEmpty)
                  Text(
                    '${submissions.length} file${submissions.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.surfaceContainer,
            child: const Row(
              children: [
                SizedBox(width: 32, child: _ColHeader('#')),
                SizedBox(width: 16),
                Expanded(flex: 5, child: _ColHeader('File Name')),
                SizedBox(width: 12),
                SizedBox(width: 52, child: _ColHeader('Format')),
                SizedBox(width: 12),
                SizedBox(width: 110, child: _ColHeader('Status')),
                SizedBox(width: 12),
                SizedBox(width: 68, child: _ColHeader('Score')),
                SizedBox(width: 12),
                SizedBox(width: 100, child: _ColHeader('Action')),
              ],
            ),
          ),
          // Rows
          if (submissions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No submissions uploaded yet.\nUse Upload Files to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
                ),
              ),
            )
          else
            for (int i = 0; i < submissions.length; i++) ...[
              _TableRow(
                index:      i,
                submission: submissions[i],
                status:     statusOf(submissions[i]),
                result:     resultFor(submissions[i]),
                ext:        _ext(submissions[i].fileName),
                statusColors: _statusColors(statusOf(submissions[i])),
                onTap: () {
                  onSelectSubmission(i);
                  onNavigate(3);
                },
              ),
            ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.index,
    required this.submission,
    required this.status,
    required this.result,
    required this.ext,
    required this.statusColors,
    required this.onTap,
  });

  final int               index;
  final Submission        submission;
  final GradingStatus     status;
  final GradingResult?    result;
  final String            ext;
  final ({Color bg, Color fg}) statusColors;
  final VoidCallback      onTap;

  @override
  Widget build(BuildContext context) {
    final scoreText = result != null
        ? result!.finalScore.toStringAsFixed(1)
        : '—';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 32,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 16),
            // File name
            Expanded(
              flex: 5,
              child: Text(
                submission.fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Format
            SizedBox(
              width: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ext,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Status
            SizedBox(
              width: 110,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        statusColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize:   11,
                    color:      statusColors.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Score
            SizedBox(
              width: 68,
              child: Text(
                scoreText,
                style: TextStyle(
                  fontSize:   13,
                  color:      result != null ? AppColors.text : AppColors.muted,
                  fontWeight: result != null ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Action
            SizedBox(
              width: 100,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onTap,
                child: Text(
                  status == GradingStatus.graded ? 'Review' : 'Open',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared card wrapper
// ═══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget   child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color:       const Color(0xFF4F46E5).withAlpha(6),
            blurRadius:  12,
            offset:      const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
