import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PageTitle extends StatelessWidget {
  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 17,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class PageHeaderWithAction extends StatelessWidget {
  const PageHeaderWithAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.button,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: PageTitle(title: title, subtitle: subtitle)),
        const SizedBox(width: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed ?? () {},
          icon: Icon(
            button.contains('Export')
                ? Icons.download_rounded
                : Icons.add_rounded,
          ),
          label: Text(
            button,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.action,
  });

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
