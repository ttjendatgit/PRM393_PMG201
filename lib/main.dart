import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/assessment.dart';
import 'models/grading_result.dart';
import 'models/submission.dart';
import 'screens/assessment_setup_screen.dart';
import 'screens/criteria_screen.dart';
import 'screens/export_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

import 'theme/app_theme.dart';
import 'widgets/side_nav.dart';
import 'widgets/top_bar.dart';

void main() {
  runApp(const PMGGradeAIApp());
}

class PMGGradeAIApp extends StatelessWidget {
  const PMGGradeAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMG GradeAI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Nav indices:
  // 0 = Home, 1 = Assessment, 2 = Criteria, 3 = Grading, 4 = Export, 5 = Settings

  int selectedIndex = 0;
  int? selectedSubmissionIndex;

  List<Submission> submissions = [];
  List<GradingResult> results = [];

  Assessment? currentAssessment;

  bool isGrading = false;
  String message = 'Ready. Import .txt files to begin Phase 1.';

  void _applyAssessment(Assessment assessment) {
    setState(() {
      currentAssessment = assessment;
      results = [];
      message = 'Assessment loaded: ${assessment.courseCode} — ${assessment.assessmentTitle}';
    });
  }

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
      selectedIndex = 3; // Grading screen
    });
  }

  GradingResult _mockGrade(Submission submission) {
    final nameInfo = _extractStudentInfo(submission.fileName);

    final criteriaScores = _buildMockCriteriaScores();
    final finalScore = criteriaScores.values.fold(0.0, (a, b) => a + b);
    final feedback = _buildMockFeedback();

    return GradingResult(
      fileName: submission.fileName,
      studentId: nameInfo.$1,
      studentName: nameInfo.$2,
      finalScore: finalScore,
      criteriaScores: criteriaScores,
      feedback: feedback,
    );
  }

  Map<String, double> _buildMockCriteriaScores() {
    final a = currentAssessment;

    // PMG201c PE2 sample: use specific realistic mock scores
    if (a != null &&
        a.questions.isNotEmpty &&
        a.assessmentId == 'pmg201c-pe2-sample') {
      return {
        a.questions[0].title: 1.4, // Project Charter Statement
        a.questions[1].title: 1.8, // Cost / Budget Plan
        a.questions[2].title: 2.4, // Risk Register
        a.questions[3].title: 2.9, // RACI Matrix
      };
    }

    // Generic assessment with parsed questions: 75% of convertedMaxScore
    if (a != null && a.questions.isNotEmpty) {
      return {
        for (final q in a.questions)
          q.title: double.parse((q.convertedMaxScore * 0.75).toStringAsFixed(1))
      };
    }

    // No assessment loaded: fall back to default PMG201c mock scores
    return const {
      'Project Charter': 1.4,
      'Cost / Budget': 1.8,
      'Risk Register': 2.4,
      'RACI Matrix': 2.9,
    };
  }

  String _buildMockFeedback() {
    final a = currentAssessment;

    if (a != null && a.assessmentId == 'pmg201c-pe2-sample') {
      return 'The submission shows a solid understanding of PMG201c project planning. '
          'The RACI matrix and risk register are clear. '
          'To improve, the student should explain budget assumptions and cost breakdowns in more detail.';
    }

    if (a != null) {
      return 'Mock AI assessment for ${a.courseCode} — ${a.assessmentTitle}. '
          'The submission demonstrates adequate understanding of the required topics. '
          'Connect the real AI API in a future phase for detailed feedback.';
    }

    return 'The submission shows a solid understanding of project planning. '
        'The RACI matrix and risk register are clear. '
        'To improve, the student should explain budget assumptions in more detail.';
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
      // 0 — Home
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
            selectedIndex = 3; // Grading screen
          });
        },
      ),
      // 1 — Assessment Setup
      AssessmentSetupScreen(
        currentAssessment: currentAssessment,
        onApplyAssessment: _applyAssessment,
      ),
      // 2 — Criteria
      CriteriaPage(assessment: currentAssessment),
      // 3 — Grading
      GradingPage(
        submission: selectedSubmission,
        result: selectedResult,
        onGradeAll: mockGradeAll,
      ),
      // 4 — Export
      ExportPage(
        results: results,
        onExportExcel: exportExcel,
      ),
      // 5 — Settings
      const SettingsScreen(),
    ];

    final titles = [
      'Workspace',
      'Assessment Setup',
      'Criteria Matrix',
      'AI Grading Detail',
      'Export Data',
      'Settings',
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
