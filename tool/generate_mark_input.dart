import 'dart:io';

import 'package:excel/excel.dart';

/// Generates `test_files/Mark_Input.xlsx` for manual testing.
void main() {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet != null) {
    excel.rename(defaultSheet, 'Mark_Input');
  }

  final sheet = excel['Mark_Input'];

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
    DoubleCellValue(2),
    DoubleCellValue(2),
    DoubleCellValue(3),
    DoubleCellValue(3),
    DoubleCellValue(10),
    TextCellValue(''),
  ]);

  sheet.appendRow([
    TextCellValue('SE172001'),
    TextCellValue('Marker A'),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
  ]);

  sheet.appendRow([
    TextCellValue('SE172002'),
    TextCellValue('Marker B'),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
  ]);

  final bytes = excel.save();
  if (bytes == null) {
    throw StateError('Failed to generate Mark_Input.xlsx');
  }

  final output = File('test_files/Mark_Input.xlsx')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  stdout.writeln('Created ${output.path}');
}
