import '../../../core/network/api_client.dart';
import '../../../models/assessment.dart';

/// CRUD operations for assessments.
///
/// Endpoints:
///   GET    /api/assessments
///   POST   /api/assessments
///   GET    /api/assessments/{id}
///   PUT    /api/assessments/{id}
///   DELETE /api/assessments/{id}
class AssessmentApiService {
  AssessmentApiService._();

  /// Fetches all assessments for the current teacher.
  ///
  /// Returns a list of [Assessment] models mapped from BE [AssessmentResponse].
  /// BE returns: [{ id, title, courseCode, description, totalRawScore, totalConvertedScore, status, createdAt, updatedAt }, ...]
  static Future<List<Assessment>> getAssessments() async {
    final data = await ApiClient.get('/api/assessments');
    final list = data as List<dynamic>;
    return list
        .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new assessment.
  ///
  /// [body] should contain: { title, courseCode?, description? }
  /// Returns the created [Assessment] with server-generated ID.
  static Future<Assessment> createAssessment(
    Map<String, dynamic> body,
  ) async {
    final data = await ApiClient.post('/api/assessments', body: body);
    return Assessment.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches a single assessment by [id].
  static Future<Assessment?> getAssessment(String id) async {
    final data = await ApiClient.get('/api/assessments/$id');
    return Assessment.fromJson(data as Map<String, dynamic>);
  }

  /// Updates an existing assessment.
  ///
  /// [body] may contain: { title?, courseCode?, description? }
  static Future<Assessment> updateAssessment(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await ApiClient.put('/api/assessments/$id', body: body);
    return Assessment.fromJson(data as Map<String, dynamic>);
  }

  /// Deletes an assessment by [id].
  static Future<void> deleteAssessment(String id) async {
    await ApiClient.delete('/api/assessments/$id');
  }
}