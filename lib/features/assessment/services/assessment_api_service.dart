import '../../../core/network/api_client.dart';

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

  static Future<List<dynamic>> getAssessments() async {
    // TODO: implement — parse response into Assessment models
    final data = await ApiClient.get('/api/assessments');
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createAssessment(
    Map<String, dynamic> body,
  ) async {
    // TODO: implement — map body to CreateAssessmentRequest model
    final data = await ApiClient.post('/api/assessments', body: body);
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAssessment(String id) async {
    // TODO: implement — return typed Assessment model
    final data = await ApiClient.get('/api/assessments/$id');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateAssessment(
    String id,
    Map<String, dynamic> body,
  ) async {
    // TODO: implement
    final data = await ApiClient.put('/api/assessments/$id', body: body);
    return data as Map<String, dynamic>;
  }

  static Future<void> deleteAssessment(String id) async {
    // TODO: implement
    await ApiClient.delete('/api/assessments/$id');
  }
}
