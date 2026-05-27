class GradingResult {
  final String fileName;
  final String studentId;
  final String studentName;
  final double finalScore;
  final Map<String, double> criteriaScores;
  final String feedback;

  GradingResult({
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
  });
}