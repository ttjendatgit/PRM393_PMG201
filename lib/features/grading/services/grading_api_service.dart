import '../../../core/network/api_client.dart';
import '../../../models/grading_result.dart';

class GradingApiService {
  GradingApiService._();

  /// POST /api/assessments/{assessmentId}/grading-jobs
  /// Returns { message, job: {...} }
  static Future<CreateGradingJobResult> createGradingJob(String assessmentId) async {
    final data = await ApiClient.post('/api/assessments/$assessmentId/grading-jobs');
    final json = data as Map<String, dynamic>;
    return CreateGradingJobResult(
      message: json['message']?.toString() ?? '',
      jobId: (json['job'] as Map<String, dynamic>?)?['id']?.toString() ?? '',
      jobStatus: (json['job'] as Map<String, dynamic>?)?['status']?.toString() ?? '',
    );
  }

  /// GET /api/assessments/{assessmentId}/grading-status
  /// Returns { assessmentId, totalSubmissions, uploaded, grading, graded, error, latestJobStatus, latestJobId }
  static Future<GradingStatusResult> getGradingStatus(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/grading-status');
    final json = data as Map<String, dynamic>;
    return GradingStatusResult(
      assessmentId: json['assessmentId']?.toString() ?? assessmentId,
      totalSubmissions: json['totalSubmissions'] as int? ?? 0,
      uploaded: json['uploaded'] as int? ?? 0,
      grading: json['grading'] as int? ?? 0,
      graded: json['graded'] as int? ?? 0,
      error: json['error'] as int? ?? 0,
      latestJobStatus: json['latestJobStatus']?.toString(),
      latestJobId: json['latestJobId']?.toString(),
    );
  }

  /// GET /api/assessments/{assessmentId}/grading-jobs/{jobId}
  static Future<Map<String, dynamic>> getGradingJob(String assessmentId, String jobId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/grading-jobs/$jobId');
    return data as Map<String, dynamic>;
  }

  /// POST /api/submissions/{submissionId}/grade
  /// Returns the grading result.
  static Future<GradingResult> gradeSubmission(String submissionId) async {
    final data = await ApiClient.post('/api/submissions/$submissionId/grade');
    return GradingResult.fromJson(data as Map<String, dynamic>);
  }

  /// GET /api/submissions/{submissionId}/grading-result
  static Future<GradingResult?> getGradingResult(String submissionId) async {
    final data = await ApiClient.get('/api/submissions/$submissionId/grading-result');
    if (data == null) return null;
    return GradingResult.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/submissions/{submissionId}/manual-result
  ///
  /// Creates a grading result manually (no AI required).
  /// [request] shape:
  /// ```
  /// {
  ///   "teacherOverallComment": "optional",
  ///   "items": [
  ///     { "rubricItemId": "<guid>", "questionNo": 1,
  ///       "reviewedRawScore": 10, "teacherComment": "Good" }
  ///   ]
  /// }
  /// ```
  /// Returns a [GradingResult] (same shape as GET grading-result).
  static Future<GradingResult> createManualResult(
    String submissionId,
    Map<String, dynamic> request,
  ) async {
    final data = await ApiClient.post(
      '/api/submissions/$submissionId/manual-result',
      body: request,
    );
    return GradingResult.fromJson(data as Map<String, dynamic>);
  }
}

class CreateGradingJobResult {
  final String message;
  final String jobId;
  final String jobStatus;

  const CreateGradingJobResult({
    required this.message,
    required this.jobId,
    required this.jobStatus,
  });
}

class GradingStatusResult {
  final String assessmentId;
  final int totalSubmissions;
  final int uploaded;
  final int grading;
  final int graded;
  final int error;
  final String? latestJobStatus;
  final String? latestJobId;

  const GradingStatusResult({
    required this.assessmentId,
    required this.totalSubmissions,
    required this.uploaded,
    required this.grading,
    required this.graded,
    required this.error,
    this.latestJobStatus,
    this.latestJobId,
  });
}
