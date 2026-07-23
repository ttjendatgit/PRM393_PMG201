import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../models/grading_result.dart';
import '../models/grading_status.dart';
import '../models/question_result.dart';
import '../models/rubric.dart';
import '../models/submission.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_card.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/status_pill.dart';
import '../widgets/tiny_tag.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mutable edit state for one question during human review
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionEditState {
  final String questionId;
  final String questionTitle;
  final double maxRawScore;
  final double maxConvertedScore;
  double rawScore;
  double convertedScore;

  _QuestionEditState({
    required this.questionId,
    required this.questionTitle,
    required this.maxRawScore,
    required this.maxConvertedScore,
    required double initialRaw,
  })  : rawScore = initialRaw.clamp(0.0, maxRawScore),
        convertedScore = maxRawScore > 0
            ? double.parse(
                (initialRaw.clamp(0.0, maxRawScore) /
                        maxRawScore *
                        maxConvertedScore)
                    .toStringAsFixed(2),
              )
            : 0.0;

  void updateRaw(double newRaw) {
    rawScore = newRaw.clamp(0.0, maxRawScore);
    convertedScore = maxRawScore > 0
        ? double.parse(
            (rawScore / maxRawScore * maxConvertedScore).toStringAsFixed(2),
          )
        : 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradingPage
// ─────────────────────────────────────────────────────────────────────────────

class GradingPage extends StatelessWidget {
  const GradingPage({
    super.key,
    required this.submission,
    required this.result,
    required this.onGradeAll,
    required this.onGradeCurrent,
    required this.onSaveReview,
    required this.aiMode,
    required this.assessment,
    required this.isGrading,
    this.status,
    this.gradingError,
    this.onFinalize,
    this.onNextSubmission,
    this.onDeleteSubmission,
    this.isContentLoading = false,
  });

  final Submission? submission;
  final GradingResult? result;
  final VoidCallback onGradeAll;
  final VoidCallback onGradeCurrent;
  final ValueChanged<GradingResult> onSaveReview;
  final ValueChanged<String>? onFinalize;
  final VoidCallback? onNextSubmission;
  final VoidCallback? onDeleteSubmission;
  final bool isContentLoading;
  final AiMode aiMode;
  final Assessment? assessment;
  final bool isGrading;
  final GradingStatus? status;
  final String? gradingError;

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
        // Left pane — full submission content
        Expanded(
          child: _SubmissionPanel(
            submission: submission!,
            isContentLoading: isContentLoading,
          ),
        ),
        // Right pane — AI analysis + review
        AiPanel(
          result:        result,
          submissionId:  submission!.id,
          onGradeAll:    onGradeAll,
          onGradeCurrent: onGradeCurrent,
          onSaveReview:  onSaveReview,
          onFinalize:    onFinalize,
          onNextSubmission: onNextSubmission,
          onDeleteSubmission: onDeleteSubmission,
          aiMode:        aiMode,
          assessment:    assessment,
          isGrading:     isGrading,
          status:        status,
          gradingError:  gradingError,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiPanel — stateful to manage review editing
// ─────────────────────────────────────────────────────────────────────────────

class AiPanel extends StatefulWidget {
  const AiPanel({
    super.key,
    required this.result,
    required this.onGradeAll,
    required this.onGradeCurrent,
    required this.onSaveReview,
    required this.aiMode,
    required this.assessment,
    required this.isGrading,
    this.submissionId = '',
    this.status,
    this.gradingError,
    this.onFinalize,
    this.onNextSubmission,
    this.onDeleteSubmission,
  });

  final GradingResult? result;
  final VoidCallback onGradeAll;
  final VoidCallback onGradeCurrent;
  final ValueChanged<GradingResult> onSaveReview;
  final ValueChanged<String>? onFinalize;
  final VoidCallback? onNextSubmission;
  final VoidCallback? onDeleteSubmission;
  final AiMode aiMode;
  final Assessment? assessment;
  final bool isGrading;
  /// Submission ID for manual grading mode — used when result.id is absent.
  final String submissionId;
  final GradingStatus? status;
  final String? gradingError;

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  List<_QuestionEditState> _editStates = [];
  final List<TextEditingController> _rawControllers = [];
  final List<TextEditingController> _commentControllers = [];
  final TextEditingController _reviewerNoteController = TextEditingController();

  // Manual Grading Mode — active when AI result is absent or unusable.
  bool _isManualMode = false;

  @override
  void initState() {
    super.initState();
    _initEditStates();
  }

  @override
  void didUpdateWidget(AiPanel old) {
    super.didUpdateWidget(old);
    // Reinitialise when:
    //  • switching to a different grading-result record (id changes), OR
    //  • switching to a different submission (submissionId changes), OR
    //  • a new result arrives for the same submission (null → non-null questionResults).
    // Using result.id / submissionId instead of fileName prevents stale edit
    // state when two files share the same name or when a result is re-fetched.
    final itemsArrived = widget.result?.questionResults?.isNotEmpty == true &&
        (old.result?.questionResults == null || old.result!.questionResults!.isEmpty);
    if (old.result?.id != widget.result?.id ||
        old.result?.submissionId != widget.result?.submissionId ||
        itemsArrived) {
      // Exit manual mode when a real AI result with items arrives.
      if (_isManualMode && itemsArrived) _isManualMode = false;
      _initEditStates();
    }
  }

  void _initEditStates() {
    for (final c in _rawControllers) { c.dispose(); }
    _rawControllers.clear();
    for (final c in _commentControllers) { c.dispose(); }
    _commentControllers.clear();
    _editStates = [];

    final qrs = widget.result?.questionResults;
    if (qrs != null) {
      final rubricItems = widget.assessment?.questions ?? const <QuestionRubric>[];

      for (int qi = 0; qi < qrs.length; qi++) {
        final qr = qrs[qi];

        double maxRaw = qr.maxRawScore;
        double maxConv = qr.maxConvertedScore;

        // P0-C fallback: if the backend didn't return max scores, derive them
        // from the active assessment rubric so scores are never clamped to 0.
        if (maxRaw == 0 && rubricItems.isNotEmpty) {
          QuestionRubric? match;
          // 1. Try to match by title
          for (final r in rubricItems) {
            if (r.title == qr.questionTitle) { match = r; break; }
          }
          // 2. Positional fallback
          if (match == null && qi < rubricItems.length) {
            match = rubricItems[qi];
          }
          if (match != null && match.rawMaxScore > 0) {
            maxRaw = match.rawMaxScore;
            maxConv = match.convertedMaxScore;
          }
        }

        // When the teacher has already reviewed this item, initialise
        // the edit field from reviewedRawScore so the reviewed score is
        // displayed (not the original AI-awarded score).
        final initRaw = qr.reviewedRawScore ?? qr.rawScore;
        // Prefer the teacher's saved comment over the AI comment.
        final initComment = qr.teacherComment.isNotEmpty
            ? qr.teacherComment
            : qr.comment;

        _editStates.add(_QuestionEditState(
          questionId:       qr.questionId,
          questionTitle:    qr.questionTitle,
          maxRawScore:      maxRaw,
          maxConvertedScore: maxConv,
          initialRaw:       initRaw,
        ));
        _rawControllers.add(
          TextEditingController(text: initRaw.toInt().toString()),
        );
        _commentControllers.add(
          TextEditingController(text: initComment),
        );
      }
    }

    // Prefer teacherOverallComment from backend; fall back to local reviewerNote.
    _reviewerNoteController.text =
        (widget.result?.teacherOverallComment.isNotEmpty ?? false)
            ? widget.result!.teacherOverallComment
            : (widget.result?.reviewerNote ?? '');
  }

  @override
  void dispose() {
    for (final c in _rawControllers) { c.dispose(); }
    for (final c in _commentControllers) { c.dispose(); }
    _reviewerNoteController.dispose();
    super.dispose();
  }

  // ── Computed totals from live edit state ──────────────────────────────────

  double get _totalRaw =>
      _editStates.fold(0.0, (sum, s) => sum + s.rawScore);

  double get _totalConverted => double.parse(
        _editStates
            .fold<double>(0.0, (sum, s) => sum + s.convertedScore)
            .toStringAsFixed(2),
      );

  // ── Callbacks ─────────────────────────────────────────────────────────────

  void _onRawChanged(int idx, String value) {
    final raw = double.tryParse(value);
    if (raw == null) return;
    setState(() {
      _editStates[idx].updateRaw(raw);
      // Correct the text if the value was clamped
      final clamped = _editStates[idx].rawScore;
      if (clamped != raw) {
        final corrected = clamped.toInt().toString();
        _rawControllers[idx].value = TextEditingValue(
          text: corrected,
          selection: TextSelection.collapsed(offset: corrected.length),
        );
      }
    });
  }

  void _saveReview() {
    final qrs = List.generate(_editStates.length, (i) {
      final state    = _editStates[i];
      final original = widget.result!.questionResults![i];
      return QuestionResult(
        id:                    original.id,
        questionId:            original.questionId,
        questionTitle:         original.questionTitle,
        rawScore:              state.rawScore,      // teacher's edited value
        convertedScore:        state.convertedScore,
        maxRawScore:           original.maxRawScore,
        maxConvertedScore:     original.maxConvertedScore,
        comment:               original.comment,   // preserve original AI comment
        evidence:              original.evidence,
        teacherComment:        _commentControllers[i].text, // teacher's text
        subscores:             original.subscores,
      );
    });

    final totalRaw = qrs.fold<double>(0.0, (s, q) => s + q.rawScore);
    final totalConverted = double.parse(
      qrs.fold<double>(0.0, (s, q) => s + q.convertedScore).toStringAsFixed(2),
    );
    // Safety clamp: reviewed totalConverted must never exceed the assessment max
    final maxTotalConv = widget.assessment?.totalConvertedScore ?? totalConverted;
    final finalScore = double.parse(
      totalConverted.clamp(0.0, maxTotalConv).toStringAsFixed(2),
    );

    final reviewNote = _reviewerNoteController.text.trim();
    final updated = GradingResult(
      id: widget.result!.id,
      submissionId: widget.result!.submissionId,
      assessmentId: widget.result!.assessmentId,
      gradingJobId: widget.result!.gradingJobId,
      fileName: widget.result!.fileName,
      studentId: widget.result!.studentId,
      studentName: widget.result!.studentName,
      totalRawScore: totalRaw,
      finalScore: finalScore,
      criteriaScores: {for (final qr in qrs) qr.questionTitle: qr.convertedScore},
      feedback: widget.result!.feedback,
      questionResults: qrs,
      reviewerNote: reviewNote,
      teacherOverallComment: reviewNote,
      reviewStatus: widget.result!.reviewStatus,
      reviewedRawScore: widget.result!.reviewedRawScore,
      reviewedConvertedScore: widget.result!.reviewedConvertedScore,
      finalRawScore: widget.result!.finalRawScore,
      finalConvertedScore: widget.result!.finalConvertedScore,
    );

    widget.onSaveReview(updated);
  }

  // ── Manual Grading Mode ───────────────────────────────────────────────────

  /// True when a usable AI result is available (has items, or has aggregate
  /// score with feedback).  False → show manual grading offer.
  void _enterManualMode() {
    final rubric = widget.assessment?.questions ?? [];
    debugPrint('[ManualMode] Enter: subId=${widget.submissionId} '
        'rubricItems=${rubric.length}');
    // Dispose existing controllers and rebuild from rubric.
    for (final c in _rawControllers) { c.dispose(); }
    _rawControllers.clear();
    for (final c in _commentControllers) { c.dispose(); }
    _commentControllers.clear();
    _editStates = [];
    _reviewerNoteController.text = widget.result?.teacherOverallComment ?? '';

    for (final q in rubric) {
      // Pre-fill from any existing reviewed scores on the result items.
      final existing = widget.result?.questionResults?.cast<QuestionResult?>()
          .firstWhere((i) => i?.questionTitle == q.title, orElse: () => null);
      final initRaw = existing?.reviewedRawScore ?? existing?.rawScore ?? 0.0;

      _editStates.add(_QuestionEditState(
        questionId:       q.questionId,
        questionTitle:    q.title,
        maxRawScore:      q.rawMaxScore,
        maxConvertedScore: q.convertedMaxScore,
        initialRaw:       initRaw,
      ));
      _rawControllers.add(TextEditingController(text: initRaw.toInt().toString()));
      _commentControllers.add(TextEditingController(
        text: existing?.teacherComment ?? existing?.comment ?? '',
      ));
    }
    setState(() => _isManualMode = true);
  }

  void _exitManualMode() {
    setState(() => _isManualMode = false);
    _initEditStates();
  }

  // ── Error-state detection ─────────────────────────────────────────────────
  //
  // A GradingResult can exist (widget.result != null) yet represent a failed
  // AI grading attempt persisted by the backend (status == "ERROR"). Such a
  // record must never be treated as a real graded result — no raw/converted
  // score, no "Item breakdown unavailable" — instead it must render the same
  // failure UI as the pre-grading error state.
  bool get _isErrorResult =>
      widget.result != null && widget.result!.status == 'ERROR';

  void _saveManualReview(BuildContext ctx) {
    final resultId      = widget.result?.id ?? '';
    final submissionId  = widget.result?.submissionId.isNotEmpty == true
        ? widget.result!.submissionId
        : widget.submissionId;
    final rubric        = widget.assessment?.questions ?? [];

    final qrs = List.generate(_editStates.length, (i) {
      final state      = _editStates[i];
      // Reuse existing item ID if available (required by PUT /review).
      final existingId = (widget.result?.questionResults?.isNotEmpty == true &&
              i < widget.result!.questionResults!.length)
          ? widget.result!.questionResults![i].id
          : '';
      final rubricItem = i < rubric.length ? rubric[i] : null;
      return QuestionResult(
        id:                existingId,
        // questionId holds the rubric item's backend ID (uuid) for PUT,
        // or the questionNo (1-based index) when no backend ID exists.
        questionId:        rubricItem?.questionId ?? state.questionId,
        questionTitle:     state.questionTitle,
        rawScore:          state.rawScore,
        convertedScore:    state.convertedScore,
        maxRawScore:       state.maxRawScore,
        maxConvertedScore: state.maxConvertedScore,
        comment:           '',
        teacherComment:    _commentControllers[i].text,
      );
    });

    final totalRaw  = qrs.fold<double>(0.0, (s, q) => s + q.rawScore);
    final totalConv = double.parse(
        qrs.fold<double>(0.0, (s, q) => s + q.convertedScore).toStringAsFixed(2));
    final maxConv   = widget.assessment?.totalConvertedScore ?? totalConv;
    final finalScore = double.parse(totalConv.clamp(0.0, maxConv).toStringAsFixed(2));
    final reviewNote = _reviewerNoteController.text.trim();

    if (resultId.isEmpty) {
      // ── POST /api/submissions/{id}/manual-result path ──────────────────────
      debugPrint('[ManualMode] POST manual-result path: '
          'submissionId=$submissionId items=${qrs.length}');
    } else {
      // ── PUT /api/grading-results/{id}/review path ──────────────────────────
      debugPrint('[ManualMode] PUT review path: '
          'submissionId=$submissionId resultId=$resultId '
          'totalRaw=$totalRaw totalConv=$finalScore items=${qrs.length}');
    }

    final updated = GradingResult(
      id:            resultId,      // empty → parent will POST; non-empty → PUT
      submissionId:  submissionId,
      assessmentId:  widget.result?.assessmentId ?? '',
      gradingJobId:  widget.result?.gradingJobId,
      fileName:      widget.result?.fileName ?? '',
      studentId:     widget.result?.studentId ?? '',
      studentName:   widget.result?.studentName ?? '',
      totalRawScore: totalRaw,
      finalScore:    finalScore,
      criteriaScores: {for (final q in qrs) q.questionTitle: q.convertedScore},
      feedback:      widget.result?.feedback ?? 'Manual grading',
      questionResults: qrs,
      reviewerNote:  reviewNote,
      teacherOverallComment: reviewNote,
      reviewStatus:  'REVIEWED',
      reviewedRawScore:       totalRaw,
      reviewedConvertedScore: finalScore,
      status:        widget.result?.status ?? '',
    );
    widget.onSaveReview(updated);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          _buildPanelHeader(),
          Expanded(
            child: _isManualMode
                ? _buildManualModePanel()
                : ((widget.result == null || _isErrorResult)
                    ? _buildPendingState()
                    : _buildResultState()),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    // Resolve displayed status: a persisted ERROR result always wins (even if
    // the caller's status map is stale/derived from reviewStatus only), then
    // fall back to the explicit status, then to result presence.
    final s = _isErrorResult
        ? GradingStatus.error
        : widget.status ??
            (widget.result == null ? GradingStatus.pending : GradingStatus.graded);

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            switch (widget.aiMode) {
              AiMode.mock       => Icons.science_rounded,
              AiMode.openRouter => Icons.cloud_rounded,
              AiMode.gemini     => Icons.cloud_rounded,
              AiMode.backend    => Icons.cloud_rounded,
            },
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
          StatusPill(text: s.label, color: s.color),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    final isError = widget.status == GradingStatus.error || _isErrorResult;
    // Prefer the live exception message (set right after a failed grade
    // attempt); fall back to the persisted result's errorMessage (e.g. when
    // reopening a submission that already has a saved ERROR result).
    final errorText = widget.gradingError ??
        (widget.result != null && widget.result!.errorMessage.isNotEmpty
            ? widget.result!.errorMessage
            : null);

    // Mode is always AiMode.backend in this app; label/icon fall back to
    // backend for any legacy non-backend value that may have slipped through.
    final providerName = switch (widget.aiMode) {
      AiMode.mock       => 'Mock AI',
      AiMode.openRouter => 'Backend AI',
      AiMode.gemini     => 'Backend AI',
      AiMode.backend    => 'Backend AI',
    };
    final providerIcon = switch (widget.aiMode) {
      AiMode.mock       => Icons.science_rounded,
      AiMode.openRouter => Icons.cloud_rounded,
      AiMode.gemini     => Icons.cloud_rounded,
      AiMode.backend    => Icons.cloud_rounded,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isError) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grading failed for this file.',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorText,
                      style: TextStyle(
                        color: AppColors.error.withValues(alpha: 0.85),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Click "Retry This File" to try again, or switch to a different AI provider in Settings.',
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            EmptyCard(
              text: widget.aiMode == AiMode.mock
                  ? 'This submission has not been graded yet. Click Grade This File to run mock grading, or Grade All Files to grade all imported submissions.'
                  : 'This submission has not been graded yet. Click Grade This File to grade via Backend AI, or Grade All Files to start a backend grading job.',
            ),
          ],
          const SizedBox(height: 16),
          // Primary: grade / retry this file
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isError
                  ? AppColors.error.withValues(alpha: 0.18)
                  : AppColors.primaryContainer,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.isGrading ? null : widget.onGradeCurrent,
            icon: widget.isGrading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.muted,
                    ),
                  )
                : Icon(isError ? Icons.refresh_rounded : providerIcon),
            label: Text(
              widget.isGrading
                  ? 'Grading...'
                  : isError
                      ? 'Retry This File ($providerName)'
                      : 'Grade This File ($providerName)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          // Secondary: grade all / retry all
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.isGrading ? null : widget.onGradeAll,
            icon: const Icon(Icons.list_rounded, size: 18),
            label: const Text('Grade All Files'),
          ),
          const SizedBox(height: 8),
          // Delete submission
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.isGrading ? null : widget.onDeleteSubmission,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete This File'),
          ),
          // Offer Manual Mode when assessment has a rubric loaded.
          if (widget.assessment?.questions.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'OR enter scores manually from the rubric:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: BorderSide(color: AppColors.warning.withAlpha(160)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _enterManualMode,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text(
                'Enter Manual Grades',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final hasQR = _editStates.isNotEmpty;
    final r     = widget.result!;

    // Prefer server-confirmed reviewed/final scores over locally recomputed
    // values.  Fall back to edit-state totals (live editing) or AI totals.
    final displayRaw = () {
      if (r.reviewStatus == 'FINALIZED' && r.finalRawScore != null) {
        return r.finalRawScore!;
      }
      if (r.reviewStatus == 'REVIEWED' && r.reviewedRawScore != null) {
        return r.reviewedRawScore!;
      }
      return hasQR ? _totalRaw : r.totalRawScore;
    }();

    final displayConverted = () {
      if (r.reviewStatus == 'FINALIZED' && r.finalConvertedScore != null) {
        return r.finalConvertedScore!;
      }
      if (r.reviewStatus == 'REVIEWED' && r.reviewedConvertedScore != null) {
        return r.reviewedConvertedScore!;
      }
      return hasQR ? _totalConverted : r.finalScore;
    }();

    final isReviewed = r.reviewStatus == 'REVIEWED' ||
        r.reviewStatus == 'FINALIZED';

    // Compute max scores from item maxRawScore / maxConvertedScore sums so the
    // denominator is correct even when assessment is not loaded.
    final maxRawFromItems  = _editStates.fold(0.0, (s, e) => s + e.maxRawScore);
    final maxConvFromItems = _editStates.fold(0.0, (s, e) => s + e.maxConvertedScore);
    final maxRaw  = (hasQR && maxRawFromItems  > 0) ? maxRawFromItems  : (widget.assessment?.totalRawScore      ?? 100.0);
    final maxConv = (hasQR && maxConvFromItems > 0) ? maxConvFromItems : (widget.assessment?.totalConvertedScore ?? 10.0);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ScoreCard(
          totalRawScore:    displayRaw,
          finalScore:       displayConverted,
          maxRawScore:      maxRaw,
          maxConvertedScore: maxConv,
          isReviewed:       isReviewed,
        ),
        const SizedBox(height: 18),
        if (hasQR) ...[
          _sectionLabel('QUESTION BREAKDOWN'),
          const SizedBox(height: 10),
          ...List.generate(
            _editStates.length,
            (i) {
              final qrs = widget.result?.questionResults;
              final evidence = (qrs != null && i < qrs.length)
                  ? qrs[i].evidence
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EditableQuestionCard(
                  state:             _editStates[i],
                  rawController:     _rawControllers[i],
                  commentController: _commentControllers[i],
                  onRawChanged:      (v) => _onRawChanged(i, v),
                  evidence:          evidence,
                ),
              );
            },
          ),
        ] else ...[
          // No item breakdown — show a warning and offer Manual Mode.
          if (widget.assessment?.questions.isNotEmpty == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item breakdown unavailable.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AI scored this submission but did not return per-question '
                    'detail. Adjust the aggregate score above, or switch to '
                    'Manual Mode to enter per-question scores from the rubric.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning.withAlpha(160)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _enterManualMode,
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text(
                      'Switch to Manual Mode',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.result!.criteriaScores.isNotEmpty)
            CriteriaMiniGrid(result: widget.result!),
        ],
        const SizedBox(height: 18),
        _sectionLabel('REVIEWER NOTE'),
        const SizedBox(height: 8),
        _ReviewerNoteField(controller: _reviewerNoteController),
        const SizedBox(height: 18),
        _sectionLabel('AI COMMENT'),
        const SizedBox(height: 8),
        FeedbackBox(feedback: widget.result!.feedback),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveReview,
                icon: const Icon(Icons.save_rounded),
                label: const Text(
                  'Save Reviewed Scores',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (widget.onDeleteSubmission != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onDeleteSubmission,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Delete this submission',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withAlpha(20),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
        ),
        if (widget.onFinalize != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final id = widget.result?.id ?? '';
                if (id.isNotEmpty) widget.onFinalize?.call(id);
              },
              icon: const Icon(Icons.lock_rounded),
              label: const Text(
                'Finalize Result',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
        if (widget.onNextSubmission != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.muted,
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: widget.onNextSubmission,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text(
                'Next Submission',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );

  // ── Manual Grading Mode panel ──────────────────────────────────────────────

  Widget _buildManualModePanel() {
    final maxRaw  = _editStates.fold(0.0, (s, e) => s + e.maxRawScore);
    final maxConv = _editStates.fold(0.0, (s, e) => s + e.maxConvertedScore);
    final resultId = widget.result?.id ?? '';

    return Builder(builder: (ctx) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Mode banner ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withAlpha(80)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Manual Grading Mode — enter scores from the rubric.',
                  style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _exitManualMode,
                child: const Text('Exit', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Live score card ────────────────────────────────────────────────
        ScoreCard(
          totalRawScore:    _totalRaw,
          finalScore:       _totalConverted,
          maxRawScore:      maxRaw  > 0 ? maxRaw  : (widget.assessment?.totalRawScore      ?? 100.0),
          maxConvertedScore: maxConv > 0 ? maxConv : (widget.assessment?.totalConvertedScore ?? 10.0),
          isReviewed: false,
        ),
        const SizedBox(height: 18),

        // ── Rubric rows ────────────────────────────────────────────────────
        if (_editStates.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withAlpha(50)),
            ),
            child: const Text(
              'No rubric items found. Load an assessment with a parsed rubric to enable manual grading.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ),
        ] else ...[
          _sectionLabel('RUBRIC BREAKDOWN (MANUAL)'),
          const SizedBox(height: 10),
          ...List.generate(_editStates.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EditableQuestionCard(
              state:             _editStates[i],
              rawController:     _rawControllers[i],
              commentController: _commentControllers[i],
              onRawChanged:      (v) => _onRawChanged(i, v),
            ),
          )),
        ],

        const SizedBox(height: 18),
        _sectionLabel('OVERALL COMMENT'),
        const SizedBox(height: 8),
        _ReviewerNoteField(controller: _reviewerNoteController),
        const SizedBox(height: 18),

        // ── Save button ────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _saveManualReview(ctx),
            icon: const Icon(Icons.save_rounded),
            label: Text(
              resultId.isNotEmpty
                  ? 'Save Manual Review'
                  : 'Save Manual Grades',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),

        // ── Finalize (if available) ────────────────────────────────────────
        if (widget.onFinalize != null && resultId.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onFinalize?.call(resultId),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Finalize Result',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubmissionPanel — left pane showing full scrollable submission text
// ─────────────────────────────────────────────────────────────────────────────

class _SubmissionPanel extends StatelessWidget {
  const _SubmissionPanel({
    required this.submission,
    required this.isContentLoading,
  });

  final Submission submission;
  final bool isContentLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF060E20),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_rounded, color: AppColors.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              submission.fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (submission.content.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () => _showFullDialog(context),
              icon: const Icon(Icons.open_in_full_rounded, size: 14),
              label: const Text(
                'View Full',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Still loading from backend
    if (isContentLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text(
              'Loading submission content…',
              style: TextStyle(
                  color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    // Content loaded but empty
    if (submission.content.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined,
                  color: AppColors.muted, size: 44),
              SizedBox(height: 16),
              Text(
                'No extracted submission content available for this file.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.muted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    // Full content — scrollable, selectable
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SelectableText(
          submission.content,
          style: const TextStyle(
            color: AppColors.muted,
            height: 1.7,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showFullDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _FullSubmissionDialog(submission: submission),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FullSubmissionDialog — full-screen readable view of the submission text
// ─────────────────────────────────────────────────────────────────────────────

class _FullSubmissionDialog extends StatelessWidget {
  const _FullSubmissionDialog({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final charCount = submission.content.length;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: AppColors.muted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      submission.fileName,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.muted, size: 22),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Scrollable content ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: SelectableText(
                  submission.content.isEmpty
                      ? 'No extracted submission content available for this file.'
                      : submission.content,
                  style: TextStyle(
                    color: submission.content.isEmpty
                        ? AppColors.muted
                        : AppColors.text,
                    height: 1.75,
                    fontSize: 14,
                    fontStyle: submission.content.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$charCount characters',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.text,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScoreCard — displays live totals (raw + converted)
// ─────────────────────────────────────────────────────────────────────────────

class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.totalRawScore,
    required this.finalScore,
    required this.maxRawScore,
    required this.maxConvertedScore,
    this.isReviewed = false,
  });

  final double totalRawScore;
  final double finalScore;
  final double maxRawScore;
  final double maxConvertedScore;
  final bool isReviewed;

  String _fmt(double v, {bool integer = false}) {
    if (integer) return v.toInt().toString();
    return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final rawProgress =
        maxRawScore > 0 ? (totalRawScore / maxRawScore).clamp(0.0, 1.0) : 0.0;
    final convProgress =
        maxConvertedScore > 0
            ? (finalScore / maxConvertedScore).clamp(0.0, 1.0)
            : 0.0;
    final threshold = maxConvertedScore * 0.6;
    final passed = finalScore >= threshold;

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
          Text(
            isReviewed ? 'TEACHER-REVIEWED SCORE' : 'AI SUGGESTED SCORE',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Raw Score',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmt(totalRawScore, integer: true)} / ${_fmt(maxRawScore, integer: true)}',
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
          Row(
            children: [
              const Text(
                'Converted Score',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    finalScore.toStringAsFixed(1),
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
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 18,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers shared by editable cards
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _fieldDec({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: hint != null
          ? const TextStyle(color: AppColors.outlineVariant, fontSize: 12)
          : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Editable question card (used during human review)
// ─────────────────────────────────────────────────────────────────────────────

class _EditableQuestionCard extends StatelessWidget {
  const _EditableQuestionCard({
    required this.state,
    required this.rawController,
    required this.commentController,
    required this.onRawChanged,
    this.evidence = '',
  });

  final _QuestionEditState state;
  final TextEditingController rawController;
  final TextEditingController commentController;
  final ValueChanged<String> onRawChanged;
  final String evidence;

  String _fmtMax(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final progress = state.maxRawScore > 0
        ? (state.rawScore / state.maxRawScore).clamp(0.0, 1.0)
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
          // Title + live converted tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  state.questionTitle,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TinyTag(
                text:
                    'Conv  ${state.convertedScore.toStringAsFixed(1)} / ${_fmtMax(state.maxConvertedScore)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Raw score input
          Row(
            children: [
              const Text(
                'Raw',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: rawController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                    signed: false,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: _fieldDec(),
                  onChanged: onRawChanged,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${_fmtMax(state.maxRawScore)}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
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
          const SizedBox(height: 10),
          // Teacher comment field
          TextField(
            controller: commentController,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
            decoration: _fieldDec(hint: 'Teacher comment…'),
          ),
          // Evidence from AI (read-only, shown when present)
          if (evidence.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EVIDENCE',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    evidence,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reviewer note text field
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewerNoteField extends StatelessWidget {
  const _ReviewerNoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 13,
        height: 1.45,
      ),
      decoration: InputDecoration(
        hintText: 'Add reviewer notes here…',
        hintStyle: const TextStyle(
          color: AppColors.outlineVariant,
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.all(12),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CriteriaMiniGrid — fallback for mock results (no questionResults)
// ─────────────────────────────────────────────────────────────────────────────

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
                'Score',
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

// ─────────────────────────────────────────────────────────────────────────────
// FeedbackBox — read-only AI comment
// ─────────────────────────────────────────────────────────────────────────────

class FeedbackBox extends StatelessWidget {
  const FeedbackBox({super.key, required this.feedback});

  final String feedback;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
