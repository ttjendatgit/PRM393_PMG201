class Submission {
  final String id;
  final String assessmentId;
  final String fileName;
  final String filePath;
  final String content;
  final int sizeInBytes;
  final String? extractionError;
  final String extractionStatus;
  final String gradingStatus;
  final String? studentId;
  final String? studentName;

  Submission({
    this.id = '',
    this.assessmentId = '',
    required this.fileName,
    required this.filePath,
    required this.content,
    required this.sizeInBytes,
    this.extractionError,
    this.extractionStatus = 'UPLOADED',
    this.gradingStatus = 'UPLOADED',
    this.studentId,
    this.studentName,
  });

  bool get hasError => extractionError != null && extractionError!.isNotEmpty;

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['id']?.toString() ?? '',
      assessmentId: json['assessmentId']?.toString() ?? '',
      fileName: json['originalFileName']?.toString() ?? '',
      filePath: json['storagePath']?.toString() ?? '',
      content: json['extractedText']?.toString() ?? '',
      sizeInBytes: json['fileSize'] as int? ?? 0,
      extractionError: json['extractionError']?.toString(),
      extractionStatus: json['extractionStatus']?.toString() ?? 'PENDING',
      gradingStatus: json['gradingStatus']?.toString() ?? 'UPLOADED',
      studentId: json['studentId']?.toString(),
      studentName: json['studentName']?.toString(),
    );
  }
}
