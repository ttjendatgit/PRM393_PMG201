import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/assessment.dart';
import '../../models/grading_result.dart';
import '../../models/question_result.dart';
import '../../models/submission.dart';
import 'prompt_builder_service.dart';

class GeminiGradingService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _timeout = Duration(seconds: 120);

  static void _validateApiKey(String apiKey) {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception(
        'Gemini API key is required. Please enter it in Settings.',
      );
    }
    if (key.contains('\n') || key.contains('\r') || key.contains(' ') ||
        key.toLowerCase().startsWith('bearer ')) {
      throw Exception(
        'Invalid Gemini API key. Please paste the key exactly from Google AI Studio, '
        'without spaces, line breaks, quotes, or Bearer prefix.',
      );
    }
  }

  static Future<GradingResult> gradeSubmission({
    required String apiKey,
    required String modelId,
    required Assessment assessment,
    required Submission submission,
  }) async {
    _validateApiKey(apiKey);

    final trimmedModel = modelId.trim();
    if (trimmedModel.isEmpty) {
      throw Exception(
        'Gemini model ID is required. Please enter it in Settings '
        '(e.g. gemini-2.0-flash-lite).',
      );
    }

    final prompt = PromptBuilderService.buildGradingPrompt(
      assessment: assessment,
      submission: submission,
    );

    final url = Uri.parse(
      '$_baseUrl/$trimmedModel:generateContent?key=${apiKey.trim()}',
    );

    final requestBody = json.encode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 8192,
      },
    });

    late http.Response response;
    try {
      response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out after ${_timeout.inSeconds}s. '
        'Check your connection and try again.',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        throw Exception(
          'Cannot reach Gemini API. Check your internet connection.',
        );
      }
      throw Exception('Network error. Check your connection and try again.');
    }

    if (response.statusCode == 400) {
      final err = _extractGeminiError(response.body);
      throw Exception('Bad request (check model ID or prompt). $err');
    }
    if (response.statusCode == 401) {
      throw Exception(
        'Invalid API key. Please paste the key exactly from the provider dashboard.',
      );
    }
    if (response.statusCode == 403) {
      throw Exception(
        'Gemini API key does not have permission or quota exceeded. '
        'Check your Google AI Studio project or switch to a lighter model.',
      );
    }
    if (response.statusCode == 429) {
      throw Exception(
        'Gemini quota/rate limit exceeded. '
        'Please wait, switch provider, or use a lighter model.',
      );
    }
    if (response.statusCode != 200) {
      final err = _extractGeminiError(response.body);
      throw Exception('Gemini error ${response.statusCode}: $err');
    }

    final Map<String, dynamic> apiBody;
    try {
      apiBody = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Failed to parse Gemini response body.');
    }

    final candidates = apiBody['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in Gemini response.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final aiText = parts?.isNotEmpty == true
        ? parts!.first['text'] as String?
        : null;

    if (aiText == null || aiText.trim().isEmpty) {
      throw Exception('Gemini returned empty content.');
    }

    return _parseAiResponse(aiText, submission, assessment);
  }

  static String _extractGeminiError(String body) {
    try {
      final decoded = json.decode(body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      return err?['message'] as String? ?? body.substring(0, body.length.clamp(0, 300));
    } catch (_) {
      return body.length > 300 ? body.substring(0, 300) : body;
    }
  }

  static GradingResult _parseAiResponse(
    String text,
    Submission submission,
    Assessment assessment,
  ) {
    var cleaned = text.trim();

    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-z]*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```\s*$'), '');
      cleaned = cleaned.trim();
    }

    final Map<String, dynamic> data;
    try {
      data = json.decode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      final preview = cleaned.length > 400 ? cleaned.substring(0, 400) : cleaned;
      throw Exception('Gemini returned invalid JSON.\nPreview: $preview');
    }

    final aiResultsRaw = data['question_results'] as List<dynamic>? ?? [];
    final List<QuestionResult> parsedQuestions;

    if (assessment.questions.isNotEmpty) {
      // Assessment is the single source of truth for question count and scoring scale.
      // Match AI results to assessment questions by question_id (primary) or index (fallback).
      parsedQuestions = List.generate(assessment.questions.length, (i) {
        final aq = assessment.questions[i];
        final maxRaw = aq.rawMaxScore;
        final maxConv = aq.convertedMaxScore;

        Map<String, dynamic>? aiQ;
        for (final raw in aiResultsRaw) {
          final candidate = raw as Map<String, dynamic>;
          final cId = (candidate['question_id'] as String? ?? '').toLowerCase();
          if (cId.isNotEmpty && cId == aq.questionId.toLowerCase()) {
            aiQ = candidate;
            break;
          }
        }
        if (aiQ == null && i < aiResultsRaw.length) {
          aiQ = aiResultsRaw[i] as Map<String, dynamic>;
        }

        final rawScore = (aiQ != null ? _toDouble(aiQ['raw_score']) : 0.0)
            .clamp(0.0, maxRaw)
            .toDouble();
        final convertedScore = maxRaw > 0
            ? double.parse((rawScore / maxRaw * maxConv).toStringAsFixed(2))
            : 0.0;
        final comment = aiQ != null
            ? ((aiQ['comment'] as String?) ?? '')
            : 'No score returned by AI for this criterion.';
        final subscoresRaw = aiQ?['subscores'] as List<dynamic>? ?? [];

        return QuestionResult(
          questionId: aq.questionId,
          questionTitle: aq.title,
          rawScore: rawScore,
          convertedScore: convertedScore,
          maxRawScore: maxRaw,
          maxConvertedScore: maxConv,
          comment: comment,
          subscores: subscoresRaw.map((s) {
            final sub = s as Map<String, dynamic>;
            return SubScoreResult(
              criterionCode: (sub['criterion_code'] as String?) ?? '',
              criterionTitle: (sub['criterion_title'] as String?) ?? '',
              maxScore: _toDouble(sub['max_score']),
              score: _toDouble(sub['score']),
              reason: (sub['reason'] as String?) ?? '',
            );
          }).toList(),
        );
      });
    } else {
      // No structured rubric — fall back to AI-provided structure for dynamic assessments.
      parsedQuestions = aiResultsRaw.map((raw) {
        final q = raw as Map<String, dynamic>;
        final subscoresRaw = q['subscores'] as List<dynamic>? ?? [];
        final maxRaw = _toDouble(q['max_raw_score']);
        final rawScore = maxRaw > 0
            ? _toDouble(q['raw_score']).clamp(0.0, maxRaw).toDouble()
            : _toDouble(q['raw_score']).clamp(0.0, double.maxFinite).toDouble();
        final maxConv = assessment.totalRawScore > 0 && maxRaw > 0
            ? double.parse(
                (maxRaw / assessment.totalRawScore * assessment.totalConvertedScore)
                    .toStringAsFixed(2),
              )
            : 0.0;
        final convertedScore = maxRaw > 0
            ? double.parse((rawScore / maxRaw * maxConv).toStringAsFixed(2))
            : 0.0;

        return QuestionResult(
          questionId: (q['question_id'] as String?) ?? '',
          questionTitle: (q['question_title'] as String?) ?? '',
          rawScore: rawScore,
          convertedScore: convertedScore,
          maxRawScore: maxRaw,
          maxConvertedScore: maxConv,
          comment: (q['comment'] as String?) ?? '',
          subscores: subscoresRaw.map((s) {
            final sub = s as Map<String, dynamic>;
            return SubScoreResult(
              criterionCode: (sub['criterion_code'] as String?) ?? '',
              criterionTitle: (sub['criterion_title'] as String?) ?? '',
              maxScore: _toDouble(sub['max_score']),
              score: _toDouble(sub['score']),
              reason: (sub['reason'] as String?) ?? '',
            );
          }).toList(),
        );
      }).toList();
    }

    final totalRaw =
        parsedQuestions.fold<double>(0, (sum, qr) => sum + qr.rawScore);
    final totalConverted = double.parse(
      (assessment.totalRawScore > 0
              ? (totalRaw / assessment.totalRawScore * assessment.totalConvertedScore)
                  .clamp(0.0, assessment.totalConvertedScore)
              : parsedQuestions
                  .fold<double>(0, (sum, qr) => sum + qr.convertedScore)
                  .clamp(0.0, assessment.totalConvertedScore))
          .toStringAsFixed(2),
    );

    final criteriaScores = <String, double>{
      for (final qr in parsedQuestions)
        if (qr.questionTitle.isNotEmpty) qr.questionTitle: qr.convertedScore,
    };

    final finalComment = (data['final_comment'] as String?) ?? '';
    final parsedId = (data['student_id'] as String?) ?? '';
    final parsedName = (data['student_name'] as String?) ?? '';
    final (fallbackId, fallbackName) = _extractStudentInfo(submission.fileName);

    return GradingResult(
      fileName: submission.fileName,
      studentId: parsedId.isNotEmpty && parsedId != 'N/A' ? parsedId : fallbackId,
      studentName: parsedName.isNotEmpty ? parsedName : fallbackName,
      totalRawScore: totalRaw,
      finalScore: totalConverted,
      criteriaScores: criteriaScores.isNotEmpty
          ? criteriaScores
          : {'Overall': totalConverted},
      feedback: finalComment,
      questionResults: parsedQuestions.isNotEmpty ? parsedQuestions : null,
    );
  }

  static (String, String) _extractStudentInfo(String fileName) {
    final clean = fileName.replaceAll('.txt', '');
    final parts = clean.split('_');
    if (parts.length >= 2 && parts.first.toUpperCase().startsWith('SE')) {
      return (parts.first, parts.sublist(1).join(' '));
    }
    return ('N/A', clean);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
