import 'package:flutter/material.dart';

import '../features/auth/models/user_profile.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../models/grading_result.dart';
import '../models/grading_status.dart';
import '../models/submission.dart';
import '../theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// HomePage — compact SaaS-dashboard layout
// ═══════════════════════════════════════════════════════════════════════════════

enum _StepState { complete, current, pending }

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

  // ── Derived state — all computed from the real data passed in ──────────────
  //
  // Deliberately NOT using `statuses[id]` as the source of truth for a
  // submission's grading status: after an Excel export, main.dart's
  // _exportBackendExcel() overwrites every graded submission's cached status
  // to GradingStatus.exported, which would hide a Finalized/Reviewed result
  // behind a generic "Exported" badge. Instead we derive status/score
  // directly from GradingResult.status / .reviewStatus (the authoritative
  // Backend fields), falling back to `statuses` only for submissions that
  // have no result yet (Pending / Grading / a pre-grading extraction Error).

  bool get _isBackend => aiMode == AiMode.backend;

  GradingResult? _resultFor(Submission s) {
    for (final r in results) {
      if (_isBackend ? r.submissionId == s.id : r.fileName == s.fileName) return r;
    }
    return null;
  }

  /// True when [s] has a persisted grading result that is not an ERROR
  /// placeholder — i.e. grading actually produced usable scores.
  bool _hasValidResult(Submission s) {
    final r = _resultFor(s);
    return r != null && r.status != 'ERROR';
  }

  /// Authoritative display status for one submission, preferring the
  /// GradingResult's own fields over the (sometimes stale) cached map.
  GradingStatus _displayStatus(Submission s) {
    final r = _resultFor(s);
    if (r != null) {
      if (r.status == 'ERROR') return GradingStatus.error;
      switch (r.reviewStatus) {
        case 'FINALIZED': return GradingStatus.finalized;
        case 'REVIEWED':  return GradingStatus.reviewed;
        default:          return GradingStatus.graded; // AI_GRADED
      }
    }
    final key    = _isBackend ? s.id : s.fileName;
    final cached = statuses[key] ?? GradingStatus.pending;
    if (cached == GradingStatus.grading) return GradingStatus.grading;
    if (cached == GradingStatus.error)   return GradingStatus.error;
    return GradingStatus.pending;
  }

  // ── KPI counts (mutually exclusive, derived from real results) ─────────────

  int get _totalCount => submissions.length;

  /// No valid (non-ERROR) result yet — covers never-graded AND failed.
  int get _pendingCount => submissions.where((s) => !_hasValidResult(s)).length;

  int get _reviewedCount => results
      .where((r) => r.status != 'ERROR' && r.reviewStatus == 'REVIEWED')
      .length;

  int get _finalizedCount => results
      .where((r) => r.status != 'ERROR' && r.reviewStatus == 'FINALIZED')
      .length;

  int get _awaitingReviewCount => results
      .where((r) => r.status != 'ERROR' && r.reviewStatus == 'AI_GRADED')
      .length;

  int get _reviewedNotFinalizedCount => _reviewedCount;

  // ── Workflow step completion (booleans preserved from existing logic) ──────

  bool get _wAssessmentDone => currentAssessment != null;
  // Preserves the existing OR-based readiness check (not tightened to AND).
  bool get _wFilesDone      => questionUploaded || guideUploaded;
  bool get _wRubricDone     => currentAssessment?.questions.isNotEmpty ?? false;
  bool get _wExportDone     => statuses.values.any((s) => s == GradingStatus.exported);

  _StepState get _aiGradingState {
    if (submissions.isEmpty) return _StepState.pending;
    if (isGrading || _pendingCount > 0) return _StepState.current;
    return _StepState.complete;
  }

  _StepState get _reviewState {
    if (_aiGradingState != _StepState.complete) return _StepState.pending;
    if (_awaitingReviewCount > 0) return _StepState.current;
    return _StepState.complete;
  }

  // ── Recommended Next Step ───────────────────────────────────────────────────

  ({String title, String desc, IconData icon, VoidCallback action, bool isComplete}) get _nextAction {
    if (!_wAssessmentDone) {
      return (
        title: 'Create an Assessment',
        desc:  'Choose or create an assessment to begin the grading workflow.',
        icon:  Icons.assignment_rounded,
        action: () => onNavigate(1),
        isComplete: false,
      );
    }
    if (!_wFilesDone) {
      return (
        title: 'Upload Assessment Files',
        desc:  'Upload the exam question and grading guide for this assessment.',
        icon:  Icons.upload_file_rounded,
        action: () => onNavigate(1),
        isComplete: false,
      );
    }
    if (!_wRubricDone) {
      return (
        title: 'Review or Parse Rubric',
        desc:  'The rubric has not been parsed yet. Go to Assessment Setup to parse it.',
        icon:  Icons.rule_rounded,
        action: () => onNavigate(1),
        isComplete: false,
      );
    }
    if (submissions.isEmpty) {
      return (
        title: 'Upload Submissions',
        desc:  'Upload student submission files to start grading.',
        icon:  Icons.folder_open_rounded,
        action: onPickFiles,
        isComplete: false,
      );
    }
    if (_pendingCount > 0) {
      return (
        title: 'Grade Pending Files',
        desc:  'You have $_pendingCount submission(s) pending AI grading. '
               'Run AI grading to continue the workflow.',
        icon:  Icons.auto_awesome_rounded,
        action: onGradeAll,
        isComplete: false,
      );
    }
    if (_awaitingReviewCount > 0) {
      return (
        title: 'Review AI-Graded Submissions',
        desc:  '$_awaitingReviewCount submission(s) are graded and awaiting your review.',
        icon:  Icons.rate_review_rounded,
        action: () => onNavigate(3),
        isComplete: false,
      );
    }
    if (_reviewedNotFinalizedCount > 0) {
      return (
        title: 'Finalize Reviewed Results',
        desc:  '$_reviewedNotFinalizedCount result(s) reviewed and ready to finalize.',
        icon:  Icons.lock_rounded,
        action: () => onNavigate(3),
        isComplete: false,
      );
    }
    return (
      title: 'Workflow Complete',
      desc:  'All steps are done. Export the results, or upload more submissions to continue.',
      icon:  Icons.verified_rounded,
      action: () => onNavigate(4),
      isComplete: true,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Context header
            _ContextHeader(
              currentAssessment: currentAssessment,
              rubricParsed:      _wRubricDone,
              backendOnline:     backendOnline,
              submissionCount:   submissions.length,
            ),
            const SizedBox(height: 16),

            // B. Primary actions
            _PrimaryActions(
              onPickFiles: onPickFiles,
              onGradeAll:  onGradeAll,
              isGrading:   isGrading,
              pendingCount: _pendingCount,
            ),
            const SizedBox(height: 20),

            // C. KPI cards
            LayoutBuilder(builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final cards = [
                _MetricCard(
                  icon: Icons.folder_open_rounded,
                  color: AppColors.primary,
                  value: '$_totalCount',
                  label: 'Total Submissions',
                  caption: 'All student submissions',
                ),
                _MetricCard(
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning,
                  value: '$_pendingCount',
                  label: 'Pending',
                  caption: 'Awaiting AI grading',
                ),
                _MetricCard(
                  icon: Icons.rate_review_rounded,
                  color: AppColors.success,
                  value: '$_reviewedCount',
                  label: 'Reviewed',
                  caption: 'Reviewed by instructor',
                ),
                _MetricCard(
                  icon: Icons.verified_rounded,
                  color: AppColors.secondary,
                  value: '$_finalizedCount',
                  label: 'Finalized',
                  caption: 'Completed & finalized',
                ),
              ];
              if (!narrow) {
                return Row(children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: cards[i]),
                  ],
                ]);
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final c in cards)
                    SizedBox(width: (constraints.maxWidth - 16) / 2, child: c),
                ],
              );
            }),
            const SizedBox(height: 20),

            // D. Workflow progress
            _WorkflowCard(steps: [
              ('Assessment', _wAssessmentDone ? _StepState.complete : _StepState.pending),
              ('Files',      _wFilesDone      ? _StepState.complete : _StepState.pending),
              ('Rubric',     _wRubricDone     ? _StepState.complete : _StepState.pending),
              ('AI Grading', _aiGradingState),
              ('Review',     _reviewState),
              ('Export',     _wExportDone     ? _StepState.complete : _StepState.pending),
            ]),
            const SizedBox(height: 20),

            // E. Lower content — 30/70 split on wide screens
            LayoutBuilder(builder: (context, constraints) {
              final left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NextActionCard(
                    title: na.title,
                    desc:  na.desc,
                    icon:  na.icon,
                    isComplete: na.isComplete,
                    action: na.action,
                  ),
                  const SizedBox(height: 16),
                  _ReadinessCard(
                    assessment:       currentAssessment,
                    questionUploaded: questionUploaded,
                    guideUploaded:    guideUploaded,
                    backendOnline:    backendOnline,
                  ),
                ],
              );
              final right = _RecentTable(
                submissions:  submissions,
                statusOf:     _displayStatus,
                resultFor:    _resultFor,
                onSelectSubmission: onSelectSubmission,
                onNavigate:   onNavigate,
              );

              if (constraints.maxWidth < 900) {
                return Column(children: [left, const SizedBox(height: 16), right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 7, child: right),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// A. Context header — assessment identity + status badges
// ═══════════════════════════════════════════════════════════════════════════════
//
// The global TopBar (widgets/top_bar.dart, shown above every screen) already
// renders a search box and the user avatar/name — both are out of scope here
// (shared component). The search box there is presentation-only (no
// onChanged/controller wired), so it is intentionally NOT duplicated here to
// avoid adding a second non-functional control, per the "no decorative-only
// control" rule. This header only adds the assessment-specific context that
// TopBar doesn't have.

class _ContextHeader extends StatelessWidget {
  const _ContextHeader({
    required this.currentAssessment,
    required this.rubricParsed,
    required this.backendOnline,
    required this.submissionCount,
  });

  final Assessment? currentAssessment;
  final bool         rubricParsed;
  final bool?        backendOnline;
  final int          submissionCount;

  @override
  Widget build(BuildContext context) {
    final name = currentAssessment != null
        ? '${currentAssessment!.courseCode} — ${currentAssessment!.assessmentTitle}'
        : 'No assessment selected';

    return _Card(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CURRENT ASSESSMENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          _Badge(
            icon:  rubricParsed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            label: rubricParsed ? 'Rubric parsed' : 'Rubric not parsed',
            color: rubricParsed ? AppColors.success : AppColors.muted,
          ),
          _Badge(
            icon:  backendOnline == true
                ? Icons.cloud_done_rounded
                : backendOnline == false
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_sync_rounded,
            label: backendOnline == true
                ? 'Backend AI connected'
                : backendOnline == false
                    ? 'Backend AI disconnected'
                    : 'Backend AI checking…',
            color: backendOnline == true
                ? AppColors.success
                : backendOnline == false
                    ? AppColors.error
                    : AppColors.muted,
          ),
          _Badge(
            icon:  Icons.description_rounded,
            label: '$submissionCount submission${submissionCount == 1 ? '' : 's'}',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// B. Primary action buttons
// ═══════════════════════════════════════════════════════════════════════════════

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.onPickFiles,
    required this.onGradeAll,
    required this.isGrading,
    required this.pendingCount,
  });

  final VoidCallback onPickFiles;
  final VoidCallback onGradeAll;
  final bool         isGrading;
  final int          pendingCount;

  @override
  Widget build(BuildContext context) {
    final gradeDisabled = isGrading || pendingCount == 0;

    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 640;
      final upload = _ActionButton(
        icon: Icons.cloud_upload_rounded,
        title: 'Upload Files',
        subtitle: 'Add student submissions',
        filled: true,
        onPressed: onPickFiles,
      );
      final grade = _ActionButton(
        icon: isGrading ? null : Icons.auto_awesome_rounded,
        loading: isGrading,
        title: isGrading ? 'Grading…' : 'Grade Pending Files',
        subtitle: isGrading
            ? 'AI grading in progress'
            : (pendingCount == 0
                ? 'No submissions pending'
                : 'Run AI grading on pending files'),
        filled: false,
        onPressed: gradeDisabled ? null : onGradeAll,
      );
      if (stacked) {
        return Column(children: [upload, const SizedBox(height: 12), grade]);
      }
      return Row(children: [
        Expanded(child: upload),
        const SizedBox(width: 12),
        Expanded(child: grade),
      ]);
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String        title;
  final String        subtitle;
  final bool          filled;
  final VoidCallback? onPressed;
  final IconData?     icon;
  final bool          loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final fg = filled
        ? Colors.white
        : (disabled ? AppColors.muted : AppColors.primary);

    final leading = loading
        ? const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Icon(icon, size: 20, color: filled ? Colors.white : fg);

    final content = Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: filled ? Colors.white : (disabled ? AppColors.muted : AppColors.text),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: filled ? Colors.white.withAlpha(210) : AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );

    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.centerLeft,
          ),
          onPressed: onPressed,
          child: content,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: disabled ? AppColors.outlineVariant : AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.centerLeft,
        ),
        onPressed: onPressed,
        child: content,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// C. KPI metric card
// ═══════════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final Color    color;
  final String   value;
  final String   label;
  final String   caption;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        color.withAlpha(24),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// D. Workflow progress card
// ═══════════════════════════════════════════════════════════════════════════════

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.steps});
  final List<(String, _StepState)> steps;

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
                final prevDone = steps[idx ~/ 2].$2 == _StepState.complete;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: _Connector(completed: prevDone),
                  ),
                );
              }
              final si    = idx ~/ 2;
              final state = steps[si].$2;
              final label = steps[si].$1;
              final Color circleColor;
              final Widget inner;
              switch (state) {
                case _StepState.complete:
                  circleColor = AppColors.success;
                  inner = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
                case _StepState.current:
                  circleColor = AppColors.primary;
                  inner = Text('${si + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13));
                case _StepState.pending:
                  circleColor = AppColors.surfaceHighest;
                  inner = Text('${si + 1}',
                      style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13));
              }
              return SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleColor,
                        border: state == _StepState.current
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Center(child: inner),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize:   10,
                        color:      state == _StepState.pending ? AppColors.muted : AppColors.text,
                        fontWeight: state == _StepState.pending ? FontWeight.w400 : FontWeight.w600,
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

