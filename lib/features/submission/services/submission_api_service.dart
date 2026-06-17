import '../../../core/network/api_client.dart';

/// Submission upload and retrieval.
///
/// Endpoints:
///   POST   /api/assessments/{id}/submissions/upload
///   GET    /api/assessments/{id}/submissions
///   GET    /api/submissions/{submissionId}
///   DELETE /api/submissions/{submissionId}
class SubmissionApiService {
  SubmissionApiService._();

  /// Upload one or more student submission files for an assessment.
  static Future<dynamic> uploadSubmissions(
    String assessmentId,
    List<String> filePaths,
  ) async {
    // TODO: implement — map response to Submission models
    return ApiClient.uploadFiles(
      '/api/assessments/$assessmentId/submissions/upload',
      filePaths,
      fieldName: 'files',
    );
  }

  static Future<List<dynamic>> getSubmissions(String assessmentId) async {
    // TODO: implement — return typed List<Submission>
    final data = await ApiClient.get(
      '/api/assessments/$assessmentId/submissions',
    );
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getSubmission(
    String submissionId,
  ) async {
    // TODO: implement
    final data = await ApiClient.get('/api/submissions/$submissionId');
    return data as Map<String, dynamic>;
  }

  static Future<void> deleteSubmission(String submissionId) async {
    // TODO: implement
    await ApiClient.delete('/api/submissions/$submissionId');
  }
}
