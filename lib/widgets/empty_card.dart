import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}
