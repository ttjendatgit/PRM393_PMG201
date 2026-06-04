import 'package:flutter/material.dart';
import '../models/grading_result.dart';
import '../models/question_result.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_card.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/score_bubble.dart';
import '../widgets/stat_card.dart';
import '../widgets/table_header.dart';

class ExportPage extends StatelessWidget {
  const ExportPage({
    super.key,
    required this.results,
    required this.onExportExcel,
  });

  final List<GradingResult> results;
  final VoidCallback onExportExcel;

  @override
  Widget build(BuildContext context) {
    final avg = results.isEmpty
        ? 0.0
        : results.map((e) => e.finalScore).reduce((a, b) => a + b) /
            results.length;

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeaderWithAction(
            title: 'Export Data',
            subtitle:
                'Review and export grading results including per-question scores and AI comments.',
            badge: results.isEmpty ? 'No Results' : '${results.length} Results',
            button: 'Export to Excel',
            onPressed: onExportExcel,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'TOTAL SUBMISSIONS',
                  value: '${results.length}',
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: StatCard(
                  label: 'GRADED',
                  value: results.isEmpty ? '0%' : '100%',
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
            child: results.isEmpty
                ? const EmptyCard(
                    text:
                        'No results yet. Go to Home, import files, then click Grade with AI.',
                  )
                : _ExportTable(results: results),
          ),
        ],
      ),
    );
  }
}

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

  // Full table with per-question raw + converted columns (OpenRouter results)
  DataTable _buildQuestionTable() {
    final qTemplate = results.first.questionResults!;

    return DataTable(
      headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceHigh),
      columnSpacing: 24,
      columns: [
        const DataColumn(label: TableHeader('STUDENT ID')),
        const DataColumn(label: TableHeader('NAME')),
        const DataColumn(label: TableHeader('FILE')),
        ...qTemplate.expand((qr) => [
          DataColumn(label: TableHeader('${qr.questionId.toUpperCase()} RAW')),
          DataColumn(label: TableHeader('${qr.questionId.toUpperCase()} CONV')),
        ]),
        const DataColumn(label: TableHeader('TOTAL RAW')),
        const DataColumn(label: TableHeader('TOTAL CONV')),
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
            DataCell(_RawCell(value: qr.rawScore, max: qr.maxRawScore)),
            DataCell(_ConvCell(value: qr.convertedScore, max: qr.maxConvertedScore)),
          ]),
          DataCell(_RawCell(value: item.totalRawScore, max: _totalRawMax(qTemplate))),
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

  // Fallback table using criteriaScores (mock results)
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
            label: TableHeader(k.length > 18 ? '${k.substring(0, 16)}…' : k.toUpperCase()),
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
            (k) => DataCell(ScoreBubble(score: item.criteriaScores[k] ?? 0.0)),
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

  double _totalRawMax(List<QuestionResult> qs) =>
      qs.fold(0, (sum, q) => sum + q.maxRawScore);
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
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
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
