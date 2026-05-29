import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/grading_result.dart';
import 'models/submission.dart';
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
      title: 'PMG201c GradeAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppShell – navigation host + state owner
// ─────────────────────────────────────────────────────────────────────────────

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

  // ── File picking ────────────────────────────────────────────────────────────

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

  // ── Mock grading ────────────────────────────────────────────────────────────

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

  // ── Excel export ────────────────────────────────────────────────────────────

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

  // ── Derived getters ─────────────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
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
      const CriteriaScreen(),
      GradingScreen(
        submission: selectedSubmission,
        result: selectedResult,
        onGradeAll: mockGradeAll,
      ),
      ExportScreen(
        results: results,
        onExportExcel: exportExcel,
      ),
      const SettingsScreen(),
    ];

    final titles = [
      'Workspace',
      'PMG201c Criteria Matrix',
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