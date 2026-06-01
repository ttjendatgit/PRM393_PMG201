import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:path/path.dart' as p;

import '../../models/submission.dart';

class SubmissionFileService {
  Future<List<Submission>> pickAndImportTxtFiles() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: ['txt'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return [];
    }

    return importTxtFilesFromPaths(
      result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList(),
    );
  }

  Future<List<Submission>> importTxtFilesFromPaths(List<String> paths) async {
    final submissions = <Submission>[];

    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final fileName = p.basename(path);
      final content = await file.readAsString();
      final sizeInBytes = await file.length();

      submissions.add(
        Submission(
          alias: Submission.extractAlias(fileName),
          fileName: fileName,
          filePath: path,
          content: content,
          sizeInBytes: sizeInBytes,
        ),
      );
    }

    return submissions;
  }
}
