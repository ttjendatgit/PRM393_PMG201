import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(48, 38, 48, 38),
      child: child,
    );
  }
}
