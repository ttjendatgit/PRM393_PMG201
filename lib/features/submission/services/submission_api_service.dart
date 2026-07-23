import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../models/submission.dart';

class SubmissionApiService {
  SubmissionApiService._();

  /// POST /api/assessments/{assessmentId}/submissions/upload
  /// Upload one or more student submission files for an assessment.
  /// Accepts [PlatformFile] (not raw paths) so it works on both desktop
  /// (file path) and Web (in-memory bytes, no filesystem access).
  /// Returns { uploaded, failed, submissions: [...], errors: [...] }
  static Future<UploadSubmissionsResult> uploadSubmissions(
    String assessmentId,
    List<PlatformFile> files,
  ) async {
    final data = await ApiClient.uploadPlatformFiles(
      '/api/assessments/$assessmentId/submissions/upload',
      files,
      fieldName: 'files',
    );
    final json = data as Map<String, dynamic>;

    final successList = (json['submissions'] as List<dynamic>?)
        ?.map((s) => Submission.fromJson(s as Map<String, dynamic>))
        .toList() ?? [];

    final errorList = (json['errors'] as List<dynamic>?)
        ?.map((e) {
            final err = e as Map<String, dynamic>;
            return FileUploadError(
              fileName: err['fileName']?.toString() ?? '',
              error: err['error']?.toString() ?? '',
            );
          })
        .toList() ?? [];

    return UploadSubmissionsResult(
      uploaded: json['uploaded'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      submissions: successList,
      errors: errorList,
    );
  }

  /// GET /api/assessments/{assessmentId}/submissions
  static Future<List<Submission>> getSubmissions(String assessmentId) async {
    final data = await ApiClient.get('/api/assessments/$assessmentId/submissions');
    final list = data as List<dynamic>;
    return list.map((s) => Submission.fromJson(s as Map<String, dynamic>)).toList();
  }

  /// GET /api/submissions/{submissionId}
  static Future<Submission> getSubmission(String submissionId) async {
    final data = await ApiClient.get('/api/submissions/$submissionId');
    return Submission.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /api/submissions/{submissionId}
  static Future<void> deleteSubmission(String submissionId) async {
    await ApiClient.delete('/api/submissions/$submissionId');
  }
}

class UploadSubmissionsResult {
  final int uploaded;
  final int failed;
  final List<Submission> submissions;
  final List<FileUploadError> errors;

  const UploadSubmissionsResult({
    required this.uploaded,
    required this.failed,
    required this.submissions,
    required this.errors,
  });
}

class FileUploadError {
  final String fileName;
  final String error;

  const FileUploadError({required this.fileName, required this.error});
}
