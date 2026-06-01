class GradingResult {
  final String alias;
  final String marker;
  final String fileName;
  final String studentId;
  final String studentName;
  final List<double> questionScores;
  final double finalScore;
  final Map<String, double> criteriaScores;
  final String feedback;

  GradingResult({
    required this.alias,
    required this.marker,
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.questionScores,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
  });

  double get total => finalScore;

  String get comment => feedback;

  static const List<String> questionLabels = [
    'Question 1',
    'Question 2',
    'Question 3',
    'Question 4',
  ];
}
