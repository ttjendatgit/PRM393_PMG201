import '../../../core/network/api_client.dart';

/// File upload and rubric management for an assessment.
///
/// Endpoints:
///   POST /api/assessments/{id}/question-file
///   POST /api/assessments/{id}/guide-file
///   GET  /api/assessments/{id}/question
///   GET  /api/assessments/{id}/guide
///   POST /api/assessments/{id}/parse-rubric
///   GET  /api/assessments/{id}/rubric
///   PUT  /api/assessments/{id}/rubric
class RubricApiService {
  RubricApiService._();

  static Future<dynamic> uploadQuestionFile(
    String assessmentId,
    String filePath,
  ) async {
    // TODO: implement
    return ApiClient.uploadFile(
      '/api/assessments/$assessmentId/question-file',
      filePath,
    );
  }

  static Future<dynamic> uploadGuideFile(
    String assessmentId,
    String filePath,
  ) async {
    // TODO: implement
    return ApiClient.uploadFile(
      '/api/assessments/$assessmentId/guide-file',
      filePath,
    );
  }

  static Future<dynamic> getQuestion(String assessmentId) async {
    // TODO: implement
    return ApiClient.get('/api/assessments/$assessmentId/question');
  }

  static Future<dynamic> getGuide(String assessmentId) async {
    // TODO: implement
    return ApiClient.get('/api/assessments/$assessmentId/guide');
  }

  static Future<dynamic> parseRubric(String assessmentId) async {
    // TODO: implement — triggers backend to extract rubric from uploaded guide file
    return ApiClient.post('/api/assessments/$assessmentId/parse-rubric');
  }

  static Future<dynamic> getRubric(String assessmentId) async {
    // TODO: implement — returns structured rubric (questions + sub-criteria)
    return ApiClient.get('/api/assessments/$assessmentId/rubric');
  }

  static Future<dynamic> updateRubric(
    String assessmentId,
    Map<String, dynamic> body,
  ) async {
    // TODO: implement
    return ApiClient.put('/api/assessments/$assessmentId/rubric', body: body);
  }
}
