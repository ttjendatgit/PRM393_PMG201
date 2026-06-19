import 'question_result.dart';

class GradingResult {
  final String id;
  final String submissionId;
  final String assessmentId;
  final String? gradingJobId;
  final String fileName;
  final String studentId;
  final String studentName;
  final double totalRawScore;
  final double finalScore;
  final Map<String, double> criteriaScores;
  final String feedback;
  final List<QuestionResult>? questionResults;
  final String reviewerNote;
  final String reviewStatus;
  final double? reviewedRawScore;
  final double? reviewedConvertedScore;
  final double? finalRawScore;
  final double? finalConvertedScore;
  final String teacherOverallComment;

  GradingResult({
    this.id = '',
    this.submissionId = '',
    this.assessmentId = '',
    this.gradingJobId,
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.totalRawScore,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
    this.questionResults,
    this.reviewerNote = '',
    this.reviewStatus = 'AI_GRADED',
    this.reviewedRawScore,
    this.reviewedConvertedScore,
    this.finalRawScore,
    this.finalConvertedScore,
    this.teacherOverallComment = '',
  });

  factory GradingResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>?;
    final questionResults = itemsJson?.map((item) {
      final i = item as Map<String, dynamic>;
      return QuestionResult(
        id: i['id']?.toString() ?? '',
        questionId: i['rubricItemId']?.toString() ?? i['questionNo']?.toString() ?? '',
        questionTitle: i['title']?.toString() ?? '',
        rawScore: (i['awardedRawScore'] as num?)?.toDouble() ?? 0,
        convertedScore: (i['awardedConvertedScore'] as num?)?.toDouble() ?? 0,
        maxRawScore: (i['maxRawScore'] as num?)?.toDouble() ?? 0,
        maxConvertedScore: (i['maxConvertedScore'] as num?)?.toDouble() ?? 0,
        comment: i['aiComment']?.toString() ?? '',
      );
    }).toList();

    final criteriaScores = <String, double>{};
    if (questionResults != null) {
      for (final qr in questionResults) {
        criteriaScores[qr.questionTitle] = qr.convertedScore;
      }
    }

    return GradingResult(
      id: json['id']?.toString() ?? '',
      submissionId: json['submissionId']?.toString() ?? '',
      assessmentId: json['assessmentId']?.toString() ?? '',
      gradingJobId: json['gradingJobId']?.toString(),
      fileName: json['originalFileName']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      studentName: json['studentName']?.toString() ?? '',
      totalRawScore: (json['totalRawScore'] as num?)?.toDouble() ?? 0,
      finalScore: (json['totalConvertedScore'] as num?)?.toDouble() ?? 0,
      criteriaScores: criteriaScores,
      feedback: json['aiOverallComment']?.toString() ?? '',
      questionResults: questionResults,
      reviewStatus: json['reviewStatus']?.toString() ?? 'AI_GRADED',
      reviewedRawScore: (json['reviewedRawScore'] as num?)?.toDouble(),
      reviewedConvertedScore: (json['reviewedConvertedScore'] as num?)?.toDouble(),
      finalRawScore: (json['finalRawScore'] as num?)?.toDouble(),
      finalConvertedScore: (json['finalConvertedScore'] as num?)?.toDouble(),
      teacherOverallComment: json['teacherOverallComment']?.toString() ?? '',
    );
  }
}
