import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmg_grading_assistant/models/grading_result.dart';
import 'package:pmg_grading_assistant/models/mark_input.dart';
import 'package:pmg_grading_assistant/models/submission.dart';
import 'package:pmg_grading_assistant/services/file/excel_export_service.dart';
import 'package:pmg_grading_assistant/services/file/mark_input_excel_service.dart';
import 'package:pmg_grading_assistant/services/file/submission_file_service.dart';

void main() {
  group('Submission', () {
    test('extractAlias parses SE student code from file name', () {
      expect(
        Submission.extractAlias('SE172001_NguyenVanA.txt'),
        'SE172001',
      );
      expect(
        Submission.extractAlias('SE172002_TranThiB.txt'),
        'SE172002',
      );
    });
  });

  group('MarkInputExcelService', () {
    late MarkInputExcelService service;
    late File sampleFile;

    setUp(() {
      service = MarkInputExcelService();
      sampleFile = File('test_files/Mark_Input.xlsx');
    });

    test('imports Mark_Input.xlsx with max score row and student rows', () async {
      expect(sampleFile.existsSync(), isTrue);

      final result = await service.importFromFile(sampleFile);

      expect(result.maxQuestionScores, [2, 2, 3, 3]);
      expect(result.maxTotal, 10);
      expect(result.rows.length, 2);
      expect(result.rows[0].alias, 'SE172001');
      expect(result.rows[0].marker, 'Marker A');
      expect(result.rows[1].alias, 'SE172002');
      expect(result.rows[1].marker, 'Marker B');
    });
  });

  group('ExcelExportService', () {
    test('exports Mark_Output.xlsx mapped by alias', () async {
      final service = ExcelExportService();
      final templateRows = [
        const MarkInputRow(
          alias: 'SE172001',
          marker: 'Marker A',
          questionScores: [null, null, null, null],
        ),
        const MarkInputRow(
          alias: 'SE172002',
          marker: 'Marker B',
          questionScores: [null, null, null, null],
        ),
      ];

      final gradingResults = [
        GradingResult(
          alias: 'SE172001',
          marker: 'AI',
          fileName: 'SE172001_NguyenVanA.txt',
          studentId: 'SE172001',
          studentName: 'NguyenVanA',
          questionScores: const [1.8, 1.9, 2.5, 2.3],
          finalScore: 8.5,
          criteriaScores: const {},
          feedback: 'Good submission.',
        ),
      ];

      final file = await service.exportMarkOutput(
        templateRows: templateRows,
        gradingResults: gradingResults,
        openAfterExport: false,
        saveDirectory: Directory.systemTemp,
      );

      expect(file.existsSync(), isTrue);
      expect(file.path.endsWith('Mark_Output.xlsx'), isTrue);
    });
  });

  group('SubmissionFileService', () {
    test('imports txt files from disk paths', () async {
      final service = SubmissionFileService();
      final submissions = await service.importTxtFilesFromPaths([
        'test_files/SE172001_NguyenVanA.txt',
        'test_files/SE172002_TranThiB.txt',
      ]);

      expect(submissions.length, 2);
      expect(submissions[0].alias, 'SE172001');
      expect(submissions[0].content, isNotEmpty);
      expect(submissions[1].alias, 'SE172002');
    });
  });
}
