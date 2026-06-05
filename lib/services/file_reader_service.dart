import 'package:file_picker/file_picker.dart' as fp;

import '../models/submission.dart';
import 'file/document_text_extractor_service.dart';

class FileReaderService {
  Future<List<Submission>> pickSubmissionFiles() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: DocumentTextExtractorService.supportedExtensions,
    );

    if (result == null) return [];

    final submissions = <Submission>[];

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;

      final extracted = await DocumentTextExtractorService.extractTextFromFile(path);

      String? extractionError;
      if (!extracted.success) {
        extractionError = extracted.errorMessage;
      } else if (extracted.isEmpty) {
        final ext = file.name.split('.').last.toLowerCase();
        extractionError = ext == 'pdf'
            ? 'This PDF may be scanned or image-based. Please convert it to text or upload a text-based file.'
            : (extracted.warningMessage ?? 'No text could be extracted from this file.');
      }

      submissions.add(
        Submission(
          fileName: file.name,
          filePath: path,
          content: extracted.extractedText,
          sizeInBytes: file.size,
          extractionError: extractionError,
        ),
      );
    }

    return submissions;
  }
}
