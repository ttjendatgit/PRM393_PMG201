class MarkInputRow {
  final String alias;
  final String marker;
  final List<double?> questionScores;
  final double? total;
  final String comment;

  const MarkInputRow({
    required this.alias,
    required this.marker,
    required this.questionScores,
    this.total,
    this.comment = '',
  });

  static const int questionCount = 4;
  static const List<double> defaultMaxScores = [2, 2, 3, 3];
  static const double defaultMaxTotal = 10;

  MarkInputRow copyWith({
    String? alias,
    String? marker,
    List<double?>? questionScores,
    double? total,
    String? comment,
  }) {
    return MarkInputRow(
      alias: alias ?? this.alias,
      marker: marker ?? this.marker,
      questionScores: questionScores ?? this.questionScores,
      total: total ?? this.total,
      comment: comment ?? this.comment,
    );
  }
}

class MarkInputImportResult {
  final List<MarkInputRow> rows;
  final List<double> maxQuestionScores;
  final double maxTotal;
  final String sourcePath;

  const MarkInputImportResult({
    required this.rows,
    required this.maxQuestionScores,
    required this.maxTotal,
    required this.sourcePath,
  });
}
