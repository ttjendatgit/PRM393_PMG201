import '../../../core/network/api_client.dart';
import '../../../models/rubric.dart';

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

  /// Uploads the question file for an assessment.
  ///
  /// Returns the [AssessmentFileResponse] as a raw Map.
  /// BE expects: multipart/form-data with field name "file".
  static Future<Map<String, dynamic>> uploadQuestionFile(
    String assessmentId,
    String filePath,
  ) async {
    final data = await ApiClient.uploadFile(
      '/api/assessments/$assessmentId/question-file',
      filePath,
    );
    return data as Map<String, dynamic>;
  }

  /// Uploads the grading guide file for an assessment.
  ///
  /// Returns the [AssessmentFileResponse] as a raw Map.
  static Future<Map<String, dynamic>> uploadGuideFile(
    String assessmentId,
    String filePath,
  ) async {
    final data = await ApiClient.uploadFile(
      '/api/assessments/$assessmentId/guide-file',
      filePath,
    );
    return data as Map<String, dynamic>;
  }

  /// Fetches the uploaded question file metadata for an assessment.
  ///
  /// Returns an [AssessmentFileResponse] Map, or null if not found.
  static Future<Map<String, dynamic>?> getQuestion(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/question');
    return data as Map<String, dynamic>?;
  }

  /// Fetches the uploaded guide file metadata for an assessment.
  ///
  /// Returns an [AssessmentFileResponse] Map, or null if not found.
  static Future<Map<String, dynamic>?> getGuide(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/guide');
    return data as Map<String, dynamic>?;
  }

  /// Triggers backend to parse the uploaded guide file and extract rubric items.
  ///
  /// Returns a list of [RubricItemResponse] (each as Map).
  static Future<List<dynamic>> parseRubric(String assessmentId) async {
    final data =
        await ApiClient.post('/api/assessments/$assessmentId/parse-rubric');
    return data as List<dynamic>;
  }

  /// Fetches the structured rubric (list of rubric items) for an assessment.
  ///
  /// Returns a list of [QuestionRubric] models mapped from [RubricItemResponse].
  static Future<List<QuestionRubric>> getRubric(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/rubric');
    final list = data as List<dynamic>;
    return list
        .map((e) => QuestionRubric.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Updates the rubric items for an assessment.
  ///
  /// [body] should match [UpdateRubricRequest]: { items: [{ id?, questionNo, title, description?, maxRawScore, maxConvertedScore }] }
  /// Returns the updated list of rubric items.
  static Future<List<dynamic>> updateRubric(
    String assessmentId,
    Map<String, dynamic> body,
  ) async {
    final data =
        await ApiClient.put('/api/assessments/$assessmentId/rubric', body: body);
    return data as List<dynamic>;
  }
}