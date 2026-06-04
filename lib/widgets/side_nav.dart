import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class BrandBlock extends StatelessWidget {
  const BrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: AppColors.text),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PMG GradeAI',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'ACADEMIC CONSOLE',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_rounded, 'Home'),
      _NavItem(Icons.quiz_rounded, 'Assessment'),
      _NavItem(Icons.rule_rounded, 'Criteria'),
      _NavItem(Icons.grading_rounded, 'Grading'),
      _NavItem(Icons.ios_share_rounded, 'Export'),
      _NavItem(Icons.settings_rounded, 'Settings'),
    ];

    return Container(
      width: 264,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(right: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandBlock(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Grading Task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        items[i].icon,
                        color: selectedIndex == i
                            ? AppColors.text
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? AppColors.text
                              : AppColors.muted,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          const Divider(color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceHighest,
                child: Icon(Icons.person_rounded, color: AppColors.muted),
              ),
              SizedBox(width: 12),
              Text(
                'PMG201c Console',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
