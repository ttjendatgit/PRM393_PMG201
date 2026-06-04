import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/assessment.dart';
import '../../models/grading_result.dart';
import '../../models/question_result.dart';
import '../../models/submission.dart';
import 'prompt_builder_service.dart';

class OpenRouterGradingService {
  static const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _timeout = Duration(seconds: 120);

  static void _validateApiKey(String apiKey) {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception(
        'OpenRouter API key is required. Please enter it in Settings.',
      );
    }
    if (!key.startsWith('sk-or-v1-') ||
        key.contains('\n') ||
        key.contains('\r') ||
        key.contains(' ')) {
      throw Exception(
        'Invalid OpenRouter API key. Please paste a valid key in Settings.',
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

    if (modelId.trim().isEmpty) {
      throw Exception('Model ID is required. Please enter it in Settings (e.g. openai/gpt-4o-mini).');
    }

    final trimmedKey = apiKey.trim();

    final prompt = PromptBuilderService.buildGradingPrompt(
      assessment: assessment,
      submission: submission,
    );

    final requestBody = json.encode({
      'model': modelId.trim(),
      'max_tokens': 4096,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
    });

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $trimmedKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://pmg-gradeai',
              'X-Title': 'PMG GradeAI',
            },
            body: requestBody,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'Request timed out after ${_timeout.inSeconds}s. Check your connection and try again.',
      );
    } catch (e) {
      // Avoid leaking user input (e.g. API key) from low-level HTTP errors
      final msg = e.toString();
      if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        throw Exception('Cannot reach OpenRouter. Check your internet connection.');
      }
      throw Exception('Network error. Check your connection and try again.');
    }

    if (response.statusCode == 401) {
      throw Exception('Invalid OpenRouter API key. Please check your key in Settings.');
    }
    if (response.statusCode == 402) {
      throw Exception('Insufficient OpenRouter credits. Please top up your account.');
    }
    if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded. Please wait before grading again.');
    }
    if (response.statusCode == 400) {
      final preview = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      throw Exception('Bad request (check model ID). Response: $preview');
    }
    if (response.statusCode != 200) {
      final preview = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      throw Exception('OpenRouter error ${response.statusCode}: $preview');
    }

    final Map<String, dynamic> apiBody;
    try {
      apiBody = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Failed to parse OpenRouter response body.');
    }

    // OpenAI-compatible format: choices[0].message.content
    final choices = apiBody['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No choices in OpenRouter response.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final aiText = message?['content'] as String?;
    if (aiText == null || aiText.trim().isEmpty) {
      throw Exception('OpenRouter returned empty content.');
    }

    return _parseAiResponse(aiText, submission, assessment);
  }

  static GradingResult _parseAiResponse(
    String text,
    Submission submission,
    Assessment assessment,
  ) {
    var cleaned = text.trim();

    // Strip markdown code fences if the model added them despite instructions
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
      throw Exception('Model returned invalid JSON.\nPreview: $preview');
    }

    final questionResultsRaw = data['question_results'] as List<dynamic>? ?? [];
    final parsedQuestions = questionResultsRaw.map((raw) {
      final q = raw as Map<String, dynamic>;
      final subscoresRaw = q['subscores'] as List<dynamic>? ?? [];
      final maxRaw = _toDouble(q['max_raw_score']);
      // Clamp raw score to [0, maxRawScore]
      final rawScore = maxRaw > 0
          ? _toDouble(q['raw_score']).clamp(0.0, maxRaw).toDouble()
          : _toDouble(q['raw_score']).clamp(0.0, double.maxFinite).toDouble();
      // Always derive convertedMax proportionally from assessment scale.
      // Never trust the AI's max_converted_score — it frequently copies rawMax
      // or uses an inconsistent scale, producing impossible values like 99/10.
      final maxConv = assessment.totalRawScore > 0 && maxRaw > 0
          ? double.parse(
              (maxRaw / assessment.totalRawScore * assessment.totalConvertedScore)
                  .toStringAsFixed(2))
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

    // Recalculate totals from per-question results.
    // Derive finalScore from totalRaw using the assessment scale — this is the
    // single source of truth and avoids rounding drift from summing per-question values.
    final totalRaw = parsedQuestions.fold<double>(0, (sum, qr) => sum + qr.rawScore);
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
