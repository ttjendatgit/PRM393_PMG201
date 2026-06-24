/// Per-item grading result, mapped from `items[]` in the detail endpoint
/// GET /api/submissions/{submissionId}/grading-result.
class SubScoreResult {
  final String criterionCode;
  final String criterionTitle;
  final double maxScore;
  final double score;
  final String reason;

  const SubScoreResult({
    required this.criterionCode,
    required this.criterionTitle,
    required this.maxScore,
    required this.score,
    required this.reason,
  });
}

class QuestionResult {
  final String id;               // items[].id
  final String questionId;       // items[].rubricItemId / questionNo
  final String questionTitle;    // items[].title

  // AI-awarded scores (awardedRawScore / awardedConvertedScore)
  final double rawScore;
  final double convertedScore;

  final double maxRawScore;      // items[].maxRawScore
  final double maxConvertedScore;// items[].maxConvertedScore

  final String comment;          // items[].aiComment
  final String evidence;         // items[].evidence

  // Teacher review overrides (null when not yet reviewed)
  final double? reviewedRawScore;       // items[].reviewedRawScore
  final double? reviewedConvertedScore; // items[].reviewedConvertedScore
  final String teacherComment;          // items[].teacherComment

  final List<SubScoreResult> subscores;

  QuestionResult({
    this.id = '',
    required this.questionId,
    required this.questionTitle,
    required this.rawScore,
    required this.convertedScore,
    required this.maxRawScore,
    required this.maxConvertedScore,
    required this.comment,
    this.evidence = '',
    this.reviewedRawScore,
    this.reviewedConvertedScore,
    this.teacherComment = '',
    this.subscores = const [],
  });
}
