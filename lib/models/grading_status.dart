import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum GradingStatus { pending, grading, graded, reviewed, finalized, exported, error }

extension GradingStatusX on GradingStatus {
  String get label => switch (this) {
        GradingStatus.pending => 'Pending',
        GradingStatus.grading => 'Grading',
        GradingStatus.graded => 'Graded',
        GradingStatus.reviewed => 'Reviewed',
        GradingStatus.finalized => 'Finalized',
        GradingStatus.exported => 'Exported',
        GradingStatus.error => 'Error',
      };

  Color get color => switch (this) {
        GradingStatus.pending => AppColors.muted,
        GradingStatus.grading => const Color(0xFFD97706),
        GradingStatus.graded => AppColors.primary,
        GradingStatus.reviewed => AppColors.success,
        GradingStatus.finalized => AppColors.secondary,
        GradingStatus.exported => const Color(0xFF7C3AED),
        GradingStatus.error => AppColors.error,
      };
}
