class Submission {
  final String fileName;
  final String filePath;
  final String content;
  final int sizeInBytes;
  final String? extractionError;

  Submission({
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.sizeInBytes,
    this.extractionError,
  });

  bool get hasError => extractionError != null && extractionError!.isNotEmpty;
}
