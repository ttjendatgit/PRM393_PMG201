import 'rubric.dart';

class Assessment {
  final String assessmentId;
  final String courseCode;
  final String assessmentTitle;
  final String examQuestionText;
  final String gradingGuideText;
  final double totalRawScore;
  final double totalConvertedScore;
  final List<QuestionRubric> questions;
  final DateTime createdAt;

  Assessment({
    required this.assessmentId,
    required this.courseCode,
    required this.assessmentTitle,
    required this.examQuestionText,
    required this.gradingGuideText,
    required this.totalRawScore,
    required this.totalConvertedScore,
    required this.questions,
    required this.createdAt,
  });
}
