/// Lightweight grading-guide text → [QuestionRubric] parser.
///
/// Supports common rubric line patterns:
///   Yêu cầu 1: Title    20 điểm          ← Vietnamese top-level (priority)
///   Q1 - Title: 5 marks
///   Q1: Title (5 marks)
///   1. Title - 5 points
///   Title: 5
///   Title (5 marks)
///   Title: 5 điểm
///
/// Score unit words: marks, mark, points, point, pts, pt, điểm
library;

import 'package:flutter/foundation.dart';
import '../models/rubric.dart';

class RubricParserResult {
  final List<QuestionRubric> questions;
  final double detectedTotalRaw;

  const RubricParserResult({
    required this.questions,
    required this.detectedTotalRaw,
  });
}

// Score-unit regex fragment (inlined in each RegExp to avoid lint false-positive)
// ignore: unused_element – used via string interpolation in RegExp patterns below
const _u = r'(?:marks?|points?|pts?|pt|điểm)';

class RubricParserService {
  // ── Public entry point ──────────────────────────────────────────────────────

  /// Parse [guideText] into rubric items.
  ///
  /// [totalRawScore] and [totalConvertedScore] are used to compute
  /// proportional [QuestionRubric.convertedMaxScore].  If not supplied,
  /// this method tries to detect the total from the text itself (falls
  /// back to 100 / 10).
  static RubricParserResult parse({
    required String guideText,
    double? totalRawScore,
    double? totalConvertedScore,
  }) {
    final detectedTotal = _detectTotal(guideText);
    final effectiveTotalRaw = totalRawScore ?? detectedTotal ?? 100.0;
    final effectiveTotalConv = totalConvertedScore ?? 10.0;

    debugPrint('[RubricParser] detectedTotalRaw=$effectiveTotalRaw');

    final items = _extractItems(guideText);

    final questions = <QuestionRubric>[];
    for (int i = 0; i < items.length; i++) {
      final raw = items[i];
      final maxConv = effectiveTotalRaw > 0
          ? double.parse(
              (raw.score / effectiveTotalRaw * effectiveTotalConv)
                  .toStringAsFixed(2),
            )
          : 0.0;

      questions.add(
        QuestionRubric(
          questionId: raw.questionId ?? 'q${i + 1}',
          title: raw.title,
          rawMaxScore: raw.score,
          convertedMaxScore: maxConv,
          description: '',
        ),
      );
    }

    return RubricParserResult(
      questions: questions,
      detectedTotalRaw: effectiveTotalRaw,
    );
  }

  // ── Total score detection ───────────────────────────────────────────────────

  static double? _detectTotal(String text) {
    final patterns = [
      // "TỔNG ĐIỂM 100 điểm" / "Tổng điểm tối đa toàn bài: 100 điểm"
      RegExp(
        r'(?:TỔNG|Tổng|tổng)\s+(?:ĐIỂM|Điểm|điểm)[^0-9]*(\d+(?:\.\d+)?)',
        multiLine: true,
      ),
      // "Total: 100" / "Total marks: 100" / "Total raw score: 100" / "Tổng điểm: 100"
      RegExp(
        r'(?:^|\n)\s*(?:total|tổng)\s*(?:raw\s*)?(?:score|marks?|points?|điểm)?\s*[:\-–]?\s*(\d+(?:\.\d+)?)',
        caseSensitive: false,
        multiLine: true,
      ),
      // "100 marks" at start of line
      RegExp(
        r'(?:^|\n)\s*(\d+(?:\.\d+)?)\s+$_u\b',
        caseSensitive: false,
        multiLine: true,
      ),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  // ── Line extraction ─────────────────────────────────────────────────────────

  static List<_RawItem> _extractItems(String text) {
    // Phase 1: Vietnamese "Yêu cầu" top-level lines take priority.
    // If any are found, return them immediately — do not parse subcriteria.
    final yeuCauItems = _extractYeuCauItems(text);
    debugPrint('[RubricParser] Yêu cầu lines found: ${yeuCauItems.length}');
    if (yeuCauItems.isNotEmpty) {
      for (final item in yeuCauItems) {
        debugPrint(
          '[RubricParser]   ${item.questionId}: "${item.title}" rawScore=${item.score}',
        );
      }
      return yeuCauItems;
    }

    // Phase 2: generic line-by-line fallback.
    final results = <_RawItem>[];
    final seen = <String>{};

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final item = _parseLine(trimmed);
      if (item == null) continue;
      if (item.score <= 0) continue;

      // Reject overly long titles — they are description/table rows, not headings
      if (item.title.length > 65) continue;

      // Deduplicate by normalised title
      final key = item.title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (seen.contains(key)) continue;
      seen.add(key);

      results.add(item);
    }

    return results;
  }

  // ── Vietnamese top-level extractor ─────────────────────────────────────────

  /// Matches lines of the form:
  ///   Yêu cầu 1: Title    20 điểm
  ///   Yêu cầu 1 - Title   30 điểm
  ///   Yêu cầu 1 – Title   30 điểm
  ///
  /// Tabs and multiple spaces between the title and score are handled by `\s+`.
  static List<_RawItem> _extractYeuCauItems(String text) {
    final re = RegExp(
      r'Yêu\s+cầu\s+(\d+)\s*[:\-–]\s*(.+?)\s+(\d+(?:[.,]\d+)?)\s*(?:điểm|diem|marks?|points?|pts?)\b',
      caseSensitive: false,
    );

    final results = <_RawItem>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final m = re.firstMatch(trimmed);
      if (m == null) continue;

      final n = m.group(1)!;
      final rawTitle = m.group(2)!.trim();
      final scoreStr = m.group(3)!.replaceAll(',', '.');
      final score = double.tryParse(scoreStr) ?? 0.0;

      if (rawTitle.isEmpty || score <= 0) continue;
      results.add(_RawItem(questionId: 'q$n', title: rawTitle, score: score));
    }
    return results;
  }

