import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

/// Download grading results as an Excel file from the backend.
///
/// Endpoint:
///   GET /api/assessments/{assessmentId}/export/excel
class ExportApiService {
  ExportApiService._();

  /// Downloads the Excel export for an assessment and saves it to the
  /// Downloads (or Documents) directory.  Returns the saved file path.
  static Future<String> downloadExcel(String assessmentId) async {
    // TODO: implement — integrate with open_filex to open after download
    final bytes = await ApiClient.downloadFile(
      '/api/assessments/$assessmentId/export/excel',
    );

    final downloads = await getDownloadsDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final saveDir = downloads ?? documents;

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'export_${assessmentId}_$stamp.xlsx';
    final filePath = p.join(saveDir.path, fileName);

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    return filePath;
  }
}
