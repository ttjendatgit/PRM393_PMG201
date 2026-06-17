import '../../../core/network/api_client.dart';

/// Grading job management and result retrieval.
///
/// Endpoints:
///   POST /api/assessments/{id}/grading-jobs
///   GET  /api/assessments/{id}/grading-status
///   GET  /api/assessments/{id}/grading-jobs/{jobId}
///   POST /api/submissions/{submissionId}/grade
///   GET  /api/submissions/{submissionId}/grading-result
class GradingApiService {
  GradingApiService._();

  static Future<Map<String, dynamic>> createGradingJob(
    String assessmentId, {
    Map<String, dynamic>? options,
  }) async {
    // TODO: implement — triggers backend AI grading for all submissions
    final data = await ApiClient.post(
      '/api/assessments/$assessmentId/grading-jobs',
      body: options,
    );
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getGradingStatus(
    String assessmentId,
  ) async {
    // TODO: implement — poll this to check progress
    final data = await ApiClient.get(
      '/api/assessments/$assessmentId/grading-status',
    );
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getGradingJob(
    String assessmentId,
    String jobId,
  ) async {
    // TODO: implement
    final data = await ApiClient.get(
      '/api/assessments/$assessmentId/grading-jobs/$jobId',
    );
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> gradeSubmission(
    String submissionId,
  ) async {
    // TODO: implement — grade a single submission
    final data = await ApiClient.post(
      '/api/submissions/$submissionId/grade',
    );
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getGradingResult(
    String submissionId,
  ) async {
    // TODO: implement — returns scored rubric + feedback
    final data = await ApiClient.get(
      '/api/submissions/$submissionId/grading-result',
    );
    return data as Map<String, dynamic>;
  }
}
