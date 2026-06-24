import 'package:flutter/material.dart';
import '../features/review/services/review_api_service.dart';
import '../models/ai_mode.dart';
import '../models/grading_result.dart';
import '../models/question_result.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_card.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/score_bubble.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/table_header.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({
    super.key,
    required this.results,
    required this.onExportExcel,
    this.aiMode,
    this.backendAssessmentId,
  });

  final List<GradingResult> results;
  final Future<void> Function() onExportExcel;
  final AiMode? aiMode;
  final String? backendAssessmentId;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _exporting = false;

  // Backend mode state
  List<ReviewResultSummary> _backendResults = [];
  bool _loadingBackend = false;
  String? _loadError;

  bool get _isBackendMode =>
      widget.aiMode == AiMode.backend &&
      widget.backendAssessmentId?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    if (_isBackendMode) _loadBackendResults();
  }

  @override
  void didUpdateWidget(ExportPage old) {
    super.didUpdateWidget(old);
    if (_isBackendMode &&
        (old.backendAssessmentId != widget.backendAssessmentId ||
            old.aiMode != widget.aiMode)) {
      _loadBackendResults();
    }
  }

  // Status priority for deduplication: higher = preferred when two rows share
  // the same submissionId.
  static const _statusPriority = {'FINALIZED': 3, 'REVIEWED': 2, 'AI_GRADED': 1};

  /// Deduplicates [list] by submissionId, keeping the highest-status entry.
  List<ReviewResultSummary> _deduplicate(List<ReviewResultSummary> list) {
    final Map<String, ReviewResultSummary> byKey = {};
    for (final r in list) {
      // Debug log every entry from the backend so duplicates are visible in console.
      debugPrint('[ExportResults] gradingResultId=${r.gradingResultId} '
          'submissionId=${r.submissionId} fileName=${r.originalFileName} '
          'status=${r.reviewStatus} '
          'score=${r.finalConvertedScore ?? r.reviewedConvertedScore ?? r.aiTotalConvertedScore}');

      // Use submissionId as dedup key; fall back to gradingResultId.
      final key =
          r.submissionId.isNotEmpty ? r.submissionId : r.gradingResultId;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = r;
      } else {
        final existingPriority = _statusPriority[existing.reviewStatus] ?? 0;
        final newPriority       = _statusPriority[r.reviewStatus]       ?? 0;
        if (newPriority > existingPriority) {
          byKey[key] = r;
        }
      }
    }
    final deduped = byKey.values.toList();
    debugPrint('[ExportResults] raw=${list.length} → deduped=${deduped.length}');
    return deduped;
  }

  Future<void> _loadBackendResults() async {
    setState(() {
      _loadingBackend = true;
      _loadError      = null;
    });
    try {
      final raw  = await ReviewApiService.getReviewResults(widget.backendAssessmentId!);
      final list = _deduplicate(raw);
      if (mounted) {
        setState(() {
          _backendResults = list;
          _loadingBackend = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBackend = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _handleExport() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await widget.onExportExcel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel file exported successfully.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final standaloneResults = widget.results;
    final totalCount =
        _isBackendMode ? _backendResults.length : standaloneResults.length;

    // Compute stats from the active data source
    double avg = 0;
    String gradedLabel;
    if (_isBackendMode) {
      if (_backendResults.isNotEmpty) {
        final scores = _backendResults.map((r) =>
            r.finalConvertedScore ??
            r.reviewedConvertedScore ??
            r.aiTotalConvertedScore);
        avg = scores.reduce((a, b) => a + b) / _backendResults.length;
      }
      final reviewedCount = _backendResults
          .where((r) =>
              r.reviewStatus == 'REVIEWED' || r.reviewStatus == 'FINALIZED')
          .length;
      gradedLabel = '$reviewedCount / $totalCount';
    } else {
      if (standaloneResults.isNotEmpty) {
        avg = standaloneResults
                .map((e) => e.finalScore)
                .reduce((a, b) => a + b) /
            standaloneResults.length;
      }
      gradedLabel = standaloneResults.isEmpty ? '0%' : '100%';
    }

    final badgeLabel =
        totalCount == 0 ? 'No Results' : '$totalCount Results';

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeaderWithAction(
            title: 'Export Data',
            subtitle:
                'Review and export grading results including per-question scores and AI comments.',
            badge: badgeLabel,
            button: _exporting ? 'Exporting…' : 'Export to Excel',
            onPressed: _exporting ? null : _handleExport,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'TOTAL SUBMISSIONS',
                  value: '$totalCount',
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: StatCard(
                  label: _isBackendMode ? 'REVIEWED' : 'GRADED',
                  value: gradedLabel,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: StatCard(
                  label: 'CLASS AVERAGE',
                  value: avg.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isBackendMode
                ? _BackendResultsSection(
                    results: _backendResults,
                    loading: _loadingBackend,
                    error: _loadError,
                    onRefresh: _loadBackendResults,
                  )
                : (standaloneResults.isEmpty
                    ? const EmptyCard(
                        text:
                            'No results yet. Go to Home, import files, then click Grade with AI.',
                      )
                    : _ExportTable(results: standaloneResults)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backend results table — fetched from GET /api/assessments/{id}/review-results
// ─────────────────────────────────────────────────────────────────────────────

class _BackendResultsSection extends StatelessWidget {
  const _BackendResultsSection({
    required this.results,
    required this.loading,
    required this.onRefresh,
    this.error,
  });

  final List<ReviewResultSummary> results;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  Color _statusColor(String status) => switch (status) {
        'AI_GRADED' => AppColors.primary,
        'REVIEWED' => const Color(0xFF81C995),
        'FINALIZED' => const Color(0xFF64B5F6),
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'Backend Review Results',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: AppColors.muted),
                    onPressed: onRefresh,
                    tooltip: 'Refresh results from backend',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading && results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load results: $error',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (results.isEmpty) {
      return const EmptyCard(
        text:
            'No review results found. Grade and review submissions first, then refresh.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor:
              const WidgetStatePropertyAll(AppColors.surfaceHigh),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: TableHeader('#')),
            DataColumn(label: TableHeader('STUDENT ID')),
            DataColumn(label: TableHeader('NAME')),
            DataColumn(label: TableHeader('FILE')),
            DataColumn(label: TableHeader('AI SCORE')),
            DataColumn(label: TableHeader('REVIEWED')),
            DataColumn(label: TableHeader('FINAL')),
            DataColumn(label: TableHeader('STATUS')),
          ],
          rows: results.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final finalScore = r.finalConvertedScore ??
                r.reviewedConvertedScore ??
                r.aiTotalConvertedScore;
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(r.studentId ?? 'N/A')),
              DataCell(Text(r.studentName ?? 'N/A')),
              DataCell(SizedBox(
                width: 180,
                child: Text(
                  r.originalFileName ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(ScoreBubble(score: r.aiTotalConvertedScore)),
              DataCell(r.reviewedConvertedScore != null
                  ? ScoreBubble(score: r.reviewedConvertedScore!)
                  : const Text('—',
                      style: TextStyle(color: AppColors.muted))),
              DataCell(ScoreBubble(score: finalScore)),
              DataCell(StatusPill(
                text: r.reviewStatus,
                color: _statusColor(r.reviewStatus),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone export table (mock / OpenRouter / Gemini modes)
// ─────────────────────────────────────────────────────────────────────────────

class _ExportTable extends StatelessWidget {
  const _ExportTable({required this.results});

  final List<GradingResult> results;

  bool get _hasQuestionResults => results.first.questionResults != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: _hasQuestionResults
              ? _buildQuestionTable()
              : _buildCriteriaTable(),
        ),
      ),
    );
  }

  DataTable _buildQuestionTable() {
    final qTemplate = results.first.questionResults!;
    final totalRawMax = qTemplate.fold<double>(0, (s, q) => s + q.maxRawScore);
    final totalConvMax =
        qTemplate.fold<double>(0, (s, q) => s + q.maxConvertedScore);

    return DataTable(
      headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceHigh),
      columnSpacing: 24,
      columns: [
        const DataColumn(label: TableHeader('STUDENT ID')),
        const DataColumn(label: TableHeader('NAME')),
        const DataColumn(label: TableHeader('FILE')),
        ...qTemplate.expand((qr) => [
              DataColumn(
                  label: TableHeader(
                      '${qr.questionId.toUpperCase()} RAW')),
              DataColumn(
                  label: TableHeader(
                      '${qr.questionId.toUpperCase()} CONV')),
            ]),
        DataColumn(
            label: TableHeader('TOTAL RAW (/${totalRawMax.toInt()})')),
        DataColumn(
            label: TableHeader('TOTAL CONV (/$totalConvMax)')),
        const DataColumn(label: TableHeader('AI COMMENT')),
        const DataColumn(label: TableHeader('REVIEWER NOTE')),
      ],
      rows: results.map((item) {
        final qrs = item.questionResults ?? <QuestionResult>[];
        return DataRow(cells: [
          DataCell(Text(item.studentId)),
          DataCell(Text(item.studentName)),
          DataCell(Text(item.fileName)),
          ...qrs.expand((qr) => [
                DataCell(
                    _RawCell(value: qr.rawScore, max: qr.maxRawScore)),
                DataCell(_ConvCell(
                    value: qr.convertedScore,
                    max: qr.maxConvertedScore)),
              ]),
          DataCell(_RawCell(value: item.totalRawScore, max: totalRawMax)),
          DataCell(ScoreBubble(score: item.finalScore)),
          DataCell(
            SizedBox(
              width: 260,
              child: Text(
                item.feedback,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: 200,
              child: Text(
                item.reviewerNote,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  DataTable _buildCriteriaTable() {
    final criteriaKeys = results.first.criteriaScores.keys.toList();

    return DataTable(
      headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceHigh),
      columnSpacing: 28,
      columns: [
        const DataColumn(label: TableHeader('STUDENT ID')),
        const DataColumn(label: TableHeader('NAME')),
        const DataColumn(label: TableHeader('FILE')),
        ...criteriaKeys.map(
          (k) => DataColumn(
            label: TableHeader(
                k.length > 18 ? '${k.substring(0, 16)}…' : k.toUpperCase()),
          ),
        ),
        const DataColumn(label: TableHeader('TOTAL CONV')),
        const DataColumn(label: TableHeader('AI COMMENT')),
        const DataColumn(label: TableHeader('REVIEWER NOTE')),
      ],
      rows: results.map((item) {
        return DataRow(cells: [
          DataCell(Text(item.studentId)),
          DataCell(Text(item.studentName)),
          DataCell(Text(item.fileName)),
          ...criteriaKeys.map(
            (k) =>
                DataCell(ScoreBubble(score: item.criteriaScores[k] ?? 0.0)),
          ),
          DataCell(ScoreBubble(score: item.finalScore)),
          DataCell(
            SizedBox(
              width: 280,
              child: Text(
                item.feedback,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          DataCell(
            SizedBox(
              width: 200,
              child: Text(
                item.reviewerNote,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ]);
      }).toList(),
    );
  }
}

class _RawCell extends StatelessWidget {
  const _RawCell({required this.value, required this.max});

  final double value;
  final double max;

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? value / max : 0.0;
    final color = pct >= 0.8
        ? AppColors.primary
        : pct >= 0.6
            ? AppColors.secondary
            : AppColors.error;

    return Container(
      height: 32,
      constraints: const BoxConstraints(minWidth: 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.toInt().toString(),
        style:
            TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}

class _ConvCell extends StatelessWidget {
  const _ConvCell({required this.value, required this.max});

  final double value;
  final double max;

  @override
  Widget build(BuildContext context) {
    return ScoreBubble(score: value);
  }
}
