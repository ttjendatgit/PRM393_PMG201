import 'question_result.dart';

class GradingResult {
  final String fileName;
  final String studentId;
  final String studentName;
  final double totalRawScore;
  final double finalScore; // converted score (e.g. /10)
  final Map<String, double> criteriaScores;
  final String feedback;
  final List<QuestionResult>? questionResults;
  final String reviewerNote;

  GradingResult({
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.totalRawScore,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
    this.questionResults,
    this.reviewerNote = '',
  });
}
