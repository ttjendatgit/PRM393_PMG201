import '../../../core/network/api_client.dart';
import '../../../models/grading_result.dart';

class ReviewApiService {
  ReviewApiService._();

  /// PUT /api/grading-results/{gradingResultId}/review
  /// Body: { teacherOverallComment, items: [{ gradingResultItemId, reviewedRawScore, teacherComment }] }
  static Future<GradingResult> submitReview(
    String gradingResultId,
    Map<String, dynamic> reviewBody,
  ) async {
    final data = await ApiClient.put(
      '/api/grading-results/$gradingResultId/review',
      body: reviewBody,
    );
    return GradingResult.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/grading-results/{gradingResultId}/finalize
  static Future<FinalizeResult> finalizeResult(String gradingResultId) async {
    final data = await ApiClient.post('/api/grading-results/$gradingResultId/finalize');
    final json = data as Map<String, dynamic>;
    return FinalizeResult(
      message: json['message']?.toString() ?? '',
      result: GradingResult.fromJson(json['result'] as Map<String, dynamic>),
    );
  }

  /// GET /api/assessments/{assessmentId}/review-results
  static Future<List<ReviewResultSummary>> getReviewResults(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/review-results');
    final list = data as List<dynamic>;
    return list.map((r) => ReviewResultSummary.fromJson(r as Map<String, dynamic>)).toList();
  }
}

class FinalizeResult {
  final String message;
  final GradingResult result;

  const FinalizeResult({required this.message, required this.result});
}

class ReviewResultSummary {
  final String gradingResultId;
  final String submissionId;
  final String? studentId;
  final String? studentName;
  final String? originalFileName;
  final double aiTotalRawScore;
  final double aiTotalConvertedScore;
  final double? reviewedRawScore;
  final double? reviewedConvertedScore;
  final double? finalRawScore;
  final double? finalConvertedScore;
  final String reviewStatus;
  final String? teacherOverallComment;
  final String? updatedAt;

  const ReviewResultSummary({
    required this.gradingResultId,
    required this.submissionId,
    this.studentId,
    this.studentName,
    this.originalFileName,
    required this.aiTotalRawScore,
    required this.aiTotalConvertedScore,
    this.reviewedRawScore,
    this.reviewedConvertedScore,
    this.finalRawScore,
    this.finalConvertedScore,
    required this.reviewStatus,
    this.teacherOverallComment,
    this.updatedAt,
  });

  factory ReviewResultSummary.fromJson(Map<String, dynamic> json) {
    return ReviewResultSummary(
      gradingResultId: json['gradingResultId']?.toString() ?? '',
      submissionId: json['submissionId']?.toString() ?? '',
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString(),
      originalFileName: json['originalFileName']?.toString(),
      aiTotalRawScore: (json['aiTotalRawScore'] as num?)?.toDouble() ?? 0,
      aiTotalConvertedScore: (json['aiTotalConvertedScore'] as num?)?.toDouble() ?? 0,
      reviewedRawScore: (json['reviewedRawScore'] as num?)?.toDouble(),
      reviewedConvertedScore: (json['reviewedConvertedScore'] as num?)?.toDouble(),
      finalRawScore: (json['finalRawScore'] as num?)?.toDouble(),
      finalConvertedScore: (json['finalConvertedScore'] as num?)?.toDouble(),
      reviewStatus: json['reviewStatus']?.toString() ?? 'AI_GRADED',
      teacherOverallComment: json['teacherOverallComment']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
