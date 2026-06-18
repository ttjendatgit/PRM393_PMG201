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
  final String status;

  Assessment({
    required this.assessmentId,
    required this.courseCode,
    required this.assessmentTitle,
    this.examQuestionText = '',
    this.gradingGuideText = '',
    this.totalRawScore = 0,
    this.totalConvertedScore = 10,
    this.questions = const [],
    required this.createdAt,
    this.status = '',
  });

  /// Creates an [Assessment] from a BE [AssessmentResponse] JSON map.
  /// For list responses, the JSON contains: id, title, courseCode, description,
  /// totalRawScore, totalConvertedScore, status, createdAt, updatedAt.
  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      assessmentId: (json['id'] ?? '').toString(),
      courseCode: json['courseCode'] as String? ?? '',
      assessmentTitle: json['title'] as String? ?? '',
      examQuestionText: json['description'] as String? ?? '',
      totalRawScore: (json['totalRawScore'] as num?)?.toDouble() ?? 0,
      totalConvertedScore:
          (json['totalConvertedScore'] as num?)?.toDouble() ?? 10,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? '',
    );
  }

  /// Converts this [Assessment] into a JSON map suitable for [CreateAssessmentRequest].
  Map<String, dynamic> toCreateRequest() {
    return {
      'title': assessmentTitle,
      'courseCode': courseCode,
      'description': examQuestionText,
    };
  }
}