import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/grading_result.dart';

class ExcelExportService {
  Future<File> exportResults(List<GradingResult> results) async {
    final excel = Excel.createExcel();

    final summarySheet = excel['Summary'];

    summarySheet.appendRow([
      TextCellValue('STT'),
      TextCellValue('Student ID'),
      TextCellValue('Student Name'),
      TextCellValue('File Name'),
      TextCellValue('Final Score'),
      TextCellValue('Feedback'),
    ]);

    for (int i = 0; i < results.length; i++) {
      final result = results[i];

      summarySheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(result.studentId),
        TextCellValue(result.studentName),
        TextCellValue(result.fileName),
        DoubleCellValue(result.finalScore),
        TextCellValue(result.feedback),
      ]);
    }

    final criteriaSheet = excel['Criteria Breakdown'];

    criteriaSheet.appendRow([
      TextCellValue('Student ID'),
      TextCellValue('Student Name'),
      TextCellValue('Criterion'),
      TextCellValue('Score'),
    ]);

    for (final result in results) {
      for (final entry in result.criteriaScores.entries) {
        criteriaSheet.appendRow([
          TextCellValue(result.studentId),
          TextCellValue(result.studentName),
          TextCellValue(entry.key),
          DoubleCellValue(entry.value),
        ]);
      }
    }

    final downloadsDir = await getDownloadsDirectory();
    final saveDir = downloadsDir ?? await getApplicationDocumentsDirectory();

    final filePath = p.join(
      saveDir.path,
      'PMG201c_grading_results.xlsx',
    );

    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('Cannot generate Excel file');
    }

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    return file;
  }
}