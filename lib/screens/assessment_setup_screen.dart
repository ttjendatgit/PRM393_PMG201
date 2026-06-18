import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import '../data/pmg201c_pe2_sample_assessment.dart';
import '../features/assessment/services/assessment_api_service.dart';
import '../features/rubric/services/rubric_api_service.dart';
import '../models/assessment.dart';
import '../models/rubric.dart';
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

  // ── Backend state ──────────────────────────────────────────────────────────────

  List<Assessment> _assessments = [];
  bool _loadingAssessments = false;
  String _beMessage = '';

  Assessment? _selectedAssessment; // Assessment selected from BE list
  List<QuestionRubric> _rubricItems = [];
  bool _parsingRubric = false;

  bool _uploadingQuestion = false;
  bool _uploadingGuide = false;

  @override
  void initState() {
    super.initState();
    _prefillFromAssessment(widget.currentAssessment);
    _loadAssessments();
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

  // ── Backend API methods ────────────────────────────────────────────────────────

  Future<void> _loadAssessments() async {
    setState(() {
      _loadingAssessments = true;
      _beMessage = '';
    });

    try {
      final list = await AssessmentApiService.getAssessments();
      if (!mounted) return;
      setState(() {
        _assessments = list;
        _loadingAssessments = false;
        _beMessage = list.isEmpty
            ? 'No assessments found. Create one below.'
            : '${list.length} assessment(s) loaded.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAssessments = false;
        _beMessage = 'Cannot reach backend: $e';
      });
    }
  }

  Future<void> _selectAssessment(Assessment? assessment) async {
    if (assessment == null) return;

    // Load full detail
    try {
      final detail = await AssessmentApiService.getAssessment(
        assessment.assessmentId,
      );
      if (!mounted) return;
      if (detail == null) {
        _showSnack('Assessment not found on backend.', isError: true);
        return;
      }
      setState(() {
        _selectedAssessment = detail;
        _rubricItems = [];
      });

      widget.onApplyAssessment(detail);
      _prefillFromAssessment(detail);

      // Automatically load rubric if it exists
      await _loadRubric();
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedAssessment = assessment);
      widget.onApplyAssessment(assessment);
    }
  }

  Future<void> _uploadQuestionFile() async {
    final assessmentId = _selectedAssessment?.assessmentId;
    if (assessmentId == null) {
      _showSnack('Please select an assessment first.', isError: true);
      return;
    }

    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx', 'pdf', 'csv', 'xlsx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;

    setState(() {
      _uploadingQuestion = true;
    });

    try {
      await RubricApiService.uploadQuestionFile(assessmentId, path);
      if (!mounted) return;
      setState(() => _uploadingQuestion = false);
      _showSnack('Question file uploaded successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingQuestion = false);
      _showSnack('Upload failed: $e', isError: true);
    }
  }

  Future<void> _uploadGuideFile() async {
    final assessmentId = _selectedAssessment?.assessmentId;
    if (assessmentId == null) {
      _showSnack('Please select an assessment first.', isError: true);
      return;
    }

    final picked = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['txt', 'md', 'docx', 'pdf', 'csv', 'xlsx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.first.path;
    if (path == null) return;

    setState(() {
      _uploadingGuide = true;
    });

    try {
      await RubricApiService.uploadGuideFile(assessmentId, path);
      if (!mounted) return;
      setState(() => _uploadingGuide = false);
      _showSnack('Guide file uploaded successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingGuide = false);
      _showSnack('Upload failed: $e', isError: true);
    }
  }

  Future<void> _parseRubric() async {
    final assessmentId = _selectedAssessment?.assessmentId;
    if (assessmentId == null) {
      _showSnack('Please select an assessment first.', isError: true);
      return;
    }

    setState(() {
      _parsingRubric = true;
      _rubricItems = [];
    });

    try {
      final rawList = await RubricApiService.parseRubric(assessmentId);
      if (!mounted) return;

      // Parse the raw response into QuestionRubric models
      final items = rawList
          .map((e) => QuestionRubric.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _rubricItems = items;
        _parsingRubric = false;
      });

      if (items.isEmpty) {
        _showSnack('No rubric items could be parsed.');
      } else {
        // Build an Assessment with rubric items and apply it
        _applyRubricToAssessment(items);
        _showSnack(
          'Rubric parsed: ${items.length} item(s) (Q1–Q${items.length}).',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _parsingRubric = false);
      _showSnack('Parse rubric failed: $e', isError: true);
    }
  }

  Future<void> _loadRubric() async {
    final assessmentId = _selectedAssessment?.assessmentId;
    if (assessmentId == null) return;

    try {
      final items = await RubricApiService.getRubric(assessmentId);
      if (!mounted) return;
      setState(() => _rubricItems = items);

      if (items.isNotEmpty) {
        _applyRubricToAssessment(items);
      }
    } catch (_) {
      // Silently ignore – rubric may not exist yet
    }
  }

  Future<void> _deleteAssessment(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assessment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AssessmentApiService.deleteAssessment(id);
      if (!mounted) return;

      setState(() {
        _assessments.removeWhere((a) => a.assessmentId == id);
        if (_selectedAssessment?.assessmentId == id) {
          _selectedAssessment = null;
          _rubricItems = [];
        }
        _beMessage = 'Assessment deleted.';
      });

      _showSnack('Assessment deleted successfully.');
    } catch (e) {
      _showSnack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _viewAssessmentDetail(Assessment assessment) async {
    // Load full detail and display in a dialog
    try {
      final detail = await AssessmentApiService.getAssessment(
        assessment.assessmentId,
      );
      if (!mounted) return;
      if (detail == null) {
        _showSnack('Assessment not found.', isError: true);
        return;
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(detail.assessmentTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('Course Code', detail.courseCode),
                _DetailRow('ID', detail.assessmentId),
                _DetailRow('Raw Score', '/${detail.totalRawScore.toInt()}'),
                _DetailRow('Converted Score', '/${detail.totalConvertedScore.toInt()}'),
                _DetailRow('Status', detail.status.isNotEmpty ? detail.status : 'Active'),
                _DetailRow('Created', detail.createdAt.toString().split('.')[0]),
                if (detail.questions.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      'Questions',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...detail.questions.asMap().entries.map((e) {
                    return Text(
                      'Q${e.key + 1}: ${e.value.title}',
                      style: const TextStyle(fontSize: 12),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack('Failed to load detail: $e', isError: true);
    }
  }

  Future<void> _editAssessment(Assessment assessment) async {
    final titleController = TextEditingController(text: assessment.assessmentTitle);
    final courseCodeController = TextEditingController(text: assessment.courseCode);
    final descriptionController = TextEditingController(text: assessment.examQuestionText);

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Assessment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Title',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Assessment title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Course Code',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: courseCodeController,
                decoration: InputDecoration(
                  hintText: 'Course code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Description (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final title = titleController.text.trim();
              final courseCode = courseCodeController.text.trim();
              
              if (title.isEmpty || courseCode.isEmpty) {
                _showSnack('Title and Course Code are required.', isError: true);
                return;
              }

              try {
                final body = {
                  'title': title,
                  'courseCode': courseCode,
                  'description': descriptionController.text.trim(),
                };

                final updated = await AssessmentApiService.updateAssessment(
                  assessment.assessmentId,
                  body,
                );

                if (!mounted) return;

                final idx = _assessments.indexWhere((a) => a.assessmentId == assessment.assessmentId);
                if (idx >= 0) {
                  setState(() {
                    _assessments[idx] = updated;
                    if (_selectedAssessment?.assessmentId == assessment.assessmentId) {
                      _selectedAssessment = updated;
                    }
                  });
                }

                _showSnack('Assessment updated successfully.');
              } catch (e) {
                _showSnack('Update failed: $e', isError: true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _applyRubricToAssessment(List<QuestionRubric> items) {
    final a = _selectedAssessment;
    if (a == null) return;

    final totalRaw =
        items.fold<double>(0, (sum, q) => sum + q.rawMaxScore);

    final updated = Assessment(
      assessmentId: a.assessmentId,
      courseCode: a.courseCode,
      assessmentTitle: a.assessmentTitle,
      examQuestionText: _examQuestionsController.text,
      gradingGuideText: _gradingGuideController.text,
      totalRawScore: totalRaw,
      totalConvertedScore: a.totalConvertedScore,
      questions: items,
      createdAt: a.createdAt,
      status: a.status,
    );

    widget.onApplyAssessment(updated);
  }

  // ── Actions (local) ────────────────────────────────────────────────────────────

  void _loadSample() {
    final sample = buildPmg201cPe2SampleAssessment();
    setState(() => _prefillFromAssessment(sample));
    widget.onApplyAssessment(sample);
    _showSnack('PMG201c PE2 sample assessment loaded.');
  }

  Future<void> _applyCustom() async {
    final title = _titleController.text.trim();
    final courseCode = _courseCodeController.text.trim();

    String? error;
    if (courseCode.isEmpty) {
      error = 'Course code is required.';
    } else if (title.isEmpty) {
      error = 'Assessment title is required.';
    }

    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    try {
      final body = {
        'title': title,
        'courseCode': courseCode,
        'description': _examQuestionsController.text.trim(),
      };
      
      final created = await AssessmentApiService.createAssessment(body);
      if (!mounted) return;

      setState(() {
        _selectedAssessment = created;
        _assessments.insert(0, created);
        _beMessage = 'Assessment created: ${created.assessmentTitle}';
      });

      widget.onApplyAssessment(created);
      _showSnack('Assessment created successfully. You can now upload files and parse rubric.');
      
      // Clear controllers after successful creation
      _titleController.clear();
      _courseCodeController.clear();
      _examQuestionsController.clear();
      _gradingGuideController.clear();
      
    } catch (e) {
      _showSnack('Create failed: $e', isError: true);
    }
  }

  // ── Snack helper ───────────────────────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false, Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            backgroundColor ?? (isError ? AppColors.error : null),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────────

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
                  // ── Backend section ─────────────────────────────────────
                  _buildBackendSection(),
                  const SizedBox(height: 28),
                  _buildDivider('Or use local sample / custom assessment'),
                  const SizedBox(height: 20),

                  _buildSampleCard(),
                  const SizedBox(height: 28),
                  _buildDivider('Or create assessment by filling form below'),
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
                  _buildFormRow(
                    label: 'Description (Optional)',
                    hint: 'Add any additional description...',
                    controller: _examQuestionsController,
                    maxLines: 6,
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
                        'Create Assessment on Backend',
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

  // ── Backend section widget ─────────────────────────────────────────────────────

  Widget _buildBackendSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Assessments from Backend',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_loadingAssessments)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadAssessments,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Refresh assessments',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Status / message
          if (_beMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _beMessage,
                style: TextStyle(
                  color: _beMessage.contains('loaded')
                      ? AppColors.primary
                      : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),

          // Assessments list
          if (_assessments.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Available Assessments',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            ...(_assessments.map((a) {
              final isSelected = _selectedAssessment?.assessmentId == a.assessmentId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(30)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(a.assessmentTitle),
                  subtitle: Text(
                    a.courseCode,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withAlpha(50),
                    child: Icon(
                      isSelected ? Icons.check_rounded : Icons.description_rounded,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 18,
                    ),
                  ),
                  onTap: () => _selectAssessment(a),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'view') {
                        await _viewAssessmentDetail(a);
                      } else if (action == 'edit') {
                        await _editAssessment(a);
                      } else if (action == 'delete') {
                        await _deleteAssessment(a.assessmentId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.info_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('View Detail'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
          ],

          const SizedBox(height: 16),

          // Selected assessment actions
          if (_selectedAssessment != null) ...[
            const Divider(color: AppColors.outlineVariant, height: 20),
            const Text(
              'Selected Assessment Actions',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            // Upload buttons row
            Row(
              children: [
                Expanded(
                  child: _uploadButton(
                    label: 'Upload Question',
                    uploading: _uploadingQuestion,
                    onPressed: _uploadQuestionFile,
                    icon: Icons.question_answer_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _uploadButton(
                    label: 'Upload Guide',
                    uploading: _uploadingGuide,
                    onPressed: _uploadGuideFile,
                    icon: Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _uploadButton(
                    label: 'Parse Rubric',
                    uploading: _parsingRubric,
                    onPressed: _parseRubric,
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],

          // Rubric items display
          if (_rubricItems.isNotEmpty) ...[
            const Divider(color: AppColors.outlineVariant, height: 20),
            const Text(
              'Rubric Items (Parsed)',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ..._rubricItems.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Q$idx',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.description.isNotEmpty)
                            Text(
                              item.description,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.rawMaxScore.toInt()} pts',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _uploadButton({
    required String label,
    required bool uploading,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(
          color: uploading ? AppColors.primary.withAlpha(80) : AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: uploading ? null : onPressed,
      icon: uploading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  // ── Existing widgets ───────────────────────────────────────────────────────────

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

// ── Detail row widget ──────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page header widget ──────────────────────────────────────────────────────────

class PageHeaderWithAction extends StatelessWidget {
  const PageHeaderWithAction({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.button,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PageTitle(title: title, subtitle: subtitle),
            const SizedBox(width: 16),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Spacer(),
            if (button != null && onPressed != null)
              FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(button!),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}