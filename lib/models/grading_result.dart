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
    // ── Items array: try every key the backend might use ─────────────────────
    final itemsJson = (json['items'] ??
            json['gradingItems'] ??
            json['rubricItems'] ??
            json['resultItems'] ??
            json['gradingResultItems'])
        as List<dynamic>?;

    final questionResults = itemsJson?.map((raw) {
      final i = raw as Map<String, dynamic>;

      // Item identity — try multiple possible id keys
      final id = i['id']?.toString() ??
          i['gradingResultItemId']?.toString() ??
          i['itemId']?.toString() ??
          i['resultItemId']?.toString() ??
          '';

      // Rubric / question identity
      final questionId = i['rubricItemId']?.toString() ??
          i['questionNo']?.toString() ??
          i['questionId']?.toString() ??
          '';

      // Max raw score — try every naming convention the backend might use
      final maxRaw = (i['maxRawScore'] as num?)?.toDouble() ??
          (i['maxRaw'] as num?)?.toDouble() ??
          (i['rubricMaxRawScore'] as num?)?.toDouble() ??
          (i['maxRawPoints'] as num?)?.toDouble() ??
          0.0;

      // Max converted score — same multi-key approach
      final maxConv = (i['maxConvertedScore'] as num?)?.toDouble() ??
          (i['maxConverted'] as num?)?.toDouble() ??
          (i['rubricMaxConvertedScore'] as num?)?.toDouble() ??
          (i['maxConvertedPoints'] as num?)?.toDouble() ??
          0.0;

      // Awarded raw score
      final rawScore = (i['awardedRawScore'] as num?)?.toDouble() ??
          (i['rawScore'] as num?)?.toDouble() ??
          (i['reviewedRawScore'] as num?)?.toDouble() ??
          0.0;

      // Awarded converted score
      final convScore = (i['awardedConvertedScore'] as num?)?.toDouble() ??
          (i['convertedScore'] as num?)?.toDouble() ??
          0.0;

      // AI comment / per-item comment
      final comment = i['aiComment']?.toString() ??
          i['comment']?.toString() ??
          i['feedback']?.toString() ??
          '';

      // Title
      final title =
          i['title']?.toString() ?? i['questionTitle']?.toString() ?? '';

      return QuestionResult(
        id: id,
        questionId: questionId,
        questionTitle: title,
        rawScore: rawScore,
        convertedScore: convScore,
        maxRawScore: maxRaw,
        maxConvertedScore: maxConv,
        comment: comment,
      );
    }).toList();

    // Build criteriaScores map for legacy standalone path
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
      reviewedConvertedScore:
          (json['reviewedConvertedScore'] as num?)?.toDouble(),
      finalRawScore: (json['finalRawScore'] as num?)?.toDouble(),
      finalConvertedScore: (json['finalConvertedScore'] as num?)?.toDouble(),
      teacherOverallComment:
          json['teacherOverallComment']?.toString() ?? '',
    );
  }
}
