import 'question_result.dart';

/// Frontend model for a single grading result.
///
/// Sources:
///   Detail  : GET /api/submissions/{id}/grading-result
///   Summary : GET /api/assessments/{id}/review-results  (via ReviewResultSummary)
///
/// The detail endpoint does NOT return originalFileName, studentId, or
/// studentName — those are preserved from the local Submission after fetch.
class GradingResult {
  final String  id;
  final String  submissionId;
  final String  assessmentId;
  final String? gradingJobId;
  final String  fileName;        // preserved from Submission; NOT in detail JSON
  final String  studentId;       // NOT in detail JSON
  final String  studentName;     // NOT in detail JSON
  final double  totalRawScore;   // totalRawScore (AI total)
  final double  finalScore;      // totalConvertedScore (AI total)
  final Map<String, double> criteriaScores;
  final String  feedback;        // aiOverallComment or aggregated from items
  final List<QuestionResult>? questionResults;
  final String  reviewerNote;
  final String  reviewStatus;    // AI_GRADED | REVIEWED | FINALIZED
  final String  status;          // GRADED | ERROR | ... (submission status)
  final String  errorMessage;
  final double? reviewedRawScore;
  final double? reviewedConvertedScore;
  final double? finalRawScore;
  final double? finalConvertedScore;
  final String  teacherOverallComment;

  GradingResult({
    this.id                    = '',
    this.submissionId          = '',
    this.assessmentId          = '',
    this.gradingJobId,
    required this.fileName,
    required this.studentId,
    required this.studentName,
    required this.totalRawScore,
    required this.finalScore,
    required this.criteriaScores,
    required this.feedback,
    this.questionResults,
    this.reviewerNote          = '',
    this.reviewStatus          = 'AI_GRADED',
    this.status                = '',
    this.errorMessage          = '',
    this.reviewedRawScore,
    this.reviewedConvertedScore,
    this.finalRawScore,
    this.finalConvertedScore,
    this.teacherOverallComment = '',
  });

  // ── Factory ─────────────────────────────────────────────────────────────────

  factory GradingResult.fromJson(Map<String, dynamic> json) {
    // 1. Parse items first so we can aggregate feedback from them.
    final questionResults = _buildItems(json);

    // 2. Build criteriaScores map (keyed by title for legacy display paths).
    final criteriaScores = <String, double>{};
    if (questionResults != null) {
      for (final qr in questionResults) {
        criteriaScores[qr.questionTitle] = qr.convertedScore;
      }
    }

    // 3. Feedback: try top-level aiOverallComment, fall back to aggregated
    //    item-level aiComments.
    final feedback = (json['aiOverallComment'] as String?)?.trim().isNotEmpty == true
        ? json['aiOverallComment'] as String
        : _aggregateFeedback(questionResults);

    return GradingResult(
      id:           json['id']?.toString() ?? '',
      submissionId: json['submissionId']?.toString() ?? '',
      assessmentId: json['assessmentId']?.toString() ?? '',
      gradingJobId: json['gradingJobId']?.toString(),

      // originalFileName is NOT present in the detail endpoint response.
      // The caller should patch fileName from the local Submission after fetch.
      fileName:     json['originalFileName']?.toString() ?? '',

      // studentId/studentName are NOT present in the detail endpoint response.
      studentId:    json['studentId']?.toString()   ?? '',
      studentName:  json['studentName']?.toString() ?? '',

      totalRawScore:    (json['totalRawScore']    as num?)?.toDouble() ?? 0,
      finalScore:       (json['totalConvertedScore'] as num?)?.toDouble() ?? 0,
      criteriaScores:   criteriaScores,
      feedback:         feedback,
      questionResults:  questionResults,

      reviewStatus: json['reviewStatus']?.toString()  ?? 'AI_GRADED',
      status:       json['status']?.toString()        ?? '',
      errorMessage: json['errorMessage']?.toString()  ?? '',

      reviewedRawScore:       (json['reviewedRawScore']       as num?)?.toDouble(),
      reviewedConvertedScore: (json['reviewedConvertedScore'] as num?)?.toDouble(),
      finalRawScore:          (json['finalRawScore']          as num?)?.toDouble(),
      finalConvertedScore:    (json['finalConvertedScore']    as num?)?.toDouble(),

      teacherOverallComment: json['teacherOverallComment']?.toString() ?? '',
      reviewerNote:          json['teacherOverallComment']?.toString() ?? '',
    );
  }

  // ── Item builder ─────────────────────────────────────────────────────────────

