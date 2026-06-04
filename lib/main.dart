import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/ai_mode.dart';
import 'models/assessment.dart';
import 'models/grading_result.dart';
import 'models/submission.dart';
import 'screens/assessment_setup_screen.dart';
import 'screens/criteria_screen.dart';
import 'screens/export_screen.dart';
import 'screens/grading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ai/openrouter_grading_service.dart';
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

  // AI configuration — stored in memory only, never persisted to disk
  String _apiKey = '';
  String _modelId = 'openrouter/free';
  AiMode _aiMode = AiMode.mock;

  bool isGrading = false;
  String message = 'Ready. Import .txt files to begin.';

  // ── Assessment ────────────────────────────────────────────────────────────

  void _applyAssessment(Assessment assessment) {
    setState(() {
      currentAssessment = assessment;
      results = [];
      message =
          'Assessment loaded: ${assessment.courseCode} — ${assessment.assessmentTitle}';
    });
  }

  // ── Review save ───────────────────────────────────────────────────────────

  void _saveReview(GradingResult updated) {
    setState(() {
      final idx = results.indexWhere((r) => r.fileName == updated.fileName);
      if (idx >= 0) {
        final copy = List<GradingResult>.from(results);
        copy[idx] = updated;
        results = copy;
      }
      message = 'Reviewed scores saved.';
    });
  }

  // ── AI configuration ──────────────────────────────────────────────────────

  void _updateApiKey(String value) => setState(() => _apiKey = value);
  void _clearApiKey() => setState(() => _apiKey = '');
  void _updateModelId(String value) => setState(() => _modelId = value);
  void _updateAiMode(AiMode mode) => setState(() => _aiMode = mode);

  // ── File import ───────────────────────────────────────────────────────────

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

  // ── Grading ───────────────────────────────────────────────────────────────

  Future<void> gradeAll() async {
    if (submissions.isEmpty) {
      setState(() => message = 'Please import .txt files first.');
      return;
    }

    if (_aiMode == AiMode.openRouter) {
      if (_apiKey.trim().isEmpty) {
        setState(() => message = 'Please enter OpenRouter API key in Settings.');
        return;
      }
      if (_modelId.trim().isEmpty) {
        setState(() => message = 'Please enter a Model ID in Settings.');
        return;
      }
      if (currentAssessment == null) {
        setState(
          () => message =
              'Please load or create an assessment first (Assessment Setup).',
        );
        return;
      }
    }

    setState(() {
      isGrading = true;
      results = [];
      message = _aiMode == AiMode.mock
          ? 'Mock AI grading started...'
          : 'OpenRouter AI grading started (${submissions.length} file(s))...';
    });

    final temp = <GradingResult>[];

    for (final submission in submissions) {
      try {
        GradingResult result;

        if (_aiMode == AiMode.mock) {
          await Future.delayed(const Duration(milliseconds: 650));
          result = _mockGrade(submission);
        } else {
          result = await OpenRouterGradingService.gradeSubmission(
            apiKey: _apiKey,
            modelId: _modelId,
            assessment: currentAssessment!,
            submission: submission,
          );
        }

        temp.add(result);
        setState(() {
          results = List.from(temp);
          message =
              'Graded ${results.length}/${submissions.length} file(s)...';
        });
      } catch (e) {
        final full = e.toString();
        debugPrint('Grading error for "${submission.fileName}": $full');
        // Strip "Exception: " prefix, take first line only, cap at 160 chars
        var display = full.startsWith('Exception: ') ? full.substring(11) : full;
        final nl = display.indexOf('\n');
        if (nl >= 0) display = display.substring(0, nl);
        if (display.length > 160) display = '${display.substring(0, 160)}…';
        setState(() {
          isGrading = false;
          message = 'Error: $display';
        });
        return;
      }
    }

    setState(() {
      isGrading = false;
      message = _aiMode == AiMode.mock
          ? 'Mock grading complete. ${temp.length} result(s) ready.'
          : 'OpenRouter grading complete. ${temp.length} result(s) ready.';
      selectedIndex = 3; // Grading screen
    });
  }

  // ── Mock grading ──────────────────────────────────────────────────────────

  GradingResult _mockGrade(Submission submission) {
    final nameInfo = _extractStudentInfo(submission.fileName);

    final criteriaScores = _buildMockCriteriaScores();
    final finalScore = criteriaScores.values.fold(0.0, (a, b) => a + b);
    final feedback = _buildMockFeedback();

    final a = currentAssessment;
    final totalRaw = a != null && a.totalConvertedScore > 0
        ? double.parse(
            (finalScore / a.totalConvertedScore * a.totalRawScore)
                .toStringAsFixed(0),
          )
        : finalScore * 10.0;

    return GradingResult(
      fileName: submission.fileName,
      studentId: nameInfo.$1,
      studentName: nameInfo.$2,
      totalRawScore: totalRaw,
      finalScore: finalScore,
      criteriaScores: criteriaScores,
      feedback: feedback,
      // questionResults is null for mock — grading screen falls back to criteriaScores grid
    );
  }

  Map<String, double> _buildMockCriteriaScores() {
    final a = currentAssessment;

    if (a != null && a.questions.isNotEmpty && a.assessmentId == 'pmg201c-pe2-sample') {
      return {
        a.questions[0].title: 1.4,
        a.questions[1].title: 1.8,
        a.questions[2].title: 2.4,
        a.questions[3].title: 2.9,
      };
    }

    if (a != null && a.questions.isNotEmpty) {
      return {
        for (final q in a.questions)
          q.title: double.parse(
            (q.convertedMaxScore * 0.75).toStringAsFixed(1),
          ),
      };
    }

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
          'The submission demonstrates adequate understanding. '
          'Connect the real AI API for detailed feedback.';
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

  // ── Excel export ──────────────────────────────────────────────────────────

  Future<void> exportExcel() async {
    if (results.isEmpty) {
      setState(() => message = 'No grading results to export.');
      return;
    }

    final excel = xls.Excel.createExcel();
    final hasQR = results.first.questionResults != null;

    // Timestamped filename
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'PMG201c_grading_results_$stamp.xlsx';

    // Shared cell styles
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('FF1F4E79'),
      fontColorHex: xls.ExcelColor.white,
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );
    final numericStyle = xls.CellStyle(
      numberFormat: xls.NumFormat.standard_2,
      horizontalAlign: xls.HorizontalAlign.Center,
    );
    final wrapStyle = xls.CellStyle(
      textWrapping: xls.TextWrapping.WrapText,
      verticalAlign: xls.VerticalAlign.Top,
    );

    void applyHeaderAndWidths(
      xls.Sheet sheet,
      int totalCols,
      int scoreCols, // first column index of score block (after fixed cols)
      int aiCommentCol,
      int reviewerNoteCol,
      int totalScoreColsBeforeComments, // number of score cols between fixed and AI comment
    ) {
      for (int c = 0; c < totalCols; c++) {
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .cellStyle = headerStyle;

        double w;
        if (c == 0) {
          w = 8;
        } else if (c == 1) {
          w = 16;
        } else if (c == 2) {
          w = 22;
        } else if (c == 3) {
          w = 28;
        } else if (c == aiCommentCol) {
          w = 45;
        } else if (c == reviewerNoteCol) {
          w = 45;
        } else if (c >= aiCommentCol - 2 && c < aiCommentCol) {
          w = 16; // Total Raw / Total Converted
        } else {
          w = 14; // per-question / per-criterion columns
        }
        sheet.setColumnWidth(c, w);
      }
    }

    if (hasQR) {
      final qTemplate = results.first.questionResults!;
      final totalRawMax = qTemplate.fold<double>(0, (s, q) => s + q.maxRawScore);
      final totalConvMax = qTemplate.fold<double>(0, (s, q) => s + q.maxConvertedScore);
      final qCount = qTemplate.length;

      // Col layout: 0=STT 1=ID 2=Name 3=File | 4..4+2q-1=Qs | +2q=TotalRaw +2q+1=TotalConv | +2q+2=AIComment +2q+3=ReviewerNote
      final aiCommentCol = 4 + qCount * 2 + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols = reviewerNoteCol + 1;

      final sheet = excel['Grading Results'];

      sheet.appendRow([
        xls.TextCellValue('STT'),
        xls.TextCellValue('Student ID'),
        xls.TextCellValue('Student Name'),
        xls.TextCellValue('File Name'),
        ...qTemplate.expand((qr) => [
          xls.TextCellValue(
            '${qr.questionId.toUpperCase()} Raw (/${qr.maxRawScore.toInt()})',
          ),
          xls.TextCellValue(
            '${qr.questionId.toUpperCase()} Conv (/${qr.maxConvertedScore})',
          ),
        ]),
        xls.TextCellValue('Total Raw (/${totalRawMax.toInt()})'),
        xls.TextCellValue('Total Converted (/$totalConvMax)'),
        xls.TextCellValue('AI Comment'),
        xls.TextCellValue('Reviewer Note'),
      ]);

      applyHeaderAndWidths(sheet, totalCols, 4, aiCommentCol, reviewerNoteCol, qCount * 2 + 2);

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        final qrs = item.questionResults ?? [];
        sheet.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(item.studentId),
          xls.TextCellValue(item.studentName),
          xls.TextCellValue(item.fileName),
          ...qrs.expand((qr) => [
            xls.DoubleCellValue(qr.rawScore),
            xls.DoubleCellValue(qr.convertedScore),
          ]),
          xls.DoubleCellValue(item.totalRawScore),
          xls.DoubleCellValue(item.finalScore),
          xls.TextCellValue(item.feedback),
          xls.TextCellValue(item.reviewerNote),
        ]);

        final rowIdx = i + 1;
        for (int c = 4; c < aiCommentCol; c++) {
          sheet
              .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx))
              .cellStyle = numericStyle;
        }
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: aiCommentCol, rowIndex: rowIdx))
            .cellStyle = wrapStyle;
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: reviewerNoteCol, rowIndex: rowIdx))
            .cellStyle = wrapStyle;
      }
    } else {
      // Mock results: criteria-based
      final criteriaKeys = results.first.criteriaScores.keys.toList();
      final qCount = criteriaKeys.length;

      // Col layout: 0=STT 1=ID 2=Name 3=File | 4..4+q-1=criteria | +q=TotalRaw +q+1=TotalConv | +q+2=AIComment +q+3=ReviewerNote
      final aiCommentCol = 4 + qCount + 2;
      final reviewerNoteCol = aiCommentCol + 1;
      final totalCols = reviewerNoteCol + 1;

      final sheet = excel['Summary'];

      sheet.appendRow([
        xls.TextCellValue('STT'),
        xls.TextCellValue('Student ID'),
        xls.TextCellValue('Student Name'),
        xls.TextCellValue('File Name'),
        ...criteriaKeys.map(xls.TextCellValue.new),
        xls.TextCellValue('Total Raw'),
        xls.TextCellValue('Total Converted'),
        xls.TextCellValue('AI Comment'),
        xls.TextCellValue('Reviewer Note'),
      ]);

      applyHeaderAndWidths(sheet, totalCols, 4, aiCommentCol, reviewerNoteCol, qCount + 2);

      for (int i = 0; i < results.length; i++) {
        final item = results[i];
        sheet.appendRow([
          xls.IntCellValue(i + 1),
          xls.TextCellValue(item.studentId),
          xls.TextCellValue(item.studentName),
          xls.TextCellValue(item.fileName),
          ...criteriaKeys.map(
            (k) => xls.DoubleCellValue(item.criteriaScores[k] ?? 0.0),
          ),
          xls.DoubleCellValue(item.totalRawScore),
          xls.DoubleCellValue(item.finalScore),
          xls.TextCellValue(item.feedback),
          xls.TextCellValue(item.reviewerNote),
        ]);

        final rowIdx = i + 1;
        for (int c = 4; c < aiCommentCol; c++) {
          sheet
              .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx))
              .cellStyle = numericStyle;
        }
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: aiCommentCol, rowIndex: rowIdx))
            .cellStyle = wrapStyle;
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: reviewerNoteCol, rowIndex: rowIdx))
            .cellStyle = wrapStyle;
      }
    }

    final downloads = await getDownloadsDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final saveDir = downloads ?? documents;

    final filePath = p.join(saveDir.path, fileName);
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

  // ── Getters ───────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pages = [
      // 0 — Home
      HomePage(
        submissions: submissions,
        results: results,
        message: message,
        isGrading: isGrading,
        aiMode: _aiMode,
        onPickFiles: pickTxtFiles,
        onGradeAll: gradeAll,
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
        onGradeAll: gradeAll,
        onSaveReview: _saveReview,
        aiMode: _aiMode,
        assessment: currentAssessment,
      ),
      // 4 — Export
      ExportPage(
        results: results,
        onExportExcel: exportExcel,
      ),
      // 5 — Settings
      SettingsScreen(
        apiKey: _apiKey,
        modelId: _modelId,
        aiMode: _aiMode,
        onSaveApiKey: _updateApiKey,
        onClearApiKey: _clearApiKey,
        onSaveModelId: _updateModelId,
        onChangeAiMode: _updateAiMode,
      ),
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
