import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum GradingStatus { pending, graded, reviewed, exported, error }

extension GradingStatusX on GradingStatus {
  String get label => switch (this) {
        GradingStatus.pending => 'Pending',
        GradingStatus.graded => 'Graded',
        GradingStatus.reviewed => 'Reviewed',
        GradingStatus.exported => 'Exported',
        GradingStatus.error => 'Error',
      };

  Color get color => switch (this) {
        GradingStatus.pending => AppColors.muted,
        GradingStatus.graded => AppColors.primary,
        GradingStatus.reviewed => const Color(0xFF81C995),
        GradingStatus.exported => const Color(0xFFFFD180),
        GradingStatus.error => AppColors.error,
      };
}
