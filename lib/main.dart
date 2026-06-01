import 'package:flutter/material.dart';

import 'models/grading_result.dart';
import 'models/mark_input.dart';
import 'models/submission.dart';
import 'screens/criteria_screen.dart';
import 'screens/export_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/file/excel_export_service.dart';
import 'services/file/mark_input_excel_service.dart';
import 'services/file/submission_file_service.dart';
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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _submissionFileService = SubmissionFileService();
  final _markInputExcelService = MarkInputExcelService();
  final _excelExportService = ExcelExportService();

  int selectedIndex = 0;
  int? selectedSubmissionIndex;

  List<Submission> submissions = [];
  List<GradingResult> results = [];
  List<MarkInputRow> markInputRows = [];
  List<double> maxQuestionScores = MarkInputRow.defaultMaxScores;
  double maxTotal = MarkInputRow.defaultMaxTotal;

  bool isGrading = false;
  String message = 'Ready. Import Mark_Input.xlsx and .txt files to begin.';

  Future<void> pickTxtFiles() async {
    final picked = await _submissionFileService.pickAndImportTxtFiles();

    if (picked.isEmpty) {
      setState(() => message = 'File selection cancelled or no .txt files found.');
      return;
    }

    setState(() {
      submissions = picked;
      results = [];
      selectedSubmissionIndex = picked.isNotEmpty ? 0 : null;
      message = 'Imported ${picked.length} .txt file(s).';
    });
  }

  Future<void> pickMarkInputFile() async {
    try {
      final imported = await _markInputExcelService.pickAndImportMarkInput();

      if (imported == null) {
        setState(() => message = 'Mark_Input selection cancelled.');
        return;
      }

      setState(() {
        markInputRows = imported.rows;
        maxQuestionScores = imported.maxQuestionScores;
        maxTotal = imported.maxTotal;
        message =
            'Imported Mark_Input.xlsx with ${imported.rows.length} row(s).';
      });
    } on MarkInputParseException catch (error) {
      setState(() => message = 'Mark_Input import failed: $error');
    } catch (error) {
      setState(() => message = 'Mark_Input import failed: $error');
    }
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
      message = 'Completed mock grading. Export Mark_Output.xlsx when ready.';
      selectedIndex = 2;
    });
  }

  GradingResult _mockGrade(Submission submission) {
    final nameInfo = _extractStudentInfo(submission.fileName);
    const questionScores = [1.8, 1.9, 2.5, 2.3];
    const finalScore = 8.5;

    final marker = markInputRows
            .where((row) => row.alias == submission.alias)
            .map((row) => row.marker)
            .firstOrNull ??
        'AI';

    return GradingResult(
      alias: submission.alias,
      marker: marker,
      fileName: submission.fileName,
      studentId: nameInfo.$1,
      studentName: nameInfo.$2,
      questionScores: questionScores,
      finalScore: finalScore,
      criteriaScores: {
        GradingResult.questionLabels[0]: questionScores[0],
        GradingResult.questionLabels[1]: questionScores[1],
        GradingResult.questionLabels[2]: questionScores[2],
        GradingResult.questionLabels[3]: questionScores[3],
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

    try {
      final file = await _excelExportService.exportMarkOutput(
        templateRows: markInputRows,
        gradingResults: results,
        maxQuestionScores: maxQuestionScores,
        maxTotal: maxTotal,
      );

      setState(() => message = 'Exported Mark_Output.xlsx: ${file.path}');
    } on ExcelExportException catch (error) {
      setState(() => message = 'Export failed: $error');
    } catch (error) {
      setState(() => message = 'Export failed: $error');
    }
  }

  GradingResult? get selectedResult {
    if (selectedSubmissionIndex == null) return null;
    if (selectedSubmissionIndex! >= submissions.length) return null;

    final alias = submissions[selectedSubmissionIndex!].alias;

    for (final result in results) {
      if (result.alias == alias) return result;
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
      HomeScreen(
        submissions: submissions,
        results: results,
        markInputCount: markInputRows.length,
        message: message,
        isGrading: isGrading,
        onPickFiles: pickTxtFiles,
        onPickMarkInput: pickMarkInputFile,
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

    const titles = [
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

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
