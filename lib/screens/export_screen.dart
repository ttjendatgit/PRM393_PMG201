import 'package:flutter/material.dart';
import '../models/grading_result.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/empty_card.dart';
import '../widgets/stat_card.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({
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
                : ExportTable(results: results),
          ),
        ],
      ),
    );
  }
}

class ExportTable extends StatelessWidget {
  const ExportTable({super.key, required this.results});

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
              DataColumn(label: _TableHeader('STUDENT ID')),
              DataColumn(label: _TableHeader('NAME')),
              DataColumn(label: _TableHeader('FILE')),
              DataColumn(label: _TableHeader('FINAL SCORE')),
              DataColumn(label: _TableHeader('AI SUMMARY COMMENT')),
            ],
            rows: results.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item.studentId)),
                  DataCell(Text(item.studentName)),
                  DataCell(Text(item.fileName)),
                  DataCell(_ScoreBubble(score: item.finalScore)),
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

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ScoreBubble extends StatelessWidget {
  const _ScoreBubble({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 8
        ? AppColors.primary
        : score >= 7
            ? AppColors.secondary
            : AppColors.error;

    return Container(
      height: 34,
      width: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}
