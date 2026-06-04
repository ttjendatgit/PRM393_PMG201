import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ScoreBubble extends StatelessWidget {
  const ScoreBubble({super.key, required this.score});

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
