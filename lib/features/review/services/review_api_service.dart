import '../../../core/network/api_client.dart';

/// Reviewer workflows — adjust scores and finalize results.
///
/// Endpoints:
///   PUT  /api/grading-results/{gradingResultId}/review
///   POST /api/grading-results/{gradingResultId}/finalize
///   GET  /api/assessments/{assessmentId}/review-results
class ReviewApiService {
  ReviewApiService._();

  static Future<Map<String, dynamic>> submitReview(
    String gradingResultId,
    Map<String, dynamic> reviewBody,
  ) async {
    // TODO: implement — body should include adjusted scores and reviewer notes
    final data = await ApiClient.put(
      '/api/grading-results/$gradingResultId/review',
      body: reviewBody,
    );
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> finalizeResult(
    String gradingResultId,
  ) async {
    // TODO: implement — locks the result as finalized
    final data = await ApiClient.post(
      '/api/grading-results/$gradingResultId/finalize',
    );
    return data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getReviewResults(String assessmentId) async {
    // TODO: implement — returns all reviewed grading results for an assessment
    final data = await ApiClient.get(
      '/api/assessments/$assessmentId/review-results',
    );
    return data as List<dynamic>;
  }
}
