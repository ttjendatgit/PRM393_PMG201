import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const PMGGradeAIApp());
}

class PMGGradeAIApp extends StatelessWidget {
  const PMGGradeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMG201c GradeAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const AppShell(),
    );
  }
}

class AppColors {
  static const background = Color(0xFF0B1326);
  static const surface = Color(0xFF0B1326);
  static const surfaceLow = Color(0xFF131B2E);
  static const surfaceContainer = Color(0xFF171F33);
  static const surfaceHigh = Color(0xFF222A3D);
  static const surfaceHighest = Color(0xFF2D3449);

  static const primary = Color(0xFFB5C4FF);
  static const primaryContainer = Color(0xFF1A56DB);
  static const secondary = Color(0xFFADC6FF);

  static const text = Color(0xFFDAE2FD);
  static const muted = Color(0xFFC3C5D7);
  static const outline = Color(0xFF8D90A0);
  static const outlineVariant = Color(0xFF434654);
  static const error = Color(0xFFFFB4AB);
}

class Submission {
  final String fileName;
  final String filePath;
  final String content;
  final int sizeInBytes;

  const Submission({
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.sizeInBytes,
  });
}

class GradingResult {
  final String fileName;
  final String studentId;
  final String studentName;
  final double finalScore;
  final Map<String, double> criteriaScores;
  final String feedback;

  const GradingResult({
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
  });
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  int? selectedSubmissionIndex;

  List<Submission> submissions = [];
  List<GradingResult> results = [];

  bool isGrading = false;
  String message = 'Ready. Import .txt files to begin Phase 1.';

  Future<void> pickTxtFiles() async {
   final result = await fp.FilePicker.pickFiles(
  allowMultiple: true,
  type: fp.FileType.custom,
  allowedExtensions: ['txt'],
);

    if (result == null) {
      setState(() => message = 'File selection cancelled.');
      return;
    }

    final picked = <Submission>[];

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final content = await File(path).readAsString();

      picked.add(
        Submission(
          fileName: file.name,
          filePath: path,
          content: content,
          sizeInBytes: file.size,
        ),
      );
    }