class _Connector extends StatelessWidget {
  const _Connector({required this.completed});
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(height: 2, color: AppColors.success);
    }
    return LayoutBuilder(builder: (context, constraints) {
      const dash = 4.0, gap = 4.0;
      final count = (constraints.maxWidth / (dash + gap)).floor().clamp(1, 999);
      return Row(
        children: List.generate(
          count,
          (_) => Padding(
            padding: const EdgeInsets.only(right: gap),
            child: Container(width: dash, height: 2, color: AppColors.outlineVariant),
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// E1. Recommended Next Step card
// ═══════════════════════════════════════════════════════════════════════════════

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.isComplete,
    required this.action,
  });

  final String        title;
  final String        desc;
  final IconData      icon;
  final bool          isComplete;
  final VoidCallback  action;

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
                child: Icon(isComplete ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                    size: 18, color: accent),
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// E2. Assessment Readiness card
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
          _ReadinessRow(label: 'Question File', ok: questionUploaded, okText: 'Uploaded', failText: 'Missing'),
          _ReadinessRow(label: 'Guide File',    ok: guideUploaded,    okText: 'Uploaded', failText: 'Missing'),
          _ReadinessRow(label: 'Rubric',        ok: rubricParsed,     okText: 'Parsed',   failText: 'Not parsed'),
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
              color: ok ? const Color(0xFFF0FDF4) : AppColors.surfaceHighest,
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
// F. Recent Submissions table
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentTable extends StatefulWidget {
  const _RecentTable({
    required this.submissions,
    required this.statusOf,
    required this.resultFor,
    required this.onSelectSubmission,
    required this.onNavigate,
  });

  final List<Submission>                    submissions;
  final GradingStatus Function(Submission)  statusOf;
  final GradingResult? Function(Submission) resultFor;
  final ValueChanged<int>                   onSelectSubmission;
  final ValueChanged<int>                   onNavigate;

  @override
  State<_RecentTable> createState() => _RecentTableState();
}

class _RecentTableState extends State<_RecentTable> {
  static const _maxVisible = 5;

  // "View all submissions" expands the table in place on the Homepage —
  // it must NOT navigate away (that was the regression: it used to call
  // widget.onNavigate(3), jumping to the Grading screen).
  bool _showAll = false;

  String _ext(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1).toUpperCase() : '—';
  }

  // Local display label — overrides "Graded" -> "AI Graded" for this table
  // only, without touching the shared GradingStatus enum (used elsewhere,
  // e.g. the Grading screen's status pill).
  String _label(GradingStatus s) =>
      s == GradingStatus.graded ? 'AI Graded' : s.label;

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
    final submissions = widget.submissions;

    // GET /api/assessments/{id}/submissions (SubmissionService.GetListAsync)
    // orders by CreatedAt DESCENDING on the Backend — i.e. submissions[0] is
    // always the most recently uploaded. Confirmed by reading Backend source
    // (SubmissionService.cs), not assumed. So "recent" = the first N items,
    // never sorted/re-ordered by filename or any client-side heuristic.
    //
    // Each entry keeps its original index (entry.key) from `submissions` so
    // Open/row-tap always resolves to the correct submission even after the
    // list is truncated to the first 5 — never the 0-4 index of the cut list.
    final indexedSubmissions = submissions.asMap().entries.toList();
    final overflow = submissions.length > _maxVisible;
    final visibleEntries = _showAll
        ? indexedSubmissions
        : indexedSubmissions.take(_maxVisible).toList();

    debugPrint('[HomeRecent] total=${submissions.length}');
    debugPrint('[HomeRecent] orderedNames=${submissions.map((s) => s.fileName).join(', ')}');
    debugPrint('[HomeRecent] displayedNames=${visibleEntries.map((e) => e.value.fileName).join(', ')}');

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Text(
                  _showAll ? 'All Submissions' : 'Recent Submissions',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const Spacer(),
                if (overflow)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_showAll ? 'Show recent' : 'View all submissions',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Icon(
                          _showAll ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.surfaceContainer,
            child: const Row(
              children: [
                SizedBox(width: 28, child: _ColHeader('#')),
                SizedBox(width: 12),
                Expanded(flex: 5, child: _ColHeader('File Name')),
                SizedBox(width: 12),
                SizedBox(width: 60, child: _ColHeader('Format')),
                SizedBox(width: 12),
                SizedBox(width: 96, child: _ColHeader('Status')),
                SizedBox(width: 12),
                SizedBox(width: 56, child: _ColHeader('Score')),
                SizedBox(width: 12),
                SizedBox(width: 64, child: _ColHeader('Action')),
              ],
            ),
          ),
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
            // Plain Column of rows (no ListView/fixed height) so the outer
            // Homepage SingleChildScrollView handles scrolling naturally —
            // no nested scroll, no clipped rows when expanded to "All".
            for (int i = 0; i < visibleEntries.length; i++) ...[
              _TableRow(
                index:      i,
                submission: visibleEntries[i].value,
                status:     widget.statusOf(visibleEntries[i].value),
                result:     widget.resultFor(visibleEntries[i].value),
                ext:        _ext(visibleEntries[i].value.fileName),
                statusLabel: _label(widget.statusOf(visibleEntries[i].value)),
                statusColors: _statusColors(widget.statusOf(visibleEntries[i].value)),
                onTap: () {
                  widget.onSelectSubmission(visibleEntries[i].key);
                  widget.onNavigate(3);
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
    required this.statusLabel,
    required this.statusColors,
    required this.onTap,
  });

  final int                    index;
  final Submission             submission;
  final GradingStatus          status;
  final GradingResult?         result;
  final String                 ext;
  final String                 statusLabel;
  final ({Color bg, Color fg}) statusColors;
  final VoidCallback           onTap;

  @override
  Widget build(BuildContext context) {
    // Never treat an ERROR result's score as a real score.
    final hasScore = result != null && result!.status != 'ERROR';
    final scoreText = hasScore ? result!.finalScore.toStringAsFixed(1) : '—';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                submission.fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(ext,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        statusColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: statusColors.fg, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 56,
              child: Text(
                scoreText,
                style: TextStyle(
                  fontSize:   13,
                  color:      hasScore ? AppColors.text : AppColors.muted,
                  fontWeight: hasScore ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onTap,
                child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

  final Widget      child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF4F46E5).withAlpha(6),
            blurRadius: 12,
            offset:     const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
