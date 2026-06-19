class SubScoreResult {
  final String criterionCode;
  final String criterionTitle;
  final double maxScore;
  final double score;
  final String reason;

  const SubScoreResult({
    required this.criterionCode,
    required this.criterionTitle,
    required this.maxScore,
    required this.score,
    required this.reason,
  });
}

class QuestionResult {
  final String id;
  final String questionId;
  final String questionTitle;
  final double rawScore;
  final double convertedScore;
  final double maxRawScore;
  final double maxConvertedScore;
  final String comment;
  final List<SubScoreResult> subscores;

  QuestionResult({
    this.id = '',
    required this.questionId,
    required this.questionTitle,
    required this.rawScore,
    required this.convertedScore,
    required this.maxRawScore,
    required this.maxConvertedScore,
    required this.comment,
    this.subscores = const [],
  });
}
