import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

class ExportApiService {
  ExportApiService._();

  /// GET /api/assessments/{assessmentId}/export/excel
  /// Downloads the Excel export and saves it to the Downloads directory.
  /// Returns the saved file path.
  static Future<String> downloadExcel(String assessmentId) async {
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
    final fileName = 'PMG201c_Results_${assessmentId}_$stamp.xlsx';
    final filePath = p.join(saveDir.path, fileName);

    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    return filePath;
  }

  /// Downloads and opens the Excel file with the system default app.
  static Future<String> downloadAndOpenExcel(String assessmentId) async {
    final filePath = await downloadExcel(assessmentId);
    await OpenFilex.open(filePath);
    return filePath;
  }
}
