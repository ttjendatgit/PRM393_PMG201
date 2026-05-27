import '../models/submission.dart';
import '../models/grading_result.dart';

class MockAiGradingService {
  Future<GradingResult> grade(Submission submission) async {
    await Future.delayed(const Duration(seconds: 1));

    final fileName = submission.fileName;

    final studentId = _extractStudentId(fileName);
    final studentName = _extractStudentName(fileName);

    return GradingResult(
      fileName: fileName,
      studentId: studentId,
      studentName: studentName,
      finalScore: 8.5,
      criteriaScores: const {
        'Project Charter': 1.4,
        'Scope & WBS': 1.8,
        'Schedule': 1.6,
        'Budget': 1.2,
        'Risk': 1.7,
        'Presentation': 0.8,
      },
      feedback:
          'The submission shows a solid understanding of project planning. The WBS and risk register are clear. To improve, the student should explain budget assumptions and schedule dependencies in more detail.',
    );
  }

  String _extractStudentId(String fileName) {
    final parts = fileName.split('_');
    if (parts.isNotEmpty && parts.first.toUpperCase().startsWith('SE')) {
      return parts.first;
    }
    return 'N/A';
  }

  String _extractStudentName(String fileName) {
    final cleanName = fileName.replaceAll('.txt', '');
    final parts = cleanName.split('_');

    if (parts.length >= 2) {
      return parts.sublist(1).join(' ');
    }

    return cleanName;
  }
}