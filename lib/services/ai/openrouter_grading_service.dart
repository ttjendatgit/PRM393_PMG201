import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/assessment.dart';
import '../../models/grading_result.dart';
import '../../models/question_result.dart';
import '../../models/submission.dart';
import 'prompt_builder_service.dart';

class OpenRouterGradingService {
  static const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const _timeout = Duration(seconds: 90);

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

  static bool _isRetryableError(String msg) {
    return msg.contains('timed out') ||
        msg.contains('Network error') ||
        msg.contains('internet connection') ||
        msg.contains('Rate limit') ||
        msg.contains('rate limit') ||
        msg.contains('empty response');
  }

  // Makes exactly one HTTP call and returns raw AI text (may be empty).
  static Future<String> _fetchContent(
    String apiKey,
    String modelId,
    String prompt,
  ) async {
    final requestBody = json.encode({
      'model': modelId,
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
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://pmg-gradeai',
              'X-Title': 'PMG GradeAI',
            },
            body: requestBody,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception(
        'AI grading timed out. Please retry this file or switch to another provider/model.',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Failed host lookup') || msg.contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
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
      throw Exception(
        'OpenRouter rate limit exceeded. Please wait or switch model.',
      );
    }
    if (response.statusCode == 400) {
      final preview = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      throw Exception('Bad request (check model ID). Response: $preview');
    }
    if (response.statusCode != 200) {
      final preview = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      throw Exception('OpenRouter error ${response.statusCode}: $preview');
    }

    final Map<String, dynamic> apiBody;
    try {
      apiBody = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Failed to parse OpenRouter response body.');
    }

    final choices = apiBody['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No choices in OpenRouter response.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final aiText = message?['content'] as String?;
    return aiText ?? '';
  }

  // Calls _fetchContent with one automatic retry on retryable errors or empty response.
  static Future<String> _fetchWithRetry(
    String apiKey,
    String modelId,
    String prompt,
  ) async {
    Future<String> doFetch() async {
      final text = await _fetchContent(apiKey, modelId, prompt);
      if (text.trim().isEmpty) {
        throw Exception('AI returned an empty response. Please retry this file.');
      }
      return text;
    }

    try {
      return await doFetch();
    } catch (e) {
      final msg = e.toString();
      if (!_isRetryableError(msg)) rethrow;
      debugPrint('[GradeAI][OpenRouter] retryable error on attempt 1, retrying in 3s: $msg');
      await Future.delayed(const Duration(seconds: 3));
      return doFetch();
    }
  }

  // Extracts first valid JSON object from response text with multiple fallback strategies.
  static (Map<String, dynamic>?, String) _extractJson(String text) {
    var cleaned = text.replaceAll('﻿', '').trim();

    if (cleaned.isEmpty) return (null, 'empty');

    // Strip markdown fences
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n?'), '');
      final last = cleaned.lastIndexOf('```');
      if (last >= 0) {
        cleaned = cleaned.substring(0, last).trim();
      } else {
        cleaned = cleaned.trim();
      }
    }

    // Direct decode
    try {
      final data = json.decode(cleaned) as Map<String, dynamic>;
      return (data, 'direct');
    } catch (_) {}

    // Fallback: scan for first balanced {...} block
    final extracted = _extractFirstJsonObject(cleaned);
    if (extracted != null) {
      try {
        final data = json.decode(extracted) as Map<String, dynamic>;
        return (data, 'extracted');
      } catch (_) {}
    }

    return (null, 'failed');
  }

  static String? _extractFirstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;

    int depth = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  static Future<GradingResult> gradeSubmission({
    required String apiKey,
    required String modelId,
    required Assessment assessment,
    required Submission submission,
  }) async {
    _validateApiKey(apiKey);

    if (modelId.trim().isEmpty) {
      throw Exception(
        'Model ID is required. Please enter it in Settings (e.g. openai/gpt-4o-mini).',
      );
    }

    final trimmedKey = apiKey.trim();
    final trimmedModel = modelId.trim();

    final prompt = PromptBuilderService.buildGradingPrompt(
      assessment: assessment,
      submission: submission,
    );

    debugPrint(
      '[GradeAI][OpenRouter] file="${submission.fileName}" '
      'model=$trimmedModel textLen=${submission.content.length}',
    );

    // Attempt 1: fetch with automatic retry for network/timeout/rate-limit/empty
    final aiText = await _fetchWithRetry(trimmedKey, trimmedModel, prompt);
    debugPrint('[GradeAI][OpenRouter] attempt1 responseLen=${aiText.length}');

    final (data1, mode1) = _extractJson(aiText);
    debugPrint('[GradeAI][OpenRouter] parse_mode=$mode1');

    if (data1 != null) {
      final result = _buildResult(data1, submission, assessment);
      debugPrint(
        '[GradeAI][OpenRouter] success '
        'resultCount=${result.questionResults?.length ?? 0}',
      );
      return result;
    }

    // JSON parse failed: retry once with stricter prompt
    debugPrint('[GradeAI][OpenRouter] error_type=invalid_json retrying with strict prompt');
    final strictPrompt = PromptBuilderService.buildRetryPrompt(original: prompt);

    final aiText2 = await _fetchContent(trimmedKey, trimmedModel, strictPrompt);

    if (aiText2.trim().isEmpty) {
      throw Exception('AI returned an empty response. Please retry this file.');
    }

    final (data2, mode2) = _extractJson(aiText2);
    debugPrint(
      '[GradeAI][OpenRouter] retry parse_mode=$mode2 responseLen=${aiText2.length}',
    );

    if (data2 != null) {
      final result = _buildResult(data2, submission, assessment);
      debugPrint(
        '[GradeAI][OpenRouter] retry_success '
        'resultCount=${result.questionResults?.length ?? 0}',
      );
      return result;
    }

    throw Exception(
      'The AI response was not valid JSON. Please retry grading this file or switch to a more reliable model.',
    );
  }

  static GradingResult _buildResult(
    Map<String, dynamic> data,
    Submission submission,
    Assessment assessment,
  ) {
    final aiResultsRaw = data['question_results'] as List<dynamic>? ?? [];
    final List<QuestionResult> parsedQuestions;

    if (assessment.questions.isNotEmpty) {
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

    debugPrint(
      '[GradeAI][OpenRouter] resultCount=${parsedQuestions.length} '
      'totalRaw=$totalRaw totalConverted=$totalConverted',
    );

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
    final lastDot = fileName.lastIndexOf('.');
    final clean = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
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
