import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as fp;

import '../../models/mark_input.dart';

class MarkInputExcelService {
  static const String sheetName = 'Mark_Input';

  static const List<String> headerAliases = [
    'alias',
    'marker',
    'question 1',
    'question 2',
    'question 3',
    'question 4',
    'total',
    'comment',
  ];

  Future<MarkInputImportResult?> pickAndImportMarkInput() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;

    if (file.bytes != null) {
      return importFromBytes(
        file.bytes!,
        sourcePath: file.path ?? file.name,
      );
    }

    if (file.path == null) {
      throw MarkInputParseException('Cannot read selected Excel file.');
    }

    return importFromFile(File(file.path!));
  }

  Future<MarkInputImportResult> importFromFile(File file) async {
    final bytes = await file.readAsBytes();
    return importFromBytes(bytes, sourcePath: file.path);
  }

  MarkInputImportResult importFromBytes(
    List<int> bytes, {
    required String sourcePath,
  }) {
    final excel = Excel.decodeBytes(bytes);
    return parseWorkbook(excel, sourcePath: sourcePath);
  }

  MarkInputImportResult parseWorkbook(
    Excel excel, {
    required String sourcePath,
  }) {
    final sheet = excel.tables[sheetName] ?? excel.tables.values.firstOrNull;

    if (sheet == null || sheet.rows.isEmpty) {
      throw MarkInputParseException('Sheet "$sheetName" not found or empty.');
    }

    final headerIndex = _findHeaderRowIndex(sheet);
    if (headerIndex == null) {
      throw MarkInputParseException(
        'Header row with Alias / Marker / Question columns not found.',
      );
    }

    final columnMap = _mapColumns(sheet.rows[headerIndex]);
    _validateRequiredColumns(columnMap);

    final maxScoreRowIndex = _findMaxScoreRowIndex(
      sheet,
      startIndex: headerIndex + 1,
      columnMap: columnMap,
    );

    final maxQuestionScores = maxScoreRowIndex != null
        ? _readQuestionScores(sheet.rows[maxScoreRowIndex], columnMap)
        : List<double>.from(MarkInputRow.defaultMaxScores);

    final maxTotal = maxScoreRowIndex != null
        ? _readDouble(
              sheet.rows[maxScoreRowIndex][columnMap['total']!],
            ) ??
            MarkInputRow.defaultMaxTotal
        : MarkInputRow.defaultMaxTotal;

    final dataStartIndex = maxScoreRowIndex != null
        ? maxScoreRowIndex + 1
        : headerIndex + 1;

    final rows = <MarkInputRow>[];

    for (var i = dataStartIndex; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      final alias = _readString(row[columnMap['alias']!]).trim();
      if (alias.isEmpty || _isMaxScoreAlias(alias)) continue;

      rows.add(
        MarkInputRow(
          alias: alias.toUpperCase(),
          marker: _readString(row[columnMap['marker']!]).trim(),
          questionScores: _readNullableQuestionScores(row, columnMap),
          total: _readDouble(row[columnMap['total']!]),
          comment: _readString(row[columnMap['comment']!]).trim(),
        ),
      );
    }

    if (rows.isEmpty) {
      throw MarkInputParseException('No student rows found in "$sheetName".');
    }

    return MarkInputImportResult(
      rows: rows,
      maxQuestionScores: maxQuestionScores,
      maxTotal: maxTotal,
      sourcePath: sourcePath,
    );
  }

  int? _findHeaderRowIndex(Sheet sheet) {
    for (var i = 0; i < sheet.rows.length; i++) {
      final labels = sheet.rows[i]
          .map((cell) => _readString(cell).trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toList();

      if (labels.contains('alias') &&
          labels.contains('marker') &&
          labels.any((label) => label.startsWith('question'))) {
        return i;
      }
    }

    return null;
  }

  Map<String, int> _mapColumns(List<Data?> headerRow) {
    final columnMap = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final label = _readString(headerRow[i]).trim().toLowerCase();
      if (label.isEmpty) continue;

      if (label == 'alias') {
        columnMap['alias'] = i;
      } else if (label == 'marker') {
        columnMap['marker'] = i;
      } else if (label.startsWith('question')) {
        final number = RegExp(r'\d+').firstMatch(label)?.group(0);
        if (number != null) {
          columnMap['question $number'] = i;
        }
      } else if (label == 'total') {
        columnMap['total'] = i;
      } else if (label == 'comment') {
        columnMap['comment'] = i;
      }
    }

    return columnMap;
  }

  void _validateRequiredColumns(Map<String, int> columnMap) {
    const requiredKeys = [
      'alias',
      'marker',
      'question 1',
      'question 2',
      'question 3',
      'question 4',
      'total',
      'comment',
    ];

    for (final key in requiredKeys) {
      if (!columnMap.containsKey(key)) {
        throw MarkInputParseException('Missing required column: $key');
      }
    }
  }

  int? _findMaxScoreRowIndex(
    Sheet sheet, {
    required int startIndex,
    required Map<String, int> columnMap,
  }) {
    for (var i = startIndex; i < sheet.rows.length; i++) {
      final scores = _readQuestionScores(sheet.rows[i], columnMap);
      if (_matchesDefaultMaxScores(scores)) {
        return i;
      }
    }

    return null;
  }

  bool _isMaxScoreAlias(String alias) {
    return alias == 'max' || alias == 'maximum' || alias == 'max score';
  }

  bool _matchesDefaultMaxScores(List<double> scores) {
    if (scores.length != MarkInputRow.defaultMaxScores.length) {
      return false;
    }

    for (var i = 0; i < scores.length; i++) {
      if (scores[i] != MarkInputRow.defaultMaxScores[i]) {
        return false;
      }
    }

    return true;
  }

  List<double> _readQuestionScores(
    List<Data?> row,
    Map<String, int> columnMap,
  ) {
    return [
      _readDouble(row[columnMap['question 1']!]) ?? 0,
      _readDouble(row[columnMap['question 2']!]) ?? 0,
      _readDouble(row[columnMap['question 3']!]) ?? 0,
      _readDouble(row[columnMap['question 4']!]) ?? 0,
    ];
  }

  List<double?> _readNullableQuestionScores(
    List<Data?> row,
    Map<String, int> columnMap,
  ) {
    return [
      _readDouble(row[columnMap['question 1']!]),
      _readDouble(row[columnMap['question 2']!]),
      _readDouble(row[columnMap['question 3']!]),
      _readDouble(row[columnMap['question 4']!]),
    ];
  }

  String _readString(Data? cell) {
    if (cell == null || cell.value == null) return '';

    final value = cell.value!;
    return switch (value) {
      TextCellValue(:final value) => _textValue(value),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => _formatNumber(value),
      _ => value.toString(),
    };
  }

  String _textValue(dynamic value) {
    if (value is String) return value;
    if (value is TextSpan) return value.text ?? '';
    return value.toString();
  }

  double? _readDouble(Data? cell) {
    if (cell == null || cell.value == null) return null;

    final value = cell.value!;
    return switch (value) {
      DoubleCellValue(:final value) => value,
      IntCellValue(:final value) => value.toDouble(),
      TextCellValue(:final value) => double.tryParse(_textValue(value).trim()),
      _ => double.tryParse(value.toString()),
    };
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class MarkInputParseException implements Exception {
  MarkInputParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
