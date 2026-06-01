import '../models/submission.dart';
import '../models/grading_result.dart';

class MockAiGradingService {
  Future<GradingResult> grade(
    Submission submission, {
    String marker = 'AI',
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    const questionScores = [1.8, 1.9, 2.5, 2.3];
    const finalScore = 8.5;

    return GradingResult(
      alias: submission.alias,
      marker: marker,
      fileName: submission.fileName,
      studentId: _extractStudentId(submission.fileName),
      studentName: _extractStudentName(submission.fileName),
      questionScores: questionScores,
      finalScore: finalScore,
      criteriaScores: {
        GradingResult.questionLabels[0]: questionScores[0],
        GradingResult.questionLabels[1]: questionScores[1],
        GradingResult.questionLabels[2]: questionScores[2],
        GradingResult.questionLabels[3]: questionScores[3],
      },
      feedback:
          'The submission shows a solid understanding of project planning. The WBS and risk register are clear. To improve, the student should explain budget assumptions and schedule dependencies in more detail.',
    );
  }

  String _extractStudentId(String fileName) {
    return Submission.extractAlias(fileName);
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
