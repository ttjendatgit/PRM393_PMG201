import 'dart:convert';
import '../../models/assessment.dart';
import '../../models/submission.dart';

class PromptBuilderService {
  static String buildGradingPrompt({
    required Assessment assessment,
    required Submission submission,
  }) {
    final rubricJson = _buildRubricJson(assessment);
    final rubricStructureSection = assessment.questions.isEmpty
        ? "No structured rubric found. Please infer the grading rubric and criteria from the GRADING GUIDE / RUBRIC text provided below to perform the evaluation."
        : "RUBRIC STRUCTURE (JSON)\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n$rubricJson";

    return '''
You are an academic grader for ${assessment.courseCode} — ${assessment.assessmentTitle}.

Your task is to evaluate the student submission below using the provided exam questions, grading guide, and rubric structure. Grade strictly based on what is given — do not invent criteria.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXAM QUESTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${assessment.examQuestionText.trim()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRADING GUIDE / RUBRIC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${assessment.gradingGuideText.trim()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$rubricStructureSection

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
STUDENT SUBMISSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
File: ${submission.fileName}

${submission.content.trim()}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRADING INSTRUCTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Grade based ONLY on the exam questions and grading guide above. Do not invent criteria.
2. If the student submission is written in Vietnamese, read and understand it directly. Do not translate or produce a separate translation output. Grade based on the rubric content requirements.
3. Do not penalise for language (Vietnamese or English) unless the rubric explicitly requires English.
4. Extract student_id and student_name from the file name if possible. Expected format: STUDENTID_FirstName_LastName.txt (e.g. SE001_Nguyen_Van_A.txt). If not parseable, use "N/A" for student_id and the raw filename for student_name.
5. Return your response as a single JSON object ONLY. No markdown fences. No explanation outside the JSON.
6. Grade EXACTLY the questions listed in RUBRIC STRUCTURE — return one question_result per assessment question, in the same order. Do NOT invent new questions, split sub-criteria into separate question entries, or merge questions. Sub-criteria details in the grading guide are context only; they do not define the question count or scoring scale.
7. For each question result: provide raw_score (integer, 0..max_raw_score from RUBRIC STRUCTURE) and a comment. Copy max_raw_score and max_converted_score exactly from RUBRIC STRUCTURE without modification — the app enforces these values and will override anything different. Do NOT invent or reduce denominators.
8. Set total_raw_score = sum of all raw_score values. Set total_converted_score = sum of all converted_score values (round to 2 decimal places).
${_inferInstructions(assessment)}
EXPECTED OUTPUT FORMAT:
{
  "file_name": "string",
  "student_id": "string",
  "student_name": "string",
  "question_results": [
    {
      "question_id": "string",
      "question_title": "string",
      "raw_score": number,
      "converted_score": number,
      "max_raw_score": number,
      "max_converted_score": number,
      "comment": "string",
      "subscores": [
        {
          "criterion_code": "string",
          "criterion_title": "string",
          "max_score": number,
          "score": number,
          "reason": "string"
        }
      ]
    }
  ],
  "total_raw_score": number,
  "total_converted_score": number,
  "final_comment": "string"
}
''';
  }

  /// Extra instruction injected when the rubric has no structured items.
  static String _inferInstructions(Assessment assessment) {
    if (assessment.questions.isNotEmpty) return '';
    final maxRaw = assessment.totalRawScore.toInt();
    final maxConv = assessment.totalConvertedScore % 1 == 0
        ? assessment.totalConvertedScore.toInt().toString()
        : assessment.totalConvertedScore.toString();
    return '8. The RUBRIC STRUCTURE JSON above is empty because no structured items were '
        'pre-parsed. Infer the question/criterion breakdown directly from the '
        'GRADING GUIDE / RUBRIC text above. The total raw score for this '
        'assessment is $maxRaw and the total converted score is $maxConv. '
        'Ensure all question raw_score values sum to a value within that range.\n';
  }

  static String _buildRubricJson(Assessment assessment) {
    if (assessment.questions.isEmpty) return '[]';

    final list = assessment.questions.map((q) {
      return {
        'question_id': q.questionId,
        'title': q.title,
        'raw_max_score': q.rawMaxScore,
        'converted_max_score': q.convertedMaxScore,
        'description': q.description,
        'sub_criteria': q.subCriteria.map((s) => {
              'code': s.code,
              'title': s.title,
              'max_score': s.maxScore,
              'full_mark_description': s.fullMarkDescription,
              'partial_mark_description': s.partialMarkDescription,
              'low_mark_description': s.lowMarkDescription,
              'common_mistakes': s.commonMistakes,
            }).toList(),
      };
    }).toList();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(list);
  }
}
