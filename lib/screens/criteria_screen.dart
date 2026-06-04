import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/page_frame.dart';
import '../widgets/page_title.dart';
import '../widgets/status_pill.dart';
import '../widgets/tiny_tag.dart';

class _Criteria {
  final String title;
  final int weight;
  final IconData icon;
  const _Criteria(this.title, this.weight, this.icon);
}

class CriteriaPage extends StatelessWidget {
  const CriteriaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final criteria = [
      _Criteria('Project Charter', 20, Icons.assignment_rounded),
      _Criteria('Cost / Budget Plan', 20, Icons.payments_rounded),
      _Criteria('Risk Register', 30, Icons.warning_amber_rounded),
      _Criteria('RACI Matrix', 30, Icons.group_rounded),
    ];

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeaderWithAction(
            title: 'PMG201c Criteria Matrix',
            subtitle:
                'Weighted evaluation dimensions for PMG201c Practical Exam 2. Total raw score 100 → converted to /10.',
            badge: 'Total Weight 100%',
            button: 'Add Criteria',
          ),
          const SizedBox(height: 26),
          Expanded(
            child: GridView.builder(
              itemCount: criteria.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 390,
                mainAxisExtent: 280,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemBuilder: (context, index) {
                final item = criteria[index];

                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        minHeight: 4,
                        value: item.weight / 100,
                        backgroundColor: AppColors.surfaceHighest,
                        color: AppColors.primary,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(item.icon, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    text: '${item.weight}%',
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'PMG201c rubric dimension. The AI will compare the student submission against this criterion and suggest score breakdown.',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.45,
                                ),
                              ),
                              const Spacer(),
                              const Row(
                                children: [
                                  TinyTag(text: 'Core'),
                                  SizedBox(width: 8),
                                  TinyTag(text: 'PMG201c'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
