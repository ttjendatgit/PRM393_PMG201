import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 48),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search students, criteria, files...',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 24),
          const Icon(Icons.notifications_none_rounded, color: AppColors.muted),
          const SizedBox(width: 16),
          const Icon(Icons.settings_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