    setState(() {
      submissions = picked;
      results = [];
      selectedSubmissionIndex = picked.isNotEmpty ? 0 : null;
      message = 'Imported ${picked.length} .txt file(s).';
    });
  }

  Future<void> mockGradeAll() async {
    if (submissions.isEmpty) {
      setState(() => message = 'Please import .txt files first.');
      return;
    }

    setState(() {
      isGrading = true;
      results = [];
      message = 'Mock AI grading started...';
    });

    final temp = <GradingResult>[];

    for (final submission in submissions) {
      await Future.delayed(const Duration(milliseconds: 650));

      temp.add(_mockGrade(submission));

      setState(() {
        results = List.from(temp);
        message = 'Graded ${results.length}/${submissions.length} file(s).';
      });
    }

    setState(() {
      isGrading = false;
      message = 'Completed mock grading. Next phase: connect real AI API.';
      selectedIndex = 2;
    });
  }

  GradingResult _mockGrade(Submission submission) {
    final nameInfo = _extractStudentInfo(submission.fileName);

    return GradingResult(
      fileName: submission.fileName,
      studentId: nameInfo.$1,
      studentName: nameInfo.$2,
      finalScore: 8.5,
      criteriaScores: const {
        'Project Charter': 1.4,
        'Scope & WBS': 1.8,
        'Schedule': 1.6,
        'Budget': 1.2,
        'Risk': 1.7,
        'Presentation': 0.8,
      },
      feedback:
          'The submission shows a solid understanding of PMG201c project planning. The WBS and risk register are clear. To improve, the student should explain budget assumptions and schedule dependencies in more detail.',
    );
  }

  (String, String) _extractStudentInfo(String fileName) {
    final clean = fileName.replaceAll('.txt', '');
    final parts = clean.split('_');

    if (parts.length >= 2 && parts.first.toUpperCase().startsWith('SE')) {
      return (parts.first, parts.sublist(1).join(' '));
    }

    return ('N/A', clean);
  }

  Future<void> exportExcel() async {
    if (results.isEmpty) {
      setState(() => message = 'No grading results to export.');
      return;
    }

    final excel = xls.Excel.createExcel();

    final summary = excel['Summary'];
    summary.appendRow([
      xls.TextCellValue('STT'),
      xls.TextCellValue('Student ID'),
      xls.TextCellValue('Student Name'),
      xls.TextCellValue('File Name'),
      xls.TextCellValue('Final Score'),
      xls.TextCellValue('Feedback'),
    ]);

    for (int i = 0; i < results.length; i++) {
      final item = results[i];
      summary.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(item.studentId),
        xls.TextCellValue(item.studentName),
        xls.TextCellValue(item.fileName),
        xls.DoubleCellValue(item.finalScore),
        xls.TextCellValue(item.feedback),
      ]);
    }

    final breakdown = excel['Criteria Breakdown'];
    breakdown.appendRow([
      xls.TextCellValue('Student ID'),
      xls.TextCellValue('Student Name'),
      xls.TextCellValue('Criterion'),
      xls.TextCellValue('Score'),
    ]);

    for (final result in results) {
      for (final entry in result.criteriaScores.entries) {
        breakdown.appendRow([
          xls.TextCellValue(result.studentId),
          xls.TextCellValue(result.studentName),
          xls.TextCellValue(entry.key),
          xls.DoubleCellValue(entry.value),
        ]);
      }
    }

    final downloads = await getDownloadsDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final saveDir = downloads ?? documents;

    final filePath = p.join(saveDir.path, 'PMG201c_grading_results.xlsx');
    final bytes = excel.save();

    if (bytes == null) {
      setState(() => message = 'Cannot generate Excel file.');
      return;
    }

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    setState(() => message = 'Excel exported: ${file.path}');
  }

  GradingResult? get selectedResult {
    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;

    final fileName = submissions[selectedSubmissionIndex!].fileName;

    for (final result in results) {
      if (result.fileName == fileName) return result;
    }

    return null;
  }

  Submission? get selectedSubmission {
    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;
    return submissions[selectedSubmissionIndex!];
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        submissions: submissions,
        results: results,
        message: message,
        isGrading: isGrading,
        onPickFiles: pickTxtFiles,
        onGradeAll: mockGradeAll,
        onSelectSubmission: (index) {
          setState(() {
            selectedSubmissionIndex = index;
            selectedIndex = 2;
          });
        },
      ),
      const CriteriaPage(),
      GradingPage(
        submission: selectedSubmission,
        result: selectedResult,
        onGradeAll: mockGradeAll,
      ),
      ExportPage(
        results: results,
        onExportExcel: exportExcel,
      ),
    ];

    final titles = [
      'Workspace',
      'PMG201c Criteria Matrix',
      'AI Grading Detail',
      'Export Data',
    ];

    return Scaffold(
      body: Row(
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            onSelect: (index) => setState(() => selectedIndex = index),
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(title: titles[selectedIndex]),
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.rule_rounded, 'Criteria'),
      _NavItem(Icons.grading_rounded, 'Grading'),
      _NavItem(Icons.ios_share_rounded, 'Export'),
    ];

    return Container(
      width: 264,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandBlock(),
          const SizedBox(height: 28),
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
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Grading Task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        color: selectedIndex == i
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? AppColors.text
                              : AppColors.muted,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          const Divider(color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceHighest,
                child: Icon(Icons.person_rounded, color: AppColors.muted),
              ),
              SizedBox(width: 12),
              Text(
                'PMG201c Console',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BrandBlock extends StatelessWidget {
  const BrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: AppColors.text),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PMG GradeAI',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'ACADEMIC CONSOLE',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search students, criteria, files...',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none_rounded, color: AppColors.muted),
          const SizedBox(width: 16),
          const Icon(Icons.settings_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

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
                  child: SubmissionsPanel(
                    submissions: submissions,
                    results: results,
                    onTap: onSelectSubmission,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 7,
                  child: UploadZone(
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

class SubmissionsPanel extends StatelessWidget {
  const SubmissionsPanel({
    super.key,
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
        const SectionHeader(title: 'Imported Submissions', action: 'View All'),
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

class UploadZone extends StatelessWidget {
  const UploadZone({
    super.key,
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

class CriteriaPage extends StatelessWidget {
  const CriteriaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final criteria = [
      _Criteria('Project Charter', 15, Icons.assignment_rounded),
      _Criteria('Scope & WBS', 20, Icons.account_tree_rounded),
      _Criteria('Schedule Management', 20, Icons.calendar_month_rounded),
      _Criteria('Budget & Resources', 15, Icons.payments_rounded),
      _Criteria('Risk Management', 20, Icons.warning_amber_rounded),
      _Criteria('Presentation & Logic', 10, Icons.auto_stories_rounded),
    ];

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeaderWithAction(
            title: 'PMG201c Criteria Matrix',
            subtitle:
                'Define weighted evaluation dimensions for Project Management assignments. Total weight must equal 100%.',
            badge: 'Total Weight 100%',
            button: 'Add Criteria',
          ),
          const SizedBox(height: 26),
          Expanded(
            child: GridView.builder(
              itemCount: criteria.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 390,
                mainAxisExtent: 280,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemBuilder: (context, index) {
                final item = criteria[index];

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        minHeight: 4,
                        value: item.weight / 100,
                        backgroundColor: AppColors.surfaceHighest,
                        color: AppColors.primary,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    text: '${item.weight}%',
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                  'PMG201c rubric dimension. The AI will compare the student submission against this criterion and suggest score breakdown.',
                                   maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    height: 1.45,
                                  ),
                                ),
                              const Spacer(),
                              const Row(
                                children: [
                                  TinyTag(text: 'Core'),
                                  SizedBox(width: 8),
                                  TinyTag(text: 'PMG201c'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
            EmptyCard(
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

class ExportPage extends StatelessWidget {
  const ExportPage({
    super.key,
    required this.results,
    required this.onExportExcel,
  });

  final List<GradingResult> results;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final avg = results.isEmpty
        ? 0
        : results.map((e) => e.finalScore).reduce((a, b) => a + b) /
            results.length;

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeaderWithAction(
            title: 'Export Data',
            subtitle:
                'Review and export PMG201c final assessment data, including scores, criteria breakdown, and AI-generated comments.',
            badge: 'Course PMG201c',
            button: 'Export to Excel',
            onPressed: onExportExcel,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'TOTAL SUBMISSIONS',
                  value: '${results.length}',
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: StatCard(
                  label: 'GRADED',
                  value: results.isEmpty ? '0%' : '100%',
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: StatCard(
                  label: 'CLASS AVERAGE',
                  value: avg.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: results.isEmpty
                ? const EmptyCard(
                    text:
                        'No results yet. Go to Home, import files, then run Translate + Grade.',
                  )
                : ExportTable(results: results),
          ),
        ],
      ),
    );
  }
}

class ExportTable extends StatelessWidget {
  const ExportTable({super.key, required this.results});

  final List<GradingResult> results;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceHigh),
            columnSpacing: 34,
            columns: const [
              DataColumn(label: TableHeader('STUDENT ID')),
              DataColumn(label: TableHeader('NAME')),
              DataColumn(label: TableHeader('FILE')),
              DataColumn(label: TableHeader('FINAL SCORE')),
              DataColumn(label: TableHeader('AI SUMMARY COMMENT')),
            ],
            rows: results.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item.studentId)),
                  DataCell(Text(item.studentName)),
                  DataCell(Text(item.fileName)),
                  DataCell(ScoreBubble(score: item.finalScore)),
                  DataCell(
                    SizedBox(
                      width: 420,
                      child: Text(
                        item.feedback,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(48, 38, 48, 38),
      child: child,
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 17,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class PageHeaderWithAction extends StatelessWidget {
  const PageHeaderWithAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.button,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: PageTitle(title: title, subtitle: subtitle)),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed ?? () {},
          icon: Icon(
            button.contains('Export')
                ? Icons.download_rounded
                : Icons.add_rounded,
          ),
          label: Text(
            button,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.action,
  });

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

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class TinyTag extends StatelessWidget {
  const TinyTag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class TableHeader extends StatelessWidget {
  const TableHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class ScoreBubble extends StatelessWidget {
  const ScoreBubble({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 8
        ? AppColors.primary
        : score >= 7
            ? AppColors.secondary
            : AppColors.error;

    return Container(
      height: 34,
      width: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}

class _Criteria {
  final String title;
  final int weight;
  final IconData icon;

  const _Criteria(this.title, this.weight, this.icon);
}