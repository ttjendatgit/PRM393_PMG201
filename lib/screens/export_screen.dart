import 'package:flutter/material.dart';
import '../models/grading_result.dart';
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
                'Review and export PMG201c final assessment data, including scores, criteria breakdown, and AI-generated comments.',
            badge: 'Course PMG201c',
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
                        'No results yet. Go to Home, import files, then run Translate + Grade.',
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
          child: DataTable(
            headingRowColor:
                const WidgetStatePropertyAll(AppColors.surfaceHigh),
            columnSpacing: 34,
            columns: const [
              DataColumn(label: TableHeader('STUDENT ID')),
              DataColumn(label: TableHeader('NAME')),
              DataColumn(label: TableHeader('FILE')),
              DataColumn(label: TableHeader('FINAL SCORE')),
              DataColumn(label: TableHeader('AI SUMMARY COMMENT')),
            ],
            rows: results.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item.studentId)),
                  DataCell(Text(item.studentName)),
                  DataCell(Text(item.fileName)),
                  DataCell(ScoreBubble(score: item.finalScore)),
                  DataCell(
                    SizedBox(
                      width: 420,
                      child: Text(
                        item.feedback,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