  // ── Single line parsers ─────────────────────────────────────────────────────

  static _RawItem? _parseLine(String line) {
    // Skip separator lines
    if (RegExp(r'^[━\-=]{3,}').hasMatch(line)) return null;
    // Skip total markers
    if (RegExp(r'^\s*(?:total|tổng)', caseSensitive: false).hasMatch(line)) return null;
    // Skip grading-level description lines (Full, Partial, Low, Mức, etc.)
    if (RegExp(
      r'^\s*(?:full|partial|part|low|poor|good|excellent|mức|loại|level|band)\b',
      caseSensitive: false,
    ).hasMatch(line)) { return null; }
    // Skip lines starting with inequality symbols — these are scoring-range descriptors
    if (RegExp(r'^\s*[≥≤<>]').hasMatch(line)) return null;
    // Skip lines that look like score-range annotations e.g. "(9-10):" or "(5–8) "
    if (RegExp(r'^\s*\(\d+\s*[-–]\s*\d+\)').hasMatch(line)) return null;

    return _tryPatternQPrefix(line) ??
        _tryPatternNumberedDot(line) ??
        _tryPatternParenScore(line) ??
        _tryPatternColonScore(line);
  }

  /// Q1 - Title: 20 marks   |   Q1: Title (20 marks)   |   Q1 — Title: 20
  static _RawItem? _tryPatternQPrefix(String line) {
    final re = RegExp(
      r'^(Q\d+(?:\.\d+)?)\s*[-–—.:]\s*'
      r'(.+?)'
      r'(?:'
        r'[-–—:]\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?'   // colon/dash + score
        r'|'
        r'\(\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?\s*\)'  // parenthesised score
        r'|'
        r'(?:$_u\b)\s*/\s*(\d+(?:\.\d+)?)'          // unit /score e.g. (/10)
      r')',
      caseSensitive: false,
    );
    final m = re.firstMatch(line);
    if (m == null) return null;

    final qId = m.group(1)!
        .toLowerCase()
        .replaceAll('.', '_')
        .replaceAll(' ', '');
    final title = _cleanTitle(m.group(2)!.trim());
    final score = double.tryParse(
          m.group(3) ?? m.group(4) ?? m.group(5) ?? '',
        ) ??
        0.0;

    if (title.isEmpty || score <= 0) return null;
    return _RawItem(questionId: qId, title: title, score: score);
  }

  /// 1. Title - 5 points   |   1) Title: 5
  static _RawItem? _tryPatternNumberedDot(String line) {
    final re = RegExp(
      r'^(\d+)[.)]\s*'
      r'(.+?)'
      r'(?:'
        r'[-–—:]\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?'
        r'|'
        r'\(\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?\s*\)'
      r')',
      caseSensitive: false,
    );
    final m = re.firstMatch(line);
    if (m == null) return null;

    final n = m.group(1)!;
    final title = _cleanTitle(m.group(2)!.trim());
    final score = double.tryParse(m.group(3) ?? m.group(4) ?? '') ?? 0.0;

    if (title.isEmpty || score <= 0) return null;
    return _RawItem(questionId: 'q$n', title: title, score: score);
  }

  /// Title (5 marks)   |   Title (5)
  static _RawItem? _tryPatternParenScore(String line) {
    final re = RegExp(
      r'^(.+?)\s*\(\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?\s*\)\s*$',
      caseSensitive: false,
    );
    final m = re.firstMatch(line);
    if (m == null) return null;

    final title = _cleanTitle(m.group(1)!);
    final score = double.tryParse(m.group(2)!) ?? 0.0;

    if (title.isEmpty || score <= 0) return null;
    return _RawItem(title: title, score: score);
  }

  /// Title: 5 marks   |   Title: 5 điểm   |   Title: 5
  static _RawItem? _tryPatternColonScore(String line) {
    final re = RegExp(
      r'^(.+?)\s*:\s*(\d+(?:\.\d+)?)\s*(?:$_u\b)?\s*$',
      caseSensitive: false,
    );
    final m = re.firstMatch(line);
    if (m == null) return null;

    final title = _cleanTitle(m.group(1)!);
    final score = double.tryParse(m.group(2)!) ?? 0.0;

    if (title.isEmpty || score <= 0) return null;
    return _RawItem(title: title, score: score);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _cleanTitle(String raw) {
    return raw.replaceAll(RegExp(r'[-–—:,]+$'), '').trim();
  }
}

// ── Internal data class ────────────────────────────────────────────────────────

class _RawItem {
  final String? questionId;
  final String title;
  final double score;

  _RawItem({
    this.questionId,
    required this.title,
    required this.score,
  });
}
