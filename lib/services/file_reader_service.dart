import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;

import '../models/submission.dart';

class FileReaderService {
  Future<List<Submission>> pickTxtFiles() async {
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: true,
      type: fp.FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result == null) {
      return [];
    }

    final submissions = <Submission>[];

    for (final file in result.files) {
      final path = file.path;

      if (path == null) continue;

      final content = await File(path).readAsString();

      submissions.add(
        Submission(
          fileName: file.name,
          filePath: path,
          content: content,
          sizeInBytes: file.size,
        ),
      );
    }

    return submissions;
  }
}