  static List<QuestionResult>? _buildItems(Map<String, dynamic> json) {
    // Try every key name the backend might use for the items array.
    final itemsJson = (json['items']              ??
                       json['gradingItems']        ??
                       json['rubricItems']         ??
                       json['resultItems']         ??
                       json['gradingResultItems']) as List<dynamic>?;
    if (itemsJson == null) return null;

    return itemsJson.map((raw) {
      final i = raw as Map<String, dynamic>;

      // Identity
      final id = i['id']?.toString()                    ??
                 i['gradingResultItemId']?.toString()   ??
                 i['itemId']?.toString()                 ?? '';

      // Rubric item identity — backend uses rubricItemId + questionNo
      final questionId = i['rubricItemId']?.toString()  ??
                         i['questionNo']?.toString()    ??
                         i['questionId']?.toString()    ?? '';

      // Max scores
      final maxRaw  = (i['maxRawScore']       as num?)?.toDouble() ??
                      (i['maxRaw']            as num?)?.toDouble() ?? 0.0;
      final maxConv = (i['maxConvertedScore'] as num?)?.toDouble() ??
                      (i['maxConverted']      as num?)?.toDouble() ?? 0.0;

      // AI-awarded scores
      final rawScore  = (i['awardedRawScore']       as num?)?.toDouble() ??
                        (i['rawScore']              as num?)?.toDouble() ?? 0.0;
      final convScore = (i['awardedConvertedScore'] as num?)?.toDouble() ??
                        (i['convertedScore']        as num?)?.toDouble() ?? 0.0;

      // AI comment and evidence
      final comment  = i['aiComment']?.toString()  ??
                       i['comment']?.toString()    ?? '';
      final evidence = i['evidence']?.toString()   ?? '';

      // Teacher review overrides (null when not yet reviewed)
      final reviewedRaw  = (i['reviewedRawScore']       as num?)?.toDouble();
      final reviewedConv = (i['reviewedConvertedScore'] as num?)?.toDouble();
      final teacherComment = i['teacherComment']?.toString() ?? '';

      // Title
      final title = i['title']?.toString()         ??
                    i['questionTitle']?.toString()  ?? '';

      return QuestionResult(
        id:                    id,
        questionId:            questionId,
        questionTitle:         title,
        rawScore:              rawScore,
        convertedScore:        convScore,
        maxRawScore:           maxRaw,
        maxConvertedScore:     maxConv,
        comment:               comment,
        evidence:              evidence,
        reviewedRawScore:      reviewedRaw,
        reviewedConvertedScore: reviewedConv,
        teacherComment:        teacherComment,
      );
    }).toList();
  }

  // ── Feedback helper ──────────────────────────────────────────────────────────

  static String _aggregateFeedback(List<QuestionResult>? items) {
    if (items == null || items.isEmpty) return '';
    final parts = items
        .where((i) => i.comment.isNotEmpty)
        .map((i) {
          final label = i.questionTitle.isNotEmpty ? i.questionTitle : 'Item';
          return '$label: ${i.comment}';
        })
        .toList();
    return parts.join('\n\n');
  }

  // ── copyWith ─────────────────────────────────────────────────────────────────
  //
  // Used by the calling code to patch fields that are absent in the detail
  // endpoint (e.g. fileName, studentId) without rebuilding from scratch.

  GradingResult copyWith({
    String?             id,
    String?             submissionId,
    String?             assessmentId,
    String?             gradingJobId,
    String?             fileName,
    String?             studentId,
    String?             studentName,
    double?             totalRawScore,
    double?             finalScore,
    Map<String, double>? criteriaScores,
    String?             feedback,
    List<QuestionResult>? questionResults,
    String?             reviewerNote,
    String?             reviewStatus,
    String?             status,
    String?             errorMessage,
    double?             reviewedRawScore,
    double?             reviewedConvertedScore,
    double?             finalRawScore,
    double?             finalConvertedScore,
    String?             teacherOverallComment,
  }) {
    return GradingResult(
      id:                    id                    ?? this.id,
      submissionId:          submissionId          ?? this.submissionId,
      assessmentId:          assessmentId          ?? this.assessmentId,
      gradingJobId:          gradingJobId          ?? this.gradingJobId,
      fileName:              fileName              ?? this.fileName,
      studentId:             studentId             ?? this.studentId,
      studentName:           studentName           ?? this.studentName,
      totalRawScore:         totalRawScore         ?? this.totalRawScore,
      finalScore:            finalScore            ?? this.finalScore,
      criteriaScores:        criteriaScores        ?? this.criteriaScores,
      feedback:              feedback              ?? this.feedback,
      questionResults:       questionResults       ?? this.questionResults,
      reviewerNote:          reviewerNote          ?? this.reviewerNote,
      reviewStatus:          reviewStatus          ?? this.reviewStatus,
      status:                status                ?? this.status,
      errorMessage:          errorMessage          ?? this.errorMessage,
      reviewedRawScore:      reviewedRawScore      ?? this.reviewedRawScore,
      reviewedConvertedScore: reviewedConvertedScore ?? this.reviewedConvertedScore,
      finalRawScore:         finalRawScore         ?? this.finalRawScore,
      finalConvertedScore:   finalConvertedScore   ?? this.finalConvertedScore,
      teacherOverallComment: teacherOverallComment ?? this.teacherOverallComment,
    );
  }
}
