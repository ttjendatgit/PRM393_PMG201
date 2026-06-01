import 'dart:io';

import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/grading_result.dart';
import '../../models/mark_input.dart';

class ExcelExportService {
  static const String sheetName = 'Mark_Output';
  static const String outputFileName = 'Mark_Output.xlsx';

  Future<File> exportMarkOutput({
    required List<MarkInputRow> templateRows,
    required List<GradingResult> gradingResults,
    List<double>? maxQuestionScores,
    double? maxTotal,
    bool openAfterExport = true,
    Directory? saveDirectory,
  }) async {
    final resultsByAlias = {
      for (final result in gradingResults)
        result.alias.toUpperCase(): result,
    };

    final maxScores = maxQuestionScores ?? MarkInputRow.defaultMaxScores;
    final totalMax = maxTotal ?? MarkInputRow.defaultMaxTotal;

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }

    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Alias'),
      TextCellValue('Marker'),
      TextCellValue('Question 1'),
      TextCellValue('Question 2'),
      TextCellValue('Question 3'),
      TextCellValue('Question 4'),
      TextCellValue('Total'),
      TextCellValue('Comment'),
    ]);

    sheet.appendRow([
      TextCellValue('Max'),
      TextCellValue(''),
      DoubleCellValue(maxScores[0]),
      DoubleCellValue(maxScores[1]),
      DoubleCellValue(maxScores[2]),
      DoubleCellValue(maxScores[3]),
      DoubleCellValue(totalMax),
      TextCellValue(''),
    ]);

    final rowsToExport = templateRows.isNotEmpty
        ? templateRows
        : gradingResults
            .map(
              (result) => MarkInputRow(
                alias: result.alias,
                marker: result.marker,
                questionScores: result.questionScores
                    .map<double?>((score) => score)
                    .toList(),
                total: result.finalScore,
                comment: result.feedback,
              ),
            )
            .toList();

    for (final template in rowsToExport) {
      final alias = template.alias.toUpperCase();
      final aiResult = resultsByAlias[alias];

      final questionScores = aiResult?.questionScores ??
          template.questionScores
              .map((score) => score ?? 0)
              .toList(growable: false);

      final total = aiResult?.finalScore ??
          template.total ??
          questionScores.fold<double>(0, (sum, score) => sum + score);

      final comment = aiResult?.feedback ?? template.comment;
      final marker = template.marker.isNotEmpty
          ? template.marker
          : (aiResult?.marker ?? '');

      sheet.appendRow([
        TextCellValue(alias),
        TextCellValue(marker),
        DoubleCellValue(questionScores[0]),
        DoubleCellValue(questionScores[1]),
        DoubleCellValue(questionScores[2]),
        DoubleCellValue(questionScores[3]),
        DoubleCellValue(total),
        TextCellValue(comment),
      ]);
    }

    final saveDir = saveDirectory ?? await _resolveSaveDirectory();
    final filePath = p.join(saveDir.path, outputFileName);
    final bytes = excel.save();

    if (bytes == null) {
      throw ExcelExportException('Cannot generate Excel file.');
    }

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    if (openAfterExport) {
      await OpenFile.open(file.path);
    }

    return file;
  }

  Future<Directory> _resolveSaveDirectory() async {
    final downloads = await getDownloadsDirectory();
    return downloads ?? await getApplicationDocumentsDirectory();
  }
}

class ExcelExportException implements Exception {
  ExcelExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
