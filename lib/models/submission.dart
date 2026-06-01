class Submission {
  final String alias;
  final String fileName;
  final String filePath;
  final String content;
  final int sizeInBytes;

  Submission({
    required this.alias,
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.sizeInBytes,
  });

  /// Derives alias from file name, e.g. `SE172001_NguyenVanA.txt` → `SE172001`.
  static String extractAlias(String fileName) {
    final clean = fileName.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    final parts = clean.split('_');

    if (parts.isNotEmpty && parts.first.toUpperCase().startsWith('SE')) {
      return parts.first.toUpperCase();
    }

    return clean;
  }
}
