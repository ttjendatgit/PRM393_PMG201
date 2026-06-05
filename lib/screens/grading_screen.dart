import 'package:flutter/material.dart';
import '../models/ai_mode.dart';
import '../models/assessment.dart';
import '../models/grading_result.dart';
import '../models/grading_status.dart';
import '../models/question_result.dart';
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
  });

  final Submission? submission;
  final GradingResult? result;
  final VoidCallback onGradeAll;
  final VoidCallback onGradeCurrent;
  final ValueChanged<GradingResult> onSaveReview;
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
        // Left pane — submission content
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
        // Right pane — AI analysis + review
        AiPanel(
          result: result,
          onGradeAll: onGradeAll,
          onGradeCurrent: onGradeCurrent,
          onSaveReview: onSaveReview,
          aiMode: aiMode,
          assessment: assessment,
          isGrading: isGrading,
          status: status,
          gradingError: gradingError,
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
    this.status,
    this.gradingError,
  });

  final GradingResult? result;
  final VoidCallback onGradeAll;
  final VoidCallback onGradeCurrent;
  final ValueChanged<GradingResult> onSaveReview;
  final AiMode aiMode;
  final Assessment? assessment;
  final bool isGrading;
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

  @override
  void initState() {
    super.initState();
    _initEditStates();
  }

  @override
  void didUpdateWidget(AiPanel old) {
    super.didUpdateWidget(old);
    // Reinitialise when switching to a different submission or when AI results
    // arrive for the first time (null → non-null questionResults).
    if (old.result?.fileName != widget.result?.fileName ||
        (widget.result?.questionResults != null &&
            old.result?.questionResults == null)) {
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
      for (final qr in qrs) {
        _editStates.add(_QuestionEditState(
          questionId: qr.questionId,
          questionTitle: qr.questionTitle,
          maxRawScore: qr.maxRawScore,
          maxConvertedScore: qr.maxConvertedScore,
          initialRaw: qr.rawScore,
        ));
        _rawControllers.add(
          TextEditingController(text: qr.rawScore.toInt().toString()),
        );
        _commentControllers.add(
          TextEditingController(text: qr.comment),
        );
      }
    }

    _reviewerNoteController.text = widget.result?.reviewerNote ?? '';
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
      final state = _editStates[i];
      final original = widget.result!.questionResults![i];
      return QuestionResult(
        questionId: original.questionId,
        questionTitle: original.questionTitle,
        rawScore: state.rawScore,
        convertedScore: state.convertedScore,
        maxRawScore: original.maxRawScore,
        maxConvertedScore: original.maxConvertedScore,
        comment: _commentControllers[i].text,
        subscores: original.subscores,
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

    final updated = GradingResult(
      fileName: widget.result!.fileName,
      studentId: widget.result!.studentId,
      studentName: widget.result!.studentName,
      totalRawScore: totalRaw,
      finalScore: finalScore,
      criteriaScores: {for (final qr in qrs) qr.questionTitle: qr.convertedScore},
      feedback: widget.result!.feedback,
      questionResults: qrs,
      reviewerNote: _reviewerNoteController.text.trim(),
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
            child: widget.result == null
                ? _buildPendingState()
                : _buildResultState(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    // Resolve displayed status: prefer explicit status; fall back to result presence
    final s = widget.status ??
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
              AiMode.openRouter => Icons.hub_rounded,
              AiMode.gemini => Icons.auto_awesome_rounded,
              AiMode.mock => Icons.science_rounded,
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
    final isError = widget.status == GradingStatus.error;

    final providerName = switch (widget.aiMode) {
      AiMode.mock => 'Mock AI',
      AiMode.openRouter => 'OpenRouter AI',
      AiMode.gemini => 'Gemini AI',
    };
    final providerIcon = switch (widget.aiMode) {
      AiMode.mock => Icons.science_rounded,
      AiMode.openRouter => Icons.hub_rounded,
      AiMode.gemini => Icons.auto_awesome_rounded,
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
                  if (widget.gradingError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.gradingError!,
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
                  : 'This submission has not been graded yet. Make sure an assessment is loaded and a valid API key is set in Settings, then grade.',
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
        ],
      ),
    );
  }

  Widget _buildResultState() {
    final hasQR = _editStates.isNotEmpty;
    final displayRaw =
        hasQR ? _totalRaw : widget.result!.totalRawScore;
    final displayConverted =
        hasQR ? _totalConverted : widget.result!.finalScore;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ScoreCard(
          totalRawScore: displayRaw,
          finalScore: displayConverted,
          maxRawScore: widget.assessment?.totalRawScore ?? 100,
          maxConvertedScore: widget.assessment?.totalConvertedScore ?? 10,
        ),
        const SizedBox(height: 18),
        if (hasQR) ...[
          _sectionLabel('QUESTION BREAKDOWN'),
          const SizedBox(height: 10),
          ...List.generate(
            _editStates.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditableQuestionCard(
                state: _editStates[i],
                rawController: _rawControllers[i],
                commentController: _commentControllers[i],
                onRawChanged: (v) => _onRawChanged(i, v),
              ),
            ),
          ),
        ] else
          CriteriaMiniGrid(result: widget.result!),
        const SizedBox(height: 18),
        _sectionLabel('REVIEWER NOTE'),
        const SizedBox(height: 8),
        _ReviewerNoteField(controller: _reviewerNoteController),
        const SizedBox(height: 18),
        _sectionLabel('AI COMMENT'),
        const SizedBox(height: 8),
        FeedbackBox(feedback: widget.result!.feedback),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
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
  });

  final double totalRawScore;
  final double finalScore;
  final double maxRawScore;
  final double maxConvertedScore;

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
  });

  final _QuestionEditState state;
  final TextEditingController rawController;
  final TextEditingController commentController;
  final ValueChanged<String> onRawChanged;

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
          // Comment field
          TextField(
            controller: commentController,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.45,
            ),
            decoration: _fieldDec(hint: 'Comment…'),
          ),
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
