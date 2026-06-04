import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import '../data/pmg201c_pe2_sample_assessment.dart';
import '../models/assessment.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';

class AssessmentSetupScreen extends StatefulWidget {
  const AssessmentSetupScreen({
    super.key,
    required this.currentAssessment,
    required this.onApplyAssessment,
  });

  final Assessment? currentAssessment;
  final ValueChanged<Assessment> onApplyAssessment;

  @override
  State<AssessmentSetupScreen> createState() => _AssessmentSetupScreenState();
}

class _AssessmentSetupScreenState extends State<AssessmentSetupScreen> {
  final _titleController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _examQuestionsController = TextEditingController();
  final _gradingGuideController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillFromAssessment(widget.currentAssessment);
  }

  @override
  void didUpdateWidget(covariant AssessmentSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAssessment != widget.currentAssessment &&
        widget.currentAssessment != null) {
      _prefillFromAssessment(widget.currentAssessment);
    }
  }

  void _prefillFromAssessment(Assessment? a) {
    if (a == null) return;
    _titleController.text = a.assessmentTitle;
    _courseCodeController.text = a.courseCode;
    _examQuestionsController.text = a.examQuestionText;
    _gradingGuideController.text = a.gradingGuideText;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    _examQuestionsController.dispose();
    _gradingGuideController.dispose();
    super.dispose();
  }

  // ── Import helpers ─────────────────────────────────────────────────────────

  Future<void> _importExamQuestion() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    setState(() => _examQuestionsController.text = content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exam question file imported.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _importGradingGuide() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final content = await File(path).readAsString();
    setState(() => _gradingGuideController.text = content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grading guide file imported.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _loadSample() {
    final sample = buildPmg201cPe2SampleAssessment();
    setState(() => _prefillFromAssessment(sample));
    widget.onApplyAssessment(sample);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PMG201c PE2 sample assessment loaded.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _applyCustom() {
    final title = _titleController.text.trim();
    final courseCode = _courseCodeController.text.trim();
    final examText = _examQuestionsController.text.trim();
    final guideText = _gradingGuideController.text.trim();

    String? error;
    if (courseCode.isEmpty) {
      error = 'Course code is required.';
    } else if (title.isEmpty) {
      error = 'Assessment title is required.';
    } else if (examText.isEmpty) {
      error = 'Exam question text is required. Paste text or import a .txt file.';
    } else if (guideText.isEmpty) {
      error = 'Grading guide text is required. Paste text or import a .txt file.';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final assessment = Assessment(
      assessmentId: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      courseCode: courseCode,
      assessmentTitle: title,
      examQuestionText: examText,
      gradingGuideText: guideText,
      totalRawScore: 100,
      totalConvertedScore: 10,
      questions: const [],
      createdAt: DateTime.now(),
    );

    widget.onApplyAssessment(assessment);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment "$title" applied.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final current = widget.currentAssessment;

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeaderWithAction(
            title: 'Assessment Setup',
            subtitle:
                'Configure the exam questions and grading rubric for this grading session. '
                'Each session can use a different assessment.',
            badge: current != null
                ? '${current.courseCode} — ${current.assessmentTitle}'
                : 'No assessment loaded',
            button: 'Load Sample',
            onPressed: _loadSample,
          ),
          const SizedBox(height: 24),

          if (current != null) _buildCurrentSummary(current),
          if (current != null) const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSampleCard(),
                  const SizedBox(height: 28),
                  _buildDivider('Or enter a custom assessment'),
                  const SizedBox(height: 24),
                  _buildFormRow(
                    label: 'Assessment Title',
                    hint: 'e.g. Practical Exam 2',
                    controller: _titleController,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: 'Course Code',
                    hint: 'e.g. PMG201c',
                    controller: _courseCodeController,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  // Import buttons row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _importExamQuestion,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text(
                            'Import Exam Question .txt',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _importGradingGuide,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: const Text(
                            'Import Grading Guide .txt',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: 'Exam Questions',
                    hint: 'Paste or import exam question text here...',
                    controller: _examQuestionsController,
                    maxLines: 10,
                  ),
                  const SizedBox(height: 16),
                  _buildFormRow(
                    label: 'Grading Guide / Rubric',
                    hint: 'Paste or import grading guide / rubric text here...',
                    controller: _gradingGuideController,
                    maxLines: 10,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _applyCustom,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Apply Custom Assessment',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildCurrentSummary(Assessment a) {
    final isSample = a.assessmentId.contains('sample');
    final source = isSample ? 'SAMPLE' : 'CUSTOM';
    final sourceColor = isSample ? AppColors.primary : const Color(0xFF81C995);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withAlpha(30),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              const Text(
                'ACTIVE ASSESSMENT',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sourceColor.withAlpha(30),
                  border: Border.all(color: sourceColor.withAlpha(100)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source,
                  style: TextStyle(
                    color: sourceColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _SummaryItem(label: 'Course', value: a.courseCode),
              _SummaryItem(label: 'Title', value: a.assessmentTitle),
              _SummaryItem(
                  label: 'Raw Total',
                  value: '/${a.totalRawScore.toInt()}'),
              _SummaryItem(
                  label: 'Converted',
                  value: '/${a.totalConvertedScore % 1 == 0 ? a.totalConvertedScore.toInt() : a.totalConvertedScore}'),
              _SummaryItem(
                  label: 'Rubric Items',
                  value: a.questions.isEmpty
                      ? 'Dynamic (AI)'
                      : '${a.questions.length} questions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'PMG201c PE2 — Quick Load',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Text(
                  'SAMPLE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Loads a pre-built rubric for PMG201c Practical Exam 2 '
            '(Q1 Project Charter 20pts, Q2 Cost/Budget 20pts, '
            'Q3 Risk Register 30pts, Q4 RACI Matrix 30pts → total /10).',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
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
              onPressed: _loadSample,
              icon: const Icon(Icons.download_rounded),
              label: const Text(
                'Use PMG201c PE2 Sample',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.outlineVariant)),
      ],
    );
  }

  Widget _buildFormRow({
    required String label,
    required String hint,
    required TextEditingController controller,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// ── Summary item chip ─────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
